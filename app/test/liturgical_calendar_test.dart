import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/liturgical_calendar.dart';
import 'package:via_sacra/core/liturgical_color.dart';

void main() {
  group('LiturgicalCalendar (espelha scraper/liturgical_calendar.py)', () {
    test('Páscoa', () {
      expect(LiturgicalCalendar.easter(2026), DateTime.utc(2026, 4, 5));
      expect(LiturgicalCalendar.easter(2027), DateTime.utc(2027, 3, 28));
    });

    test('Quinta-feira da 33ª Semana do Tempo Comum (19/11/2026)', () {
      final d = LiturgicalCalendar.compute(DateTime(2026, 11, 19));
      expect(d.season, LiturgicalSeason.comum);
      expect(d.week, 33);
      expect(d.color, LiturgicalColor.verde);
      expect(d.celebration, 'Quinta-feira da 33ª Semana do Tempo Comum');
      expect(d.mysteries, MysterySetId.luminosos);
      expect((d.sundayCycle, d.weekdayCycle), ('A', 'II'));
    });

    test('Solenidades e tempos fortes', () {
      expect(
        LiturgicalCalendar.compute(DateTime(2026, 11, 22)).celebration,
        'Nosso Senhor Jesus Cristo, Rei do Universo',
      );
      expect(LiturgicalCalendar.compute(DateTime(2026, 11, 29)).season, LiturgicalSeason.advento);
      expect(LiturgicalCalendar.compute(DateTime(2026, 12, 13)).color, LiturgicalColor.rosa);
      expect(LiturgicalCalendar.compute(DateTime(2026, 12, 25)).celebration, 'Natal do Senhor');
      expect(LiturgicalCalendar.compute(DateTime(2027, 1, 17)).celebration, '2º Domingo do Tempo Comum');
      expect(LiturgicalCalendar.compute(DateTime(2027, 2, 10)).celebration, 'Quarta-feira de Cinzas');
      expect(LiturgicalCalendar.compute(DateTime(2027, 5, 16)).color, LiturgicalColor.vermelho);
      expect(LiturgicalCalendar.compute(DateTime(2026, 10, 12)).celebration, contains('Aparecida'));
      expect(LiturgicalCalendar.cycles(DateTime(2026, 12, 1)), ('B', 'I'));
    });

    test('Mistérios do dia', () {
      expect(LiturgicalCalendar.mysteriesFor(DateTime(2026, 11, 16)), MysterySetId.gozosos); // segunda
      expect(LiturgicalCalendar.mysteriesFor(DateTime(2026, 11, 17)), MysterySetId.dolorosos);
      expect(LiturgicalCalendar.mysteriesFor(DateTime(2026, 11, 18)), MysterySetId.gloriosos);
      expect(LiturgicalCalendar.mysteriesFor(DateTime(2026, 11, 22)), MysterySetId.gloriosos); // domingo
    });

    test('Calendário completo de um ano não lança exceções e é contínuo', () {
      var d = DateTime(2026, 1, 1);
      while (d.year == 2026) {
        final day = LiturgicalCalendar.compute(d);
        expect(day.celebration, isNotEmpty);
        if (day.season == LiturgicalSeason.comum) expect(day.week, inInclusiveRange(1, 34));
        d = DateTime(d.year, d.month, d.day + 1);
      }
    });
  });

  // Paridade com scraper/liturgical_calendar.py: o fixture é gerado pelo teste
  // Python (scraper/tests/test_liturgical_calendar.py) e lido pelos dois lados.
  group('Paridade Dart ↔ Python (2023–2031)', () {
    final fixture =
        jsonDecode(File('test/fixtures/liturgical_calendar_parity.json').readAsStringSync()) as Map<String, dynamic>;

    String line(DateTime d) {
      final x = LiturgicalCalendar.compute(d);
      final iso = x.date.toIso8601String().substring(0, 10);
      return '$iso|${x.season.name}|${x.week ?? ''}|${x.color.name}|${x.celebration}|${x.rank}|'
          '${x.sundayCycle}|${x.weekdayCycle}|${x.mysteries.name}';
    }

    String fnv1a(String text) {
      var h = 0x811C9DC5;
      for (final b in utf8.encode(text)) {
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
      }
      return h.toRadixString(16).padLeft(8, '0');
    }

    test('mesma impressão digital, ano a ano', () {
      final years = (fixture['anos'] as Map<String, dynamic>).cast<String, String>();
      for (final MapEntry(key: year, value: expected) in years.entries) {
        final y = int.parse(year);
        final lines = [for (var d = DateTime(y); d.year == y; d = DateTime(y, d.month, d.day + 1)) line(d)];
        expect(fnv1a(lines.join('\n')), expected, reason: 'Dart e Python divergem em $year');
      }
    });

    test('casos-chave (Tempo Comum, Todos os Santos/Finados, Sagrada Família, transferências)', () {
      for (final c in (fixture['casos'] as List).cast<Map<String, dynamic>>()) {
        final d = LiturgicalCalendar.compute(DateTime.parse(c['data'] as String));
        expect(d.celebration, c['celebracao'], reason: c['data'] as String);
        expect(d.week, c['semana'], reason: c['data'] as String);
      }
    });

    test('transferências das Normas Universais', () {
      expect(LiturgicalCalendar.saintJoseph(2008), DateTime.utc(2008, 3, 15)); // Semana Santa
      expect(LiturgicalCalendar.saintJoseph(2023), DateTime.utc(2023, 3, 20));
      expect(LiturgicalCalendar.annunciation(2024), DateTime.utc(2024, 4, 8));
      expect(LiturgicalCalendar.immaculateConception(2024), DateTime.utc(2024, 12, 9));
      expect(LiturgicalCalendar.holyFamily(2022), DateTime.utc(2022, 12, 30));
    });
  });
}
