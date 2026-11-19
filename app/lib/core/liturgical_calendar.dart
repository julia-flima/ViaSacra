import 'liturgical_color.dart';

/// Porta em Dart de `scraper/liturgical_calendar.py` — calcula localmente o
/// Tempo Litúrgico, a semana, a cor e a celebração principal (adaptações do
/// Brasil). Usado offline, nos lembretes e quando o JSON do dia não existe.
enum LiturgicalSeason {
  advento('Tempo do Advento'),
  natal('Tempo do Natal'),
  quaresma('Tempo da Quaresma'),
  triduo('Tríduo Pascal'),
  pascoa('Tempo Pascal'),
  comum('Tempo Comum');

  const LiturgicalSeason(this.label);
  final String label;

  static LiturgicalSeason fromName(String? n) =>
      LiturgicalSeason.values.firstWhere((s) => s.name == n, orElse: () => LiturgicalSeason.comum);
}

enum MysterySetId {
  gozosos('Mistérios Gozosos'),
  luminosos('Mistérios Luminosos'),
  dolorosos('Mistérios Dolorosos'),
  gloriosos('Mistérios Gloriosos');

  const MysterySetId(this.label);
  final String label;

  static MysterySetId fromName(String? n) =>
      MysterySetId.values.firstWhere((s) => s.name == n, orElse: () => MysterySetId.gozosos);
}

class LiturgicalDay {
  const LiturgicalDay({
    required this.date,
    required this.weekdayName,
    required this.season,
    required this.week,
    required this.color,
    required this.celebration,
    required this.rank,
    required this.sundayCycle,
    required this.weekdayCycle,
    required this.mysteries,
  });

  final DateTime date;
  final String weekdayName;
  final LiturgicalSeason season;
  final int? week;
  final LiturgicalColor color;
  final String celebration;
  final String rank; // solenidade | festa | memoria | domingo | feria
  final String sundayCycle; // A | B | C
  final String weekdayCycle; // I | II
  final MysterySetId mysteries;
}

class LiturgicalCalendar {
  static const weekdayNames = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  /// Mistérios do Rosário por dia da semana (DateTime.weekday: 1 = segunda).
  static MysterySetId mysteriesFor(DateTime d) => const [
    MysterySetId.gozosos, // segunda
    MysterySetId.dolorosos, // terça
    MysterySetId.gloriosos, // quarta
    MysterySetId.luminosos, // quinta
    MysterySetId.dolorosos, // sexta
    MysterySetId.gozosos, // sábado
    MysterySetId.gloriosos, // domingo
  ][d.weekday - 1];

  static DateTime _d(int y, int m, int d) => DateTime.utc(y, m, d);
  static DateTime _only(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  static DateTime _add(DateTime d, int days) => d.add(Duration(days: days));
  static int _diff(DateTime a, DateTime b) => a.difference(b).inDays;

  static DateTime easter(int year) {
    final a = year % 19;
    final b = year ~/ 100, c = year % 100;
    final d = b ~/ 4, e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4, k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return _d(year, month, day);
  }

  static DateTime _sundayOnOrAfter(DateTime d) => _add(d, (7 - d.weekday) % 7);

  static DateTime adventStart(int year) {
    final christmas = _d(year, 12, 25);
    final back = christmas.weekday % 7 == 0 ? 7 : christmas.weekday % 7;
    return _add(christmas, -back - 21);
  }

  static DateTime epiphany(int year) => _sundayOnOrAfter(_d(year, 1, 2));

  static DateTime baptismOfTheLord(int year) {
    final ep = epiphany(year);
    return ep.day >= 7 ? _add(ep, 1) : _add(ep, 7);
  }

  static (String, String) cycles(DateTime date) {
    final d = _only(date);
    final endYear = d.isBefore(adventStart(d.year)) ? d.year : d.year + 1;
    const sunday = {1: 'A', 2: 'B', 0: 'C'};
    return (sunday[endYear % 3]!, endYear.isOdd ? 'I' : 'II');
  }

  static (String, LiturgicalColor, String)? _movable(DateTime d) {
    final p = easter(d.year);
    final map = <DateTime, (String, LiturgicalColor, String)>{
      _add(p, -46): ('Quarta-feira de Cinzas', LiturgicalColor.roxo, 'feria'),
      _add(p, -7): ('Domingo de Ramos e da Paixão do Senhor', LiturgicalColor.vermelho, 'domingo'),
      _add(p, -3): ('Quinta-feira Santa — Ceia do Senhor', LiturgicalColor.branco, 'solenidade'),
      _add(p, -2): ('Sexta-feira Santa — Paixão do Senhor', LiturgicalColor.vermelho, 'solenidade'),
      _add(p, -1): ('Sábado Santo — Vigília Pascal', LiturgicalColor.branco, 'solenidade'),
      p: ('Domingo de Páscoa da Ressurreição do Senhor', LiturgicalColor.branco, 'solenidade'),
      _add(p, 7): ('2º Domingo da Páscoa — Divina Misericórdia', LiturgicalColor.branco, 'solenidade'),
      _add(p, 42): ('Ascensão do Senhor', LiturgicalColor.branco, 'solenidade'),
      _add(p, 49): ('Domingo de Pentecostes', LiturgicalColor.vermelho, 'solenidade'),
      _add(p, 56): ('Santíssima Trindade', LiturgicalColor.branco, 'solenidade'),
      _add(p, 60): ('Santíssimo Corpo e Sangue de Cristo', LiturgicalColor.branco, 'solenidade'),
      _add(p, 68): ('Sagrado Coração de Jesus', LiturgicalColor.branco, 'solenidade'),
      _add(adventStart(d.year), -7): (
        'Nosso Senhor Jesus Cristo, Rei do Universo',
        LiturgicalColor.branco,
        'solenidade',
      ),
    };
    return map[d];
  }

  static (String, LiturgicalColor, String)? _fixed(DateTime d) {
    final y = d.year;
    final map = <DateTime, (String, LiturgicalColor, String)>{
      _d(y, 1, 1): ('Santa Maria, Mãe de Deus', LiturgicalColor.branco, 'solenidade'),
      _d(y, 2, 2): ('Apresentação do Senhor', LiturgicalColor.branco, 'festa'),
      _d(y, 2, 22): ('Cátedra de São Pedro', LiturgicalColor.branco, 'festa'),
      _d(y, 3, 19): ('São José, Esposo da Virgem Maria', LiturgicalColor.branco, 'solenidade'),
      _d(y, 3, 25): ('Anunciação do Senhor', LiturgicalColor.branco, 'solenidade'),
      _d(y, 6, 24): ('Natividade de São João Batista', LiturgicalColor.branco, 'solenidade'),
      _d(y, 8, 6): ('Transfiguração do Senhor', LiturgicalColor.branco, 'festa'),
      _d(y, 9, 14): ('Exaltação da Santa Cruz', LiturgicalColor.vermelho, 'festa'),
      _d(y, 10, 12): (
        'Nossa Senhora da Conceição Aparecida, Padroeira do Brasil',
        LiturgicalColor.branco,
        'solenidade',
      ),
      _d(y, 11, 2): ('Comemoração de Todos os Fiéis Defuntos', LiturgicalColor.roxo, 'solenidade'),
      _d(y, 12, 8): ('Imaculada Conceição de Nossa Senhora', LiturgicalColor.branco, 'solenidade'),
      _d(y, 12, 25): ('Natal do Senhor', LiturgicalColor.branco, 'solenidade'),
      _d(y, 12, 26): ('Santo Estêvão, primeiro mártir', LiturgicalColor.vermelho, 'festa'),
      _d(y, 12, 27): ('São João, Apóstolo e Evangelista', LiturgicalColor.branco, 'festa'),
      _d(y, 12, 28): ('Santos Inocentes, mártires', LiturgicalColor.vermelho, 'festa'),
      _sundayOnOrAfter(_d(y, 6, 29)): ('São Pedro e São Paulo, Apóstolos', LiturgicalColor.vermelho, 'solenidade'),
      _sundayOnOrAfter(_d(y, 8, 15)): ('Assunção de Nossa Senhora', LiturgicalColor.branco, 'solenidade'),
      _sundayOnOrAfter(_d(y, 11, 1)): ('Todos os Santos', LiturgicalColor.branco, 'solenidade'),
      epiphany(y): ('Epifania do Senhor', LiturgicalColor.branco, 'solenidade'),
      baptismOfTheLord(y): ('Batismo do Senhor', LiturgicalColor.branco, 'festa'),
    };
    return map[d];
  }

  static const _feastsOfTheLord = {'Apresentação do Senhor', 'Transfiguração do Senhor', 'Exaltação da Santa Cruz'};

  static LiturgicalDay compute(DateTime date) {
    final d = _only(date);
    final y = d.year;
    final p = easter(y);
    final ash = _add(p, -46);
    final pentecost = _add(p, 49);
    final advent = adventStart(y);
    final baptism = baptismOfTheLord(y);
    final sunday = d.weekday == DateTime.sunday;

    LiturgicalSeason season;
    if (!d.isBefore(advent)) {
      season = d.isBefore(_d(y, 12, 25)) ? LiturgicalSeason.advento : LiturgicalSeason.natal;
    } else if (!d.isAfter(baptism)) {
      season = LiturgicalSeason.natal;
    } else if (d.isBefore(ash)) {
      season = LiturgicalSeason.comum;
    } else if (d.isBefore(_add(p, -3))) {
      season = LiturgicalSeason.quaresma;
    } else if (d.isBefore(p)) {
      season = LiturgicalSeason.triduo;
    } else if (!d.isAfter(pentecost)) {
      season = LiturgicalSeason.pascoa;
    } else {
      season = LiturgicalSeason.comum;
    }

    int? week;
    switch (season) {
      case LiturgicalSeason.advento:
        week = _diff(d, advent) ~/ 7 + 1;
      case LiturgicalSeason.quaresma:
        final firstSunday = _add(ash, 4);
        week = d.isBefore(firstSunday) ? 0 : _diff(d, firstSunday) ~/ 7 + 1;
      case LiturgicalSeason.pascoa:
        week = _diff(d, p) ~/ 7 + 1;
      case LiturgicalSeason.comum:
        if (d.isBefore(ash)) {
          week = _diff(d, _add(baptism, 1)) ~/ 7 + 1 + (sunday ? 1 : 0);
        } else {
          final christKing = _add(advent, -7);
          week = 34 - (_diff(christKing, d) + 6) ~/ 7;
        }
      case LiturgicalSeason.natal:
      case LiturgicalSeason.triduo:
        week = null;
    }

    var color = switch (season) {
      LiturgicalSeason.advento || LiturgicalSeason.quaresma => LiturgicalColor.roxo,
      LiturgicalSeason.comum => LiturgicalColor.verde,
      _ => LiturgicalColor.branco,
    };
    if (sunday && week == 3 && season == LiturgicalSeason.advento) color = LiturgicalColor.rosa;
    if (sunday && week == 4 && season == LiturgicalSeason.quaresma) color = LiturgicalColor.rosa;

    final weekdayName = weekdayNames[d.weekday - 1];
    var celebration = _defaultName(season, week, weekdayName, sunday);
    var rank = sunday ? 'domingo' : 'feria';

    final movable = _movable(d);
    final fixed = _fixed(d);
    if (movable != null) {
      (celebration, color, rank) = movable;
    } else if (fixed != null && _fixedPrevails(fixed, season, sunday, d, p)) {
      (celebration, color, rank) = fixed;
    }

    final (sc, wc) = cycles(d);
    return LiturgicalDay(
      date: d,
      weekdayName: weekdayName,
      season: season,
      week: week,
      color: color,
      celebration: celebration,
      rank: rank,
      sundayCycle: sc,
      weekdayCycle: wc,
      mysteries: mysteriesFor(d),
    );
  }

  static bool _fixedPrevails(
    (String, LiturgicalColor, String) fixed,
    LiturgicalSeason season,
    bool sunday,
    DateTime d,
    DateTime p,
  ) {
    final (name, _, rank) = fixed;
    final holyWeekOrOctave = !d.isBefore(_add(p, -7)) && !d.isAfter(_add(p, 7));
    if (season == LiturgicalSeason.triduo || holyWeekOrOctave) return false;
    if (sunday && {LiturgicalSeason.advento, LiturgicalSeason.quaresma, LiturgicalSeason.pascoa}.contains(season)) {
      return false;
    }
    if (sunday && season == LiturgicalSeason.comum) {
      return rank == 'solenidade' || _feastsOfTheLord.contains(name);
    }
    return true;
  }

  static String _defaultName(LiturgicalSeason s, int? week, String weekday, bool sunday) {
    switch (s) {
      case LiturgicalSeason.triduo:
        return 'Tríduo Pascal';
      case LiturgicalSeason.natal:
        return sunday ? 'Domingo do Tempo do Natal' : '$weekday do Tempo do Natal';
      case LiturgicalSeason.quaresma when week == 0:
        return '$weekday depois das Cinzas';
      default:
        final name = switch (s) {
          LiturgicalSeason.advento => 'do Advento',
          LiturgicalSeason.quaresma => 'da Quaresma',
          LiturgicalSeason.pascoa => 'da Páscoa',
          _ => 'do Tempo Comum',
        };
        return sunday ? '$weekº Domingo $name' : '$weekday da $weekª Semana $name';
    }
  }
}
