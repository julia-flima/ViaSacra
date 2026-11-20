import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/bible/bible_canon.dart';
import '../../data/bible/bible_models.dart';
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
  BibleService? _bible;
  List<({String bookId, int chapter, int verse, VerseAnnotation a, String? text})> _items = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bible = context.read<BibleService>();
    if (_bible != bible) {
      _bible = bible;
      _reload(bible);
    }
  }

  void _reload(BibleService bible) {
    _items = bible.repo.marked(favoritesOnly: _favoritesOnly, translationId: bible.currentTranslationId);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas marcações')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Todas')),
                      ButtonSegment(value: true, label: Text('Favoritos')),
                    ],
                    selected: {_favoritesOnly},
                    onSelectionChanged: (v) => setState(() {
                      _favoritesOnly = v.first;
                      if (_bible != null) _reload(_bible!);
                    }),
                  ),
                  if (_items.isEmpty) ...[
                    const SizedBox(height: VsSpacing.md),
                    Text(
                      'Toque em um versículo durante a leitura para marcá-lo, favoritá-lo ou anotar.',
                      style: t.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_items.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, VsSpacing.xxl),
              sliver: SliverList.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final m = _items[index];
                  final book = bookById(m.bookId);
                  final label = book != null ? '${book.abbreviation} ${m.chapter},${m.verse}' : m.bookId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: m.a.color == null
                          ? Theme.of(context).colorScheme.outline
                          : Color(dark ? m.a.color!.dark : m.a.color!.light),
                      child: m.a.favorite ? const Icon(Icons.bookmark, size: 14) : null,
                    ),
                    title: Text(label, style: t.titleMedium),
                    subtitle: Text(
                      [?m.text, if (m.a.note != null) 'Nota: ${m.a.note}'].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, (m.bookId, m.chapter, m.verse)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
