import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/constants.dart';
import 'database.dart';
import 'models/liturgy.dart';

enum LiturgyOrigin { cache, network, calendarOnly }

class LiturgyResult {
  const LiturgyResult(this.liturgy, this.origin, {this.error});
  final DailyLiturgy liturgy;
  final LiturgyOrigin origin;
  final String? error;
}

/// Liturgia offline-first: SQLite → CDN (jsDelivr → GitHub raw) → calendário local.
///
/// Única comunicação de rede do app: baixa JSON estático do próprio
/// repositório. Sem cookies, sem identificadores, sem analytics.
class LiturgyRepository {
  LiturgyRepository(this._db, {http.Client? client}) : _client = client ?? http.Client();

  final AppDatabase _db;
  final http.Client _client;
  static final _iso = DateFormat('yyyy-MM-dd');
  static const _timeout = Duration(seconds: 12);

  /// Conteúdo de hoje e de dias futuros pode mudar (correções); após este
  /// intervalo, tentamos atualizar em segundo plano.
  static const _refreshAfter = Duration(hours: 6);

  static String isoDate(DateTime d) => _iso.format(d);

  DailyLiturgy? cached(DateTime date) {
    final row = _db.db.select('SELECT json FROM liturgy_cache WHERE date = ?', [isoDate(date)]).firstOrNull;
    if (row == null) return null;
    try {
      return DailyLiturgy.fromJson(jsonDecode(row['json'] as String) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Cache corrompido para ${isoDate(date)}: $e');
      return null;
    }
  }

  bool isCached(DateTime date) =>
      _db.db.select('SELECT 1 FROM liturgy_cache WHERE date = ?', [isoDate(date)]).isNotEmpty;

  Set<String> cachedDates() => _db.db.select('SELECT date FROM liturgy_cache').map((r) => r['date'] as String).toSet();

  DateTime? _fetchedAt(DateTime date) {
    final row = _db.db.select('SELECT fetched_at FROM liturgy_cache WHERE date = ?', [isoDate(date)]).firstOrNull;
    return row == null ? null : DateTime.fromMillisecondsSinceEpoch(row['fetched_at'] as int);
  }

  Future<LiturgyResult> load(DateTime date, {bool forceRefresh = false}) async {
    final local = cached(date);
    final fetched = _fetchedAt(date);
    final stale = fetched == null || DateTime.now().difference(fetched) > _refreshAfter;
    if (local != null && local.hasReadings && !forceRefresh && !stale) {
      return LiturgyResult(local, LiturgyOrigin.cache);
    }
    try {
      final remote = await _fetch(date);
      return LiturgyResult(remote, LiturgyOrigin.network);
    } catch (e) {
      if (local != null) return LiturgyResult(local, LiturgyOrigin.cache, error: '$e');
      return LiturgyResult(DailyLiturgy.calendarOnly(date), LiturgyOrigin.calendarOnly, error: '$e');
    }
  }

  Future<DailyLiturgy> _fetch(DateTime date) async {
    final iso = isoDate(date);
    Object? lastError;
    for (final uri in DataEndpoints.liturgy(iso)) {
      try {
        final resp = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(_timeout);
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode} em ${uri.host}';
          continue;
        }
        final body = utf8.decode(resp.bodyBytes);
        final json = jsonDecode(body) as Map<String, dynamic>;
        final liturgy = DailyLiturgy.fromJson(json);
        _db.db.execute(
          'INSERT OR REPLACE INTO liturgy_cache(date, json, schema_version, source_url, fetched_at) VALUES (?,?,?,?,?)',
          [iso, body, json['schema_version'] ?? 1, uri.toString(), DateTime.now().millisecondsSinceEpoch],
        );
        return liturgy;
      } on TimeoutException {
        lastError = 'Tempo esgotado em ${uri.host}';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Não foi possível baixar a liturgia de $iso ($lastError)');
  }

  /// "Baixar Semana Offline": hoje + 6 dias. Retorna quantos dias ficaram salvos.
  Future<int> downloadWeek(DateTime from, {void Function(int done, int total)? onProgress}) async {
    var ok = 0;
    for (var i = 0; i < 7; i++) {
      final d = from.add(Duration(days: i));
      try {
        await _fetch(d);
        ok++;
      } catch (e) {
        debugPrint('Semana offline: ${isoDate(d)} falhou: $e');
      }
      onProgress?.call(i + 1, 7);
    }
    return ok;
  }

  /// Mantém o cache enxuto (padrão: 120 dias).
  void prune({Duration keep = const Duration(days: 120)}) {
    final limit = isoDate(DateTime.now().subtract(keep));
    _db.db.execute('DELETE FROM liturgy_cache WHERE date < ?', [limit]);
  }
}
