import 'bible_canon.dart';

class BibleTranslation {
  const BibleTranslation({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.license,
    this.source,
    this.description,
    this.psalmNumbering = 'grega',
    this.bundled = false,
    this.verseCount = 0,
    this.moduleVersion = 1,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String language;
  final String license;
  final String? source;
  final String? description;
  final String psalmNumbering;
  final bool bundled;
  final int verseCount;
  final int moduleVersion;

  factory BibleTranslation.fromRow(Map<String, Object?> r) => BibleTranslation(
    id: r['id']! as String,
    name: r['name']! as String,
    abbreviation: r['abbreviation']! as String,
    language: r['language']! as String,
    license: r['license']! as String,
    source: r['source'] as String?,
    description: r['description'] as String?,
    psalmNumbering: r['psalm_numbering'] as String? ?? 'grega',
    bundled: (r['bundled'] as int? ?? 0) == 1,
    verseCount: r['verse_count'] as int? ?? 0,
    moduleVersion: r['module_version'] as int? ?? 1,
  );
}

/// Metadados leves de uma tradução embutida no catálogo (`assets/bible/bundled.json`).
class BundledTranslationInfo {
  const BundledTranslationInfo({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.license,
    this.description,
    this.psalmNumbering = 'grega',
    this.version = 1,
    this.sizeMb,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String language;
  final String license;
  final String? description;
  final String psalmNumbering;
  final int version;
  final double? sizeMb;

  /// Ex.: " · ~4,2 MB" (vazio quando o catálogo não informa o tamanho).
  String get sizeSuffix => sizeMb == null ? '' : ' · ~${sizeMb!.toStringAsFixed(1).replaceAll('.', ',')} MB';

  factory BundledTranslationInfo.fromJson(Map<String, dynamic> j) => BundledTranslationInfo(
    id: j['id'] as String,
    name: (j['nome'] as String?) ?? (j['id'] as String),
    abbreviation: (j['abreviacao'] as String?) ?? (j['sigla'] as String?) ?? (j['id'] as String).toUpperCase(),
    language: (j['idioma'] as String?) ?? 'pt-BR',
    license: (j['licenca'] as String?) ?? 'Domínio público',
    description: j['descricao'] as String?,
    psalmNumbering: (j['numeracao_salmos'] as String?) ?? 'grega',
    version: (j['versao_modulo'] as num?)?.toInt() ?? 1,
    sizeMb: (j['tamanho_mb'] as num?)?.toDouble(),
  );
}

class BibleVerse {
  const BibleVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.snippet,
  });

  final String bookId;
  final int chapter;
  final int verse;
  final String text;

  /// Trecho com «destaques» vindo da busca FTS5.
  final String? snippet;

  BibleBook get book => bibleBooksById[bookId]!;
  String get reference => '${book.abbreviation} $chapter,$verse';
}

/// Cores suaves de marcação (harmonizam com pergaminho e Modo Igreja).
enum HighlightColor {
  ouro('Ouro', 0xFFE9D8A6, 0xFF6B5A2A),
  oliva('Oliva', 0xFFD5E2C4, 0xFF44533A),
  rosa('Rosa', 0xFFF0D3D9, 0xFF6A3F4A),
  azul('Azul', 0xFFCFDFEA, 0xFF34495A),
  lilas('Lilás', 0xFFE0D6EC, 0xFF4E4262);

  const HighlightColor(this.label, this.light, this.dark);
  final String label;
  final int light;
  final int dark;

  static HighlightColor? fromName(String? n) => HighlightColor.values.where((c) => c.name == n).firstOrNull;
}

class VerseAnnotation {
  const VerseAnnotation({this.color, this.favorite = false, this.note});
  final HighlightColor? color;
  final bool favorite;
  final String? note;

  bool get isEmpty => color == null && !favorite && (note == null || note!.isEmpty);
}

class ReadingPosition {
  const ReadingPosition(this.translationId, this.bookId, this.chapter, [this.verse]);
  final String translationId;
  final String bookId;
  final int chapter;
  final int? verse;

  String encode() => '$translationId|$bookId|$chapter|${verse ?? ''}';

  static ReadingPosition? decode(String? s) {
    final p = s?.split('|');
    if (p == null || p.length < 3 || bibleBooksById[p[1]] == null) return null;
    return ReadingPosition(p[0], p[1], int.tryParse(p[2]) ?? 1, p.length > 3 ? int.tryParse(p[3]) : null);
  }
}
