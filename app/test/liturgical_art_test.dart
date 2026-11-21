import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/liturgical_calendar.dart';
import 'package:via_sacra/data/liturgical_art.dart';
import 'package:via_sacra/data/models/mystery.dart';

void main() {
  final catalog = (jsonDecode(File('assets/data/sacred_art.json').readAsStringSync()) as List)
      .map((j) => SacredArt.fromJson((j as Map).cast<String, dynamic>()))
      .toList();

  SacredArt? artOn(int y, int m, int d) => artForDay(catalog, LiturgicalCalendar.compute(DateTime(y, m, d)));

  test('cada tempo litúrgico tem várias obras com imagem no aparelho', () {
    for (final season in LiturgicalSeason.values) {
      final pool = catalog.where((a) => a.seasons.contains(season.name) && a.assetPath != null).toList();
      expect(pool.length, greaterThanOrEqualTo(3), reason: season.name);
      for (final a in pool) {
        expect(File(a.assetPath!).existsSync(), isTrue, reason: a.assetPath);
      }
    }
  });

  test('a obra muda de um dia para o outro e é estável no mesmo dia', () {
    final days = [for (var d = 2; d <= 8; d++) artOn(2026, 7, d)!.id];
    expect(days.toSet().length, greaterThan(3));
    expect(artOn(2026, 7, 2)!.id, artOn(2026, 7, 2)!.id);
    expect(artOn(2026, 7, 2)!.seasons, contains('comum'));
  });

  test('festas usam a obra própria', () {
    expect(artOn(2026, 5, 24)!.feasts, contains('pentecostes'));
    expect(artOn(2026, 12, 25)!.feasts, contains('natal do senhor'));
    expect(artOn(2026, 4, 3)!.feasts, contains('sexta-feira santa'));
    expect(artOn(2026, 8, 6)!.id, 'luminosos-4');
  });

  test('tempos sem festa usam obras do próprio tempo', () {
    expect(artOn(2026, 12, 2)!.seasons, contains('advento'));
    expect(artOn(2026, 3, 4)!.seasons, contains('quaresma'));
    expect(artOn(2026, 4, 22)!.seasons, contains('pascoa'));
  });
}
