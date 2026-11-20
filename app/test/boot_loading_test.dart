import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:via_sacra/app_state.dart';
import 'package:via_sacra/core/liturgical_color.dart';
import 'package:via_sacra/core/theme.dart';
import 'package:via_sacra/data/bible/bible_module.dart';
import 'package:via_sacra/data/bible/bible_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/features/bible/bible_screen.dart';
import 'package:via_sacra/services/bible_service.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _miniBible(String id, String name, String abbr, String lang, {int version = 1}) => {
  'formato': 'viasacra-biblia',
  'versao': 1,
  'id': id,
  'nome': name,
  'abreviacao': abbr,
  'idioma': lang,
  'licenca': 'Domínio público',
  'versao_modulo': version,
  'livros': [
    {
      'id': 'gn',
      'capitulos': [
        ['No princípio Deus criou o céu e a terra.'],
      ],
    },
    {
      'id': 'jo',
      'capitulos': [
        ['No princípio era o Verbo.'],
      ],
    },
  ],
};

String _fakeManifest({List<String> ids = const ['bpm', 'vulgata']}) => jsonEncode({
  'modulos': ids,
  'catalogo': [
    for (final id in ids)
      {
        'id': id,
        'nome': id == 'bpm' ? 'Bíblia Portuguesa Mundial' : 'Vulgata Clementina',
        'abreviacao': id == 'bpm' ? 'BPM' : 'VUL',
        'idioma': id == 'bpm' ? 'pt-BR' : 'la',
        'licenca': 'Domínio público',
        'versao_modulo': 1,
        'tamanho_mb': 4.5,
      },
  ],
});

void main() {
  setUpScreens();

  test('BibleRepository.install não mantém transação SQLite aberta entre await e oculta parcial', () async {
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(db.close);
    final repo = BibleRepository(db);
    final vulgata = BibleModule.parse(
      jsonDecode(File('assets/bible/vulgata.json').readAsStringSync()) as Map<String, dynamic>,
    );

    var concurrentWrites = 0;
    var visibleWhileInstalling = false;

    await repo.install(
      vulgata,
      bundled: true,
      onProgress: (_) {
        if (concurrentWrites == 0) {
          visibleWhileInstalling = repo.translations().isNotEmpty;
          // Outra transação no mesmo banco durante a instalação não pode falhar com
          // "cannot start a transaction within a transaction".
          db.db.execute('BEGIN');
          db.db.execute('INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)', ['concurrent_test', 'ok']);
          db.db.execute('COMMIT');
          concurrentWrites++;
        }
      },
    );

    expect(concurrentWrites, 1);
    expect(visibleWhileInstalling, isFalse);
    expect(db.meta('concurrent_test'), 'ok');
    expect(repo.translations().single.id, 'vulgata');
    expect(repo.translations().single.verseCount, 35807);
  });

  test('Modo Web (autoInstallBundled: false) lê só bundled.json e instala sob demanda sem re-parse', () async {
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(db.close);
    final repo = BibleRepository(db);
    final reads = <String, int>{};

    Future<String> fakeLoad(String path) async {
      reads[path] = (reads[path] ?? 0) + 1;
      if (path == 'assets/bible/bundled.json') return _fakeManifest();
      if (path == 'assets/bible/bpm.json') {
        return jsonEncode(_miniBible('bpm', 'Bíblia Portuguesa Mundial', 'BPM', 'pt-BR'));
      }
      if (path == 'assets/bible/vulgata.json') {
        return jsonEncode(_miniBible('vulgata', 'Vulgata Clementina', 'VUL', 'la'));
      }
      throw StateError('Asset inesperado: $path');
    }

    final service = BibleService(repo, autoInstallBundled: false, loadAsset: fakeLoad);
    await service.ensureBundled();

    expect(reads['assets/bible/bundled.json'], 1);
    expect(reads['assets/bible/bpm.json'], isNull);
    expect(reads['assets/bible/vulgata.json'], isNull);
    expect(service.ready, isFalse);
    expect(service.availableBundled.map((b) => b.id), ['bpm', 'vulgata']);

    await service.installBundled('bpm');
    expect(reads['assets/bible/bpm.json'], 1);
    expect(service.ready, isTrue);
    expect(service.translations.map((t) => t.id), ['bpm']);
    expect(service.availableBundled.map((b) => b.id), ['vulgata']);

    // Segunda chamada para a mesma tradução não re-lê nem re-parseia o JSON.
    await service.installBundled('bpm');
    expect(reads['assets/bible/bpm.json'], 1);
  });

  test('Modo Nativo permite retry após erro e pula JSONs já instalados', () async {
    final db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    addTearDown(db.close);
    final repo = BibleRepository(db);
    final reads = <String, int>{};
    var failFirst = true;

    Future<String> fakeLoad(String path) async {
      reads[path] = (reads[path] ?? 0) + 1;
      if (path == 'assets/bible/bundled.json') {
        if (failFirst) {
          failFirst = false;
          throw Exception('Falha transitória simulada');
        }
        return _fakeManifest(ids: const ['bpm']);
      }
      if (path == 'assets/bible/bpm.json') {
        return jsonEncode(_miniBible('bpm', 'Bíblia Portuguesa Mundial', 'BPM', 'pt-BR'));
      }
      throw StateError('Asset inesperado: $path');
    }

    final service1 = BibleService(repo, autoInstallBundled: true, loadAsset: fakeLoad);
    await expectLater(service1.ensureBundled(), throwsException);
    expect(service1.ready, isFalse);

    // Retry deve funcionar (Future rejeitada não pode ficar em cache).
    await service1.ensureBundled();
    expect(service1.ready, isTrue);
    expect(reads['assets/bible/bpm.json'], 1);

    // Nova instância sobre o mesmo banco já populado não re-lê bpm.json.
    final service2 = BibleService(repo, autoInstallBundled: true, loadAsset: fakeLoad);
    await service2.ensureBundled();
    expect(reads['assets/bible/bpm.json'], 1);
    expect(service2.ready, isTrue);
  });

  testWidgets('BibleScreen no modo Web exibe catálogo sob demanda e instala ao clicar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final services = await buildServices(onboardingDone: true);
    addTearDown(services.database.close);
    final repo = BibleRepository(services.database);

    Future<String> fakeLoad(String path) async {
      if (path == 'assets/bible/bundled.json') return File('assets/bible/bundled.json').readAsStringSync();
      if (path == 'assets/bible/bpm.json') {
        return jsonEncode(_miniBible('bpm', 'Bíblia Portuguesa Mundial', 'BPM', 'pt-BR'));
      }
      throw StateError('Asset inesperado: $path');
    }

    final webBible = BibleService(repo, autoInstallBundled: false, loadAsset: fakeLoad);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider<BibleService>.value(value: webBible),
          ChangeNotifierProvider.value(value: services.settings),
          ChangeNotifierProvider.value(value: services.audio),
        ],
        child: MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light, liturgicalColor: LiturgicalColor.verde),
          home: const BibleScreen(),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Bíblia Portuguesa Mundial'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Vulgata Clementina'), 200);
    expect(find.text('Vulgata Clementina'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Douay-Rheims (Challoner)'), 200);
    expect(find.text('Douay-Rheims (Challoner)'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.scrollUntilVisible(find.text('CÂNON CATÓLICO · 73 LIVROS'), -200);
    await tester.ensureVisible(find.text('Baixar e ler').first);
    await tester.tap(find.text('Baixar e ler').first);
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !webBible.ready; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await settle(tester);

    expect(webBible.ready, isTrue);
    expect(find.text('ANTIGO TESTAMENTO'), findsOneWidget);
  });
}
