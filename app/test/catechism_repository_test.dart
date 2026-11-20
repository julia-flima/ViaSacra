import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/constants.dart';
import 'package:via_sacra/data/catechism_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/models/catechism.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:via_sacra/services/catechism_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // rootBundle (assets) no seed
  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    await db.importCatechism(jsonDecode(File('assets/db/catechism.json').readAsStringSync()) as Map<String, dynamic>);
  });

  tearDown(() => db.close());

  test('Índice do CIC com 4 partes + prólogo', () {
    final toc = CatechismRepository(db).toc();
    expect(toc, hasLength(5));
    expect(toc.last.last, 2865);
    expect(toc[2].children.last.children.first.children.last.title, 'O sacramento da Eucaristia');
    // Cada parte (inclusive o Prólogo, id "prologo") abre a sua página oficial.
    final urls = [for (final n in toc) ExternalLinks.catechismPartUrl(n.id)];
    expect(urls.toSet(), hasLength(5));
    expect(urls, isNot(contains(ExternalLinks.catechismVatican)));
    expect(urls.first, contains('prologo'));
  });

  test('Favoritos, anotações e constância', () {
    final u = UserDataRepository(db);
    expect(u.toggleFavorite('catechism', '1324'), isTrue);
    expect(u.favorites('catechism'), ['1324']);
    u.saveNote('catechism', '1324', 'Fonte e ápice!');
    expect(u.note('catechism', '1324'), 'Fonte e ápice!');

    final today = DateTime(2026, 11, 19);
    for (var i = 0; i < 5; i++) {
      u.logPrayer(PrayerKind.terco, day: DateTime(2026, 11, 19 - i), mysterySet: 'gozosos');
    }
    u.logPrayer(PrayerKind.liturgia, day: DateTime(2026, 11, 10));
    final s = u.streak(today: today);
    expect(s.current, 5);
    expect(s.best, 5);
    expect(s.daysThisMonth, containsAll([10, 15, 16, 17, 18, 19]));
    // Sem oração hoje ainda: a sequência de ontem continua (sem punição)
    expect(u.streak(today: DateTime(2026, 11, 20)).current, 5);
    expect(u.streak(today: DateTime(2026, 11, 22)).current, 0);
  });

  test('São Pio X embutido (994 perguntas) e importador modular JSON', () async {
    final spx = jsonDecode(File('assets/db/sao_pio_x.json').readAsStringSync()) as Map<String, dynamic>;
    await db.importCatechismWork(spx, bundled: true);
    final repo = CatechismRepository(db);
    expect(db.catechismWorkVersion('sao_pio_x'), 3);
    expect(db.catechismWorkVersion('inexistente'), isNull);
    expect(repo.works().map((w) => w.id), ['sao_pio_x']);
    expect(repo.work('sao_pio_x')!.entryCount, 994);
    expect(repo.parts('sao_pio_x'), isNotEmpty);
    final summaries = repo.partSummaries('sao_pio_x');
    expect(summaries.map((s) => s.part).toList(), repo.parts('sao_pio_x'));
    expect(summaries.fold<int>(0, (acc, s) => acc + s.count), repo.work('sao_pio_x')!.entryCount);
    expect(repo.searchEntries('sao_pio_x', '1').single.question, 'Sois cristão?');
    expect(repo.searchEntries('sao_pio_x', 'Eucaristia'), isNotEmpty);

    final importer = CatechismImportService(repo);
    final payload = utf8.encode(
      jsonEncode({
        'formato': 'viasacra-catecismo',
        'versao': 1,
        'id': 'cic_local',
        'nome': 'Catecismo da Igreja Católica (Local)',
        'sigla': 'CIC 1992',
        'idioma': 'pt-BR',
        'rotulo_entrada': '§',
        'entradas': [
          {
            'numero': 1324,
            'parte': 'Segunda Parte — A Celebração do Mistério Cristão',
            'capitulo': 'O Sacramento da Eucaristia',
            'resposta': 'A Eucaristia é fonte e ápice de toda a vida cristã.',
          },
        ],
      }),
    );
    final res = await importer.importFromBytes(Uint8List.fromList(payload));
    expect((res.id, res.entryCount), ('cic_local', 1));
    expect(repo.searchEntries('cic_local', '§1324').single.number, 1324);
    expect(repo.searchEntries('cic_local', 'apice').single.number, 1324);
    expect(repo.searchEntries('sao_pio_x', 'apice'), isEmpty);

    await expectLater(importer.deleteWork('sao_pio_x'), throwsA(isA<CatechismModuleException>()));
    await importer.deleteWork('cic_local');
    expect(repo.work('cic_local'), isNull);
  });

  test('sao_pio_x.json: 994 perguntas em sequência, sem artefatos de OCR nem notas do tradutor', () {
    final spx = jsonDecode(File('assets/db/sao_pio_x.json').readAsStringSync()) as Map<String, dynamic>;
    final entries = (spx['entradas'] as List).cast<Map<String, dynamic>>();
    expect([for (final e in entries) e['numero']], [for (var n = 1; n <= 994; n++) n]);
    final artefato = RegExp(r'CATECISMO MAIOR|Pio X|Page \d|Nota d[oa] Tradutor|CAP[ÍI]TULO|\d{1,2}º\s*-\s*D[aoe]');
    for (final e in entries) {
      final texto = '${e['pergunta']} ${e['resposta']}';
      expect(artefato.hasMatch(texto), isFalse, reason: 'P. ${e['numero']}: $texto');
      expect((e['resposta'] as String).trim(), isNotEmpty, reason: 'P. ${e['numero']}');
    }
    // Perguntas imperativas antes perdidas pelo extrator.
    expect(entries[17]['pergunta'], 'Dizei-os.');
    expect(entries[284]['pergunta'], 'Rezai o Padre-Nosso.');
  });

  test('Catecismo Romano embutido (retirado) é apagado; importação do usuário é mantida', () async {
    Map<String, dynamic> obra(String id) => {
      'id': id,
      'nome': 'Catecismo Romano',
      'idioma': 'pt-BR',
      'entradas': [
        {'numero': 1, 'resposta': 'Texto.'},
      ],
    };
    await db.importCatechismWork(obra('romano_trento'), bundled: true);
    await db.importCatechismWork(obra('romano_usuario'));
    await db.seedBundledCatechismWorks();
    final repo = CatechismRepository(db);
    expect(repo.work('romano_trento'), isNull);
    expect(db.db.select("SELECT 1 FROM catechism_entries WHERE catechism_id = 'romano_trento'"), isEmpty);
    expect(repo.work('romano_usuario'), isNotNull);
    expect(db.catechismWorkVersion('sao_pio_x'), 3); // instalado pelo seed a partir do asset
  });
}
