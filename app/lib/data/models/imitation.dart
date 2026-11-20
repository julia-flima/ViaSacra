/// "A Imitação de Cristo" (Tomás de Kempis) — 4 livros, embutida em assets.
class ImitationOfChrist {
  const ImitationOfChrist({required this.books, required this.source, required this.license});

  factory ImitationOfChrist.fromJson(Map<String, dynamic> data) => ImitationOfChrist(
    books: [
      for (final b in (data['livros'] as List).cast<Map<String, dynamic>>())
        ImitationBook(
          number: b['numero'] as String,
          title: b['titulo'] as String,
          subtitle: b['subtitulo'] as String? ?? '',
          chapters: [
            for (final c in (b['capitulos'] as List).cast<Map<String, dynamic>>())
              ImitationChapter(
                bookNumber: b['numero'] as String,
                number: (c['numero'] as num).toInt(),
                title: c['titulo'] as String? ?? '',
                paragraphs: (c['paragrafos'] as List).cast<String>(),
              ),
          ],
        ),
    ],
    source: data['fonte'] as String? ?? 'Tomás de Kempis — A Imitação de Cristo',
    license: data['licenca'] as String? ?? 'Domínio público',
  );

  final List<ImitationBook> books;
  final String source;
  final String license;

  /// Todos os capítulos em ordem (Livro I → IV).
  List<ImitationChapter> get chapters => [for (final b in books) ...b.chapters];
}

class ImitationBook {
  const ImitationBook({required this.number, required this.title, required this.subtitle, required this.chapters});

  final String number;
  final String title;
  final String subtitle;
  final List<ImitationChapter> chapters;
}

class ImitationChapter {
  const ImitationChapter({
    required this.bookNumber,
    required this.number,
    required this.title,
    required this.paragraphs,
  });

  final String bookNumber;
  final int number;
  final String title;
  final List<String> paragraphs;

  String get label => 'Livro $bookNumber · Cap. $number';

  /// Chave estável para favoritos e "Continuar lendo" (ex.: "I-12").
  String get ref => '$bookNumber-$number';
}
