import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'neural_tts_types.dart';

/// Retorna `true` em Android e iOS, onde o binário nativo do `sherpa_onnx`
/// acompanha o app. Mantém testes Linux VM livres de FFI/rede.
bool nativeTtsIsSupported() => Platform.isAndroid || Platform.isIOS;

/// Caminhos validados do pacote Kokoro-82M v1.0 extraído no armazenamento local.
class KokoroModelFiles {
  const KokoroModelFiles({
    required this.modelPath,
    required this.voicesPath,
    required this.tokensPath,
    required this.espeakDataDir,
  });

  final String modelPath;
  final String voicesPath;
  final String tokensPath;
  final String espeakDataDir;
}

/// Gerencia download, extração streaming (`.tar.bz2`), validação e limpeza do
/// modelo Kokoro-82M multi-idiomas int8 (`sherpa-onnx`).
class KokoroModelStore {
  KokoroModelStore(this.baseDir);

  static const archiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2';
  static const extractSubdir = 'kokoro-int8-multi-lang-v1_0';
  static const readySentinelName = '.ready-v1';
  static const _partFileName = 'model.tar.bz2.part';
  static const defaultMinArchiveBytes = 10 * 1024 * 1024;

  final Directory baseDir;

  File get readySentinel => File('${baseDir.path}/$readySentinelName');

  /// Procura os arquivos obrigatórios do modelo em `<baseDir>/kokoro-int8-multi-lang-v1_0`
  /// (padrão do tarball) ou diretamente em `<baseDir>`.
  KokoroModelFiles? resolveModelFiles() {
    for (final dir in [Directory('${baseDir.path}/$extractSubdir'), baseDir]) {
      if (!dir.existsSync()) continue;
      final int8Model = File('${dir.path}/model.int8.onnx');
      final fullModel = File('${dir.path}/model.onnx');
      final model = int8Model.existsSync()
          ? int8Model
          : fullModel.existsSync()
          ? fullModel
          : null;
      final voices = File('${dir.path}/voices.bin');
      final tokens = File('${dir.path}/tokens.txt');
      final espeakDir = Directory('${dir.path}/espeak-ng-data');

      if (model != null &&
          voices.existsSync() &&
          tokens.existsSync() &&
          espeakDir.existsSync() &&
          espeakDir.listSync().isNotEmpty) {
        return KokoroModelFiles(
          modelPath: model.path,
          voicesPath: voices.path,
          tokensPath: tokens.path,
          espeakDataDir: espeakDir.path,
        );
      }
    }
    return null;
  }

  bool get isReady => readySentinel.existsSync() && resolveModelFiles() != null;

  int computeCacheBytes() {
    if (!baseDir.existsSync()) return 0;
    var total = 0;
    for (final entity in baseDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && !entity.path.endsWith(_partFileName)) {
        total += entity.lengthSync();
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    if (baseDir.existsSync()) {
      await baseDir.delete(recursive: true);
    }
  }

  Future<KokoroModelFiles> ensureDownloaded({
    required void Function(double? progress, String label) onProgress,
    http.Client? client,
    String? url,
    int minArchiveBytes = defaultMinArchiveBytes,
  }) async {
    final existing = resolveModelFiles();
    if (readySentinel.existsSync() && existing != null) {
      return existing;
    }

    if (!baseDir.existsSync()) {
      await baseDir.create(recursive: true);
    }

    // Limpa eventual extração parcial anterior sem sentinela válida.
    final subDir = Directory('${baseDir.path}/$extractSubdir');
    if (!readySentinel.existsSync() && subDir.existsSync()) {
      await subDir.delete(recursive: true);
    }
    if (readySentinel.existsSync()) {
      await readySentinel.delete();
    }

    final partFile = File('${baseDir.path}/$_partFileName');
    if (partFile.existsSync()) {
      await partFile.delete();
    }

    final ownedClient = client == null;
    final httpClient = client ?? http.Client();

    try {
      onProgress(0.02, 'Conectando para baixar voz neural Kokoro (~126 MB)…');
      final req = http.Request('GET', Uri.parse(url ?? archiveUrl));
      req.headers['User-Agent'] = 'ViaSacra-TTS/1.0';
      final resp = await httpClient.send(req);
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode} ao baixar pacote Kokoro');
      }

      final total = resp.contentLength ?? 0;
      var received = 0;
      var lastReportMs = 0;
      final sink = partFile.openWrite();
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - lastReportMs >= 150) {
            lastReportMs = nowMs;
            if (total > 0) {
              final ratio = (received / total).clamp(0.0, 1.0);
              onProgress(0.02 + ratio * 0.80, 'Baixando voz neural Kokoro (${(ratio * 100).round()}%)…');
            } else {
              onProgress(null, 'Baixando voz neural Kokoro…');
            }
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (received < minArchiveBytes) {
        throw StateError('Download incompleto do modelo Kokoro ($received bytes)');
      }

      onProgress(0.85, 'Extraindo pacote de voz offline…');
      final partPath = partFile.path;
      final basePath = baseDir.path;
      await Isolate.run(() => _extractTarBz2(partPath, basePath));

      final files = resolveModelFiles();
      if (files == null) {
        throw StateError('Arquivos do modelo Kokoro ausentes após extração.');
      }

      await readySentinel.writeAsString(DateTime.now().toUtc().toIso8601String(), flush: true);
      return files;
    } finally {
      if (partFile.existsSync()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      if (ownedClient) {
        httpClient.close();
      }
    }
  }

  static Future<void> _extractTarBz2(String archivePath, String outputDir) =>
      extractFileToDisk(archivePath, outputDir, throwOnError: true);
}

class _KokoroWorker {
  _KokoroWorker._(this._isolate, this._sendPort, this._receivePort) {
    _sub = _receivePort.listen((msg) {
      if (msg is Map) {
        final id = msg['id'] as int?;
        final ok = msg['ok'] == true;
        final err = msg['error'] as String?;
        if (err != null) debugPrint('Erro no Isolate Kokoro: $err');
        if (id != null) {
          _pending.remove(id)?.complete(ok);
        }
      }
    });
  }

  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  late final StreamSubscription<dynamic> _sub;
  final Map<int, Completer<bool>> _pending = {};
  int _nextId = 1;
  bool _disposed = false;

  static Future<_KokoroWorker> spawn(KokoroModelFiles files) async {
    final handshakePort = ReceivePort();
    final runtimePort = ReceivePort();
    final threads = Platform.numberOfProcessors.clamp(1, 4);

    final isolate = await Isolate.spawn(_isolateMain, [handshakePort.sendPort, runtimePort.sendPort, files, threads]);
    final firstMsg = await handshakePort.first;
    handshakePort.close();

    if (firstMsg is SendPort) {
      return _KokoroWorker._(isolate, firstMsg, runtimePort);
    }

    runtimePort.close();
    isolate.kill(priority: Isolate.immediate);
    throw StateError('Falha ao inicializar Kokoro offline: $firstMsg');
  }

  static Future<void> _isolateMain(List<Object> args) async {
    final handshakeTo = args[0] as SendPort;
    final replyTo = args[1] as SendPort;
    final files = args[2] as KokoroModelFiles;
    final numThreads = args[3] as int;

    sherpa_onnx.OfflineTts? tts;
    try {
      // Cada Isolate precisa inicializar seus próprios bindings FFI.
      sherpa_onnx.initBindings();
      final config = sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          kokoro: sherpa_onnx.OfflineTtsKokoroModelConfig(
            model: files.modelPath,
            voices: files.voicesPath,
            tokens: files.tokensPath,
            dataDir: files.espeakDataDir,
            lang: 'pt-br',
          ),
          numThreads: numThreads,
          debug: false,
        ),
        maxNumSenetences: 1,
      );
      tts = sherpa_onnx.OfflineTts(config);
    } catch (e) {
      handshakeTo.send('Erro initBindings/OfflineTts: $e');
      return;
    }

    final inbox = ReceivePort();
    handshakeTo.send(inbox.sendPort);

    await for (final msg in inbox) {
      if (msg is! Map) continue;
      final cmd = msg['cmd'];
      final id = msg['id'] as int?;

      if (cmd == 'dispose') {
        tts.free();
        if (id != null) replyTo.send({'id': id, 'ok': true});
        inbox.close();
        break;
      }

      if (cmd == 'synth' && id != null) {
        try {
          final clean = normalizeTextForKokoro((msg['text'] as String?) ?? '');
          if (clean.isEmpty) {
            replyTo.send({'id': id, 'ok': false, 'error': 'Texto vazio após normalização'});
            continue;
          }
          final sid = msg['sid'] as int;
          final speed = (msg['speed'] as num).toDouble();
          final espeakLang = (msg['espeakLang'] as String?) ?? 'pt-br';
          final wavPath = msg['wavPath'] as String;

          final audio = tts.generateWithConfig(
            text: clean,
            config: sherpa_onnx.OfflineTtsGenerationConfig(sid: sid, speed: speed, extra: {'lang': espeakLang}),
          );
          if (audio.samples.isEmpty || audio.sampleRate <= 0) {
            replyTo.send({'id': id, 'ok': false, 'error': 'Amostras vazias geradas pelo Kokoro'});
            continue;
          }
          final written = sherpa_onnx.writeWave(
            filename: wavPath,
            samples: audio.samples,
            sampleRate: audio.sampleRate,
          );
          replyTo.send({'id': id, 'ok': written});
        } catch (e) {
          replyTo.send({'id': id, 'ok': false, 'error': '$e'});
        }
      }
    }
  }

  Future<bool> synthesize({
    required String text,
    required int sid,
    required double speed,
    required String espeakLang,
    required String wavPath,
  }) {
    if (_disposed) return Future.value(false);
    final id = _nextId++;
    final completer = Completer<bool>();
    _pending[id] = completer;
    _sendPort.send({
      'cmd': 'synth',
      'id': id,
      'text': text,
      'sid': sid,
      'speed': speed,
      'espeakLang': espeakLang,
      'wavPath': wavPath,
    });
    return completer.future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final id = _nextId++;
    final completer = Completer<bool>();
    _pending[id] = completer;
    _sendPort.send({'cmd': 'dispose', 'id': id});
    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      _isolate.kill(priority: Isolate.immediate);
    }
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pending.clear();
    await _sub.cancel();
    _receivePort.close();
  }
}

class _PrefetchedChunk {
  const _PrefetchedChunk({required this.key, required this.slot, required this.wavPath, required this.future});

  final String key;
  final int slot;
  final String wavPath;
  final Future<bool> future;
}

class _NativeKokoroEngine {
  AudioPlayer? _player;
  KokoroModelStore? _store;
  _KokoroWorker? _worker;
  Future<_KokoroWorker>? _readyTask;
  _PrefetchedChunk? _prefetched;
  Completer<void>? _activePlayCompleter;
  int _activeSlot = 0;
  int _epoch = 0;

  NeuralTtsStatus _status = const NeuralTtsStatus();
  final List<void Function(NeuralTtsStatus)> _listeners = [];

  void _emit(NeuralTtsStatus next) {
    _status = next;
    for (final l in List.of(_listeners)) {
      l(next);
    }
  }

  Future<KokoroModelStore> _getStore() async {
    if (_store != null) return _store!;
    final supportDir = await getApplicationSupportDirectory();
    final store = KokoroModelStore(Directory('${supportDir.path}/kokoro-v1'));
    _store = store;
    return store;
  }

  Future<String> _wavPathForSlot(int slot) async {
    final tmp = await getTemporaryDirectory();
    return '${tmp.path}/vs_kokoro_$slot.wav';
  }

  Future<_KokoroWorker> _ensureReady() {
    final existing = _worker;
    if (existing != null) return Future.value(existing);
    final inflight = _readyTask;
    if (inflight != null) return inflight;

    final task = () async {
      final store = await _getStore();
      final files = await store.ensureDownloaded(
        onProgress: (progress, label) {
          final isExtracting = (progress ?? 0) >= 0.84;
          _emit(
            NeuralTtsStatus(
              state: isExtracting ? NeuralTtsState.loading : NeuralTtsState.downloading,
              progress: progress,
              label: label,
              device: 'onnx-cpu',
              cached: false,
              cacheBytes: 0,
            ),
          );
        },
      );

      final bytes = store.computeCacheBytes();
      _emit(
        NeuralTtsStatus(
          state: NeuralTtsState.loading,
          progress: 0.96,
          label: 'Carregando voz neural offline…',
          device: 'onnx-cpu',
          cached: true,
          cacheBytes: bytes,
        ),
      );

      final worker = await _KokoroWorker.spawn(files);
      _worker = worker;
      _emit(NeuralTtsStatus(state: NeuralTtsState.ready, device: 'onnx-cpu', cached: true, cacheBytes: bytes));
      return worker;
    }();

    _readyTask = task.whenComplete(() => _readyTask = null);
    return _readyTask!;
  }

  void listenStatus(void Function(NeuralTtsStatus status) onChange) {
    _listeners.add(onChange);
    onChange(_status);
  }

  Future<NeuralTtsStatus> refreshStatus() async {
    if (!nativeTtsIsSupported()) return const NeuralTtsStatus();
    if (_status.isBusy || _status.state == NeuralTtsState.speaking) return _status;
    try {
      final store = await _getStore();
      final ready = store.isReady;
      final bytes = store.computeCacheBytes();
      final next = NeuralTtsStatus(
        state: ready ? NeuralTtsState.ready : NeuralTtsState.idle,
        device: ready ? 'onnx-cpu' : null,
        cached: ready,
        cacheBytes: bytes,
      );
      _emit(next);
      return next;
    } catch (_) {
      return _status;
    }
  }

  Future<bool> preload() async {
    if (!nativeTtsIsSupported()) return false;
    try {
      await _ensureReady();
      await refreshStatus();
      return true;
    } catch (e) {
      debugPrint('Erro ao baixar/inicializar Kokoro offline: $e');
      _emit(NeuralTtsStatus(state: NeuralTtsState.error, error: '$e', cached: _store?.isReady ?? false));
      return false;
    }
  }

  Future<bool> clearCache() async {
    if (!nativeTtsIsSupported()) return false;
    stop();
    try {
      await _readyTask;
    } catch (_) {}
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      await worker.dispose();
    }
    try {
      final store = await _getStore();
      await store.clearCache();
      for (final slot in [0, 1]) {
        final f = File(await _wavPathForSlot(slot));
        if (f.existsSync()) await f.delete();
      }
      _emit(const NeuralTtsStatus(state: NeuralTtsState.idle, cached: false, cacheBytes: 0));
      return true;
    } catch (e) {
      debugPrint('Erro ao limpar cache Kokoro offline: $e');
      return false;
    }
  }

  String _cacheKey(KokoroSpeaker speaker, double speed, String text) =>
      '${speaker.sid}|${speaker.espeakLang}|${speed.toStringAsFixed(2)}|$text';

  void _startPrefetch({
    required _KokoroWorker worker,
    required KokoroSpeaker speaker,
    required double speed,
    required String nextText,
    required int slot,
    required String wavPath,
  }) {
    final key = _cacheKey(speaker, speed, nextText);
    if (_prefetched?.key == key) return;
    final future = worker.synthesize(
      text: nextText,
      sid: speaker.sid,
      speed: speed,
      espeakLang: speaker.espeakLang,
      wavPath: wavPath,
    );
    _prefetched = _PrefetchedChunk(key: key, slot: slot, wavPath: wavPath, future: future);
  }

  Future<bool> speak(
    String text,
    double speed, {
    String voice = 'pf_dora',
    String language = 'pt-BR',
    String? nextText,
  }) async {
    if (!nativeTtsIsSupported()) return false;
    if (normalizeTextForKokoro(text).isEmpty) return true;

    final epoch = _epoch;
    _KokoroWorker worker;
    try {
      worker = await _ensureReady();
    } catch (e) {
      debugPrint('Kokoro offline indisponível, usando fallback do sistema: $e');
      _emit(NeuralTtsStatus(state: NeuralTtsState.error, error: '$e', cached: _store?.isReady ?? false));
      return false;
    }
    if (_epoch != epoch) return true;

    final speaker = resolveKokoroSpeaker(voiceId: voice, language: language);
    final clampedSpeed = speed.clamp(0.5, 2.0);
    final key = _cacheKey(speaker, clampedSpeed, text);

    int slot;
    String wavPath;
    Future<bool> synthFuture;

    final cachedPrefetch = _prefetched;
    if (cachedPrefetch != null && cachedPrefetch.key == key) {
      slot = cachedPrefetch.slot;
      wavPath = cachedPrefetch.wavPath;
      synthFuture = cachedPrefetch.future;
      _prefetched = null;
    } else {
      _prefetched = null;
      slot = 1 - _activeSlot;
      wavPath = await _wavPathForSlot(slot);
      synthFuture = worker.synthesize(
        text: text,
        sid: speaker.sid,
        speed: clampedSpeed,
        espeakLang: speaker.espeakLang,
        wavPath: wavPath,
      );
    }

    final synthOk = await synthFuture;
    if (_epoch != epoch) return true;
    if (!synthOk) return false;
    _activeSlot = slot;

    if (nextText != null && normalizeTextForKokoro(nextText).isNotEmpty) {
      final nextSlot = 1 - _activeSlot;
      final nextWavPath = await _wavPathForSlot(nextSlot);
      if (_epoch != epoch) return true;
      _startPrefetch(
        worker: worker,
        speaker: speaker,
        speed: clampedSpeed,
        nextText: nextText,
        slot: nextSlot,
        wavPath: nextWavPath,
      );
    }

    final bytes = _store?.computeCacheBytes() ?? 0;
    _emit(NeuralTtsStatus(state: NeuralTtsState.speaking, device: 'onnx-cpu', cached: true, cacheBytes: bytes));

    try {
      await _playWavFile(wavPath, epoch);
      if (_epoch == epoch) {
        _emit(NeuralTtsStatus(state: NeuralTtsState.ready, device: 'onnx-cpu', cached: true, cacheBytes: bytes));
      }
      return true;
    } catch (e) {
      if (_epoch != epoch) return true;
      debugPrint('Erro ao reproduzir WAV do Kokoro offline: $e');
      _emit(NeuralTtsStatus(state: NeuralTtsState.ready, device: 'onnx-cpu', cached: true, cacheBytes: bytes));
      return false;
    }
  }

  Future<void> _playWavFile(String wavPath, int epoch) async {
    final player = _player ??= AudioPlayer();
    final completer = Completer<void>();
    _activePlayCompleter = completer;

    late final StreamSubscription<PlayerState> sub;
    sub = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await player.setFilePath(wavPath);
      await player.setSpeed(1.0);
      if (_epoch != epoch) return;
      unawaited(
        player.play().whenComplete(() {
          if (!completer.isCompleted) completer.complete();
        }),
      );
      await completer.future;
    } finally {
      await sub.cancel();
      if (identical(_activePlayCompleter, completer)) {
        _activePlayCompleter = null;
      }
    }
  }

  void stop() {
    _epoch++;
    _prefetched = null;
    if (_activePlayCompleter != null && !_activePlayCompleter!.isCompleted) {
      _activePlayCompleter!.complete();
    }
    if (_player != null) {
      unawaited(_player!.stop());
    }
    if (_status.state == NeuralTtsState.speaking) {
      _emit(
        NeuralTtsStatus(
          state: _store?.isReady == true ? NeuralTtsState.ready : NeuralTtsState.idle,
          device: _store?.isReady == true ? 'onnx-cpu' : null,
          cached: _store?.isReady ?? false,
          cacheBytes: _store?.computeCacheBytes() ?? 0,
        ),
      );
    }
  }
}

final _engine = _NativeKokoroEngine();

Future<bool> nativeTtsSpeak(
  String text,
  double speed, {
  String voice = 'pf_dora',
  String language = 'pt-BR',
  String? nextText,
}) => _engine.speak(text, speed, voice: voice, language: language, nextText: nextText);

void nativeTtsStop() => _engine.stop();

Future<bool> nativeTtsPreload({String voice = 'pf_dora'}) => _engine.preload();

Future<bool> nativeTtsClearCache() => _engine.clearCache();

Future<NeuralTtsStatus> nativeTtsRefreshStatus() => _engine.refreshStatus();

void nativeTtsListenStatus(void Function(NeuralTtsStatus status) onChange) => _engine.listenStatus(onChange);
