import 'database.dart';
import 'models/catechism.dart';

/// Catecismos: índice do CIC (texto oficial no vatican.va) e obras em perguntas e
/// respostas (embutidas ou importadas), com busca FTS5 offline.
class CatechismRepository {
  CatechismRepository(this._db);

  final AppDatabase _db;

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

  /// Converte texto livre em consulta FTS5 segura: cada termo vira prefixo
  /// entre aspas ("graca"* "maria"*), evitando erros de sintaxe.
  static String _toFtsQuery(String input) => input
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceAll(RegExp(r'["*^():\-]'), ''))
      .where((t) => t.length > 1)
      .map((t) => '"$t"*')
      .join(' ');

  // ---------------------------------------------------------------- obras (v3)
  /// Obras instaladas (embutidas em Domínio Público primeiro, depois importadas).
  List<CatechismWork> works() => _db.db
      .select('SELECT * FROM catechisms ORDER BY bundled DESC, year DESC, name')
      .map(CatechismWork.fromRow)
      .toList();

  CatechismWork? work(String id) {
    final r = _db.db.select('SELECT * FROM catechisms WHERE id = ?', [id]).firstOrNull;
    return r == null ? null : CatechismWork.fromRow(r);
  }

  Future<void> installWork(CatechismModule module, {bool bundled = false}) =>
      _db.importCatechismWork(module.raw, bundled: bundled, force: true);

  Future<void> removeWork(String id) async {
    _db.db.execute('BEGIN');
    try {
      _db.db.execute('DELETE FROM catechism_entries WHERE catechism_id = ?', [id]);
      _db.db.execute('DELETE FROM catechisms WHERE id = ?', [id]);
      _db.db.execute('COMMIT');
    } catch (_) {
      _db.db.execute('ROLLBACK');
      rethrow;
    }
    await _db.flush();
  }

  /// Partes distintas da obra na ordem em que aparecem.
  List<String> parts(String catechismId) {
    const sql = 'SELECT part FROM catechism_entries WHERE catechism_id = ? GROUP BY part ORDER BY MIN(number)';
    return _db.db.select(sql, [catechismId]).map((r) => r['part'] as String).toList();
  }

  /// Resumo das partes (título e total de entradas) sem carregar os textos.
  List<({String part, int count})> partSummaries(String catechismId) {
    const sql =
        'SELECT part, COUNT(*) AS c FROM catechism_entries WHERE catechism_id = ? GROUP BY part ORDER BY MIN(number)';
    return _db.db.select(sql, [catechismId]).map((r) => (part: r['part'] as String, count: r['c'] as int)).toList();
  }

  List<CatechismEntry> entriesByPart(String catechismId, String part) {
    const sql = 'SELECT * FROM catechism_entries WHERE catechism_id = ? AND part = ? ORDER BY number';
    return _db.db.select(sql, [catechismId, part]).map(CatechismEntry.fromRow).toList();
  }

  CatechismEntry? entryByNumber(String catechismId, int number) {
    const sql = 'SELECT * FROM catechism_entries WHERE catechism_id = ? AND number = ?';
    final r = _db.db.select(sql, [catechismId, number]).firstOrNull;
    return r == null ? null : CatechismEntry.fromRow(r);
  }

  /// Busca instantânea offline na obra ativa: por número ("1324", "§1324", "P. 1") ou FTS5.
  List<CatechismEntry> searchEntries(String catechismId, String query, {int limit = 50}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final number = int.tryParse(q.replaceAll(RegExp(r'^[§PpCc\.\s]+'), '').trim());
    if (number != null) {
      final exact = entryByNumber(catechismId, number);
      return exact == null ? const [] : [exact];
    }
    final fts = _toFtsQuery(q);
    if (fts.isEmpty) return const [];
    return _db.db
        .select(
          '''
          SELECT e.catechism_id, e.number, e.part, e.chapter, e.question, e.answer,
                 snippet(catechism_entries_fts, 1, '«', '»', '…', 18) AS snippet
          FROM catechism_entries_fts
          JOIN catechism_entries e ON e.id = catechism_entries_fts.rowid
          WHERE catechism_entries_fts MATCH ? AND e.catechism_id = ?
          ORDER BY bm25(catechism_entries_fts, 2.0, 1.0, 0.5, 0.5)
          LIMIT ?''',
          [fts, catechismId, limit],
        )
        .map(CatechismEntry.fromRow)
        .toList();
  }
}
