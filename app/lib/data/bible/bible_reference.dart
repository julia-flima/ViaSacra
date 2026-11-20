import 'bible_canon.dart';

/// Referência bíblica no padrão brasileiro: "Jo 3,16", "Lc 19,41-44",
/// "1Cor 15,20-26.28", "Lc 3,15-16.21-22", "Is 52,13-53,12", "Sl 121(122),1-2",
/// "Fm 9-10", "Jd 3", "Mt 5", "João 3:16".
class BibleRef {
  const BibleRef(
    this.book,
    this.chapter, {
    this.verseStart,
    this.verseEnd,
    this.chapterEnd,
    this.extraVerses = const [],
    this.alternateChapter,
  });

  /// Livros de um só capítulo: "Fm 9-10" e "Jd 3" citam versículos, não capítulos.
  static const singleChapterBooks = {'ab', 'fm', '2jo', '3jo', 'jd'};

  final BibleBook book;
  final int chapter;
  final int? verseStart;

  /// Último versículo (no capítulo [chapterEnd], se houver).
  final int? verseEnd;

  /// Último capítulo quando a referência atravessa capítulos, ex.: 53 em "Is 52,13-53,12".
  final int? chapterEnd;

  /// Versículos avulsos após "." (no último capítulo), ex.: 28 em "15,20-26.28"
  /// e 21, 22 em "3,15-16.21-22".
  final List<int> extraVerses;

  /// Número entre parênteses, ex.: 122 em "Sl 121(122)". Nos lecionários
  /// brasileiros o primeiro número segue a numeração grega (Vulgata) e o
  /// segundo, a hebraica.
  final int? alternateChapter;

  /// Capítulo na numeração usada pela tradução ("grega" ou "hebraica").
  int chapterFor(String psalmNumbering) =>
      psalmNumbering == 'hebraica' && alternateChapter != null ? alternateChapter! : chapter;

  bool get hasVerses => verseStart != null;

  /// Quantos capítulos além do primeiro a referência abrange (0 = um só).
  int get chapterSpan => (chapterEnd ?? chapter) - chapter;

  /// Versículo [verse] do primeiro capítulo da referência.
  bool contains(int verse) => containsAt(0, verse);

  /// Versículo [verse] do capítulo de índice [index] (0 = primeiro capítulo
  /// da referência, independentemente da numeração grega/hebraica).
  bool containsAt(int index, int verse) {
    if (verseStart == null || index < 0 || index > chapterSpan) return false;
    final last = index == chapterSpan;
    if (last && extraVerses.contains(verse)) return true;
    final from = index == 0 ? verseStart! : 1;
    final to = last ? (verseEnd ?? verseStart!) : 1 << 30;
    return verse >= from && verse <= to;
  }

  String get label {
    final b = StringBuffer('${book.abbreviation} $chapter');
    if (verseStart != null) {
      b.write(',$verseStart');
      if (chapterEnd != null && chapterEnd != chapter) {
        b.write('-$chapterEnd,$verseEnd');
      } else if (verseEnd != null && verseEnd != verseStart) {
        b.write('-$verseEnd');
      }
      for (final v in extraVerses) {
        b.write('.$v');
      }
    } else if (chapterEnd != null && chapterEnd != chapter) {
      b.write('-$chapterEnd');
    }
    return b.toString();
  }

  @override
  String toString() => label;

  /// Chaves com acento preservado: distingue "Jó" (Job) de "Jo" (João).
  static final Map<String, BibleBook> _exact = {
    for (final b in bibleCanon)
      for (final k in [b.abbreviation, b.name]) _compact(k): b,
  };

  static String _compact(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\.]'), '');

  static final Map<String, BibleBook> _index = () {
    final m = <String, BibleBook>{};
    for (final b in bibleCanon) {
      for (final k in [b.id, b.abbreviation, b.name, ...b.aliases]) {
        m[normalize(k)] = b;
      }
    }
    return m;
  }();

  static String normalize(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final b = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      final i = from.indexOf(c);
      b.write(i >= 0 ? to[i] : c);
    }
    return b.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // Grupos: 1 livro · 2 capítulo · 3 capítulo alternativo (Salmos) · 4 versículo
  // inicial · 5 capítulo final · 6 versículo (ou capítulo) final · 7 trechos ".a-b".
  static final _re = RegExp(
    r'^\s*([1-3]?\s*[A-Za-zÀ-ÿ\.]+(?:\s+[A-Za-zÀ-ÿ]+)*?)\s*(\d{1,3})(?:\s*\((\d{1,3})\))?'
    r'(?:\s*[,:]\s*(\d{1,3})[a-z]?)?'
    r'(?:\s*[-–]\s*(?:(\d{1,3})\s*[,:]\s*)?(\d{1,3})[a-z]?)?'
    r'((?:\s*\.\s*\d{1,3}[a-z]?(?:\s*[-–]\s*\d{1,3}[a-z]?)?)*)',
  );
  static final _extra = RegExp(r'(\d{1,3})[a-z]?(?:\s*[-–]\s*(\d{1,3}))?');

  /// Interpreta uma referência; retorna null se não for uma referência válida.
  static BibleRef? parse(String input) {
    final m = _re.firstMatch(input);
    if (m == null) return null;
    final raw = m.group(1)!;
    final book = _exact[_compact(raw)] ?? _index[normalize(raw)];
    if (book == null) return null;
    int? n(int g) => m.group(g) == null ? null : int.parse(m.group(g)!);
    final extras = [
      for (final x in _extra.allMatches(m.group(7) ?? ''))
        for (var v = int.parse(x.group(1)!); v <= int.parse(x.group(2) ?? x.group(1)!); v++) v,
    ];
    var chapter = n(2)!;
    var verseStart = n(4);
    var chapterEnd = n(5);
    var verseEnd = n(6);
    if (verseStart == null && singleChapterBooks.contains(book.id)) {
      // "Jd 3", "Fm 9-10": o número é versículo do capítulo único.
      (verseStart, chapter) = (chapter, 1);
    } else if (verseStart == null && verseEnd != null) {
      // "Mt 5-7": intervalo de capítulos inteiros.
      (chapterEnd, verseEnd) = (verseEnd, null);
    }
    if (chapterEnd != null && chapterEnd <= chapter) return null;
    return BibleRef(
      book,
      chapter,
      alternateChapter: n(3),
      verseStart: verseStart,
      verseEnd: verseEnd,
      chapterEnd: chapterEnd,
      extraVerses: extras,
    );
  }
}
