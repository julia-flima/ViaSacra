import 'bible_canon.dart';

/// Referência bíblica no padrão brasileiro: "Jo 3,16", "Lc 19,41-44",
/// "1Cor 15,20-26.28", "Sl 121(122),1-2", "Mt 5", "João 3:16".
class BibleRef {
  const BibleRef(
    this.book,
    this.chapter, {
    this.verseStart,
    this.verseEnd,
    this.extraVerses = const [],
    this.alternateChapter,
  });

  final BibleBook book;
  final int chapter;
  final int? verseStart;
  final int? verseEnd;

  /// Versículos avulsos após ".", ex.: 28 em "15,20-26.28".
  final List<int> extraVerses;

  /// Número entre parênteses, ex.: 122 em "Sl 121(122)". Nos lecionários
  /// brasileiros o primeiro número segue a numeração grega (Vulgata) e o
  /// segundo, a hebraica.
  final int? alternateChapter;

  /// Capítulo na numeração usada pela tradução ("grega" ou "hebraica").
  int chapterFor(String psalmNumbering) =>
      psalmNumbering == 'hebraica' && alternateChapter != null ? alternateChapter! : chapter;

  bool get hasVerses => verseStart != null;

  bool contains(int verse) =>
      verseStart != null &&
      ((verse >= verseStart! && verse <= (verseEnd ?? verseStart!)) || extraVerses.contains(verse));

  String get label {
    final b = StringBuffer('${book.abbreviation} $chapter');
    if (verseStart != null) {
      b.write(',$verseStart');
      if (verseEnd != null && verseEnd != verseStart) b.write('-$verseEnd');
      for (final v in extraVerses) {
        b.write('.$v');
      }
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

  static final _re = RegExp(
    r'^\s*([1-3]?\s*[A-Za-zÀ-ÿ\.]+(?:\s+[A-Za-zÀ-ÿ]+)*?)\s*(\d{1,3})(?:\s*\((\d{1,3})\))?'
    r'(?:\s*[,:]\s*(\d{1,3})[a-z]?(?:\s*[-–]\s*(\d{1,3})[a-z]?)?((?:\s*\.\s*\d{1,3}[a-z]?)*))?',
  );

  /// Interpreta uma referência; retorna null se não for uma referência válida.
  static BibleRef? parse(String input) {
    final m = _re.firstMatch(input);
    if (m == null) return null;
    final raw = m.group(1)!;
    final book = _exact[_compact(raw)] ?? _index[normalize(raw)];
    if (book == null) return null;
    final extras = RegExp(r'\d{1,3}').allMatches(m.group(6) ?? '').map((x) => int.parse(x.group(0)!)).toList();
    return BibleRef(
      book,
      int.parse(m.group(2)!),
      alternateChapter: m.group(3) == null ? null : int.parse(m.group(3)!),
      verseStart: m.group(4) == null ? null : int.parse(m.group(4)!),
      verseEnd: m.group(5) == null ? null : int.parse(m.group(5)!),
      extraVerses: extras,
    );
  }
}
