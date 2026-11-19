/// Parágrafo do Catecismo da Igreja Católica.
class CatechismParagraph {
  const CatechismParagraph({required this.number, required this.text, this.part, this.heading, this.snippet});

  final int number;
  final String text;
  final int? part;
  final String? heading;

  /// Trecho com destaques `«…»` retornado pela busca FTS5.
  final String? snippet;

  factory CatechismParagraph.fromRow(Map<String, Object?> r) => CatechismParagraph(
    number: r['number'] as int,
    text: r['text'] as String? ?? '',
    part: r['part'] as int?,
    heading: r['heading'] as String?,
    snippet: r['snippet'] as String?,
  );
}

/// Nó do índice (Partes → Seções → Capítulos → Artigos).
class CatechismTocNode {
  const CatechismTocNode({
    required this.id,
    required this.level,
    required this.title,
    required this.first,
    required this.last,
    this.parentId,
    this.children = const [],
  });

  final String id;
  final String? parentId;
  final int level;
  final String title;
  final int first;
  final int last;
  final List<CatechismTocNode> children;

  String get range => first == last ? '§ $first' : '§§ $first–$last';

  factory CatechismTocNode.fromJson(Map<String, dynamic> j, {String? parentId}) {
    final id = j['id'] as String;
    return CatechismTocNode(
      id: id,
      parentId: parentId,
      level: j['nivel'] as int,
      title: j['titulo'] as String,
      first: j['inicio'] as int,
      last: j['fim'] as int,
      children: (j['filhos'] as List? ?? const [])
          .map((c) => CatechismTocNode.fromJson((c as Map).cast<String, dynamic>(), parentId: id))
          .toList(),
    );
  }
}
