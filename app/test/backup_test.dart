// Backup local (issue #13) e migração da tabela de favoritos (schema v5).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/data/backup_repository.dart';
import 'package:via_sacra/data/database.dart';
import 'package:via_sacra/data/user_data_repository.dart';

Future<AppDatabase> _db() => AppDatabase.memory(schema: File('assets/db/schema.sql').readAsStringSync());

void main() {
  test('exporta e importa favoritos, anotações, constância e marcações da Bíblia', () async {
    final origem = await _db();
    final user = UserDataRepository(origem)
      ..toggleFavorite('prayer', 'angelus', label: 'Angelus')
      ..toggleFavorite('imitacao', 'I-11') // antes da v5 o CHECK rejeitava este tipo
      ..saveNote('lectio', '2026-11-19|Homilia', 'Meditação')
      ..logPrayer(PrayerKind.terco, day: DateTime(2026, 11, 18), mysterySet: 'gozosos', decades: 5);
    origem.db.execute(
      'INSERT INTO bible_highlights_notes(book_id, chapter, verse, color, favorite, note, updated_at) '
      "VALUES ('jo', 3, 16, 'ouro', 1, 'Deus amou', 100)",
    );
    final backup = BackupRepository(origem).export(now: DateTime.utc(2026, 11, 20));
    // Ida e volta pelo JSON, como no arquivo salvo.
    final arquivo = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
    expect(arquivo['formato'], 'viasacra-backup');

    final destino = await _db();
    final r = await BackupRepository(destino).import(arquivo);
    expect((r.favorites, r.notes, r.prayers, r.bible), (2, 1, 1, 1));
    final u2 = UserDataRepository(destino);
    expect(u2.isFavorite('imitacao', 'I-11'), isTrue);
    expect(u2.note('lectio', '2026-11-19|Homilia'), 'Meditação');
    expect(u2.prayedOn(DateTime(2026, 11, 18), kind: PrayerKind.terco), isTrue);
    expect(
      destino.db.select("SELECT note FROM bible_highlights_notes WHERE book_id = 'jo'").single['note'],
      'Deus amou',
    );
    expect(user.isFavorite('prayer', 'angelus'), isTrue);

    // Importar de novo não duplica nada.
    expect((await BackupRepository(destino).import(arquivo)).total, 0);
  });

  test('mescla: a anotação mais recente vence, a mais antiga é ignorada', () async {
    final db = await _db();
    final user = UserDataRepository(db)..saveNote('catechism', '1', 'Versão do aparelho');
    final agora = db.db.select('SELECT updated_at FROM note').single['updated_at'] as int;
    Map<String, dynamic> com(String body, int updated) => {
      'formato': 'viasacra-backup',
      'versao': 1,
      'anotacoes': [
        {'kind': 'catechism', 'ref': '1', 'body': body, 'created_at': 1, 'updated_at': updated},
      ],
    };
    expect((await BackupRepository(db).import(com('Antiga', agora - 1000))).notes, 0);
    expect(user.note('catechism', '1'), 'Versão do aparelho');
    expect((await BackupRepository(db).import(com('Nova', agora + 1000))).notes, 1);
    expect(user.note('catechism', '1'), 'Nova');
  });

  test('rejeita arquivos que não são backup ou de versão mais nova', () async {
    final repo = BackupRepository(await _db());
    await expectLater(repo.import({'formato': 'outra-coisa'}), throwsA(isA<BackupException>()));
    await expectLater(repo.import({'formato': 'viasacra-backup', 'versao': 99}), throwsA(isA<BackupException>()));
    await expectLater(
      repo.import({
        'formato': 'viasacra-backup',
        'versao': 1,
        'favoritos': [
          {'kind': 1},
        ],
      }),
      throwsA(isA<BackupException>()),
    );
  });

  test('migração v5: recria `favorite` sem o CHECK e preserva os favoritos', () async {
    final db = await AppDatabase.memory(
      schema: File('assets/db/schema.sql').readAsStringSync(),
      before: (raw) {
        raw.execute('''
          CREATE TABLE favorite (
            kind TEXT NOT NULL CHECK (kind IN ('catechism', 'prayer', 'reading', 'homily')),
            ref TEXT NOT NULL, label TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (kind, ref))''');
        raw.execute("INSERT INTO favorite VALUES ('prayer', 'angelus', 'Angelus', 1)");
        raw.execute('PRAGMA user_version = 4');
      },
    );
    final user = UserDataRepository(db);
    expect(user.isFavorite('prayer', 'angelus'), isTrue);
    expect(user.toggleFavorite('imitacao', 'I-1'), isTrue);
    expect(db.db.select('PRAGMA user_version').single.columnAt(0), AppDatabase.schemaVersion);
  });
}
