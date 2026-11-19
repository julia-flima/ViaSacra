import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/data/catechism_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/models/catechism.dart';
import 'package:via_sacra/data/user_data_repository.dart';
import 'package:via_sacra/services/catechism_import_service.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());
    await db.importCatechism(jsonDecode(File('assets/db/catechism.json').readAsStringSync()) as Map<String, dynamic>);
  });

  tearDown(() => db.close());

  test('Busca por número exato e FTS5 sem acentos', () {
    final repo = CatechismRepository(db);
    expect(repo.search('1324').single.number, 1324);
    expect(repo.search('§ 27').single.number, 27);
    final graca = repo.search('graca');
    expect(graca.map((p) => p.number), contains(1996));
    expect(graca.first.snippet, contains('«'));
    expect(repo.search('Eucaristia').first.number, 1324);
    expect(repo.search('"(*'), isEmpty); // entrada malformada não quebra o FTS
  });

  test('Índice do CIC com 4 partes + prólogo', () {
    final toc = CatechismRepository(db).toc();
    expect(toc, hasLength(5));
    expect(toc.last.last, 2865);
    expect(toc[2].children.last.children.first.children.last.title, 'O sacramento da Eucaristia');
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

  test('Catecismos embutidos (São Pio X + Catecismo Romano) e importador modular JSON', () async {
    await db.importCatechismWork(
      jsonDecode(File('assets/db/sao_pio_x.json').readAsStringSync()) as Map<String, dynamic>,
      bundled: true,
    );
    await db.importCatechismWork(
      jsonDecode(File('assets/db/catecismo_romano.json').readAsStringSync()) as Map<String, dynamic>,
      bundled: true,
    );
    final repo = CatechismRepository(db);
    expect(repo.works().map((w) => w.id), containsAll(['sao_pio_x', 'romano_trento']));
    expect(repo.work('sao_pio_x')!.entryCount, greaterThan(900));
    expect(repo.parts('sao_pio_x'), isNotEmpty);
    expect(repo.searchEntries('sao_pio_x', '1').single.question, 'Sois cristão?');
    expect(repo.searchEntries('sao_pio_x', 'Eucaristia'), isNotEmpty);
    expect(repo.searchEntries('romano_trento', 'transubstanciacao').single.number, 6);

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
}
