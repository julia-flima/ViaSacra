import 'database.dart';
import 'models/catechism.dart';

/// Catecismo: índice, leitura por número e busca FTS5 instantânea offline.
class CatechismRepository {
  CatechismRepository(this._db);

  final AppDatabase _db;

  bool get hasText => _db.meta('catechism_has_text') == 'true';

  int get paragraphCount => _db.db.select('SELECT COUNT(*) AS c FROM catechism_paragraph').first['c'] as int;

  List<CatechismTocNode> toc() {
    final rows = _db.db.select(
      'SELECT id, parent_id, level, title, first_paragraph, last_paragraph FROM catechism_toc ORDER BY sort_order',
    );
    final byParent = <String?, List<Map<String, Object?>>>{};
    for (final r in rows) {
      byParent.putIfAbsent(r['parent_id'] as String?, () => []).add(r);
    }
    List<CatechismTocNode> build(String? parent) => [
      for (final r in byParent[parent] ?? const <Map<String, Object?>>[])
        CatechismTocNode(
          id: r['id'] as String,
          parentId: parent,
          level: r['level'] as int,
          title: r['title'] as String,
          first: r['first_paragraph'] as int,
          last: r['last_paragraph'] as int,
          children: build(r['id'] as String),
        ),
    ];
    return build(null);
  }

  CatechismParagraph? byNumber(int n) {
    final r = _db.db.select('SELECT * FROM catechism_paragraph WHERE number = ?', [n]).firstOrNull;
    return r == null ? null : CatechismParagraph.fromRow(r);
  }

  List<CatechismParagraph> range(int first, int last) => _db.db
      .select('SELECT * FROM catechism_paragraph WHERE number BETWEEN ? AND ? ORDER BY number', [first, last])
      .map(CatechismParagraph.fromRow)
      .toList();

  List<String> topics() => _db.db
      .select('SELECT DISTINCT topic FROM catechism_topic ORDER BY topic')
      .map((r) => r['topic'] as String)
      .toList();

  /// Busca por número exato ("1324", "§1324") ou palavras-chave (FTS5).
  List<CatechismParagraph> search(String query, {int limit = 50}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final number = int.tryParse(q.replaceAll(RegExp(r'[§\s]'), ''));
    if (number != null) {
      final p = byNumber(number);
      return p == null ? const [] : [p];
    }
    final fts = _toFtsQuery(q);
    if (fts.isEmpty) return const [];
    final rows = _db.db.select(
      '''
      SELECT p.number, p.part, p.heading, p.text,
             snippet(catechism_fts, 0, '«', '»', '…', 18) AS snippet
      FROM catechism_fts
      JOIN catechism_paragraph p ON p.number = catechism_fts.rowid
      WHERE catechism_fts MATCH ?
      ORDER BY bm25(catechism_fts, 1.0, 2.0)
      LIMIT ?
    ''',
      [fts, limit],
    );
    final results = rows.map(CatechismParagraph.fromRow).toList();
    if (results.isNotEmpty) return results;
    // Tema do índice temático, ex.: "Eucaristia"
    return _db.db
        .select(
          '''
          SELECT p.* FROM catechism_topic t JOIN catechism_paragraph p ON p.number = t.number
          WHERE t.topic = ? COLLATE NOCASE ORDER BY p.number LIMIT ?''',
          [q, limit],
        )
        .map(CatechismParagraph.fromRow)
        .toList();
  }

  /// Converte texto livre em consulta FTS5 segura: cada termo vira prefixo
  /// entre aspas ("graca"* "maria"*), evitando erros de sintaxe.
  static String _toFtsQuery(String input) => input
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceAll(RegExp(r'["*^():\-]'), ''))
      .where((t) => t.length > 1)
      .map((t) => '"$t"*')
      .join(' ');
}
