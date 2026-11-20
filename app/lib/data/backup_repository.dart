import 'database.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Quantos itens a importação acrescentou ou atualizou.
class BackupSummary {
  const BackupSummary({this.favorites = 0, this.notes = 0, this.prayers = 0, this.bible = 0});
  final int favorites;
  final int notes;
  final int prayers;
  final int bible;

  int get total => favorites + notes + prayers + bible;
}

/// Backup local dos dados do usuário — favoritos, anotações, constância (orações
/// rezadas) e marcações da Bíblia — num único JSON, sem nuvem e sem conta.
///
/// A importação **mescla** com o que já existe no aparelho (nunca apaga):
/// favoritos e orações já presentes ficam como estão; anotações e marcações da
/// Bíblia ficam com a versão mais recente (`updated_at`).
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  static const format = 'viasacra-backup';
  static const version = 1;

  List<Map<String, Object?>> _rows(String sql) =>
      _db.db.select(sql).map((r) => {for (final k in r.keys) k: r[k]}).toList();

  Map<String, Object?> export({DateTime? now}) => {
    'formato': format,
    'versao': version,
    'exportado_em': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'favoritos': _rows('SELECT kind, ref, label, created_at FROM favorite ORDER BY created_at'),
    'anotacoes': _rows('SELECT kind, ref, body, created_at, updated_at FROM note ORDER BY id'),
    'oracoes': _rows('SELECT day, kind, mystery_set, decades, completed_at FROM prayer_log ORDER BY day, kind'),
    'biblia': _rows(
      'SELECT book_id, chapter, verse, color, favorite, note, updated_at FROM bible_highlights_notes '
      'ORDER BY book_id, chapter, verse',
    ),
  };

  Future<BackupSummary> import(Map<String, dynamic> json) async {
    if (json['formato'] != format) {
      throw BackupException('Este arquivo não é um backup do Via Sacra.');
    }
    if (json['versao'] is! int || (json['versao'] as int) > version) {
      throw BackupException('Backup de uma versão mais nova do app. Atualize o Via Sacra e tente de novo.');
    }
    List<Map<String, dynamic>> list(String key) {
      final v = json[key] ?? const [];
      if (v is! List || v.any((e) => e is! Map)) throw BackupException('Backup malformado (campo "$key").');
      return [for (final e in v) (e as Map).cast<String, dynamic>()];
    }

    T field<T>(Map<String, dynamic> m, String k, String key) {
      final v = m[k];
      if (v is! T) throw BackupException('Backup malformado (campo "$key.$k").');
      return v;
    }

    final favorites = list('favoritos');
    final notes = list('anotacoes');
    final prayers = list('oracoes');
    final bible = list('biblia');
    final db = _db.db;
    int changes() => db.updatedRows;
    var nFav = 0, nNote = 0, nPrayer = 0, nBible = 0;

    db.execute('BEGIN');
    try {
      for (final f in favorites) {
        db.execute('INSERT OR IGNORE INTO favorite(kind, ref, label, created_at) VALUES (?,?,?,?)', [
          field<String>(f, 'kind', 'favoritos'),
          field<String>(f, 'ref', 'favoritos'),
          f['label'] as String?,
          field<int>(f, 'created_at', 'favoritos'),
        ]);
        nFav += changes();
      }
      for (final n in notes) {
        final kind = field<String>(n, 'kind', 'anotacoes');
        final ref = field<String>(n, 'ref', 'anotacoes');
        final body = field<String>(n, 'body', 'anotacoes');
        final updated = field<int>(n, 'updated_at', 'anotacoes');
        final current = db.select('SELECT id, updated_at FROM note WHERE kind = ? AND ref = ? LIMIT 1', [
          kind,
          ref,
        ]).firstOrNull;
        if (current == null) {
          db.execute('INSERT INTO note(kind, ref, body, created_at, updated_at) VALUES (?,?,?,?,?)', [
            kind,
            ref,
            body,
            field<int>(n, 'created_at', 'anotacoes'),
            updated,
          ]);
          nNote++;
        } else if (updated > (current['updated_at'] as int)) {
          db.execute('UPDATE note SET body = ?, updated_at = ? WHERE id = ?', [body, updated, current['id']]);
          nNote++;
        }
      }
      for (final p in prayers) {
        db.execute(
          'INSERT OR IGNORE INTO prayer_log(day, kind, mystery_set, decades, completed_at) VALUES (?,?,?,?,?)',
          [
            field<String>(p, 'day', 'oracoes'),
            field<String>(p, 'kind', 'oracoes'),
            p['mystery_set'] as String?,
            p['decades'] as int?,
            field<int>(p, 'completed_at', 'oracoes'),
          ],
        );
        nPrayer += changes();
      }
      for (final b in bible) {
        final bookId = field<String>(b, 'book_id', 'biblia');
        if (db.select('SELECT 1 FROM bible_books WHERE id = ?', [bookId]).isEmpty) continue;
        db.execute(
          '''INSERT INTO bible_highlights_notes(book_id, chapter, verse, color, favorite, note, updated_at)
             VALUES (?,?,?,?,?,?,?)
             ON CONFLICT(book_id, chapter, verse) DO UPDATE SET
               color = excluded.color, favorite = excluded.favorite, note = excluded.note,
               updated_at = excluded.updated_at
             WHERE excluded.updated_at > bible_highlights_notes.updated_at''',
          [
            bookId,
            field<int>(b, 'chapter', 'biblia'),
            field<int>(b, 'verse', 'biblia'),
            b['color'] as String?,
            field<int>(b, 'favorite', 'biblia'),
            b['note'] as String?,
            field<int>(b, 'updated_at', 'biblia'),
          ],
        );
        nBible += changes();
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    await _db.flush();
    return BackupSummary(favorites: nFav, notes: nNote, prayers: nPrayer, bible: nBible);
  }
}
