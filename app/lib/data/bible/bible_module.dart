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
/// {"formato": "viasacra-biblia", "versao": 1, "id": "cnbb", "nome": "Bíblia Sagrada — CNBB",
///  "abreviacao": "CNBB", "idioma": "pt-BR", "licenca": "© CNBB — uso pessoal",
///  "numeracao_salmos": "grega",
///  "livros": [{"id": "gn", "capitulos": [["No princípio…", "…"], …]}]}
/// ```
/// Um capítulo também pode ser um objeto {"1": "texto", "2": "texto"} ou conter
/// pares [número, texto] quando a numeração não é sequencial.
class BibleModule {
  BibleModule._(this.meta, this.books);

  final Map<String, Object?> meta;

  /// bookId → capítulos → (versículo, texto)
  final Map<String, List<List<(int, String)>>> books;

  String get id => meta['id']! as String;
  String get name => meta['nome']! as String;
  int get version => (meta['versao_modulo'] as num?)?.toInt() ?? 1;
  int get verseCount => books.values.fold(0, (a, b) => a + b.fold(0, (x, c) => x + c.length));

  static final _idRe = RegExp(r'^[a-z0-9_\-]{2,32}$');

  static BibleModule parse(Map<String, dynamic> j) {
    if (j['formato'] != 'viasacra-biblia') {
      throw BibleModuleException('Arquivo não é um módulo de Bíblia do Via Sacra (campo "formato").');
    }
    if ((j['versao'] as num?)?.toInt() != 1) throw BibleModuleException('Versão de formato não suportada.');
    for (final k in ['id', 'nome', 'abreviacao', 'idioma', 'licenca']) {
      if (j[k] is! String || (j[k] as String).trim().isEmpty) {
        throw BibleModuleException('Campo obrigatório ausente: $k');
      }
    }
    if (!_idRe.hasMatch(j['id'] as String)) {
      throw BibleModuleException('id inválido (use letras minúsculas, números, _ ou -).');
    }
    final livros = j['livros'];
    if (livros is! List || livros.isEmpty) throw BibleModuleException('O módulo não contém livros.');
    final books = <String, List<List<(int, String)>>>{};
    for (final l in livros) {
      if (l is! Map) throw BibleModuleException('Livro malformado.');
      final id = l['id'];
      if (id is! String || !bibleBooksById.containsKey(id)) {
        throw BibleModuleException('Livro desconhecido no cânon católico: $id');
      }
      final caps = l['capitulos'];
      if (caps is! List) throw BibleModuleException('Capítulos malformados em $id.');
      books[id] = [for (final c in caps) _chapter(c, id)];
    }
    return BibleModule._(Map<String, Object?>.from(j)..remove('livros'), books);
  }

  static List<(int, String)> _chapter(Object? c, String book) {
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
          throw BibleModuleException('Versículo malformado em $book.');
        }
      }
    } else if (c is Map) {
      final entries = c.entries.map((e) => (int.tryParse('${e.key}'), e.value)).toList();
      if (entries.any((e) => e.$1 == null || e.$2 is! String)) {
        throw BibleModuleException('Versículo malformado em $book.');
      }
      for (final e in entries..sort((a, b) => a.$1!.compareTo(b.$1!))) {
        out.add((e.$1!, e.$2! as String));
      }
    } else {
      throw BibleModuleException('Capítulo malformado em $book.');
    }
    return out;
  }
}
