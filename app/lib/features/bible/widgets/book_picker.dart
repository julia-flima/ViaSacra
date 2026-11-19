import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../data/bible/bible_canon.dart';
import '../../../data/bible/bible_repository.dart';

/// Seletor Livro › Capítulo, com Antigo e Novo Testamento separados.
/// Retorna (bookId, chapter) ou null.
Future<(String, int)?> showBookPicker(
  BuildContext context, {
  required BibleRepository repo,
  required String translationId,
  String? currentBookId,
  bool openChapters = false,
}) {
  return showModalBottomSheet<(String, int)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _BookPicker(
        repo: repo,
        translationId: translationId,
        currentBookId: currentBookId,
        openChapters: openChapters,
      ),
    ),
  );
}

class _BookPicker extends StatefulWidget {
  const _BookPicker({required this.repo, required this.translationId, this.currentBookId, this.openChapters = false});

  final BibleRepository repo;
  final String translationId;
  final String? currentBookId;

  /// Abre direto na grade de capítulos de [currentBookId].
  final bool openChapters;

  @override
  State<_BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<_BookPicker> {
  late BibleBook? _book = widget.openChapters ? bookById(widget.currentBookId ?? '') : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final available = widget.repo.books(widget.translationId).map((b) => b.id).toSet();
    final book = _book;
    if (book != null) {
      final count = widget.repo.chapterCount(widget.translationId, book.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: IconButton(
              tooltip: 'Voltar aos livros',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _book = null),
            ),
            title: Text(book.name, style: t.titleLarge),
            subtitle: Text('${book.latinName} · $count capítulo${count == 1 ? '' : 's'}'),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(VsSpacing.md),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: count,
              itemBuilder: (_, i) => OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
                onPressed: () => Navigator.pop(context, (book.id, i + 1)),
                child: Text('${i + 1}'),
              ),
            ),
          ),
        ],
      );
    }
    return DefaultTabController(
      length: 2,
      initialIndex: bookById(widget.currentBookId ?? '')?.testament == Testament.nt ? 1 : 0,
      child: Column(
        children: [
          TabBar(tabs: [for (final te in Testament.values) Tab(text: te.label)]),
          Expanded(
            child: TabBarView(
              children: [
                for (final te in Testament.values)
                  ListView(
                    padding: const EdgeInsets.symmetric(vertical: VsSpacing.sm),
                    children: [
                      for (final b in bibleCanon.where((b) => b.testament == te))
                        ListTile(
                          enabled: available.contains(b.id),
                          selected: b.id == widget.currentBookId,
                          leading: SizedBox(
                            width: 44,
                            child: Text(
                              b.abbreviation,
                              style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          title: Text(b.name),
                          subtitle: b.deutero ? const Text('Deuterocanônico') : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() => _book = b),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
