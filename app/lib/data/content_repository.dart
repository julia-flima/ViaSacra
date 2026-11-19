import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/liturgical_calendar.dart';
import 'models/mystery.dart';
import 'models/prayer.dart';

/// Conteúdo estático empacotado no app (100% offline):
/// orações, mistérios do Rosário e catálogo de arte sacra.
class ContentRepository {
  List<PrayerCategory> categories = const [];
  List<Prayer> prayers = const [];
  List<Mystery> mysteries = const [];
  Map<String, SacredArt> art = const {};
  Map<String, String> rosaryPrayers = const {};

  Future<void> load() async {
    final artJson = jsonDecode(await rootBundle.loadString('assets/data/sacred_art.json')) as List;
    art = {for (final a in artJson) (a as Map)['id'] as String: SacredArt.fromJson(a.cast<String, dynamic>())};

    final prayersJson = jsonDecode(await rootBundle.loadString('assets/data/prayers.json')) as Map<String, dynamic>;
    categories = (prayersJson['categorias'] as List)
        .map((c) => PrayerCategory.fromJson((c as Map).cast<String, dynamic>()))
        .toList();
    prayers = (prayersJson['oracoes'] as List).map((p) => Prayer.fromJson((p as Map).cast<String, dynamic>())).toList();

    final mysteriesJson = jsonDecode(await rootBundle.loadString('assets/data/mysteries.json')) as Map<String, dynamic>;
    mysteries = (mysteriesJson['misterios'] as List).map((m) {
      final map = (m as Map).cast<String, dynamic>();
      return Mystery.fromJson(map, art: art[map['arte'] ?? map['id']]);
    }).toList();
    rosaryPrayers = (mysteriesJson['oracoes_do_terco'] as Map).cast<String, String>();
  }

  Prayer? prayer(String id) => prayers.where((p) => p.id == id).firstOrNull;

  List<Prayer> prayersIn(String category) => prayers.where((p) => p.category == category).toList();

  List<Mystery> mysteriesOf(MysterySetId set) =>
      mysteries.where((m) => m.set == set).toList()..sort((a, b) => a.order.compareTo(b.order));

  /// Rosário completo (20 mistérios) na ordem tradicional.
  List<Mystery> get fullRosary => [
    for (final s in [MysterySetId.gozosos, MysterySetId.luminosos, MysterySetId.dolorosos, MysterySetId.gloriosos])
      ...mysteriesOf(s),
  ];
}
