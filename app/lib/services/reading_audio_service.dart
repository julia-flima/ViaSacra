import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/liturgy.dart';
import 'native_tts.dart';
import 'web_tts.dart';

/// Um trecho da fila de leitura: texto (TTS local) ou URL de áudio aberto.
class ReadingSegment {
  const ReadingSegment({
    required this.id,
    required this.title,
    this.subtitle,
    this.text,
    this.audioUrl,
    this.clipStart,
    this.clipEnd,
    this.language = 'pt-BR',
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? text;
  final String? audioUrl;

  /// Trecho do [audioUrl] que pertence a este item (uma leitura dentro do MP3 da Liturgia).
  final Duration? clipStart;
  final Duration? clipEnd;

  /// Idioma do texto (BCP-47) — ex.: "pt-BR", "en", "la".
  final String language;

  bool get isRecorded => audioUrl != null;

  MediaItem toMediaItem() => MediaItem(
    id: id,
    title: title,
    album: 'Via Sacra — Liturgia Diária',
    artist: subtitle ?? (isRecorded ? 'Áudio' : 'Leitura em voz alta'),
  );
}

/// Monta a fila "Ouvir Liturgia": 1ª Leitura → Salmo → 2ª Leitura → Evangelho → (opcional)
/// Homilia/Reflexão. Com o MP3 narrado preferido:
/// - se ele traz as marcas de início de cada leitura, cada leitura vira um trecho recortado do
///   mesmo MP3 (avançar/voltar e "Ouvir a partir daqui" funcionam sem síntese de voz);
/// - sem marcas, o MP3 inteiro é um item só, usado apenas quando a leitura começa do início.
/// Fora disso, cada leitura é lida pela voz (neural ou do aparelho).
List<ReadingSegment> buildLiturgyQueue(
  DailyLiturgy l, {
  bool preferRecorded = true,
  int startAt = 0,
  Homily? reflection,
}) {
  final q = <ReadingSegment>[];
  final url = preferRecorded ? l.audio.liturgyAudioUrl : null;
  final marks = l.audio.liturgyAudioMarks;
  final clipped = url != null && l.readings.isNotEmpty && l.readings.every((r) => marks.containsKey(r.kind.jsonKey));
  if (url != null && !clipped && startAt == 0) {
    q.add(
      ReadingSegment(
        id: '${l.date.toIso8601String()}#audio',
        title: 'Liturgia do dia',
        subtitle: l.audio.creditFor('liturgia_audio_url')?.channel,
        text: l.readings.map((r) => r.toSpeech()).join('\n\n'),
        audioUrl: url,
      ),
    );
  } else {
    for (final (i, r) in l.readings.indexed) {
      q.add(
        ReadingSegment(
          id: '${l.date.toIso8601String()}#${r.kind.jsonKey}',
          title: r.kind.label,
          subtitle: r.reference,
          text: r.toSpeech(),
          audioUrl: clipped ? url : null,
          // A 1ª leitura inclui a abertura ("Liturgia Diária. …"); a última vai até o fim do MP3.
          clipStart: clipped && i > 0 ? marks[r.kind.jsonKey] : null,
          clipEnd: clipped && i + 1 < l.readings.length ? marks[l.readings[i + 1].kind.jsonKey] : null,
        ),
      );
    }
  }
  if (reflection != null && reflection.text.isNotEmpty) {
    q.add(
      ReadingSegment(
        id: '${l.date.toIso8601String()}#reflexao',
        title: reflection.title,
        subtitle: reflection.author,
        text: '${reflection.title}. ${reflection.author != null ? '${reflection.author}. ' : ''}${reflection.text}',
      ),
    );
  }
  return q;
}

/// Tamanho dos trechos enviados à voz neural: o primeiro é curto para o som começar logo;
/// o segundo é sintetizado enquanto o primeiro toca, e assim por diante.
const kNeuralChunkLen = 280;
const kNeuralFirstChunkLen = 90;

/// Divide textos longos em trechos de até [maxLen] caracteres (limite seguro do TTS Android ≈ 4000)
/// para permitir pausar/retomar com precisão de frase. Corta em fim de frase; se a frase não couber,
/// em vírgula ou travessão; em último caso, entre palavras — nunca no meio de uma palavra.
/// Com [firstLen], o 1º trecho tem até [firstLen] caracteres e o 2º até o dobro disso.
@visibleForTesting
List<String> splitForSpeech(String text, {int maxLen = 600, int? firstLen}) {
  int limitFor(int i) => firstLen == null || i > 1 ? maxLen : (firstLen * (i + 1)).clamp(1, maxLen);
  final levels = <List<String> Function(String)>[
    (s) => s.split(RegExp(r'(?<=[,—–])\s+')),
    (s) => s.split(RegExp(r'\s+')),
  ];
  final chunks = <String>[];
  var buf = '';
  void add(String unit, int level) {
    final joined = buf.isEmpty ? unit : '$buf $unit';
    if (joined.length <= limitFor(chunks.length)) {
      buf = joined;
      return;
    }
    if (buf.isNotEmpty) {
      chunks.add(buf);
      buf = '';
      return add(unit, level);
    }
    for (var l = level; l < levels.length; l++) {
      final parts = levels[l](unit).where((p) => p.isNotEmpty).toList();
      if (parts.length > 1) {
        for (final p in parts) {
          add(p, l + 1);
        }
        return;
      }
    }
    final limit = limitFor(chunks.length); // palavra maior que o limite (raríssimo)
    chunks.add(unit.substring(0, limit));
    add(unit.substring(limit), levels.length);
  }

  for (final m in RegExp(r'[^.!?;:\n]+[.!?;:\n]*').allMatches(text)) {
    final s = m.group(0)!.trim();
    if (s.isNotEmpty) add(s, 0);
  }
  if (buf.isNotEmpty) chunks.add(buf);
  return chunks;
}

/// Handler de áudio integrado ao sistema (tela de bloqueio, fones Bluetooth,
/// notificação de mídia e reprodução em segundo plano via `audio_service`).
class ReadingAudioHandler extends BaseAudioHandler with QueueHandler {
  ReadingAudioHandler({
    Future<bool> Function(String text, double speed, {String voice, String language, String? nextText})? neuralSpeak,
    void Function()? neuralStop,
    this.fallbackSpeak,
    this.recordedPlay,
    bool? useNeuralEngine,
  }) : _neuralSpeak = neuralSpeak ?? (kIsWeb ? webTtsSpeak : nativeTtsSpeak),
       _neuralStop = neuralStop ?? (kIsWeb ? webTtsStop : nativeTtsStop),
       _useNeuralEngine = useNeuralEngine ?? (kIsWeb || nativeTtsIsSupported()) {
    _playerStateSub = _player.playerStateStream.listen((s) {
      if (!_disposed && s.processingState == ProcessingState.completed && _playingRecorded) {
        unawaited(_advance());
      }
    });
    if (_useNeuralEngine && neuralSpeak == null) {
      if (!kIsWeb) nativeTtsUsePlayer(_playSynthesized);
      if (kIsWeb) {
        webTtsListenStatus((s) {
          if (!_disposed) neuralTtsStatus.value = s;
        });
      } else if (nativeTtsIsSupported()) {
        nativeTtsListenStatus((s) {
          if (!_disposed) neuralTtsStatus.value = s;
        });
      }
    }
  }

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerStateSub;
  final Future<bool> Function(String text, double speed, {String voice, String language, String? nextText})
  _neuralSpeak;
  final void Function() _neuralStop;
  @visibleForTesting
  final Future<void> Function(String text, String language, double speed)? fallbackSpeak;
  @visibleForTesting
  final Future<void> Function(String url, double speed)? recordedPlay;
  final bool _useNeuralEngine;

  List<ReadingSegment> _segments = const [];
  int _index = 0;
  int _chunk = 0;
  List<String> _chunks = const [];
  double _speed = 1.0;
  bool _playing = false;
  bool _playingRecorded = false;
  bool _recordedFailed = false;
  bool _disposed = false;
  int _generation = 0; // invalida laços de TTS antigos
  bool _ttsReady = false;
  bool _audioSessionReady = false;
  String? _ttsLanguage;
  String _kokoroVoice = KokoroVoice.dora.id;
  TtsEngine _engine = TtsEngine.kokoro;
  String _piperVoice = PiperVoice.all.first.id;
  final ValueNotifier<NeuralTtsStatus> neuralTtsStatus = ValueNotifier(const NeuralTtsStatus());

  @visibleForTesting
  bool get playingRecorded => _playingRecorded;
  int get chunkIndex => _chunk;
  int get chunkCount => _chunks.length;

  /// flutter_tts normaliza 0.5 como velocidade "normal" no Android/iOS,
  /// enquanto na Web Speech API o valor normal é 1.0.
  @visibleForTesting
  static double speechRateFor(double speed, {required bool isWeb}) =>
      isWeb ? speed.clamp(0.5, 2.0) : (0.5 * speed).clamp(0.1, 1.0);

  @visibleForTesting
  static bool supportsKokoro(String lang) {
    final l = lang.toLowerCase();
    return l.startsWith('pt') || l.startsWith('en') || l.startsWith('la') || l.startsWith('it') || l.startsWith('es');
  }

  /// Mapeia o idioma do texto para uma voz disponível. Não há vozes de latim
  /// nos sistemas; a voz italiana se aproxima da pronúncia eclesiástica.
  static String voiceLanguageFor(String lang) {
    final l = lang.toLowerCase();
    if (l.startsWith('la')) return 'it-IT';
    if (l.startsWith('en')) return 'en-US';
    if (l.startsWith('es')) return 'es-ES';
    if (l.startsWith('it')) return 'it-IT';
    return 'pt-BR';
  }

  Future<void> _useLanguage(String lang) async {
    final voice = voiceLanguageFor(lang);
    if (_ttsLanguage == voice) return;
    try {
      final ok = await _tts.isLanguageAvailable(voice);
      await _tts.setLanguage(ok == true || voice != 'pt-BR' ? voice : 'pt-PT');
    } catch (_) {
      await _tts.setLanguage(voice);
    }
    _ttsLanguage = voice;
  }

  ReadingSegment? get _current => _index < _segments.length ? _segments[_index] : null;
  int get index => _index;
  double get speed => _speed;

  Future<void> _ensureAudioSession() async {
    if (_audioSessionReady) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _audioSessionReady = true;
    } catch (_) {
      // Web/plataformas sem sessão de áudio configurável.
    }
  }

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _tts.awaitSpeakCompletion(true);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ], IosTextToSpeechAudioMode.spokenAudio);
    }
    await _useLanguage('pt-BR');
    await _applySpeed();
    await _ensureAudioSession();
    _ttsReady = true;
  }

  /// flutter_tts normaliza 0.5 como velocidade "normal" em Android e iOS; na Web é 1.0.
  Future<void> _applySpeed() => _tts.setSpeechRate(speechRateFor(_speed, isWeb: kIsWeb));

  Future<void> setVoice(String? name, String? locale) async {
    await _initTts();
    if (name != null) {
      await _tts.setVoice({'name': name, 'locale': locale ?? 'pt-BR'});
      _ttsLanguage = locale ?? 'pt-BR';
    } else {
      // "Padrão do sistema": limpa a voz escolhida e reaplica o idioma na próxima fala.
      try {
        await _tts.clearVoice();
      } catch (e) {
        debugPrint('clearVoice indisponível: $e');
      }
      _ttsLanguage = null;
    }
  }

  /// Vozes pt-* instaladas no aparelho (nenhuma é baixada pelo app).
  Future<List<({String name, String locale})>> portugueseVoices() async {
    await _initTts();
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((v) => (name: '${v['name']}', locale: '${v['locale']}'))
        .where((v) => v.locale.toLowerCase().startsWith('pt'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> load(List<ReadingSegment> segments, {int startAt = 0}) async {
    if (_disposed) return;
    await stop();
    _segments = segments;
    _index = startAt.clamp(0, segments.isEmpty ? 0 : segments.length - 1);
    _chunk = 0;
    queue.add(segments.map((s) => s.toMediaItem()).toList());
    _broadcast();
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    final seg = _current;
    if (seg == null) return;
    _trace('play #$_index ${seg.id} chunk $_chunk recorded=${seg.isRecorded}');
    _playing = true;
    mediaItem.add(seg.toMediaItem());
    _broadcast();
    final gen = ++_generation;
    if (seg.isRecorded && !_recordedFailed) {
      _neuralStop();
      await _tts.stop();
      try {
        if (recordedPlay != null) {
          _playingRecorded = true;
          _chunk = 1;
          await recordedPlay!(seg.audioUrl!, _speed);
        } else {
          if (_player.audioSource == null || _chunk == 0) {
            final source = AudioSource.uri(Uri.parse(seg.audioUrl!));
            await _player.setAudioSource(
              seg.clipStart == null && seg.clipEnd == null
                  ? source
                  : ClippingAudioSource(child: source, start: seg.clipStart, end: seg.clipEnd),
            );
            _chunk = 1; // marca como carregado
          }
          await _player.setSpeed(_speed);
          _playingRecorded = true;
          _broadcast(); // a interface deixa de mostrar "Sintetizando…"
          unawaited(_player.play());
        }
        return;
      } catch (e) {
        debugPrint('Áudio gravado indisponível (${seg.audioUrl}), usando fallback TTS local: $e');
        _playingRecorded = false;
        _recordedFailed = true;
        _chunk = 0;
        if (seg.text == null || seg.text!.trim().isEmpty) {
          _playing = false;
          _broadcast();
          return;
        }
      }
    }
    _playingRecorded = false;
    final useNeural = _useNeuralEngine && _engine != TtsEngine.system && supportsKokoro(seg.language);
    if (useNeural && !kIsWeb && fallbackSpeak == null) {
      await _ensureAudioSession();
    } else if (!useNeural && fallbackSpeak == null) {
      await _initTts();
      await _useLanguage(seg.language);
    }
    if (_chunks.isEmpty || _chunk == 0) {
      _chunks = useNeural
          ? splitForSpeech(seg.text ?? '', maxLen: kNeuralChunkLen, firstLen: kNeuralFirstChunkLen)
          : splitForSpeech(seg.text ?? '');
      _broadcast();
    }
    var neuralFailed = false;
    while (_playing && gen == _generation && _chunk < _chunks.length) {
      var spoken = false;
      if (useNeural && !neuralFailed) {
        final next = _chunk + 1 < _chunks.length ? _chunks[_chunk + 1] : _firstChunkOfNext(seg);
        spoken = await _neuralSpeak(
          _chunks[_chunk],
          _speed,
          voice: _voiceFor(seg.language),
          language: seg.language,
          nextText: next,
        );
        if (!spoken && _playing && gen == _generation) neuralFailed = true;
      }
      if (!spoken && _playing && gen == _generation) {
        if (fallbackSpeak != null) {
          await fallbackSpeak!(_chunks[_chunk], seg.language, _speed);
        } else {
          await _initTts();
          await _useLanguage(seg.language);
          await _tts.speak(_chunks[_chunk]);
        }
      }
      if (!_playing || gen != _generation) return; // pausado/pulado durante a fala
      _chunk++;
      if (_chunk < _chunks.length) _broadcast();
    }
    if (_playing && gen == _generation) await _advance();
  }

  /// 1º trecho da próxima leitura, para a voz neural já sintetizá-lo enquanto a atual termina
  /// (evita o silêncio na troca de leitura). Só quando a próxima também será falada no mesmo idioma.
  String? _firstChunkOfNext(ReadingSegment current) {
    if (_index + 1 >= _segments.length) return null;
    final next = _segments[_index + 1];
    if (next.isRecorded || next.language != current.language) return null;
    final chunks = splitForSpeech(next.text ?? '', maxLen: kNeuralChunkLen, firstLen: kNeuralFirstChunkLen);
    return chunks.isEmpty ? null : chunks.first;
  }

  Future<void> _advance() async {
    final wasRecorded = _playingRecorded;
    _playingRecorded = false;
    _recordedFailed = false;
    if (_index < _segments.length - 1) {
      _index++;
      _chunk = 0;
      _chunks = const [];
      if (wasRecorded) await _player.stop();
      await play();
    } else {
      _playing = false;
      _index = 0;
      _chunk = 0;
      _chunks = const [];
      _broadcast(completed: true);
    }
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _generation++;
    _neuralStop();
    await _tts.stop(); // retoma do início da frase atual
    await _player.pause();
    _broadcast();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _playingRecorded = false;
    _recordedFailed = false;
    _generation++;
    _chunk = 0;
    _chunks = const [];
    _neuralStop();
    await _tts.stop();
    await _player.stop();
    _broadcast();
  }

  /// Para a leitura e esvazia completamente a fila (usado ao fechar o mini-player).
  Future<void> clear() async {
    if (_disposed) return;
    await stop();
    _segments = const [];
    _index = 0;
    queue.add(const []);
    _broadcast();
  }

  @override
  Future<void> skipToNext() => _jump(_index + 1);

  @override
  Future<void> skipToPrevious() async {
    // Comportamento de player: se já avançou na leitura, volta ao início dela.
    if (_chunk > 1 && !_playingRecorded) return _jump(_index);
    return _jump(_index - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) => _jump(index);

  Future<void> jumpTo(int index, {bool autoplay = false}) async {
    _trace('jumpTo $index (atual $_index de ${_segments.length}) autoplay=$autoplay');
    if (_disposed || _segments.isEmpty) return;
    await stop();
    _index = index.clamp(0, _segments.length - 1);
    mediaItem.add(_segments[_index].toMediaItem());
    _broadcast();
    if (autoplay) await play();
  }

  Future<void> _jump(int i) => jumpTo(i, autoplay: _playing);

  @override
  Future<void> setSpeed(double speed) async {
    if (_speed == speed) return;
    _speed = speed;
    if (_ttsReady) await _applySpeed();
    if (_playingRecorded) await _player.setSpeed(speed);
    if (_playing && !_playingRecorded) {
      // Reaplica a nova velocidade a partir da frase atual.
      _generation++;
      _neuralStop();
      await _tts.stop();
      await _player.stop();
      unawaited(play());
    }
    _broadcast();
  }

  /// Registro para diagnóstico (só fora do modo release; aparece no `adb logcat` como `VS-TTS`).
  void _trace(String msg) {
    if (!kReleaseMode) debugPrint('VS-TTS $msg');
  }

  String get kokoroVoice => _kokoroVoice;
  TtsEngine get engine => _engine;

  /// O Piper só fala português; os trechos em outros idiomas seguem com o Kokoro.
  String _voiceFor(String language) =>
      _engine == TtsEngine.piper && language.toLowerCase().startsWith('pt') ? _piperVoice : _kokoroVoice;

  Future<void> setKokoroVoice(String voiceId) => _changeVoice(() => _kokoroVoice = KokoroVoice.byId(voiceId).id);

  Future<void> setEngine(TtsEngine engine) => _changeVoice(() => _engine = engine);

  Future<void> setPiperVoice(String voiceId) =>
      _changeVoice(() => _piperVoice = (PiperVoice.byId(voiceId) ?? PiperVoice.all.first).id);

  /// Aplica a troca e, se estiver lendo em voz alta, recomeça a frase atual com a nova voz.
  Future<void> _changeVoice(void Function() apply) async {
    final before = (_engine, _kokoroVoice, _piperVoice);
    apply();
    if (before == (_engine, _kokoroVoice, _piperVoice)) return;
    if (_playing && !_playingRecorded) {
      _generation++;
      _neuralStop();
      await _tts.stop();
      await _player.stop();
      unawaited(play());
    }
    _broadcast();
  }

  /// Toca o WAV gerado pela voz neural no mesmo player do áudio narrado.
  /// O `play()` do just_audio termina ao fim do arquivo ou quando a leitura é pausada/parada.
  Future<void> _playSynthesized(String path) async {
    await _player.setFilePath(path);
    await _player.setSpeed(1.0);
    if (_playing) await _player.play();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _playerStateSub.cancel();
    _playing = false;
    _playingRecorded = false;
    _recordedFailed = false;
    _generation++;
    _neuralStop();
    await _tts.stop();
    await _player.stop();
    await _player.dispose();
    neuralTtsStatus.dispose();
  }

  /// Deixa a voz neural pronta em segundo plano, sem nunca baixar nada sozinho:
  /// no celular copia a voz embutida no app (1ª vez); na Web carrega o modelo se já estiver no cache.
  Future<void> prepareNeuralTts() async {
    if (!_useNeuralEngine || _disposed) return;
    if (!kIsWeb) return nativeTtsPrepare();
    final s = await refreshNeuralTtsStatus();
    if (s.cached && !s.isBusy && !_playing && !_disposed) await preloadNeuralTts();
  }

  /// Web: baixa o modelo Kokoro para o cache do navegador.
  Future<bool> preloadNeuralTts() async {
    if (!_useNeuralEngine || !kIsWeb) return false;
    final ok = await webTtsPreload(voice: _kokoroVoice);
    await refreshNeuralTtsStatus();
    return ok;
  }

  /// Web: apaga o modelo do cache do navegador.
  Future<bool> clearNeuralTtsCache() async {
    if (!_useNeuralEngine || !kIsWeb) return false;
    final ok = await webTtsClearCache();
    await refreshNeuralTtsStatus();
    return ok;
  }

  Future<bool> downloadPiperVoice(String voiceId) => nativeTtsDownloadPiper(voiceId);
  void cancelVoiceDownload() => nativeTtsCancelDownload();
  Future<void> removePiperVoice(String voiceId) => nativeTtsRemovePiper(voiceId);

  Future<NeuralTtsStatus> refreshNeuralTtsStatus() async {
    if (!_useNeuralEngine) return const NeuralTtsStatus();
    final s = kIsWeb ? await webTtsRefreshStatus() : await nativeTtsRefreshStatus();
    neuralTtsStatus.value = s;
    return s;
  }

  void _broadcast({bool completed = false}) {
    if (_disposed) return;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.skipToQueueItem, MediaAction.setSpeed},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: completed
            ? AudioProcessingState.completed
            : (_segments.isEmpty ? AudioProcessingState.idle : AudioProcessingState.ready),
        playing: _playing,
        speed: _speed,
        queueIndex: _index,
      ),
    );
  }
}

/// Fachada observável para a UI (Provider).
class ReadingAudioController extends ChangeNotifier {
  ReadingAudioController._(this._handler, {this.ownsHandler = true}) {
    _playbackSub = _handler.playbackState.listen((s) {
      if (_disposed) return;
      playing = s.playing;
      index = s.queueIndex ?? 0;
      speed = s.speed;
      chunkIndex = _handler.chunkIndex;
      chunkCount = _handler.chunkCount;
      notifyListeners();
    });
    _queueSub = _handler.queue.listen((q) {
      if (_disposed) return;
      titles = q.map((m) => m.title).toList();
      subtitles = q.map((m) => m.artist).toList();
      notifyListeners();
    });
    _handler.neuralTtsStatus.addListener(_onStatusChanged);
  }

  final ReadingAudioHandler _handler;
  final bool ownsHandler;
  late final StreamSubscription<PlaybackState> _playbackSub;
  late final StreamSubscription<List<MediaItem>> _queueSub;
  bool _disposed = false;
  bool playing = false;
  int index = 0;
  int chunkIndex = 0;
  int chunkCount = 0;
  double speed = 1.0;
  List<String> titles = const [];
  List<String?> subtitles = const [];
  String? loadedKey;

  void _onStatusChanged() {
    if (!_disposed) notifyListeners();
  }

  /// Inicializa o serviço de áudio do sistema. Se indisponível (ex.: testes),
  /// usa o handler localmente sem integração com a tela de bloqueio.
  static Future<ReadingAudioController> create() async {
    ReadingAudioHandler handler;
    try {
      handler = await AudioService.init(
        builder: ReadingAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'io.github.juliaflima.via_sacra.audio',
          androidNotificationChannelName: 'Leitura da Liturgia',
          androidNotificationChannelDescription: 'Controles de reprodução da Liturgia em voz alta',
          androidNotificationOngoing: true,
          androidNotificationIcon: 'drawable/ic_stat_cross',
        ),
      );
    } catch (e) {
      debugPrint('audio_service indisponível, usando modo local: $e');
      handler = ReadingAudioHandler();
    }
    // Prepara a voz neural depois que o app já abriu, sem disputar a inicialização.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), handler.prepareNeuralTts).catchError((Object e) {
        debugPrint('Preparo da voz neural falhou: $e');
      }),
    );
    return ReadingAudioController._(handler);
  }

  /// Controlador sem integração com o sistema (testes e plataformas sem audio_service).
  @visibleForTesting
  factory ReadingAudioController.local({ReadingAudioHandler? handler, bool ownsHandler = true}) =>
      ReadingAudioController._(handler ?? ReadingAudioHandler(), ownsHandler: ownsHandler);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_playbackSub.cancel());
    unawaited(_queueSub.cancel());
    _handler.neuralTtsStatus.removeListener(_onStatusChanged);
    if (ownsHandler) unawaited(_handler.dispose());
    super.dispose();
  }

  String? get currentTitle => index < titles.length ? titles[index] : null;
  String? get currentSubtitle => index < subtitles.length ? subtitles[index] : null;
  double? get chunkProgress => chunkCount > 0 ? ((chunkIndex + 1) / chunkCount).clamp(0.0, 1.0) : null;
  bool get isSynthesizing => playing && !playingRecorded && neuralTtsStatus.state == NeuralTtsState.ready;
  bool get hasQueue => titles.isNotEmpty;
  NeuralTtsStatus get neuralTtsStatus => _handler.neuralTtsStatus.value;

  bool get playingRecorded => _handler.playingRecorded;

  bool isLoadedFor(String expectedKey) =>
      hasQueue && loadedKey != null && (loadedKey == expectedKey || loadedKey!.startsWith('$expectedKey#'));

  /// Atualiza diretamente o estado do motor neural em testes de widget.
  @visibleForTesting
  void setNeuralTtsStatusForTest(NeuralTtsStatus status) {
    if (!_disposed) _handler.neuralTtsStatus.value = status;
  }

  Future<void> playQueue(String key, List<ReadingSegment> segments, {int startAt = 0, double? speed}) async {
    if (_disposed) return;
    if (loadedKey != key || !hasQueue || segments.length != titles.length) {
      await _handler.load(segments, startAt: startAt);
      loadedKey = key;
    } else {
      await _handler.jumpTo(startAt, autoplay: false);
    }
    if (speed != null) await _handler.setSpeed(speed);
    await _handler.play();
  }

  /// Lê um único trecho (ex.: reflexão), substituindo a fila atual.
  Future<void> playSingle(ReadingSegment segment, {double? speed}) => playQueue(segment.id, [segment], speed: speed);

  Future<void> pause() => _handler.pause();
  Future<void> toggle() => playing ? _handler.pause() : _handler.play();
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> stop() => _handler.stop();

  /// Encerra a reprodução atual e fecha o mini-player global.
  Future<void> dismiss() async {
    if (_disposed) return;
    loadedKey = null;
    titles = const [];
    subtitles = const [];
    index = 0;
    chunkIndex = 0;
    chunkCount = 0;
    playing = false;
    notifyListeners();
    await _handler.clear();
  }

  Future<void> setSpeed(double s) => _handler.setSpeed(s);
  Future<void> setVoice(String? name, String? locale) => _handler.setVoice(name, locale);
  Future<void> setKokoroVoice(String voiceId) => _handler.setKokoroVoice(voiceId);
  Future<void> setEngine(TtsEngine engine) => _handler.setEngine(engine);
  Future<void> setPiperVoice(String voiceId) => _handler.setPiperVoice(voiceId);
  Future<bool> downloadPiperVoice(String voiceId) => _handler.downloadPiperVoice(voiceId);
  void cancelVoiceDownload() => _handler.cancelVoiceDownload();
  Future<void> removePiperVoice(String voiceId) => _handler.removePiperVoice(voiceId);
  Future<bool> preloadNeuralTts() => _handler.preloadNeuralTts();
  Future<bool> clearNeuralTtsCache() => _handler.clearNeuralTtsCache();
  Future<NeuralTtsStatus> refreshNeuralTtsStatus() => _handler.refreshNeuralTtsStatus();
  Future<List<({String name, String locale})>> voices() => _handler.portugueseVoices();
}
