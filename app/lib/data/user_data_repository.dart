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

  // ---------------- Favoritos ----------------
  bool isFavorite(String kind, String ref) =>
      _db.db.select('SELECT 1 FROM favorite WHERE kind = ? AND ref = ?', [kind, ref]).isNotEmpty;

  bool toggleFavorite(String kind, String ref, {String? label}) {
    if (isFavorite(kind, ref)) {
      _db.db.execute('DELETE FROM favorite WHERE kind = ? AND ref = ?', [kind, ref]);
      return false;
    }
    _db.db.execute('INSERT INTO favorite(kind, ref, label, created_at) VALUES (?,?,?,?)', [kind, ref, label, _now]);
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

  void saveNote(String kind, String ref, String body) {
    _db.db.execute('DELETE FROM note WHERE kind = ? AND ref = ?', [kind, ref]);
    if (body.trim().isEmpty) return;
    _db.db.execute('INSERT INTO note(kind, ref, body, created_at, updated_at) VALUES (?,?,?,?,?)', [
      kind,
      ref,
      body.trim(),
      _now,
      _now,
    ]);
  }

  // ---------------- Constância ----------------
  void logPrayer(PrayerKind kind, {DateTime? day, String? mysterySet, int? decades}) {
    _db.db.execute(
      'INSERT OR REPLACE INTO prayer_log(day, kind, mystery_set, decades, completed_at) VALUES (?,?,?,?,?)',
      [_iso.format(day ?? DateTime.now()), kind.name, mysterySet, decades, _now],
    );
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

  void clearRosaryProgress() => _db.db.execute('DELETE FROM rosary_progress');
}
