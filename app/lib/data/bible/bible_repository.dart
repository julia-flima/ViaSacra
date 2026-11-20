import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../database.dart';
import 'bible_canon.dart';
import 'bible_models.dart';
import 'bible_module.dart';
import 'bible_reference.dart';

/// Acesso à Bíblia no SQLite: traduções (módulos), leitura, busca FTS5,
/// marcações/anotações e última posição de leitura.
class BibleRepository {
  BibleRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------- traduções
  List<BibleTranslation> translations() => _db.db
      .select(
        'SELECT * FROM bible_translations WHERE module_version > 0 '
        "ORDER BY bundled DESC, CASE WHEN language LIKE 'pt%' THEN 0 ELSE 1 END, language, name",
      )
      .map(BibleTranslation.fromRow)
      .toList();

  BibleTranslation? translation(String id) {
    final r = _db.db.select('SELECT * FROM bible_translations WHERE id = ? AND module_version > 0', [id]).firstOrNull;
    return r == null ? null : BibleTranslation.fromRow(r);
  }

  int? installedVersion(String id) =>
      _db.db.select('SELECT module_version FROM bible_translations WHERE id = ?', [id]).firstOrNull?['module_version']
          as int?;

  void _runTx(void Function() fn) {
    final db = _db.db;
    db.execute('BEGIN');
    try {
      fn();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _deleteSync(String translationId) {
    _runTx(() {
      final db = _db.db;
      db.execute('DELETE FROM bible_verses WHERE translation_id = ?', [translationId]);
      db.execute('DELETE FROM bible_chapters WHERE translation_id = ?', [translationId]);
      db.execute('DELETE FROM bible_translations WHERE id = ?', [translationId]);
    });
  }

  /// Instala (ou substitui) um módulo com transações síncronas por livro,
  /// cedendo o event loop entre livros sem manter transação SQLite aberta.
  Future<void> install(BibleModule m, {bool bundled = false, void Function(double progress)? onProgress}) async {
    final db = _db.db;
    try {
      _runTx(() {
        db.execute('DELETE FROM bible_verses WHERE translation_id = ?', [m.id]);
        db.execute('DELETE FROM bible_chapters WHERE translation_id = ?', [m.id]);
        db.execute(
          '''INSERT OR REPLACE INTO bible_translations
            (id, name, abbreviation, language, license, source, description, psalm_numbering, bundled,
             verse_count, module_version, installed_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)''',
          [
            m.id,
            m.name,
            m.meta['abreviacao'],
            m.meta['idioma'],
            m.meta['licenca'],
            m.meta['fonte'],
            m.meta['descricao'],
            m.meta['numeracao_salmos'] == 'hebraica' ? 'hebraica' : 'grega',
            bundled ? 1 : 0,
            0,
            0, // sentinela: só visível após concluir todos os livros
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      });

      var done = 0;
      final total = m.books.length;
      for (final entry in m.books.entries) {
        _runTx(() {
          final insV = db.prepare(
            'INSERT INTO bible_verses(translation_id, book_id, chapter, verse, text) VALUES (?,?,?,?,?)',
          );
          final insC = db.prepare(
            'INSERT INTO bible_chapters(translation_id, book_id, chapter, verse_count) VALUES (?,?,?,?)',
          );
          try {
            for (final (ci, chapter) in entry.value.indexed) {
              insC.execute([m.id, entry.key, ci + 1, chapter.length]);
              for (final (v, text) in chapter) {
                insV.execute([m.id, entry.key, ci + 1, v, text]);
              }
            }
          } finally {
            insV.close();
            insC.close();
          }
        });
        onProgress?.call(++done / total);
        await Future<void>.delayed(kIsWeb ? const Duration(milliseconds: 4) : Duration.zero);
      }

      _runTx(() {
        db.execute('UPDATE bible_translations SET verse_count = ?, module_version = ?, installed_at = ? WHERE id = ?', [
          m.verseCount,
          m.version,
          DateTime.now().millisecondsSinceEpoch,
          m.id,
        ]);
      });
    } catch (_) {
      _deleteSync(m.id);
      rethrow;
    }
    await _db.flush();
  }

  Future<void> remove(String translationId) async {
    _deleteSync(translationId);
    await _db.flush();
  }

  // ---------------------------------------------------------------- leitura
  /// Livros presentes na tradução (na ordem do cânon).
  List<BibleBook> books(String translationId) {
    final ids = _db.db
        .select('SELECT DISTINCT book_id FROM bible_chapters WHERE translation_id = ?', [translationId])
        .map((r) => r['book_id'] as String)
        .toSet();
    return bibleCanon.where((b) => ids.contains(b.id)).toList();
  }

  int chapterCount(String translationId, String bookId) =>
      _db.db.select('SELECT COUNT(*) AS c FROM bible_chapters WHERE translation_id = ? AND book_id = ?', [
            translationId,
            bookId,
          ]).first['c']
          as int;

  List<BibleVerse> chapter(String translationId, String bookId, int chapter) => _db.db
      .select(
        'SELECT verse, text FROM bible_verses WHERE translation_id = ? AND book_id = ? AND chapter = ? ORDER BY verse',
        [translationId, bookId, chapter],
      )
      .map((r) => BibleVerse(bookId: bookId, chapter: chapter, verse: r['verse'] as int, text: r['text'] as String))
      .toList();

  /// Resolve uma referência na tradução (considerando a numeração dos Salmos).
  ({String bookId, int chapter, int? verse})? resolve(BibleRef ref, String translationId) {
    final t = translation(translationId);
    final ch = ref.book.id == 'sl' ? ref.chapterFor(t?.psalmNumbering ?? 'grega') : ref.chapter;
    if (ch < 1 || ch > chapterCount(translationId, ref.book.id)) return null;
    return (bookId: ref.book.id, chapter: ch, verse: ref.verseStart);
  }

  // ---------------------------------------------------------------- busca
  /// "Jo 3,16" → versículos da referência; caso contrário, busca FTS5 por palavras.
  List<BibleVerse> search(String translationId, String query, {int limit = 100}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final ref = BibleRef.parse(q);
    if (ref != null) {
      final r = resolve(ref, translationId);
      if (r == null) return const [];
      final verses = chapter(translationId, r.bookId, r.chapter);
      return ref.hasVerses ? verses.where((v) => ref.contains(v.verse)).toList() : verses.take(limit).toList();
    }
    final fts = q
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'["*^():\-]'), ''))
        .where((t) => t.length > 1)
        .map(_termVariants)
        .join(' AND ');
    if (fts.isEmpty) return const [];
    return _db.db
        .select(
          '''
          SELECT v.book_id, v.chapter, v.verse, v.text,
                 snippet(bible_fts, 0, '«', '»', '…', 16) AS snippet
          FROM bible_fts JOIN bible_verses v ON v.id = bible_fts.rowid
          WHERE bible_fts MATCH ? AND v.translation_id = ?
          ORDER BY bm25(bible_fts)
          LIMIT ?''',
          [fts, translationId, limit],
        )
        .map(
          (r) => BibleVerse(
            bookId: r['book_id'] as String,
            chapter: r['chapter'] as int,
            verse: r['verse'] as int,
            text: r['text'] as String,
            snippet: r['snippet'] as String?,
          ),
        )
        .toList();
  }

  /// Latim da Vulgata usa ligaduras (cælum, cœli): "caelum" também encontra "cælum".
  static String _termVariants(String t) {
    final v = {t, t.replaceAll('ae', 'æ'), t.replaceAll('oe', 'œ'), t.replaceAll('æ', 'ae'), t.replaceAll('œ', 'oe')};
    return v.length == 1 ? '"$t"*' : '(${v.map((x) => '"$x"*').join(' OR ')})';
  }

  // ---------------------------------------------------------------- anotações
  Map<int, VerseAnnotation> annotations(String bookId, int chapter) => {
    for (final r in _db.db.select(
      'SELECT verse, color, favorite, note FROM bible_highlights_notes WHERE book_id = ? AND chapter = ?',
      [bookId, chapter],
    ))
      r['verse'] as int: VerseAnnotation(
        color: HighlightColor.fromName(r['color'] as String?),
        favorite: (r['favorite'] as int) == 1,
        note: r['note'] as String?,
      ),
  };

  VerseAnnotation annotation(String bookId, int chapter, int verse) =>
      annotations(bookId, chapter)[verse] ?? const VerseAnnotation();

  void saveAnnotation(String bookId, int chapter, int verse, VerseAnnotation a) {
    if (a.isEmpty) {
      _db.db.execute('DELETE FROM bible_highlights_notes WHERE book_id = ? AND chapter = ? AND verse = ?', [
        bookId,
        chapter,
        verse,
      ]);
    } else {
      _db.db.execute(
        'INSERT OR REPLACE INTO bible_highlights_notes(book_id, chapter, verse, color, favorite, note, updated_at) '
        'VALUES (?,?,?,?,?,?,?)',
        [bookId, chapter, verse, a.color?.name, a.favorite ? 1 : 0, a.note, DateTime.now().millisecondsSinceEpoch],
      );
    }
    unawaited(_db.flush());
  }

  /// Versículos favoritos/marcados/anotados (mais recentes primeiro).
  List<({String bookId, int chapter, int verse, VerseAnnotation a})> marked({bool favoritesOnly = false}) => _db.db
      .select(
        'SELECT * FROM bible_highlights_notes ${favoritesOnly ? 'WHERE favorite = 1' : ''} '
        'ORDER BY updated_at DESC LIMIT 500',
      )
      .map(
        (r) => (
          bookId: r['book_id'] as String,
          chapter: r['chapter'] as int,
          verse: r['verse'] as int,
          a: VerseAnnotation(
            color: HighlightColor.fromName(r['color'] as String?),
            favorite: (r['favorite'] as int) == 1,
            note: r['note'] as String?,
          ),
        ),
      )
      .toList();

  // ---------------------------------------------------------------- posição
  ReadingPosition? lastPosition() => ReadingPosition.decode(_db.meta('bible_last_position'));

  void savePosition(ReadingPosition p) {
    _db.setMeta('bible_last_position', p.encode());
    unawaited(_db.flush());
  }
}
