import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/app_state.dart';
import 'package:via_sacra/data/bible/bible_module.dart';
import 'package:via_sacra/data/bible/bible_repository.dart';
import 'package:via_sacra/data/catechism_repository.dart';
import 'package:via_sacra/data/content_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/liturgy_repository.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:via_sacra/features/bible/bible_screen.dart';
import 'package:via_sacra/features/prayers/via_sacra_screen.dart';
import 'package:via_sacra/services/bible_service.dart';
import 'package:via_sacra/services/neural_tts_types.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';
import 'package:via_sacra/widgets/global_audio_mini_player.dart';

void _mockChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.just_audio.methods'),
    (call) async => <String, dynamic>{},
  );
  messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'), (call) async => null);
}

class _SpeechGate {
  final gates = <Completer<bool>>[];
  final texts = <String>[];
  final speeds = <double>[];

  Future<bool> speak(
    String text,
    double speed, {
    String voice = 'pf_dora',
    String language = 'pt-BR',
    String? nextText,
  }) {
    texts.add(text);
    speeds.add(speed);
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
    await tester.pump(const Duration(milliseconds: 10));
  }
}

ReadingAudioController _newController(_SpeechGate gate) => ReadingAudioController.local(
  handler: ReadingAudioHandler(
    useNeuralEngine: true,
    neuralSpeak: gate.speak,
    neuralStop: gate.stopAll,
    fallbackSpeak: (text, language, speed) async {},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_mockChannels);

  testWidgets('GlobalAudioMiniPlayer fica oculto quando não há áudio nem download ativo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final audio = _newController(_SpeechGate());
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(), bottomNavigationBar: GlobalAudioMiniPlayer()),
        ),
      ),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('BibleScreen inicia áudio e pausa/retoma/ajusta velocidade/fecha sem sair da tela', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final settings = await SettingsService.load();
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(() async => db.close());

    final repo = BibleRepository(db);
    await tester.runAsync(() async {
      final mod = BibleModule.parse({
        'formato': 'viasacra-biblia',
        'versao': 1,
        'id': 'teste-biblia',
        'nome': 'Tradução Teste',
        'abreviacao': 'TST',
        'idioma': 'pt-BR',
        'licenca': 'Domínio público',
        'livros': [
          {
            'id': 'gn',
            'capitulos': {
              '1': {'1': 'No princípio, Deus criou o céu e a terra.', '2': 'A terra estava informe e vazia.'},
            },
          },
        ],
      });
      await repo.install(mod, bundled: true);
    });

    final bible = BibleService(repo, autoInstallBundled: false)..open('teste-biblia', 'gn', 1);
    final gate = _SpeechGate();
    final audio = _newController(gate);
    addTearDown(audio.dispose);

    final services = AppServices(
      settings: settings,
      database: db,
      liturgyRepository: LiturgyRepository(db),
      content: ContentRepository(),
      catechism: CatechismRepository(db),
      userData: UserDataRepository(db),
      audio: audio,
      notifications: null,
      bible: bible,
    );

    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BibleService>.value(value: bible),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BibleScreen(), bottomNavigationBar: GlobalAudioMiniPlayer()),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Continuar lendo'), 200);
    await tester.tap(find.text('Continuar lendo'));
    await _pumpAsync(tester);

    expect(find.byTooltip('Ouvir capítulo'), findsOneWidget);
    await tester.tap(find.byTooltip('Ouvir capítulo'));
    await _pumpAsync(tester);

    // Mini-player aparece sobre a tela da Bíblia sem navegação para Liturgia.
    expect(find.text('Gênesis 1'), findsWidgets);
    expect(find.text('Tradução Teste'), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    expect(find.byTooltip('Anterior'), findsNothing);
    expect(find.byTooltip('Próximo'), findsNothing);
    expect(audio.playing, isTrue);

    // Pausar e retomar pela barra global.
    await tester.tap(find.byTooltip('Pausar'));
    await _pumpAsync(tester);
    expect(audio.playing, isFalse);
    expect(find.byTooltip('Retomar'), findsOneWidget);

    await tester.tap(find.byTooltip('Retomar'));
    await _pumpAsync(tester);
    expect(audio.playing, isTrue);
    expect(find.byTooltip('Pausar'), findsOneWidget);

    // Alterar velocidade e verificar persistência.
    await tester.tap(find.byTooltip('Velocidade de leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1,25×'));
    await tester.pumpAndSettle();
    await _pumpAsync(tester);
    expect(audio.speed, 1.25);
    expect(settings.ttsSpeed, 1.25);

    // Parar e fechar oculta o mini-player mantendo o leitor aberto em Gênesis 1.
    await tester.tap(find.byTooltip('Parar e fechar'));
    await _pumpAsync(tester);
    expect(audio.hasQueue, isFalse);
    expect(audio.playing, isFalse);
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(find.byTooltip('Ouvir capítulo'), findsOneWidget);
  });

  testWidgets('GlobalAudioMiniPlayer em largura 360px exibe Anterior/Próximo em fila múltipla sem overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final gate = _SpeechGate();
    final audio = _newController(gate);
    addTearDown(audio.dispose);

    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    unawaited(
      audio.playQueue('liturgia-2026-11-19#segmented', const [
        ReadingSegment(id: '1', title: '1ª Leitura com título bem comprido para testar ellipsis', text: 'Um.'),
        ReadingSegment(id: '2', title: 'Salmo Responsorial', subtitle: 'Sl 149', text: 'Dois.'),
      ]),
    );
    await _pumpAsync(tester);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(), bottomNavigationBar: GlobalAudioMiniPlayer()),
        ),
      ),
    );
    await _pumpAsync(tester);

    expect(find.byTooltip('Anterior'), findsOneWidget);
    expect(find.byTooltip('Próximo'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo'));
    await _pumpAsync(tester);
    expect(find.text('Salmo Responsorial'), findsOneWidget);
    expect(find.text('Sl 149'), findsOneWidget);
  });

  testWidgets('GlobalAudioMiniPlayer mostra progresso de download e indicador de síntese Kokoro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final gate = _SpeechGate();
    final audio = _newController(gate);
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(), bottomNavigationBar: GlobalAudioMiniPlayer()),
        ),
      ),
    );

    // 1. Download sem fila ainda criada.
    audio.setNeuralTtsStatusForTest(
      const NeuralTtsStatus(
        state: NeuralTtsState.downloading,
        progress: 0.65,
        label: 'Baixando voz neural Kokoro (65%)…',
      ),
    );
    await tester.pump();
    expect(find.text('Baixando voz neural Kokoro (65%)…'), findsOneWidget);
    final downloadBar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(downloadBar.value, 0.65);

    // 2. Fila tocando durante síntese neural (NeuralTtsState.ready + playing).
    audio.setNeuralTtsStatusForTest(const NeuralTtsStatus(state: NeuralTtsState.ready, cached: true));
    unawaited(audio.playSingle(const ReadingSegment(id: 'seg', title: 'Evangelho', text: 'Naquele tempo.')));
    await _pumpAsync(tester);
    expect(find.text('Sintetizando voz neural…'), findsOneWidget);
    final synthBar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(synthBar.value, isNull);
  });

  testWidgets('Rota isolada ViaSacraScreen inclui GlobalAudioMiniPlayer para pausar e fechar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(() async => db.close());

    final gate = _SpeechGate();
    final audio = _newController(gate);
    addTearDown(audio.dispose);

    final services = AppServices(
      settings: settings,
      database: db,
      liturgyRepository: LiturgyRepository(db),
      content: ContentRepository(),
      catechism: CatechismRepository(db),
      userData: UserDataRepository(db),
      audio: audio,
      notifications: null,
      bible: BibleService(BibleRepository(db), autoInstallBundled: false),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ReadingAudioController>.value(value: audio),
        ],
        child: const MaterialApp(home: ViaSacraScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Ouvir estação'));
    await _pumpAsync(tester);
    expect(find.text('1ª Estação'), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsOneWidget);

    await tester.tap(find.byTooltip('Parar e fechar'));
    await _pumpAsync(tester);
    expect(audio.hasQueue, isFalse);
    expect(find.byTooltip('Pausar'), findsNothing);
  });
}
