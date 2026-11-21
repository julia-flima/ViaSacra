import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/features/liturgy/widgets/audio_player_bar.dart';
import 'package:via_sacra/features/liturgy/widgets/reading_card.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';

void _mockAudioChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.just_audio.methods'),
    (call) async => <String, dynamic>{},
  );
  messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'), (call) async => null);
}

class _FakeAudioPlayer implements AudioPlayer {
  final _stateController = StreamController<PlayerState>.broadcast();
  final List<String> setUrlCalls = [];
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
  bool _playing = false;
  ProcessingState _processingState = ProcessingState.idle;
  Completer<void>? _playCompleter;

  @override
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  @override
  ProcessingState get processingState => _processingState;

  @override
  bool get playing => _playing;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    setUrlCalls.add(url);
    _processingState = ProcessingState.ready;
    _stateController.add(PlayerState(_playing, _processingState));
    return const Duration(seconds: 30);
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
    _processingState = ProcessingState.ready;
    _stateController.add(PlayerState(true, _processingState));
    final completer = Completer<void>();
    _playCompleter = completer;
    await completer.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing = false;
    _stateController.add(PlayerState(false, _processingState));
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _processingState = ProcessingState.idle;
    _stateController.add(PlayerState(false, _processingState));
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seekCalls++;
  }

  @override
  Future<void> dispose() async {
    _playCompleter?.complete();
    _playCompleter = null;
    await _stateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpeechGate {
  final calls = <({String text, double speed, String voice})>[];
  final gates = <Completer<bool>>[];

  Future<bool> speak(
    String text,
    double speed, {
    String voice = 'pf_dora',
    String language = 'pt-BR',
    String? nextText,
  }) {
    calls.add((text: text, speed: speed, voice: voice));
    final c = Completer<bool>();
    gates.add(c);
    return c.future;
  }

  void stopAll() {
    for (final g in gates) {
      if (!g.isCompleted) g.complete(true);
    }
  }
}

Future<void> _pumpAsync(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_mockAudioChannels);

  final sampleJson =
      jsonDecode(File('test/fixtures/liturgia-2026-11-19.json').readAsStringSync()) as Map<String, dynamic>;

  test('buildLiturgyQueue só usa MP3 único quando startAt == 0 e preferRecorded == true', () {
    final withRecorded = <String, dynamic>{
      ...sampleJson,
      'audio': {
        ...(sampleJson['audio'] as Map<String, dynamic>),
        'liturgia_audio_url': 'https://cdn.example/2026-11-19.mp3',
      },
    };
    final lit = DailyLiturgy.fromJson(withRecorded);

    final recordedStart = buildLiturgyQueue(lit, preferRecorded: true, startAt: 0);
    expect(recordedStart, hasLength(1));
    expect(recordedStart.first.isRecorded, isTrue);

    final psalmStart = buildLiturgyQueue(lit, preferRecorded: true, startAt: 1);
    expect(psalmStart, hasLength(3));
    expect(psalmStart.every((s) => !s.isRecorded), isTrue);
    expect(psalmStart[1].title, 'Salmo Responsorial');

    final gospelStart = buildLiturgyQueue(lit, preferRecorded: true, startAt: 2);
    expect(gospelStart, hasLength(3));
    expect(gospelStart[2].title, 'Evangelho');

    final ttsOnly = buildLiturgyQueue(lit, preferRecorded: false, startAt: 0);
    expect(ttsOnly, hasLength(3));
    expect(ttsOnly.every((s) => !s.isRecorded), isTrue);
  });

  test('MP3 com marcas vira um trecho por leitura: avançar/voltar trocam de leitura (bug da v1.6.0-beta.1)', () async {
    final lit = DailyLiturgy.fromJson({
      ...sampleJson,
      'audio': {
        ...(sampleJson['audio'] as Map<String, dynamic>),
        'liturgia_audio_url': 'https://cdn.example/2026-11-19.mp3',
        'liturgia_audio_marcas': {'primeira_leitura': 0.0, 'salmo': 61.2, 'evangelho': 120.5},
      },
    });
    expect(lit.audio.liturgyAudioMarks['salmo'], const Duration(milliseconds: 61200));

    final q = buildLiturgyQueue(lit, preferRecorded: true);
    expect(q, hasLength(3));
    expect(q.every((s) => s.audioUrl == 'https://cdn.example/2026-11-19.mp3'), isTrue);
    expect(
      [for (final s in q) (s.clipStart, s.clipEnd)],
      [
        (null, const Duration(milliseconds: 61200)),
        (const Duration(milliseconds: 61200), const Duration(milliseconds: 120500)),
        (const Duration(milliseconds: 120500), null),
      ],
    );
    // "Ouvir a partir daqui" também usa o MP3, sem síntese de voz.
    expect(buildLiturgyQueue(lit, preferRecorded: true, startAt: 2).every((s) => s.isRecorded), isTrue);

    final played = <int>[];
    late final ReadingAudioHandler handler;
    handler = ReadingAudioHandler(
      useNeuralEngine: false,
      recordedPlay: (url, speed) async => played.add(handler.index),
      fallbackSpeak: (text, lang, speed) async {},
    );
    addTearDown(handler.dispose);
    await handler.load(q);
    await handler.play();
    await handler.skipToNext();
    await handler.skipToNext();
    await handler.skipToPrevious();
    expect(played, [0, 1, 2, 1]);
  });

  test('ReadingAudioHandler trata fallback MP3->TTS, velocidade, voz e skipToPrevious', () async {
    var recordedAttempts = 0;
    final gate = _SpeechGate();

    final longChunkText =
        '${List.filled(18, 'Primeira frase do texto longo.').join(' ')} '
        '${List.filled(18, 'Segunda frase do texto longo.').join(' ')}';

    final handler = ReadingAudioHandler(
      useNeuralEngine: true,
      recordedPlay: (url, speed) async {
        recordedAttempts++;
        throw StateError('404');
      },
      neuralSpeak: gate.speak,
      neuralStop: gate.stopAll,
      fallbackSpeak: (text, language, speed) async {},
    );

    await handler.load([
      const ReadingSegment(id: 'seg-0', title: '1ª Leitura', text: 'Um.'),
      ReadingSegment(id: 'seg-1', title: '2ª Leitura', text: longChunkText, audioUrl: 'https://cdn.example/fail.mp3'),
    ], startAt: 1);

    // 1. Falha no MP3 cai no TTS, marca playingRecorded=false e avança do chunk 0 ao chunk 1.
    unawaited(handler.play());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recordedAttempts, 1);
    expect(handler.playingRecorded, isFalse);
    expect(gate.calls, hasLength(1));

    gate.gates[0].complete(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gate.calls, hasLength(2));

    // 2. Pausar e retomar em fallback NÃO tenta recarregar a URL que falhou.
    await handler.pause();
    recordedAttempts = 0;
    unawaited(handler.play());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recordedAttempts, 0);
    expect(handler.playingRecorded, isFalse);
    expect(gate.calls, hasLength(3));

    // 3. Alterar velocidade e voz durante fallback reinicia trecho; mesma velocidade é no-op.
    await handler.setSpeed(1.25);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gate.calls.last.speed, 1.25);
    final beforeNoop = gate.calls.length;
    await handler.setSpeed(1.25);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gate.calls, hasLength(beforeNoop));

    await handler.setKokoroVoice('pm_alex');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gate.calls.last.voice, 'pm_alex');

    // 4. Avança além do 2º bloco (_chunk > 1) e valida skipToPrevious voltando ao início da leitura (index 1).
    gate.gates.last.complete(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    unawaited(handler.skipToPrevious());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(handler.index, 1);

    await handler.dispose();
  });

  test('ReadingAudioController evita double-play, valida isLoadedFor e encerra em dispose', () async {
    final gate = _SpeechGate();
    final handler = ReadingAudioHandler(
      useNeuralEngine: true,
      neuralSpeak: gate.speak,
      neuralStop: gate.stopAll,
      fallbackSpeak: (text, language, speed) async {},
    );
    final controller = ReadingAudioController.local(handler: handler);
    const queue = [
      ReadingSegment(id: 'a', title: '1ª Leitura', text: 'Texto A.'),
      ReadingSegment(id: 'b', title: 'Salmo Responsorial', text: 'Texto B.'),
      ReadingSegment(id: 'c', title: 'Evangelho', text: 'Texto C.'),
    ];

    // 1. Iniciar no Salmo (índice 1) chama síntese exatamente 1 vez.
    unawaited(controller.playQueue('liturgia-2026-11-19#segmented', queue, startAt: 1, speed: 1.0));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gate.calls.map((c) => c.text), ['Texto B.']);
    expect(controller.index, 1);

    // 2. Trocar para Evangelho (índice 2) na mesma fila tocando NÃO faz double-play.
    unawaited(controller.playQueue('liturgia-2026-11-19#segmented', queue, startAt: 2, speed: 1.0));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gate.calls.map((c) => c.text), ['Texto B.', 'Texto C.']);
    expect(controller.index, 2);

    expect(controller.isLoadedFor('liturgia-2026-11-19'), isTrue);
    expect(controller.isLoadedFor('liturgia-2026-11-20'), isFalse);
    expect(controller.isLoadedFor('homilia-2026-11-19'), isFalse);

    var notificationsAfterDispose = 0;
    controller.addListener(() => notificationsAfterDispose++);
    controller.dispose();
    notificationsAfterDispose = 0;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notificationsAfterDispose, 0);
  });

  testWidgets('AudioPlayerBar só exibe Pause/controles quando carregada para expectedKey', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final gate = _SpeechGate();
    final handler = ReadingAudioHandler(
      useNeuralEngine: true,
      neuralSpeak: gate.speak,
      neuralStop: gate.stopAll,
      fallbackSpeak: (text, language, speed) async {},
    );
    final audio = ReadingAudioController.local(handler: handler);
    addTearDown(audio.dispose);

    // Outro conteúdo (Bíblia) tocando no controller global.
    unawaited(audio.playSingle(const ReadingSegment(id: 'bible-Gn-1', title: 'Gênesis 1', text: 'No princípio.')));
    await _pumpAsync(tester);
    expect(audio.playing, isTrue);

    var playAllCalls = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioPlayerBar(expectedKey: 'liturgia-2026-11-19', onPlayAll: () => playAllCalls++, recorded: true),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.text('Áudio narrado disponível'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(playAllCalls, 1);

    // Agora carrega e toca a liturgia do dia esperado no índice 2 (Evangelho).
    unawaited(
      audio.playQueue('liturgia-2026-11-19#segmented', const [
        ReadingSegment(id: '1', title: '1ª Leitura', text: 'A.'),
        ReadingSegment(id: '2', title: 'Salmo Responsorial', text: 'B.'),
        ReadingSegment(id: '3', title: 'Evangelho', text: 'C.'),
      ], startAt: 2),
    );
    await _pumpAsync(tester);

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('Evangelho'), findsOneWidget);
  });

  testWidgets('PsalmCard coordena pausa mútua com ReadingAudioController e retoma sem recarregar URL', (tester) async {
    final gate = _SpeechGate();
    final handler = ReadingAudioHandler(
      useNeuralEngine: true,
      neuralSpeak: gate.speak,
      neuralStop: gate.stopAll,
      fallbackSpeak: (text, language, speed) async {},
    );
    final audio = ReadingAudioController.local(handler: handler);
    addTearDown(audio.dispose);

    final fakePlayer = _FakeAudioPlayer();
    const psalm = Reading(
      kind: ReadingKind.salmo,
      reference: 'Sl 149,1-2',
      refrain: 'O Senhor é bom.',
      text: 'Cantai ao Senhor.',
      source: 'CNBB',
    );
    const liturgyAudio = LiturgyAudio(psalmAudioUrl: 'https://cdn.example/salmo.mp3');

    // Inicia leitura principal antes de tocar o salmo.
    unawaited(audio.playSingle(const ReadingSegment(id: 'lit-1', title: '1ª Leitura', text: 'Texto longo.')));
    await _pumpAsync(tester);
    expect(audio.playing, isTrue);

    await tester.pumpWidget(
      ChangeNotifierProvider<ReadingAudioController>.value(
        value: audio,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PsalmCard(
                psalm: psalm,
                audio: liturgyAudio,
                onListenFromHere: () {},
                playerFactory: () => fakePlayer,
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Tocar salmo pausa o player principal e carrega URL 1 vez.
    await tester.tap(find.text('Ouvir Refrão Cantado'));
    await _pumpAsync(tester);
    expect(audio.playing, isFalse);
    expect(fakePlayer.setUrlCalls, ['https://cdn.example/salmo.mp3']);
    expect(fakePlayer.playCalls, 1);
    expect(find.text('Pausar refrão'), findsOneWidget);

    // 2. Pausar e retomar não recarrega URL.
    await tester.tap(find.text('Pausar refrão'));
    await _pumpAsync(tester);
    expect(fakePlayer.pauseCalls, 1);
    expect(find.text('Ouvir Refrão Cantado'), findsOneWidget);

    await tester.tap(find.text('Ouvir Refrão Cantado'));
    await _pumpAsync(tester);
    expect(fakePlayer.setUrlCalls, hasLength(1));
    expect(fakePlayer.playCalls, 2);
    expect(find.text('Pausar refrão'), findsOneWidget);

    // 3. Iniciar leitura principal novamente pausa o salmo automaticamente.
    unawaited(audio.playSingle(const ReadingSegment(id: 'lit-2', title: 'Evangelho', text: 'Naquele tempo.')));
    await _pumpAsync(tester);
    expect(fakePlayer.pauseCalls, 2);
    expect(find.text('Ouvir Refrão Cantado'), findsOneWidget);
  });
}
