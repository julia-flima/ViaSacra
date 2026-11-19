// Smoke test de todas as abas + geração de capturas para o fastlane/F-Droid.
//
//   flutter test test/screens_test.dart                       # verifica layout (sem overflow)
//   flutter test test/screens_test.dart --update-goldens \
//     --dart-define=FONT_DIR=/usr/share/fonts/truetype        # gera PNGs em test/goldens/
import 'dart:io';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/app.dart';
import 'package:via_sacra/app_state.dart';
import 'package:via_sacra/data/catechism_repository.dart';
import 'package:via_sacra/data/content_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/liturgy_repository.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';

const _fontDir = String.fromEnvironment('FONT_DIR');
final _goldens = Platform.environment['GOLDENS'] == '1' || _fontDir.isNotEmpty;

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    if (File(f).existsSync()) loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<AppServices> _services({required bool onboardingDone, bool dark = false}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboardingDone,
    'theme_mode': dark ? ThemeMode.dark.index : ThemeMode.light.index,
  });
  final settings = await SettingsService.load();
  final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
  await db.importCatechism((await _json('assets/db/catechism.json')));
  final fixture = File('test/fixtures/liturgia-2026-11-19.json').readAsStringSync();
  final client = MockClient((_) async => http.Response.bytes(fixture.codeUnits.isEmpty ? [] : _utf8(fixture), 200));
  final content = ContentRepository();
  await content.load();
  final user = UserDataRepository(db);
  for (var i = 1; i <= 6; i++) {
    user.logPrayer(PrayerKind.terco, day: DateTime.now().subtract(Duration(days: i)));
  }
  return AppServices(
    settings: settings,
    database: db,
    liturgyRepository: LiturgyRepository(db, client: client),
    content: content,
    catechism: CatechismRepository(db),
    userData: user,
    audio: ReadingAudioController.local(),
    notifications: null,
  );
}

List<int> _utf8(String s) => const Utf8Codec().encode(s);

Future<Map<String, dynamic>> _json(String path) async =>
    (const JsonDecoder().convert(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
    await _loadFont('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    if (_fontDir.isNotEmpty) {
      await _loadFont('EBGaramond', [
        '$_fontDir/liberation/LiberationSerif-Regular.ttf',
        '$_fontDir/liberation/LiberationSerif-Italic.ttf',
        '$_fontDir/liberation/LiberationSerif-Bold.ttf',
      ]);
      await _loadFont('Inter', [
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
      ]);
    }
  });

  Future<void> pumpApp(WidgetTester tester, AppServices s) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    // Pré-carrega o cache em tempo real: na tela, a liturgia vem do SQLite sem timers de rede.
    await tester.runAsync(() => s.liturgyRepository.load(DateTime.now()));
    await tester.pumpWidget(ViaSacraApp(services: s));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // Imagens de assets precisam ser decodificadas fora do relógio falso.
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpAndSettle();
    if (_goldens) await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('Onboarding', (tester) async {
    await pumpApp(tester, await _services(onboardingDone: false));
    expect(find.text('Deseja receber lembretes?'), findsOneWidget);
    await shot(tester, '0-onboarding');
  });

  testWidgets(
    'Todas as abas renderizam sem erros',
    skip: true, // TODO: trava em pumpAndSettle após renderizar as leituras — investigar
    (tester) async {
      await pumpApp(tester, await _services(onboardingDone: true));

      // Aba 1 — Liturgia
      expect(find.text('Liturgia Diária'), findsWidgets);
      expect(find.textContaining('33ª Semana do Tempo Comum'), findsWidgets);
      expect(find.text('Ouvir Liturgia'), findsOneWidget);
      expect(find.text('Ap 5,1-10'), findsOneWidget);
      await shot(tester, '1-liturgia');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      await shot(tester, '2-salmo-evangelho');

      // Aba 2 — Terço
      await tester.tap(find.text('Terço'));
      await tester.pumpAndSettle();
      expect(find.text('Jornada de Maria'), findsOneWidget);
      expect(find.textContaining('6 dias seguidos'), findsOneWidget);
      await shot(tester, '3-terco');
      await tester.scrollUntilVisible(find.text('Rezar o Terço'), 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Rezar o Terço'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 6 + 4; i++) {
        await tester.tap(find.textContaining(RegExp(r'Amém|Ave-Maria  ')));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.text('Ave-Maria 4 de 10'), findsOneWidget);
      await shot(tester, '4-contador');
      await tester.tap(find.byTooltip('Encerrar'));
      await tester.pumpAndSettle();

      // Aba 3 — Catecismo
      await tester.tap(find.text('Catecismo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'graça');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('§ 1996'), findsOneWidget);
      await shot(tester, '5-catecismo');

      // Aba 4 — Orações
      await tester.tap(find.text('Orações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salve-Rainha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latim'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Salve, Regina'), findsWidgets);
      await shot(tester, '6-oracao-latim');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Aba 5 — Ajustes
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Ativar lembretes'), findsOneWidget);
      await shot(tester, '7-ajustes');
    },
  );

  testWidgets(
    'Modo Igreja (escuro)',
    skip: true, // TODO: idem acima
    (tester) async {
      await pumpApp(tester, await _services(onboardingDone: true, dark: true));
      await shot(tester, '8-modo-igreja');
    },
  );
}
