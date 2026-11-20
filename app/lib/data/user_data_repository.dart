import 'dart:async';

import 'package:intl/intl.dart';

import 'database.dart';

enum PrayerKind { terco, rosario, liturgia }

class StreakSummary {
  const StreakSummary({required this.current, required this.best, required this.daysThisMonth});
  final int current;
  final int best;
  final Set<int> daysThisMonth;
}

/// Favoritos, anotações e constância — tudo local, nunca sincronizado.
class UserDataRepository {
  UserDataRepository(this._db);

  final AppDatabase _db;
  static final _iso = DateFormat('yyyy-MM-dd');
  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Na Web (IndexedDB) as páginas só são gravadas no flush; sem ele os dados
  /// do usuário podem sumir ao fechar a aba. No nativo é um no-op.
  void _persist() => unawaited(_db.flush());

  // ---------------- Favoritos ----------------
  bool isFavorite(String kind, String ref) =>
      _db.db.select('SELECT 1 FROM favorite WHERE kind = ? AND ref = ?', [kind, ref]).isNotEmpty;

  bool toggleFavorite(String kind, String ref, {String? label}) {
    if (isFavorite(kind, ref)) {
      _db.db.execute('DELETE FROM favorite WHERE kind = ? AND ref = ?', [kind, ref]);
      _persist();
      return false;
    }
    _db.db.execute('INSERT INTO favorite(kind, ref, label, created_at) VALUES (?,?,?,?)', [kind, ref, label, _now]);
    _persist();
    return true;
  }

  List<String> favorites(String kind) => _db.db
      .select('SELECT ref FROM favorite WHERE kind = ? ORDER BY created_at DESC', [kind])
      .map((r) => r['ref'] as String)
      .toList();

  // ---------------- Anotações ----------------
  String? note(String kind, String ref) =>
      _db.db.select('SELECT body FROM note WHERE kind = ? AND ref = ? ORDER BY updated_at DESC LIMIT 1', [
            kind,
            ref,
          ]).firstOrNull?['body']
          as String?;

  /// Grava (ou apaga, se vazia) a anotação, preservando o `created_at` original.
  void saveNote(String kind, String ref, String body) {
    final text = body.trim();
    final db = _db.db;
    db.execute('BEGIN');
    try {
      if (text.isEmpty) {
        db.execute('DELETE FROM note WHERE kind = ? AND ref = ?', [kind, ref]);
      } else {
        final id = db.select('SELECT id FROM note WHERE kind = ? AND ref = ? ORDER BY updated_at DESC LIMIT 1', [
          kind,
          ref,
        ]).firstOrNull?['id'];
        if (id == null) {
          db.execute('INSERT INTO note(kind, ref, body, created_at, updated_at) VALUES (?,?,?,?,?)', [
            kind,
            ref,
            text,
            _now,
            _now,
          ]);
        } else {
          db.execute('UPDATE note SET body = ?, updated_at = ? WHERE id = ?', [text, _now, id]);
          // Remove duplicatas antigas (versões anteriores faziam DELETE + INSERT).
          db.execute('DELETE FROM note WHERE kind = ? AND ref = ? AND id != ?', [kind, ref, id]);
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    _persist();
  }

  /// Data de criação da anotação (ms desde a época), se existir.
  int? noteCreatedAt(String kind, String ref) =>
      _db.db.select('SELECT created_at FROM note WHERE kind = ? AND ref = ? LIMIT 1', [
            kind,
            ref,
          ]).firstOrNull?['created_at']
          as int?;

  // ---------------- Constância ----------------
  void logPrayer(PrayerKind kind, {DateTime? day, String? mysterySet, int? decades}) {
    _db.db.execute(
      'INSERT OR REPLACE INTO prayer_log(day, kind, mystery_set, decades, completed_at) VALUES (?,?,?,?,?)',
      [_iso.format(day ?? DateTime.now()), kind.name, mysterySet, decades, _now],
    );
    _persist();
  }

  bool prayedOn(DateTime day, {PrayerKind? kind}) => _db.db.select(
    'SELECT 1 FROM prayer_log WHERE day = ? ${kind != null ? 'AND kind = ?' : ''} LIMIT 1',
    [_iso.format(day), if (kind != null) kind.name],
  ).isNotEmpty;

  Set<String> _allDays() => _db.db.select('SELECT DISTINCT day FROM prayer_log').map((r) => r['day'] as String).toSet();

  /// Sequência atual: conta dias consecutivos até hoje. Se hoje ainda não
  /// houve oração, a sequência de ontem continua valendo (sem punição).
  StreakSummary streak({DateTime? today}) {
    final t = today ?? DateTime.now();
    final days = _allDays();
    var cursor = DateTime(t.year, t.month, t.day);
    if (!days.contains(_iso.format(cursor))) cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    var current = 0;
    while (days.contains(_iso.format(cursor))) {
      current++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    final sorted = days.map((d) => DateTime.parse('${d}T00:00:00Z')).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    final prefix = DateFormat('yyyy-MM-').format(t);
    final month = days.where((d) => d.startsWith(prefix)).map((d) => int.parse(d.substring(8))).toSet();
    return StreakSummary(current: current, best: best, daysThisMonth: month);
  }

  // ---------------- Progresso do terço ----------------
  void saveRosaryProgress({required String mode, required String set, required int decade, required int bead}) {
    _db.db.execute(
      'INSERT OR REPLACE INTO rosary_progress(id, day, mode, mystery_set, decade, bead, updated_at) VALUES (1,?,?,?,?,?,?)',
      [_iso.format(DateTime.now()), mode, set, decade, bead, _now],
    );
    _persist();
  }

  ({String mode, String set, int decade, int bead})? rosaryProgress() {
    final r = _db.db.select('SELECT * FROM rosary_progress WHERE id = 1 AND day = ?', [
      _iso.format(DateTime.now()),
    ]).firstOrNull;
    if (r == null) return null;
    return (
      mode: r['mode'] as String,
      set: r['mystery_set'] as String,
      decade: r['decade'] as int,
      bead: r['bead'] as int,
    );
  }

  void clearRosaryProgress() {
    _db.db.execute('DELETE FROM rosary_progress');
    _persist();
  }
}
