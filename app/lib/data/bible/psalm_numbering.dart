/// Correspondência exata dos Salmos entre a numeração grega (Septuaginta/Vulgata,
/// usada nos lecionários) e a hebraica (Texto Massorético):
///
/// | Grega      | Hebraica    |
/// |------------|-------------|
/// | 1–8        | 1–8         |
/// | 9          | 9 + 10      |
/// | 10–112     | 11–113      |
/// | 113        | 114 + 115   |
/// | 114 e 115  | 116         |
/// | 116–145    | 117–146     |
/// | 146 e 147  | 147         |
/// | 148–150    | 148–150     |
///
/// Quando um salmo de uma numeração corresponde a dois da outra, devolve o
/// primeiro (é onde começa o texto correspondente).
abstract final class PsalmNumbering {
  static int greekToHebrew(int g) {
    if (g <= 8 || g >= 148) return g;
    if (g == 9) return 9;
    if (g <= 112) return g + 1;
    if (g == 113) return 114;
    if (g <= 115) return 116;
    if (g <= 145) return g + 1;
    return 147; // 146 e 147
  }

  static int hebrewToGreek(int h) {
    if (h <= 8 || h >= 148) return h;
    if (h <= 10) return 9;
    if (h <= 113) return h - 1;
    if (h <= 115) return 113;
    if (h == 116) return 114;
    if (h <= 146) return h - 1;
    return 146; // 147
  }

  /// Converte [chapter] da numeração [from] para [to] ("grega" ou "hebraica").
  static int convert(int chapter, {required String from, required String to}) {
    if (from == to) return chapter;
    if (from == 'grega' && to == 'hebraica') return greekToHebrew(chapter);
    if (from == 'hebraica' && to == 'grega') return hebrewToGreek(chapter);
    return chapter;
  }
}
