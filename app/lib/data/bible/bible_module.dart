import 'bible_canon.dart';

class BibleModuleException implements Exception {
  BibleModuleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Módulo de tradução "viasacra-biblia" v1, já validado.
///
/// ```json
/// {
///   "formato": "viasacra-biblia",
///   "versao": 1,
///   "id": "cnbb",
///   "nome": "Bíblia Sagrada — CNBB",
///   "sigla": "CNBB",
///   "idioma": "pt-BR",
///   "licenca": "© CNBB — uso pessoal",
///   "numeracao_salmos": "grega",
///   "livros": [{"id": "gn", "capitulos": [["No princípio…", "…"], …]}]
/// }
/// ```
/// Aceita tanto `"sigla"` quanto `"abreviacao"` nos metadados.
/// Um capítulo pode ser lista de textos, lista de pares `[número, texto]` ou
/// objeto `{"1": "texto", "2": "texto"}`. O campo `"capitulos"` também pode
/// ser um objeto numerado por capítulo (`{"1": {"1": "texto"}}`).
class BibleModule {
  BibleModule._(this.meta, this.books);

  final Map<String, Object?> meta;

  /// bookId → capítulos → (versículo, texto)
  final Map<String, List<List<(int, String)>>> books;

  String get id => meta['id']! as String;
  String get name => meta['nome']! as String;
  String get abbreviation => meta['abreviacao']! as String;
  String get language => meta['idioma']! as String;
  int get version => (meta['versao_modulo'] as num?)?.toInt() ?? 1;
  int get verseCount => books.values.fold(0, (a, b) => a + b.fold(0, (x, c) => x + c.length));

  static final _idRe = RegExp(r'^[a-z0-9_\-]{2,32}$');

  static BibleModule parse(Map<String, dynamic> j) {
    final formato = j['formato'];
    if (formato != null && formato != 'viasacra-biblia') {
      throw BibleModuleException('Arquivo não é um módulo de Bíblia do Via Sacra (campo "formato": $formato).');
    }
    final versao = j['versao'];
    if (versao != null && (versao as num?)?.toInt() != 1) {
      throw BibleModuleException('Versão de formato não suportada: $versao (esperado: 1).');
    }
    for (final k in ['id', 'nome', 'idioma']) {
      if (j[k] is! String || (j[k] as String).trim().isEmpty) {
        throw BibleModuleException('Campo obrigatório ausente ou vazio: "$k".');
      }
    }
    final siglaRaw = j['abreviacao'] ?? j['sigla'];
    if (siglaRaw is! String || siglaRaw.trim().isEmpty) {
      throw BibleModuleException('Campo obrigatório ausente ou vazio: "sigla" (ou "abreviacao").');
    }
    final id = (j['id'] as String).trim();
    if (!_idRe.hasMatch(id)) {
      throw BibleModuleException('Campo "id" inválido ("$id"): use 2 a 32 caracteres (a-z, 0-9, _ ou -).');
    }
    final livros = j['livros'];
    if (livros is! List || livros.isEmpty) {
      throw BibleModuleException('O arquivo não contém a lista de "livros".');
    }
    final books = <String, List<List<(int, String)>>>{};
    for (final (idx, l) in livros.indexed) {
      if (l is! Map) {
        throw BibleModuleException('Livro #${idx + 1} malformado (esperado objeto JSON).');
      }
      final rawId = l['id'];
      if (rawId is! String || !bibleBooksById.containsKey(rawId)) {
        throw BibleModuleException('Livro desconhecido no cânon católico (73 livros): "$rawId".');
      }
      final caps = l['capitulos'];
      books[rawId] = _chapters(caps, rawId);
    }
    final totalVerses = books.values.fold(0, (a, b) => a + b.fold(0, (x, c) => x + c.length));
    if (totalVerses == 0) {
      throw BibleModuleException('O módulo não possui nenhum versículo válido.');
    }
    final meta = Map<String, Object?>.from(j)..remove('livros');
    final sigla = siglaRaw.trim();
    meta['id'] = id;
    meta['nome'] = (j['nome'] as String).trim();
    meta['abreviacao'] = sigla;
    meta['sigla'] = sigla;
    meta['idioma'] = (j['idioma'] as String).trim();
    if (meta['licenca'] is! String || (meta['licenca'] as String).trim().isEmpty) {
      meta['licenca'] = 'Importada localmente pelo usuário';
    }
    return BibleModule._(meta, books);
  }

  static List<List<(int, String)>> _chapters(Object? caps, String book) {
    if (caps is List) {
      return [for (final (i, c) in caps.indexed) _chapter(c, book, i + 1)];
    }
    if (caps is Map) {
      final parsed = <int, List<(int, String)>>{};
      var maxCap = 0;
      for (final e in caps.entries) {
        final numCap = int.tryParse('${e.key}');
        if (numCap == null || numCap < 1) {
          throw BibleModuleException('Número de capítulo inválido em "$book": "${e.key}".');
        }
        if (parsed.containsKey(numCap)) {
          throw BibleModuleException('Capítulo $numCap repetido em "$book".');
        }
        if (numCap > maxCap) maxCap = numCap;
        parsed[numCap] = _chapter(e.value, book, numCap);
      }
      return [for (var i = 1; i <= maxCap; i++) parsed[i] ?? const <(int, String)>[]];
    }
    throw BibleModuleException('Campo "capitulos" malformado em "$book".');
  }

  static List<(int, String)> _chapter(Object? c, String book, int chapterNum) {
    final out = <(int, String)>[];
    if (c is List) {
      var n = 0;
      for (final v in c) {
        if (v is String) {
          out.add((++n, v));
        } else if (v is List && v.length == 2 && v[0] is num && v[1] is String) {
          n = (v[0] as num).toInt();
          out.add((n, v[1] as String));
        } else {
          throw BibleModuleException('Versículo malformado em "$book" capítulo $chapterNum.');
        }
      }
    } else if (c is Map) {
      final entries = c.entries.map((e) => (int.tryParse('${e.key}'), e.value)).toList();
      if (entries.any((e) => e.$1 == null || e.$2 is! String)) {
        throw BibleModuleException('Versículo malformado em "$book" capítulo $chapterNum.');
      }
      for (final e in entries..sort((a, b) => a.$1!.compareTo(b.$1!))) {
        out.add((e.$1!, e.$2! as String));
      }
    } else {
      throw BibleModuleException('Capítulo $chapterNum malformado em "$book".');
    }
    // Duplicatas violariam a chave (livro, capítulo, versículo) no INSERT do SQLite.
    final seen = <int>{};
    for (final (n, _) in out) {
      if (n < 1) throw BibleModuleException('Versículo inválido ($n) em "$book" capítulo $chapterNum.');
      if (!seen.add(n)) throw BibleModuleException('Versículo $n repetido em "$book" capítulo $chapterNum.');
    }
    return out;
  }
}
