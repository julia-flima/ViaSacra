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

/// Exceção de validação de módulo JSON de catecismo.
class CatechismModuleException implements Exception {
  CatechismModuleException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Obra de catecismo instalada no banco local (`catechisms`).
class CatechismWork {
  const CatechismWork({
    required this.id,
    required this.name,
    required this.shortName,
    required this.language,
    required this.license,
    required this.entryLabel,
    required this.bundled,
    required this.entryCount,
    required this.moduleVersion,
    this.year,
    this.source,
    this.description,
  });

  final String id;
  final String name;
  final String shortName;
  final int? year;
  final String language;
  final String license;
  final String? source;
  final String? description;
  final String entryLabel;
  final bool bundled;
  final int entryCount;
  final int moduleVersion;

  factory CatechismWork.fromRow(Map<String, Object?> r) => CatechismWork(
    id: r['id'] as String,
    name: r['name'] as String,
    shortName: r['short_name'] as String,
    year: r['year'] as int?,
    language: r['language'] as String? ?? 'pt-BR',
    license: r['license'] as String,
    source: r['source'] as String?,
    description: r['description'] as String?,
    entryLabel: r['entry_label'] as String? ?? '§',
    bundled: (r['bundled'] as int? ?? 0) == 1,
    entryCount: r['entry_count'] as int? ?? 0,
    moduleVersion: r['module_version'] as int? ?? 1,
  );
}

/// Pergunta/resposta ou parágrafo pertencente a uma obra de catecismo (`catechism_entries`).
class CatechismEntry {
  const CatechismEntry({
    required this.catechismId,
    required this.number,
    required this.part,
    required this.answer,
    this.chapter,
    this.question,
    this.snippet,
  });

  final String catechismId;
  final int number;
  final String part;
  final String? chapter;
  final String? question;
  final String answer;
  final String? snippet;

  String get favRef => '$catechismId:$number';

  factory CatechismEntry.fromRow(Map<String, Object?> r) => CatechismEntry(
    catechismId: r['catechism_id'] as String,
    number: r['number'] as int,
    part: r['part'] as String? ?? 'Geral',
    chapter: r['chapter'] as String?,
    question: r['question'] as String?,
    answer: r['answer'] as String? ?? '',
    snippet: r['snippet'] as String?,
  );
}

/// Módulo JSON de catecismo ("viasacra-catecismo" v1) validado para importação local.
class CatechismModule {
  CatechismModule._(this.raw);

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get name => raw['nome'] as String;
  String get shortName => (raw['nome_curto'] ?? raw['sigla'] ?? raw['nome']) as String;
  int get entryCount => ((raw['entradas'] ?? raw['paragrafos']) as List).length;

  static final _idRe = RegExp(r'^[a-z0-9_\-]{2,32}$');

  static CatechismModule parse(Map<String, dynamic> j) {
    final formato = j['formato'];
    if (formato != null && formato != 'viasacra-catecismo') {
      throw CatechismModuleException('Arquivo não é um módulo de catecismo do Via Sacra (campo "formato": $formato).');
    }
    final versao = j['versao'];
    if (versao != null && (versao as num?)?.toInt() != 1) {
      throw CatechismModuleException('Versão de formato não suportada: $versao (esperado: 1).');
    }
    final idRaw = j['id'];
    if (idRaw is! String || !_idRe.hasMatch(idRaw.trim())) {
      throw CatechismModuleException('Campo "id" inválido: use 2 a 32 caracteres (a-z, 0-9, _ ou -).');
    }
    final nomeRaw = j['nome'];
    if (nomeRaw is! String || nomeRaw.trim().isEmpty) {
      throw CatechismModuleException('Campo obrigatório ausente ou vazio: "nome".');
    }
    final list = j['entradas'] ?? j['paragrafos'];
    if (list is! List || list.isEmpty) {
      throw CatechismModuleException('O módulo não contém nenhuma entrada em "entradas" (ou "paragrafos").');
    }
    final seen = <int>{};
    for (final (i, item) in list.indexed) {
      if (item is! Map) {
        throw CatechismModuleException('Entrada #${i + 1} malformada (esperado objeto JSON).');
      }
      final numVal = item['numero'] ?? item['n'];
      if (numVal is! num || numVal.toInt() < 1) {
        throw CatechismModuleException('Entrada #${i + 1} sem número inteiro positivo ("numero" ou "n").');
      }
      final n = numVal.toInt();
      if (!seen.add(n)) {
        throw CatechismModuleException('Número duplicado no arquivo: $n.');
      }
      final body = item['resposta'] ?? item['texto'];
      if (body is! String || body.trim().isEmpty) {
        throw CatechismModuleException('Entrada #$n sem texto em "resposta" (ou "texto").');
      }
    }
    final normalized = Map<String, dynamic>.from(j);
    normalized['id'] = idRaw.trim();
    normalized['nome'] = nomeRaw.trim();
    normalized['idioma'] = (j['idioma'] is String && (j['idioma'] as String).trim().isNotEmpty)
        ? (j['idioma'] as String).trim()
        : 'pt-BR';
    normalized['licenca'] = (j['licenca'] is String && (j['licenca'] as String).trim().isNotEmpty)
        ? (j['licenca'] as String).trim()
        : 'Importado localmente pelo usuário';
    return CatechismModule._(normalized);
  }
}
