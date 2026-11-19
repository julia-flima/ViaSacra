import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/bible/bible_canon.dart';
import '../../services/bible_service.dart';

/// Favoritos, marcações e anotações (independentes da tradução).
/// Retorna (bookId, chapter, verse) do item escolhido.
class MarkedVersesScreen extends StatefulWidget {
  const MarkedVersesScreen({super.key});

  @override
  State<MarkedVersesScreen> createState() => _MarkedVersesScreenState();
}

class _MarkedVersesScreenState extends State<MarkedVersesScreen> {
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final bible = context.read<BibleService>();
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = bible.repo.marked(favoritesOnly: _favoritesOnly);
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas marcações')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Todas')),
              ButtonSegment(value: true, label: Text('Favoritos')),
            ],
            selected: {_favoritesOnly},
            onSelectionChanged: (v) => setState(() => _favoritesOnly = v.first),
          ),
          const SizedBox(height: VsSpacing.md),
          if (items.isEmpty)
            Text('Toque em um versículo durante a leitura para marcá-lo, favoritá-lo ou anotar.', style: t.bodyMedium),
          for (final m in items)
            Builder(
              builder: (context) {
                final book = bookById(m.bookId)!;
                final text = bible.repo
                    .chapter(bible.currentTranslationId, m.bookId, m.chapter)
                    .where((v) => v.verse == m.verse)
                    .firstOrNull
                    ?.text;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: m.a.color == null
                        ? Theme.of(context).colorScheme.outline
                        : Color(dark ? m.a.color!.dark : m.a.color!.light),
                    child: m.a.favorite ? const Icon(Icons.bookmark, size: 14) : null,
                  ),
                  title: Text('${book.abbreviation} ${m.chapter},${m.verse}', style: t.titleMedium),
                  subtitle: Text(
                    [?text, if (m.a.note != null) 'Nota: ${m.a.note}'].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, (m.bookId, m.chapter, m.verse)),
                );
              },
            ),
        ],
      ),
    );
  }
}
