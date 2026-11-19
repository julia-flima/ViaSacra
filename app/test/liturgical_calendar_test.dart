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
}
