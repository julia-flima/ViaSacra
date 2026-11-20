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
    this.language = 'pt-BR',
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? text;
  final String? audioUrl;

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

/// Monta a fila "Ouvir Liturgia": 1ª Leitura → Salmo → 2ª Leitura → Evangelho
/// → (opcional) Homilia/Reflexão. Usa áudio narrado aberto quando houver e o
/// usuário preferir; caso contrário, TTS pt-BR offline.
List<ReadingSegment> buildLiturgyQueue(DailyLiturgy l, {bool preferRecorded = true, Homily? reflection}) {
  final q = <ReadingSegment>[];
  if (preferRecorded && l.audio.liturgyAudioUrl != null) {
    q.add(
      ReadingSegment(
        id: '${l.date.toIso8601String()}#audio',
        title: 'Liturgia do dia',
        subtitle: l.audio.creditFor('liturgia_audio_url')?.channel,
        text: l.readings.map((r) => r.toSpeech()).join('\n\n'),
        audioUrl: l.audio.liturgyAudioUrl,
      ),
    );
  } else {
    for (final r in l.readings) {
      q.add(
        ReadingSegment(
          id: '${l.date.toIso8601String()}#${r.kind.jsonKey}',
          title: r.kind.label,
          subtitle: r.reference,
          text: r.toSpeech(),
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

/// Divide textos longos em frases (limite seguro do TTS Android ≈ 4000 chars)
/// para permitir pausar/retomar com precisão de frase.
@visibleForTesting
List<String> splitForSpeech(String text, {int maxLen = 600}) {
  final sentences = RegExp(r'[^.!?;:\n]+[.!?;:\n]*').allMatches(text).map((m) => m.group(0)!.trim());
  final chunks = <String>[];
  final buf = StringBuffer();
  for (final s in sentences.where((s) => s.isNotEmpty)) {
    if (buf.length + s.length + 1 > maxLen && buf.isNotEmpty) {
      chunks.add(buf.toString());
      buf.clear();
    }
    if (s.length > maxLen) {
      for (var i = 0; i < s.length; i += maxLen) {
        chunks.add(s.substring(i, (i + maxLen).clamp(0, s.length)));
      }
      continue;
    }
    if (buf.isNotEmpty) buf.write(' ');
    buf.write(s);
  }
  if (buf.isNotEmpty) chunks.add(buf.toString());
  return chunks;
}

/// Handler de áudio integrado ao sistema (tela de bloqueio, fones Bluetooth,
/// notificação de mídia e reprodução em segundo plano via `audio_service`).
class ReadingAudioHandler extends BaseAudioHandler with QueueHandler {
  ReadingAudioHandler({
    Future<bool> Function(String text, double speed, {String voice, String language, String? nextText})? neuralSpeak,
    void Function()? neuralStop,
    this.fallbackSpeak,
    bool? useNeuralEngine,
  }) : _neuralSpeak = neuralSpeak ?? (kIsWeb ? webTtsSpeak : nativeTtsSpeak),
       _neuralStop = neuralStop ?? (kIsWeb ? webTtsStop : nativeTtsStop),
       _useNeuralEngine = useNeuralEngine ?? (kIsWeb || nativeTtsIsSupported()) {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && _current?.isRecorded == true) {
        _advance();
      }
    });
    if (_useNeuralEngine && neuralSpeak == null) {
      if (kIsWeb) {
        webTtsListenStatus((s) => neuralTtsStatus.value = s);
      } else if (nativeTtsIsSupported()) {
        nativeTtsListenStatus((s) => neuralTtsStatus.value = s);
      }
    }
  }

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final Future<bool> Function(String text, double speed, {String voice, String language, String? nextText})
  _neuralSpeak;
  final void Function() _neuralStop;
  @visibleForTesting
  final Future<void> Function(String text, String language, double speed)? fallbackSpeak;
  final bool _useNeuralEngine;

  List<ReadingSegment> _segments = const [];
  int _index = 0;
  int _chunk = 0;
  List<String> _chunks = const [];
  double _speed = 1.0;
  bool _playing = false;
  int _generation = 0; // invalida laços de TTS antigos
  bool _ttsReady = false;
  bool _audioSessionReady = false;
  String? _ttsLanguage;
  String _kokoroVoice = KokoroVoice.dora.id;
  final ValueNotifier<NeuralTtsStatus> neuralTtsStatus = ValueNotifier(const NeuralTtsStatus());

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
    await stop();
    _segments = segments;
    _index = startAt.clamp(0, segments.isEmpty ? 0 : segments.length - 1);
    _chunk = 0;
    queue.add(segments.map((s) => s.toMediaItem()).toList());
    _broadcast();
  }

  @override
  Future<void> play() async {
    final seg = _current;
    if (seg == null) return;
    _playing = true;
    mediaItem.add(seg.toMediaItem());
    _broadcast();
    final gen = ++_generation;
    if (seg.isRecorded) {
      _neuralStop();
      await _tts.stop();
      try {
        if (_player.audioSource == null || _chunk == 0) {
          await _player.setUrl(seg.audioUrl!);
          _chunk = 1; // marca como carregado
        }
        await _player.setSpeed(_speed);
        unawaited(_player.play());
        return;
      } catch (e) {
        debugPrint('Áudio gravado indisponível (${seg.audioUrl}), usando fallback TTS local: $e');
        _chunk = 0;
        if (seg.text == null || seg.text!.trim().isEmpty) {
          _playing = false;
          _broadcast();
          return;
        }
      }
    }
    final useNeural = _useNeuralEngine && supportsKokoro(seg.language);
    if (useNeural && !kIsWeb && fallbackSpeak == null) {
      await _ensureAudioSession();
    } else if (!useNeural && fallbackSpeak == null) {
      await _initTts();
      await _useLanguage(seg.language);
    }
    if (_chunks.isEmpty || _chunk == 0) _chunks = splitForSpeech(seg.text ?? '', maxLen: useNeural ? 280 : 600);
    var neuralFailed = false;
    while (_playing && gen == _generation && _chunk < _chunks.length) {
      var spoken = false;
      if (useNeural && !neuralFailed) {
        final next = _chunk + 1 < _chunks.length ? _chunks[_chunk + 1] : null;
        spoken = await _neuralSpeak(
          _chunks[_chunk],
          _speed,
          voice: _kokoroVoice,
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
    }
    if (_playing && gen == _generation) await _advance();
  }

  Future<void> _advance() async {
    if (_index < _segments.length - 1) {
      _index++;
      _chunk = 0;
      _chunks = const [];
      await _player.stop();
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
    _generation++;
    _chunk = 0;
    _chunks = const [];
    _neuralStop();
    await _tts.stop();
    await _player.stop();
    _broadcast();
  }

  @override
  Future<void> skipToNext() => _jump(_index + 1);

  @override
  Future<void> skipToPrevious() async {
    // Comportamento de player: se já avançou na leitura, volta ao início dela.
    if (_chunk > 1 && !(_current?.isRecorded ?? false)) return _jump(_index);
    return _jump(_index - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) => _jump(index);

  Future<void> _jump(int i) async {
    if (_segments.isEmpty) return;
    final wasPlaying = _playing;
    await stop();
    _index = i.clamp(0, _segments.length - 1);
    mediaItem.add(_segments[_index].toMediaItem());
    _broadcast();
    if (wasPlaying) await play();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _applySpeed();
    await _player.setSpeed(speed);
    if (_playing && !(_current?.isRecorded ?? false)) {
      // Reaplica a nova velocidade a partir da frase atual.
      _generation++;
      _neuralStop();
      await _tts.stop();
      unawaited(play());
    }
    _broadcast();
  }

  String get kokoroVoice => _kokoroVoice;

  Future<void> setKokoroVoice(String voiceId) async {
    final normalized = KokoroVoice.byId(voiceId).id;
    if (_kokoroVoice == normalized) return;
    _kokoroVoice = normalized;
    if (_playing && _useNeuralEngine && !(_current?.isRecorded ?? false)) {
      _generation++;
      _neuralStop();
      await _tts.stop();
      unawaited(play());
    }
    _broadcast();
  }

  Future<bool> preloadNeuralTts() async {
    if (!_useNeuralEngine) return false;
    final ok = kIsWeb ? await webTtsPreload(voice: _kokoroVoice) : await nativeTtsPreload(voice: _kokoroVoice);
    await refreshNeuralTtsStatus();
    return ok;
  }

  Future<bool> clearNeuralTtsCache() async {
    if (!_useNeuralEngine) return false;
    final ok = kIsWeb ? await webTtsClearCache() : await nativeTtsClearCache();
    await refreshNeuralTtsStatus();
    return ok;
  }

  Future<NeuralTtsStatus> refreshNeuralTtsStatus() async {
    if (!_useNeuralEngine) return const NeuralTtsStatus();
    final s = kIsWeb ? await webTtsRefreshStatus() : await nativeTtsRefreshStatus();
    neuralTtsStatus.value = s;
    return s;
  }

  void _broadcast({bool completed = false}) {
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
  ReadingAudioController._(this._handler) {
    _handler.playbackState.listen((s) {
      playing = s.playing;
      index = s.queueIndex ?? 0;
      speed = s.speed;
      notifyListeners();
    });
    _handler.queue.listen((q) {
      titles = q.map((m) => m.title).toList();
      notifyListeners();
    });
    _handler.neuralTtsStatus.addListener(notifyListeners);
  }

  final ReadingAudioHandler _handler;
  bool playing = false;
  int index = 0;
  double speed = 1.0;
  List<String> titles = const [];
  String? loadedKey;

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
    return ReadingAudioController._(handler);
  }

  /// Controlador sem integração com o sistema (testes e plataformas sem audio_service).
  @visibleForTesting
  factory ReadingAudioController.local({ReadingAudioHandler? handler}) =>
      ReadingAudioController._(handler ?? ReadingAudioHandler());

  @override
  void dispose() {
    _handler.neuralTtsStatus.removeListener(notifyListeners);
    super.dispose();
  }

  String? get currentTitle => index < titles.length ? titles[index] : null;
  bool get hasQueue => titles.isNotEmpty;
  NeuralTtsStatus get neuralTtsStatus => _handler.neuralTtsStatus.value;

  /// Atualiza diretamente o estado do motor neural em testes de widget.
  @visibleForTesting
  void setNeuralTtsStatusForTest(NeuralTtsStatus status) => _handler.neuralTtsStatus.value = status;

  Future<void> playQueue(String key, List<ReadingSegment> segments, {int startAt = 0, double? speed}) async {
    if (speed != null) await _handler.setSpeed(speed);
    if (loadedKey != key || !hasQueue) {
      await _handler.load(segments, startAt: startAt);
      loadedKey = key;
    } else {
      await _handler.skipToQueueItem(startAt);
    }
    await _handler.play();
  }

  /// Lê um único trecho (ex.: reflexão), substituindo a fila atual.
  Future<void> playSingle(ReadingSegment segment, {double? speed}) => playQueue(segment.id, [segment], speed: speed);

  Future<void> toggle() => playing ? _handler.pause() : _handler.play();
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> stop() => _handler.stop();
  Future<void> setSpeed(double s) => _handler.setSpeed(s);
  Future<void> setVoice(String? name, String? locale) => _handler.setVoice(name, locale);
  Future<void> setKokoroVoice(String voiceId) => _handler.setKokoroVoice(voiceId);
  Future<bool> preloadNeuralTts() => _handler.preloadNeuralTts();
  Future<bool> clearNeuralTtsCache() => _handler.clearNeuralTtsCache();
  Future<NeuralTtsStatus> refreshNeuralTtsStatus() => _handler.refreshNeuralTtsStatus();
  Future<List<({String name, String locale})>> voices() => _handler.portugueseVoices();
}
