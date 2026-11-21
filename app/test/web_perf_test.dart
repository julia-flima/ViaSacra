import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:via_sacra/app.dart';
import 'package:via_sacra/app_state.dart';
import 'package:via_sacra/core/liturgical_color.dart';
import 'package:via_sacra/core/theme.dart';
import 'package:via_sacra/data/bible/bible_models.dart';
import 'package:via_sacra/data/bible/bible_module.dart';
import 'package:via_sacra/data/bible/bible_repository.dart';
import 'package:via_sacra/data/catechism_repository.dart';
import 'package:via_sacra/data/content_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/liturgy_repository.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/data/models/mystery.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:via_sacra/features/bible/bible_screen.dart';
import 'package:via_sacra/features/bible/marked_verses_screen.dart';
import 'package:via_sacra/features/catechism/catechism_screen.dart';
import 'package:via_sacra/features/liturgy/widgets/reading_card.dart';
import 'package:via_sacra/services/bible_service.dart';
import 'package:via_sacra/services/reading_audio_service.dart';
import 'package:via_sacra/services/settings_service.dart';
import 'package:via_sacra/widgets/sacred_art_header.dart';
import 'package:via_sacra/widgets/sacred_art_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppTheme alinha famílias e pesos com pubspec.yaml', () {
    final light = AppTheme.build(brightness: Brightness.light, liturgicalColor: LiturgicalColor.verde);
    final t = light.textTheme;
    expect(t.displaySmall?.fontFamily, 'Merriweather');
    expect(t.headlineSmall?.fontWeight, FontWeight.w400);
    expect(t.titleLarge?.fontWeight, FontWeight.w400);
    expect(t.titleMedium?.fontFamily, 'Roboto');
    expect(t.titleMedium?.fontWeight, FontWeight.w500);
    expect(t.titleSmall?.fontWeight, FontWeight.w500);
    expect(t.labelLarge?.fontWeight, FontWeight.w500);
    expect(t.bodyLarge?.fontFamily, 'Merriweather');

    final sans = AppTheme.build(
      brightness: Brightness.dark,
      liturgicalColor: LiturgicalColor.roxo,
      font: ReadingFont.sans,
    );
    expect(sans.textTheme.bodyLarge?.fontFamily, 'Roboto');
  });

  testWidgets('ReadingCard e PsalmCard usam um SelectionArea único (zero SelectableText)', (tester) async {
    const reading = Reading(
      kind: ReadingKind.evangelho,
      reference: 'Jo 3,16',
      acclamation: 'Aleluia!',
      text: 'Porque Deus amou o mundo de tal maneira...',
      source: 'CNBB',
    );
    const psalm = Reading(
      kind: ReadingKind.salmo,
      reference: 'Sl 22(23)',
      refrain: 'O Senhor é o pastor que me conduz.',
      stanzas: ['Estrofe 1', 'Estrofe 2', 'Estrofe 3'],
      text: 'Estrofe 1\nEstrofe 2\nEstrofe 3',
      source: 'CNBB',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ReadingCard(reading: reading, onListenFromHere: () {}),
              PsalmCard(psalm: psalm, onListenFromHere: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNWidgets(2));
  });

  testWidgets('CatechismScreen expande partes sob demanda sem instanciar 978 entradas no boot', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final settings = await SettingsService.load();
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(() async => db.close());
    await tester.runAsync(() async {
      await db.importCatechismWork(
        jsonDecode(File('assets/db/sao_pio_x.json').readAsStringSync()) as Map<String, dynamic>,
        bundled: true,
      );
    });
    final services = AppServices(
      settings: settings,
      database: db,
      liturgyRepository: LiturgyRepository(db),
      content: ContentRepository(),
      catechism: CatechismRepository(db),
      userData: UserDataRepository(db),
      audio: ReadingAudioController.local(),
      notifications: null,
      bible: BibleService(BibleRepository(db), autoInstallBundled: false),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Provider<AppServices>.value(
        value: services,
        child: const MaterialApp(home: CatechismScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Sois cristão?'), findsNothing);
    expect(find.text('P. 1'), findsNothing);

    final firstPart = services.catechism.partSummaries('sao_pio_x').first.part;
    await tester.scrollUntilVisible(find.text(firstPart), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(firstPart));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Sois cristão?'), 150, scrollable: find.byType(Scrollable).first);

    expect(find.text('Sois cristão?'), findsOneWidget);
    expect(find.text('P. 1'), findsOneWidget);
    expect(find.byType(SliverList), findsWidgets);
  });

  testWidgets('BibleScreen renderiza capítulo longo com SliverList lazy e MarkedVersesScreen sem N+1', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final settings = await SettingsService.load();
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(() async => db.close());

    final repo = BibleRepository(db);
    await tester.runAsync(() async {
      final mod = BibleModule.parse({
        'formato': 'viasacra-biblia',
        'versao': 1,
        'id': 'teste',
        'nome': 'Tradução Teste',
        'abreviacao': 'TST',
        'idioma': 'pt-BR',
        'licenca': 'Domínio público',
        'livros': [
          {
            'id': 'sl',
            'capitulos': {
              '119': {for (var v = 1; v <= 150; v++) '$v': 'Versículo longo número $v do salmo.'},
            },
          },
        ],
      });
      await repo.install(mod, bundled: true);
    });
    repo.saveAnnotation('sl', 119, 120, const VerseAnnotation(favorite: true, note: 'Meditar'));

    final bible = BibleService(repo, autoInstallBundled: false)..open('teste', 'sl', 119, verse: 1);
    final services = AppServices(
      settings: settings,
      database: db,
      liturgyRepository: LiturgyRepository(db),
      content: ContentRepository(),
      catechism: CatechismRepository(db),
      userData: UserDataRepository(db),
      audio: ReadingAudioController.local(),
      notifications: null,
      bible: bible,
    );

    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BibleService>.value(value: bible),
          ChangeNotifierProvider<ReadingAudioController>.value(value: services.audio),
        ],
        child: const MaterialApp(home: BibleScreen()),
      ),
    );
    await tester.pump();
    // Entra no leitor pelo card "Continuar lendo"
    await tester.scrollUntilVisible(find.text('Continuar lendo'), 200);
    await tester.tap(find.text('Continuar lendo'));
    await tester.pumpAndSettle();

    expect(find.byType(SliverList), findsOneWidget);
    final builtVerses = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('teste-sl-119-'),
    );
    expect(builtVerses.evaluate().length, lessThan(40));

    // Marcações carregadas sem N+1
    await tester.pumpWidget(
      ChangeNotifierProvider<BibleService>.value(
        value: bible,
        child: const MaterialApp(home: MarkedVersesScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Sl 119,120'), findsOneWidget);
    expect(find.textContaining('Versículo longo número 120'), findsOneWidget);
    expect(find.textContaining('Nota: Meditar'), findsOneWidget);
  });

  testWidgets('SacredArt widgets usam RepaintBoundary e cacheWidth', (tester) async {
    const art = SacredArt(
      id: 'header-biblia',
      title: 'Bíblia',
      artist: 'Autor',
      year: '1600',
      collection: 'Acervo',
      license: 'Domínio público',
      assetPath: 'assets/art/header-biblia.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const SacredArtBanner(title: 'T1', art: art),
              SacredArtCard(title: 'T2', subtitle: 'S2', art: art, onTap: () {}),
              const SacredArtImage(art: art),
            ],
          ),
        ),
      ),
    );

    final imgs = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(imgs, hasLength(3));
    for (final img in imgs) {
      expect(img.image, isA<ResizeImage>());
      expect((img.image as ResizeImage).width, 800);
    }
    expect(find.ancestor(of: find.byType(SacredArtBanner), matching: find.byType(RepaintBoundary)), findsWidgets);
    expect(find.descendant(of: find.byType(SacredArtBanner), matching: find.byType(RepaintBoundary)), findsWidgets);
    expect(find.descendant(of: find.byType(SacredArtCard), matching: find.byType(RepaintBoundary)), findsWidgets);
    expect(find.descendant(of: find.byType(SacredArtImage), matching: find.byType(RepaintBoundary)), findsWidgets);
  });

  // Cada tela carrega só a obra que mostra; o limite protege o tamanho do APK e do site.
  test('Imagens em assets/art existem no catálogo e pesam menos de 8 MB no total', () {
    final catalog = (jsonDecode(File('assets/data/sacred_art.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    for (final entry in catalog) {
      final path = entry['imagem'] as String;
      expect(File(path).existsSync(), isTrue, reason: 'Arquivo ausente: $path');
    }
    final files = Directory('assets/art').listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList();
    expect(files, hasLength(catalog.length));
    final totalBytes = files.fold<int>(0, (acc, f) => acc + f.lengthSync());
    expect(totalBytes, lessThan(8 * 1024 * 1024));
  });

  testWidgets('ViaSacraApp usa Selector sem reconstruir HomeShell ao mudar textScale', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final settings = await SettingsService.load();
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(() async => db.close());
    final services = AppServices(
      settings: settings,
      database: db,
      liturgyRepository: LiturgyRepository(db),
      content: ContentRepository(),
      catechism: CatechismRepository(db),
      userData: UserDataRepository(db),
      audio: ReadingAudioController.local(),
      notifications: null,
      bible: BibleService(BibleRepository(db), autoInstallBundled: false),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ViaSacraApp(services: services));
    await tester.pump();
    final shellState = tester.state(find.byType(HomeShell));

    settings.textScale = 1.3;
    await tester.pump();
    expect(tester.state(find.byType(HomeShell)), same(shellState));
    expect(MediaQuery.textScalerOf(tester.element(find.byType(HomeShell))).scale(10), closeTo(13, 0.01));
  });
}
