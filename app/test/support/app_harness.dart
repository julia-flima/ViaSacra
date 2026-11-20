// Infraestrutura comum dos testes de tela (smoke tests + capturas para o fastlane).
//
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
import 'package:via_sacra/data/bible/bible_repository.dart';
import 'package:via_sacra/data/catechism_repository.dart';
import 'package:via_sacra/data/content_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/liturgy_repository.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:via_sacra/services/bible_service.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';

final _goldens = Platform.environment['GOLDENS'] == '1';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    if (File(f).existsSync()) loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<AppServices> buildServices({
  required bool onboardingDone,
  bool dark = false,
  ReadingAudioController? audio,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboardingDone,
    'theme_mode': dark ? ThemeMode.dark.index : ThemeMode.light.index,
  });
  final settings = await SettingsService.load();
  final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
  await db.importCatechism((await _json('assets/db/catechism.json')));
  await db.importCatechismWork((await _json('assets/db/sao_pio_x.json')), bundled: true);
  await db.importCatechismWork((await _json('assets/db/catecismo_romano.json')), bundled: true);
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
    audio: audio ?? ReadingAudioController.local(),
    notifications: null,
    bible: BibleService(BibleRepository(db)),
  );
}

List<int> _utf8(String s) => const Utf8Codec().encode(s);

Future<Map<String, dynamic>> _json(String path) async =>
    (const JsonDecoder().convert(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

/// Avança um número fixo de quadros. Evita pumpAndSettle, que nestes testes
/// (tempo real via runAsync + tempo falso) pode esperar indefinidamente.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Registra o carregamento de fontes/locale. Chame no início de cada main().
void setUpScreens() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
    // flutter_tester fica em <sdk>/bin/cache/artifacts/engine/<plataforma>/
    var dir = File(Platform.resolvedExecutable).parent;
    while (!Directory('${dir.path}/bin/cache/artifacts').existsSync() && dir.parent.path != dir.path) {
      dir = dir.parent;
    }
    final sdk = dir.path;
    await _loadFont('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    if (_goldens) {
      // Mesmas fontes embutidas no app (assets/fonts), para capturas fiéis.
      await _loadFont('Merriweather', [
        'assets/fonts/Merriweather-Regular.ttf',
        'assets/fonts/Merriweather-Italic.ttf',
        'assets/fonts/Merriweather-Light.ttf',
        'assets/fonts/Merriweather-BoldItalic.ttf',
      ]);
      await _loadFont('Roboto', [
        'assets/fonts/Roboto-Regular.ttf',
        'assets/fonts/Roboto-Medium.ttf',
        'assets/fonts/Roboto-Bold.ttf',
        'assets/fonts/Roboto-Italic.ttf',
      ]);
      await _loadFont('ViaSacraSymbols', ['assets/fonts/ViaSacraSymbols.ttf']);
    }
  });
}

Future<void> pumpApp(WidgetTester tester, AppServices s) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  // Pré-carrega o cache em tempo real: na tela, a liturgia vem do SQLite sem timers de rede.
  await tester.runAsync(() => s.liturgyRepository.load(DateTime.now()));
  await tester.runAsync(() => s.bible.ensureBundled()); // Bíblia pronta (senão o progresso anima para sempre)
  await tester.pumpWidget(ViaSacraApp(services: s));
  await tester.pump(const Duration(milliseconds: 100));
  await settle(tester);
}

Future<void> shot(WidgetTester tester, String name) async {
  if (_goldens) {
    // Só para capturas: imagens de assets são decodificadas fora do relógio falso.
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
  }
  await settle(tester);
  if (_goldens) await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}
