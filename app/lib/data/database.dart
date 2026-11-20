import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/common.dart';

import 'bible/bible_canon.dart';
import 'platform/db_opener.dart';

/// Banco SQLite local (com FTS5) — única fonte de verdade offline.
///
/// Usa `package:sqlite3`, que embarca uma build do SQLite com FTS5 em todas
/// as plataformas (o SQLite do sistema Android nem sempre tem FTS5).
class AppDatabase {
  AppDatabase._(this.db);

  final CommonDatabase db;

  /// 1 = conteúdo inicial; 2 = Bíblia Sagrada; 3 = múltiplos catecismos (100% FOSS + importador);
  /// 4 = remove as tabelas v1 do CIC (texto/temas), mantendo só o índice.
  static const schemaVersion = 4;

  static const _bundledCatechismVersion = '2';
  static const _bundledCatechismWorks = <(String id, String asset, int version)>[
    ('sao_pio_x', 'assets/db/sao_pio_x.json', 3),
  ];

  /// Obras que já vieram embutidas e foram retiradas do app: são apagadas das
  /// instalações existentes (só a cópia embutida; importações do usuário ficam).
  /// `romano_trento`: eram 11 resumos, não o texto integral do Catecismo Romano (issue #12).
  static const _retiredBundledCatechismWorks = ['romano_trento'];

  static Future<AppDatabase> open() async {
    final db = await openPlatformDatabase('via_sacra');
    db.execute('PRAGMA foreign_keys = ON;');
    final app = AppDatabase._(db);
    await app._migrate();
    await app._seedCatechism();
    await app.seedBundledCatechismWorks();
    return app;
  }

  /// Grava alterações pendentes (relevante na web/IndexedDB).
  Future<void> flush() => flushPlatformDatabase();

  /// Banco em memória para testes.
  static Future<AppDatabase> memory({String? schema}) async {
    final app = AppDatabase._(openMemoryDatabase());
    app.db.execute('PRAGMA foreign_keys = ON;');
    await app._migrate(schemaOverride: schema);
    return app;
  }

  int get _userVersion => db.select('PRAGMA user_version').first.columnAt(0) as int;

  Future<void> _migrate({String? schemaOverride}) async {
    final current = _userVersion;
    if (current >= schemaVersion) return;
    final schema = schemaOverride ?? await rootBundle.loadString('assets/db/schema.sql');
    db.execute('BEGIN');
    try {
      // O esquema é idempotente (CREATE … IF NOT EXISTS): reaplicá-lo cria as
      // tabelas novas de cada versão sem tocar nos dados existentes.
      db.execute(schema);
      if (current < 2) _seedBibleBooks();
      db.execute('PRAGMA user_version = $schemaVersion');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _seedBibleBooks() {
    final ins = db.prepare(
      'INSERT OR REPLACE INTO bible_books(id, position, abbreviation, name, latin_name, testament, deuterocanonical) '
      'VALUES (?,?,?,?,?,?,?)',
    );
    for (final (i, b) in bibleCanon.indexed) {
      ins.execute([
        b.id,
        i + 1,
        b.abbreviation,
        b.name,
        b.latinName,
        b.testament.name.toUpperCase(),
        b.deutero ? 1 : 0,
      ]);
    }
    ins.close();
  }

  String? meta(String key) => db.select('SELECT value FROM meta WHERE key = ?', [key]).firstOrNull?['value'] as String?;

  void setMeta(String key, String value) =>
      db.execute('INSERT OR REPLACE INTO meta(key, value) VALUES (?, ?)', [key, value]);

  int? catechismWorkVersion(String id) =>
      db.select('SELECT module_version FROM catechisms WHERE id = ?', [id]).firstOrNull?['module_version'] as int?;

  /// Importa o índice do CIC (`assets/db/catechism.json`). O texto do CIC é
  /// protegido (LEV) e não é distribuído — ver docs/COPYRIGHT.md.
  Future<void> _seedCatechism() async {
    if (meta('catechism_version') == _bundledCatechismVersion) return;
    try {
      final raw = await rootBundle.loadString('assets/db/catechism.json');
      await importCatechism(jsonDecode(raw) as Map<String, dynamic>);
    } on FlutterError {
      debugPrint('catechism.json ausente — sem índice do CIC.');
    }
  }

  /// Grava o índice (Partes → Seções → Capítulos → Artigos) do CIC.
  Future<void> importCatechism(Map<String, dynamic> data, {bool force = false}) async {
    final version = '${data['versao'] ?? 1}';
    if (!force && meta('catechism_version') == version) return;
    db.execute('BEGIN');
    try {
      db.execute('DELETE FROM catechism_toc');
      final insT = db.prepare(
        'INSERT INTO catechism_toc(id, parent_id, level, title, first_paragraph, last_paragraph, sort_order) VALUES (?,?,?,?,?,?,?)',
      );
      var order = 0;
      void walk(List<dynamic> nodes, String? parent) {
        for (final n in nodes) {
          final m = (n as Map).cast<String, dynamic>();
          insT.execute([m['id'], parent, m['nivel'], m['titulo'], m['inicio'], m['fim'], order++]);
          walk(m['filhos'] as List<dynamic>? ?? const [], m['id'] as String);
        }
      }

      walk(data['indice'] as List<dynamic>? ?? const [], null);
      insT.close();
      setMeta('catechism_version', version);
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
    await flush();
  }

  /// Instala/atualiza os catecismos embutidos e remove os retirados do app.
  @visibleForTesting
  Future<void> seedBundledCatechismWorks() async {
    for (final id in _retiredBundledCatechismWorks) {
      if (db.select('SELECT 1 FROM catechisms WHERE id = ? AND bundled = 1', [id]).isEmpty) continue;
      db.execute('BEGIN');
      try {
        db.execute('DELETE FROM catechism_entries WHERE catechism_id = ?', [id]);
        db.execute('DELETE FROM catechisms WHERE id = ?', [id]);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
      await flush();
    }
    for (final (id, asset, version) in _bundledCatechismWorks) {
      final current = catechismWorkVersion(id);
      if (current != null && current >= version) continue;
      try {
        final raw = await rootBundle.loadString(asset);
        await importCatechismWork(jsonDecode(raw) as Map<String, dynamic>, bundled: true);
      } on FlutterError {
        debugPrint('$asset ausente.');
      }
    }
  }

  /// Instala/atualiza uma obra de catecismo nas tabelas `catechisms` e `catechism_entries`.
  Future<void> importCatechismWork(Map<String, dynamic> data, {bool bundled = false, bool force = false}) async {
    final id = (data['id'] as String).trim();
    final version = (data['versao_modulo'] as num?)?.toInt() ?? 1;
    final current = catechismWorkVersion(id);
    if (!force && current != null && current >= version) return;

    final entries = (data['entradas'] ?? data['paragrafos']) as List? ?? const [];
    db.execute('BEGIN');
    try {
      db.execute('DELETE FROM catechism_entries WHERE catechism_id = ?', [id]);
      db.execute(
        '''INSERT OR REPLACE INTO catechisms
           (id, name, short_name, year, language, license, source, description,
            entry_label, bundled, entry_count, module_version, installed_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)''',
        [
          id,
          (data['nome'] as String).trim(),
          ((data['nome_curto'] ?? data['sigla'] ?? data['nome']) as String).trim(),
          (data['ano'] as num?)?.toInt(),
          (data['idioma'] as String? ?? 'pt-BR').trim(),
          (data['licenca'] as String? ?? 'Importado localmente pelo usuário').trim(),
          data['fonte'],
          data['descricao'],
          (data['rotulo_entrada'] as String? ?? '§').trim(),
          bundled ? 1 : 0,
          entries.length,
          version,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      final ins = db.prepare(
        'INSERT INTO catechism_entries(catechism_id, number, part, chapter, question, answer) '
        'VALUES (?,?,?,?,?,?)',
      );
      for (final raw in entries) {
        final m = (raw as Map).cast<String, dynamic>();
        final numVal = (m['numero'] ?? m['n']) as num;
        final textVal = (m['resposta'] ?? m['texto']) as String;
        ins.execute([
          id,
          numVal.toInt(),
          (m['parte'] as String? ?? 'Geral').trim(),
          (m['capitulo'] as String?)?.trim(),
          (m['pergunta'] ?? m['titulo']) as String?,
          textVal.trim(),
        ]);
      }
      ins.close();
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
    await flush();
  }

  void close() => db.close();
}
