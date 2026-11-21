import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'neural_tts_types.dart';

/// Voz neural offline (sherpa-onnx) só em Android e iOS. Mantém os testes na VM livres de FFI.
bool nativeTtsIsSupported() => Platform.isAndroid || Platform.isIOS;

/// Arquivos de um modelo prontos para o sherpa-onnx (Kokoro ou Piper/VITS).
class NeuralModelFiles {
  const NeuralModelFiles.kokoro({
    required this.model,
    required String this.voices,
    required this.tokens,
    required this.espeakDir,
  }) : isKokoro = true;
  const NeuralModelFiles.piper({required this.model, required this.tokens, required this.espeakDir})
    : isKokoro = false,
      voices = null;

  final bool isKokoro;
  final String model;
  final String? voices;
  final String tokens;
  final String espeakDir;
}

/// A voz Kokoro vem dentro do app, em partes (`assets/voice/kokoro/`, gerada por
/// `tool/fetch_kokoro_model.py`). O sherpa-onnx precisa de arquivos de verdade, então ela é
/// copiada uma vez por versão para a pasta do app, uma parte por vez (memória limitada).
class BundledKokoro {
  BundledKokoro(this.dir, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetDir = 'assets/voice/kokoro';

  final Directory dir;
  final AssetBundle _bundle;

  File get _versionFile => File('${dir.path}/.version');

  NeuralModelFiles get files => NeuralModelFiles.kokoro(
    model: '${dir.path}/model.int8.onnx',
    voices: '${dir.path}/voices.bin',
    tokens: '${dir.path}/tokens.txt',
    espeakDir: '${dir.path}/espeak-ng-data',
  );

  /// Instala se preciso e devolve o tamanho em bytes, ou `null` se o app foi compilado sem a voz.
  Future<int?> install({void Function(double progress)? onProgress}) async {
    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(await _bundle.loadString('$assetDir/manifest.json', cache: false)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final version = manifest['version'] as String;
    final files = (manifest['files'] as List).cast<Map<String, dynamic>>();
    final total = files.fold<int>(0, (sum, f) => sum + (f['size'] as int));
    if (await _versionFile.exists() && await _versionFile.readAsString() == version) return total;

    if (await dir.exists()) await dir.delete(recursive: true);
    var done = 0;
    for (final f in files) {
      final out = File('${dir.path}/${f['path']}');
      await out.parent.create(recursive: true);
      final sink = out.openWrite();
      try {
        for (final part in (f['parts'] as List).cast<String>()) {
          final data = await _bundle.load('$assetDir/$part');
          sink.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
      if (await out.length() != f['size']) throw StateError('Voz Kokoro incompleta: ${f['path']}');
      done += f['size'] as int;
      onProgress?.call(done / total);
    }
    await _versionFile.writeAsString(version, flush: true);
    return total;
  }
}

/// Vozes Piper baixadas pelo usuário: `<baseDir>/<id>/<archive>/…` + `.ready` com o tamanho em bytes.
class PiperStore {
  PiperStore(this.baseDir);

  final Directory baseDir;

  Directory _dir(PiperVoice v) => Directory('${baseDir.path}/${v.id}');
  File _ready(PiperVoice v) => File('${_dir(v).path}/.ready');

  NeuralModelFiles files(PiperVoice v) {
    final d = '${_dir(v).path}/${v.archive}';
    return NeuralModelFiles.piper(model: '$d/${v.onnx}', tokens: '$d/tokens.txt', espeakDir: '$d/espeak-ng-data');
  }

  /// Vozes instaladas (id → bytes). Lê só os arquivos `.ready`.
  Future<Map<String, int>> installed() async {
    final result = <String, int>{};
    for (final v in PiperVoice.all) {
      final ready = _ready(v);
      if (await ready.exists()) result[v.id] = int.tryParse(await ready.readAsString()) ?? 0;
    }
    return result;
  }

  Future<void> remove(PiperVoice v) async {
    if (await _dir(v).exists()) await _dir(v).delete(recursive: true);
  }

  /// Baixa, confere o SHA-256 e extrai (em outro Isolate). [isCancelled] interrompe o download.
  Future<void> download(
    PiperVoice v, {
    required void Function(double? progress) onProgress,
    bool Function()? isCancelled,
    http.Client? client,
    String? url,
    String? sha256Hex,
  }) async {
    await remove(v);
    final dir = await _dir(v).create(recursive: true);
    final part = File('${dir.path}/download.part');
    final httpClient = client ?? http.Client();
    try {
      final resp = await httpClient.send(http.Request('GET', Uri.parse(url ?? v.url)));
      if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode} ao baixar a voz ${v.label}');
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in resp.stream) {
          if (isCancelled?.call() ?? false) throw const _Cancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress(total > 0 ? received / total : null);
        }
      } finally {
        await sink.close();
      }
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString() != (sha256Hex ?? v.sha256)) throw StateError('Arquivo da voz ${v.label} corrompido.');

      final partPath = part.path;
      final outPath = dir.path;
      await Isolate.run(() => extractFileToDisk(partPath, outPath, throwOnError: true));
      await part.delete();
      final model = files(v);
      if (!await File(model.model).exists() || !await File(model.tokens).exists()) {
        throw StateError('Pacote da voz ${v.label} sem os arquivos esperados.');
      }
      var bytes = 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) bytes += await e.length();
      }
      await _ready(v).writeAsString('$bytes', flush: true);
    } catch (_) {
      await remove(v);
      rethrow;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Um modelo carregado num Isolate próprio. A síntese roda lá; a UI nunca espera por ela.
class _Worker {
  _Worker._(this.key, this._isolate, this._sendPort, this._replies, Stream<dynamic> exits) {
    _replySub = _replies.listen((msg) {
      if (msg is! Map) return;
      if (msg['error'] != null) debugPrint('Voz neural: ${msg['error']}');
      _pending.remove(msg['id'])?.complete(msg['ok'] == true);
    });
    _exitSub = exits.listen((_) => _shutdown());
  }

  final String key;
  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _replies;
  late final StreamSubscription<dynamic> _replySub;
  late final StreamSubscription<dynamic> _exitSub;
  final Map<int, Completer<bool>> _pending = {};
  int _nextId = 1;
  bool _closed = false;

  /// Chamado se o Isolate morrer sozinho (erro), para o motor não tentar de novo em laço.
  void Function()? onDied;

  static Future<_Worker> spawn(String key, NeuralModelFiles files) async {
    final handshake = ReceivePort();
    final replies = ReceivePort();
    final exitPort = ReceivePort();
    final exits = exitPort.asBroadcastStream();
    // Deixa um núcleo livre para a interface e o áudio (medido no emulador: com menos threads
    // a síntese fica mais lenta que a fala e surgem pausas entre os trechos).
    final threads = (Platform.numberOfProcessors - 1).clamp(1, 4);
    final isolate = await Isolate.spawn(
      _main,
      [handshake.sendPort, replies.sendPort, files, threads],
      onExit: exitPort.sendPort,
      onError: exitPort.sendPort,
    );
    final first = await Future.any([handshake.first, exits.first.then((_) => 'o Isolate terminou ao carregar')]);
    handshake.close();
    if (first is SendPort) return _Worker._(key, isolate, first, replies, exits);
    replies.close();
    exitPort.close();
    isolate.kill(priority: Isolate.immediate);
    throw StateError('Falha ao carregar a voz neural: $first');
  }

  static Future<void> _main(List<Object> args) async {
    final handshake = args[0] as SendPort;
    final replies = args[1] as SendPort;
    final files = args[2] as NeuralModelFiles;
    final threads = args[3] as int;

    final sherpa_onnx.OfflineTts tts;
    try {
      sherpa_onnx.initBindings(); // cada Isolate inicializa os próprios bindings FFI
      final model = files.isKokoro
          ? sherpa_onnx.OfflineTtsModelConfig(
              kokoro: sherpa_onnx.OfflineTtsKokoroModelConfig(
                model: files.model,
                voices: files.voices!,
                tokens: files.tokens,
                dataDir: files.espeakDir,
                lang: 'pt-br',
              ),
              numThreads: threads,
              debug: false,
            )
          : sherpa_onnx.OfflineTtsModelConfig(
              vits: sherpa_onnx.OfflineTtsVitsModelConfig(
                model: files.model,
                tokens: files.tokens,
                dataDir: files.espeakDir,
              ),
              numThreads: threads,
              debug: false,
            );
      tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model: model, maxNumSenetences: 1));
    } catch (e) {
      handshake.send('$e');
      return;
    }

    final inbox = ReceivePort();
    handshake.send(inbox.sendPort);
    await for (final msg in inbox) {
      if (msg is! Map) continue;
      final id = msg['id'] as int;
      if (msg['cmd'] == 'dispose') {
        tts.free();
        replies.send({'id': id, 'ok': true});
        inbox.close();
        break;
      }
      try {
        final audio = tts.generateWithConfig(
          text: msg['text'] as String,
          config: sherpa_onnx.OfflineTtsGenerationConfig(
            sid: msg['sid'] as int,
            speed: msg['speed'] as double,
            extra: files.isKokoro ? {'lang': msg['lang'] as String} : const {},
          ),
        );
        final ok =
            audio.samples.isNotEmpty &&
            sherpa_onnx.writeWave(filename: msg['wav'] as String, samples: audio.samples, sampleRate: audio.sampleRate);
        replies.send({'id': id, 'ok': ok});
      } catch (e) {
        replies.send({'id': id, 'ok': false, 'error': '$e'});
      }
    }
  }

  Future<bool> synthesize({
    required String text,
    required int sid,
    required double speed,
    required String lang,
    required String wav,
  }) {
    if (_closed) return Future.value(false);
    final id = _nextId++;
    final c = _pending[id] = Completer<bool>();
    _sendPort.send({'cmd': 'synth', 'id': id, 'text': text, 'sid': sid, 'speed': speed, 'lang': lang, 'wav': wav});
    return c.future;
  }

  void _shutdown() {
    if (_closed) return;
    _closed = true;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pending.clear();
    unawaited(_replySub.cancel());
    unawaited(_exitSub.cancel());
    _replies.close();
    onDied?.call();
  }

  Future<void> dispose() async {
    if (_closed) return;
    onDied = null;
    final id = _nextId++;
    final c = _pending[id] = Completer<bool>();
    _sendPort.send({'cmd': 'dispose', 'id': id});
    try {
      await c.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      _isolate.kill(priority: Isolate.immediate);
    }
    _shutdown();
  }
}

/// Modelo e locutor escolhidos para um trecho.
typedef _Choice = ({String key, NeuralModelFiles files, int sid, String lang});

class _NativeEngine {
  final List<void Function(NeuralTtsStatus)> _listeners = [];
  NeuralTtsStatus _status = const NeuralTtsStatus();
  Future<void> Function(String wavPath)? _play;

  Future<void>? _prepared;
  String? _tmpDir;
  BundledKokoro? _kokoro;
  int? _kokoroBytes; // null = app sem a voz embutida
  PiperStore? _piper;
  Map<String, int> _piperBytes = const {};

  _Worker? _worker;
  Future<_Worker>? _spawning;
  final Set<String> _failed = {}; // modelos que falharam: não tenta de novo nesta sessão
  Timer? _idleTimer;

  ({String key, Future<bool> done, int slot})? _prefetch;
  int _slot = 0;
  int _epoch = 0;
  bool _cancelDownload = false;
  int _lastEmitMs = 0;

  void _emit(NeuralTtsState state, {double? progress, String? label, String? error, bool throttle = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (throttle && now - _lastEmitMs < 500) return;
    _lastEmitMs = now;
    _status = NeuralTtsStatus(
      state: state,
      progress: progress,
      label: label,
      error: error,
      device: _kokoroBytes != null ? 'onnx-cpu' : null,
      cached: _kokoroBytes != null,
      cacheBytes: _kokoroBytes ?? 0,
      piperBytes: _piperBytes,
    );
    for (final l in List.of(_listeners)) {
      l(_status);
    }
  }

  void _emitIdle() => _emit(_kokoroBytes != null ? NeuralTtsState.ready : NeuralTtsState.idle);

  /// Copia a voz embutida (só na 1ª vez de cada versão) e lê o que já está instalado.
  Future<void> prepare() => _prepared ??= _doPrepare();

  Future<void> _doPrepare() async {
    final support = (await getApplicationSupportDirectory()).path;
    _tmpDir = (await getTemporaryDirectory()).path;
    // Versões até a 1.5 baixavam o Kokoro inteiro aqui (~330 MB extraídos).
    final legacy = Directory('$support/kokoro-v1');
    if (await legacy.exists()) await legacy.delete(recursive: true);

    _piper = PiperStore(Directory('$support/piper'));
    _piperBytes = await _piper!.installed();
    _kokoro = BundledKokoro(Directory('$support/kokoro'));
    try {
      _kokoroBytes = await _kokoro!.install(
        onProgress: (p) =>
            _emit(NeuralTtsState.loading, progress: p, label: 'Preparando voz offline (1ª vez)…', throttle: true),
      );
    } catch (e) {
      debugPrint('Não foi possível instalar a voz Kokoro embutida: $e');
      _emit(NeuralTtsState.error, error: '$e');
      return;
    }
    _emitIdle();
  }

  _Choice? _choose(String voice, String language) {
    final piper = PiperVoice.byId(voice);
    if (piper != null && _piperBytes.containsKey(piper.id) && language.toLowerCase().startsWith('pt')) {
      return (key: piper.id, files: _piper!.files(piper), sid: 0, lang: 'pt-br');
    }
    if (_kokoroBytes == null) return null;
    final speaker = resolveKokoroSpeaker(voiceId: voice, language: language);
    return (key: 'kokoro', files: _kokoro!.files, sid: speaker.sid, lang: speaker.espeakLang);
  }

  Future<_Worker> _workerFor(_Choice choice) async {
    final current = _worker;
    if (current != null && current.key == choice.key) return current;
    final spawning = _spawning;
    if (spawning != null) {
      final w = await spawning;
      if (w.key == choice.key) return w;
    }
    _worker = null;
    await current?.dispose();
    final task = _spawning = _Worker.spawn(choice.key, choice.files);
    try {
      final w = await task;
      w.onDied = () {
        if (identical(_worker, w)) _worker = null;
        _failed.add(w.key);
      };
      return _worker = w;
    } finally {
      _spawning = null;
    }
  }

  /// Libera a memória do modelo depois de alguns minutos sem leitura.
  void _scheduleRelease() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 5), () async {
      final w = _worker;
      _worker = null;
      await w?.dispose();
    });
  }

  String _wav(int slot) => '$_tmpDir/vs_tts_$slot.wav';

  Future<bool> speak(
    String text,
    double speed, {
    required String voice,
    required String language,
    String? nextText,
  }) async {
    if (!nativeTtsIsSupported() || _play == null) return false;
    final clean = normalizeTextForKokoro(text);
    if (clean.isEmpty) return true;
    final epoch = _epoch;
    await prepare();
    final choice = _choose(voice, language);
    if (choice == null || _failed.contains(choice.key)) return false;
    _idleTimer?.cancel();

    final _Worker worker;
    try {
      if (_worker?.key != choice.key) _emit(NeuralTtsState.loading, label: 'Carregando voz neural…');
      worker = await _workerFor(choice);
    } catch (e) {
      debugPrint('Voz neural indisponível, usando a do sistema: $e');
      _failed.add(choice.key);
      _emit(NeuralTtsState.error, error: '$e');
      return false;
    }
    if (_epoch != epoch) return true;

    final s = speed.clamp(0.5, 2.0).toDouble();
    String keyOf(String t) => '${choice.key}|${choice.sid}|$s|$t';
    final pre = _prefetch;
    _prefetch = null;
    final reuse = pre != null && pre.key == keyOf(clean);
    final slot = reuse ? pre.slot : 1 - _slot;
    final done = reuse
        ? pre.done
        : worker.synthesize(text: clean, sid: choice.sid, speed: s, lang: choice.lang, wav: _wav(slot));
    final ok = await done;
    if (_epoch != epoch) return true;
    if (!ok) return false;
    _slot = slot;

    // Sintetiza o próximo trecho enquanto este toca.
    final next = nextText == null ? '' : normalizeTextForKokoro(nextText);
    if (next.isNotEmpty) {
      final nextSlot = 1 - slot;
      _prefetch = (
        key: keyOf(next),
        slot: nextSlot,
        done: worker.synthesize(text: next, sid: choice.sid, speed: s, lang: choice.lang, wav: _wav(nextSlot)),
      );
    }

    _emit(NeuralTtsState.speaking);
    try {
      await _play!(_wav(slot));
      return true;
    } catch (e) {
      debugPrint('Erro ao tocar a voz neural: $e');
      return _epoch != epoch;
    } finally {
      if (_epoch == epoch) {
        _emitIdle();
        _scheduleRelease();
      }
    }
  }

  void stop() {
    _epoch++;
    _prefetch = null;
    if (_status.state == NeuralTtsState.speaking) _emitIdle();
    if (_worker != null) _scheduleRelease();
  }

  Future<bool> downloadPiper(String voiceId) async {
    final v = PiperVoice.byId(voiceId);
    if (v == null || !nativeTtsIsSupported()) return false;
    await prepare();
    if (_status.isBusy) return false;
    _cancelDownload = false;
    _emit(NeuralTtsState.downloading, progress: 0, label: 'Baixando voz ${v.label}…');
    try {
      await _piper!.download(
        v,
        isCancelled: () => _cancelDownload,
        onProgress: (p) => _emit(
          NeuralTtsState.downloading,
          progress: p,
          label: 'Baixando voz ${v.label}${p == null ? '' : ' (${(p * 100).round()}%)'}…',
          throttle: true,
        ),
      );
      _piperBytes = await _piper!.installed();
      _failed.remove(v.id);
      _emitIdle();
      return true;
    } on _Cancelled {
      _emitIdle();
      return false;
    } catch (e) {
      debugPrint('Erro ao baixar a voz Piper: $e');
      _emit(NeuralTtsState.error, error: '$e');
      return false;
    }
  }

  Future<void> removePiper(String voiceId) async {
    final v = PiperVoice.byId(voiceId);
    if (v == null || !nativeTtsIsSupported()) return;
    await prepare();
    if (_worker?.key == v.id) {
      stop();
      final w = _worker;
      _worker = null;
      await w?.dispose();
    }
    await _piper!.remove(v);
    _piperBytes = await _piper!.installed();
    _emitIdle();
  }
}

final _engine = _NativeEngine();

/// Registra quem toca os WAV gerados (o player do `ReadingAudioHandler`): um só player no app.
void nativeTtsUsePlayer(Future<void> Function(String wavPath) play) => _engine._play = play;

Future<bool> nativeTtsSpeak(
  String text,
  double speed, {
  String voice = 'pf_dora',
  String language = 'pt-BR',
  String? nextText,
}) => _engine.speak(text, speed, voice: voice, language: language, nextText: nextText);

void nativeTtsStop() => _engine.stop();

Future<void> nativeTtsPrepare() async {
  if (nativeTtsIsSupported()) await _engine.prepare();
}

Future<NeuralTtsStatus> nativeTtsRefreshStatus() async {
  if (!nativeTtsIsSupported()) return const NeuralTtsStatus();
  await _engine.prepare();
  return _engine._status;
}

void nativeTtsListenStatus(void Function(NeuralTtsStatus status) onChange) {
  _engine._listeners.add(onChange);
  onChange(_engine._status);
}

Future<bool> nativeTtsDownloadPiper(String voiceId) => _engine.downloadPiper(voiceId);

void nativeTtsCancelDownload() => _engine._cancelDownload = true;

Future<void> nativeTtsRemovePiper(String voiceId) => _engine.removePiper(voiceId);
