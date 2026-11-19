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

  /// 1 = conteúdo inicial; 2 = Bíblia Sagrada.
  static const schemaVersion = 2;

  static Future<AppDatabase> open() async {
    final db = await openPlatformDatabase('via_sacra');
    db.execute('PRAGMA foreign_keys = ON;');
    final app = AppDatabase._(db);
    await app._migrate();
    await app._seedCatechism();
    return app;
  }

  /// Grava alterações pendentes (relevante na web/IndexedDB).
  Future<void> flush() => flushPlatformDatabase();

  /// Banco em memória para testes.
  static Future<AppDatabase> memory({String? schema}) async {
    final app = AppDatabase._(openMemoryDatabase());
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

  /// Importa `assets/db/catechism.json` (se presente) e o índice temático.
  /// O texto integral do CIC é protegido por direitos autorais (LEV) e só é
  /// distribuído mediante licença — ver docs/COPYRIGHT.md.
  Future<void> _seedCatechism() async {
    try {
      final raw = await rootBundle.loadString('assets/db/catechism.json');
      await importCatechism(jsonDecode(raw) as Map<String, dynamic>);
    } on FlutterError {
      debugPrint('catechism.json ausente — Catecismo sem texto offline.');
    }
  }

  Future<void> importCatechism(Map<String, dynamic> data, {bool force = false}) async {
    final version = '${data['versao'] ?? 1}';
    if (!force && meta('catechism_version') == version) return;
    db.execute('BEGIN');
    try {
      db.execute('DELETE FROM catechism_paragraph');
      db.execute('DELETE FROM catechism_toc');
      db.execute('DELETE FROM catechism_topic');
      final insP = db.prepare(
        'INSERT INTO catechism_paragraph(number, part, section, chapter, article, heading, text) VALUES (?,?,?,?,?,?,?)',
      );
      for (final pg in (data['paragrafos'] as List? ?? const [])) {
        final m = (pg as Map).cast<String, dynamic>();
        insP.execute([m['n'], m['parte'] ?? 0, m['secao'], m['capitulo'], m['artigo'], m['titulo'], m['texto']]);
      }
      insP.close();

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

      final insTopic = db.prepare('INSERT OR IGNORE INTO catechism_topic(topic, number) VALUES (?, ?)');
      (data['temas'] as Map? ?? const {}).forEach((topic, ranges) {
        for (final r in (ranges as List)) {
          final parts = '$r'.split('-').map(int.parse).toList();
          for (var n = parts.first; n <= parts.last; n++) {
            insTopic.execute([topic, n]);
          }
        }
      });
      insTopic.close();
      setMeta('catechism_version', version);
      setMeta('catechism_has_text', '${(data['paragrafos'] as List? ?? const []).isNotEmpty}');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => db.close();
}
