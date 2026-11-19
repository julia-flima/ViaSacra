import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/bible/bible_canon.dart';
import '../../data/bible/bible_models.dart';
import '../../data/bible/bible_reference.dart';
import '../../services/bible_service.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import 'bible_search_screen.dart';
import 'marked_verses_screen.dart';
import 'translations_screen.dart';
import 'widgets/book_picker.dart';
import 'widgets/translation_selector.dart';
import 'widgets/verse_actions_sheet.dart';

/// Aba 2 — Bíblia Sagrada (cânon católico, 73 livros), 100% offline.
class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  bool _reading = false;
  String? _compareId;
  BibleRef? _highlightRef; // trecho vindo da Liturgia
  final _verseKeys = <int, GlobalKey>{};
  final _scroll = ScrollController();

  BibleService get _bible => context.read<BibleService>();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Abre a referência pedida por outra aba (ex.: leitura da Liturgia).
  void _consumePendingRef(BibleService bible) {
    final ref = bible.pendingRef;
    if (ref == null || !bible.ready) return;
    bible.pendingRef = null;
    final r = bible.repo.resolve(ref, bible.currentTranslationId);
    if (r == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(r.bookId, r.chapter, verse: r.verse, highlight: ref);
    });
  }

  void _open(String bookId, int chapter, {int? verse, BibleRef? highlight, String? translationId}) {
    _bible.open(translationId ?? _bible.currentTranslationId, bookId, chapter, verse: verse);
    setState(() {
      _reading = true;
      _highlightRef = highlight;
      _verseKeys.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = verse == null ? null : _verseKeys[verse];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!, alignment: 0.15, duration: const Duration(milliseconds: 350));
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
  }

  Future<void> _pickBook() async {
    final b = _bible;
    final r = await showBookPicker(
      context,
      repo: b.repo,
      translationId: b.currentTranslationId,
      currentBookId: b.position?.bookId,
    );
    if (r != null) _open(r.$1, r.$2);
  }

  Future<void> _pickTranslation() async {
    final b = _bible;
    final choice = await showTranslationSelector(
      context,
      translations: b.translations,
      currentId: b.currentTranslationId,
      compareId: _compareId,
    );
    if (choice == null || !mounted) return;
    if (choice.manage) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TranslationsScreen()));
      return;
    }
    if (choice.clearCompare) setState(() => _compareId = null);
    if (choice.compareId != null) setState(() => _compareId = choice.compareId);
    if (choice.translationId != null) {
      final p = b.position;
      if (p != null) {
        final count = b.repo.chapterCount(choice.translationId!, p.bookId);
        _open(p.bookId, p.chapter.clamp(1, count < 1 ? 1 : count), translationId: choice.translationId);
      } else {
        b.open(choice.translationId!, 'mt', 1);
      }
      if (_compareId == choice.translationId) setState(() => _compareId = null);
    }
  }

  void _listen(BibleTranslation tr, String bookId, int chapter, List<BibleVerse> verses) {
    final book = bookById(bookId)!;
    final settings = context.read<SettingsService>();
    context.read<ReadingAudioController>().playSingle(
      ReadingSegment(
        id: 'biblia-${tr.id}-$bookId-$chapter',
        title: '${book.name} $chapter',
        subtitle: tr.name,
        text: '${book.name}, capítulo $chapter. ${verses.map((v) => v.text).join(' ')}',
        language: tr.language,
      ),
      speed: settings.ttsSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bible = context.watch<BibleService>();
    if (!bible.ready) return _Preparing(bible: bible);
    _consumePendingRef(bible);
    final pos = bible.position;
    if (!_reading || pos == null) return _home(context, bible);
    return _reader(context, bible, pos);
  }

  // ------------------------------------------------------------------ início
  Widget _home(BuildContext context, BibleService bible) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final pos = bible.position;
    final tr = bible.current!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia Sagrada'),
        actions: [
          IconButton(tooltip: 'Buscar na Bíblia', icon: const Icon(Icons.search), onPressed: () => _search(bible)),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          if (bible.progress != null) _ProgressBanner(bible: bible),
          ActionChip(
            avatar: const Icon(Icons.translate, size: 18),
            label: Text('${tr.abbreviation} · ${tr.name}'),
            onPressed: _pickTranslation,
          ),
          const SizedBox(height: VsSpacing.md),
          if (pos != null && bookById(pos.bookId) != null)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: VsSpacing.sm),
                leading: Icon(Icons.bookmark_outline, color: Theme.of(context).colorScheme.primary),
                title: const Text('Continuar lendo'),
                subtitle: Text('${bookById(pos.bookId)!.name} ${pos.chapter}', style: t.titleLarge),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _open(pos.bookId, pos.chapter, verse: pos.verse),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('Favoritos, marcações e anotações'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final r = await Navigator.of(context)
                  .push<(String, int, int)>(MaterialPageRoute(builder: (_) => const MarkedVersesScreen()));
              if (r != null) _open(r.$1, r.$2, verse: r.$3);
            },
          ),
          for (final te in Testament.values) ...[
            const SizedBox(height: VsSpacing.md),
            Eyebrow(te.label),
            const SizedBox(height: VsSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in bible.repo.books(tr.id).where((b) => b.testament == te))
                  Tooltip(
                    message: b.name,
                    child: ActionChip(
                      label: Text(b.abbreviation),
                      onPressed: () async {
                        final r = await showBookPicker(
                          context,
                          repo: bible.repo,
                          translationId: tr.id,
                          currentBookId: b.id,
                          openChapters: true,
                        );
                        if (r != null) _open(r.$1, r.$2);
                      },
                    ),
                  ),
              ],
            ),
          ],
          const CrossDivider(),
          SourceAttribution(source: tr.name, license: '${tr.license}${tr.source != null ? ' · ${tr.source}' : ''}'),
        ],
      ),
    );
  }

  Future<void> _search(BibleService bible) async {
    final r = await Navigator.of(
      context,
    ).push<BibleVerse>(MaterialPageRoute(builder: (_) => BibleSearchScreen(translationId: bible.currentTranslationId)));
    if (r != null) _open(r.bookId, r.chapter, verse: r.verse);
  }

  // ------------------------------------------------------------------ leitor
  Widget _reader(BuildContext context, BibleService bible, ReadingPosition pos) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pad = VsSpacing.page(context);
    final tr = bible.translation(pos.translationId) ?? bible.current!;
    final book = bookById(pos.bookId)!;
    final verses = bible.repo.chapter(tr.id, book.id, pos.chapter);
    final total = bible.repo.chapterCount(tr.id, book.id);
    final compare = _compareId == null ? null : bible.translation(_compareId!);
    final compareVerses = compare == null
        ? const <int, String>{}
        : {for (final v in bible.repo.chapter(compare.id, book.id, pos.chapter)) v.verse: v.text};
    final notes = bible.repo.annotations(book.id, pos.chapter);
    final highlight = _highlightRef?.book.id == book.id ? _highlightRef : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Início da Bíblia',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _reading = false),
        ),
        title: InkWell(
          onTap: _pickBook,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text('${book.name} ${pos.chapter}', overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pickTranslation,
            child: Text(compare == null ? tr.abbreviation : '${tr.abbreviation}+${compare.abbreviation}'),
          ),
          IconButton(
            tooltip: 'Ouvir capítulo',
            icon: const Icon(Icons.headphones_outlined),
            onPressed: () => _listen(tr, book.id, pos.chapter, verses),
          ),
          IconButton(tooltip: 'Buscar', icon: const Icon(Icons.search), onPressed: () => _search(bible)),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
        children: [
          Eyebrow(book.testament.label),
          const SizedBox(height: 4),
          Text('${book.name} ${pos.chapter}', style: t.headlineMedium),
          if (book.id == 'sl')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Numeração ${tr.psalmNumbering} dos Salmos', style: t.bodySmall),
            ),
          const SizedBox(height: VsSpacing.md),
          for (final v in verses)
            _VerseTile(
              key: _verseKeys.putIfAbsent(v.verse, GlobalKey.new),
              verse: v,
              annotation: notes[v.verse],
              compareText: compareVerses[v.verse],
              compareLabel: compare?.abbreviation,
              emphasized: highlight?.contains(v.verse) ?? false,
              dark: dark,
              onTap: () async {
                final r = await showVerseActions(
                  context,
                  verse: v,
                  translation: tr,
                  annotation: notes[v.verse] ?? const VerseAnnotation(),
                );
                if (r != null) {
                  bible.repo.saveAnnotation(book.id, pos.chapter, v.verse, r);
                  setState(() {});
                }
              },
            ),
          const SizedBox(height: VsSpacing.lg),
          Row(
            children: [
              if (pos.chapter > 1)
                OutlinedButton.icon(
                  onPressed: () => _open(book.id, pos.chapter - 1),
                  icon: const Icon(Icons.chevron_left),
                  label: Text('Cap. ${pos.chapter - 1}'),
                ),
              const Spacer(),
              if (pos.chapter < total)
                FilledButton.tonalIcon(
                  onPressed: () => _open(book.id, pos.chapter + 1),
                  icon: const Icon(Icons.chevron_right),
                  label: Text('Cap. ${pos.chapter + 1}'),
                ),
            ],
          ),
          const CrossDivider(),
          SourceAttribution(source: tr.name, license: tr.license),
          if (compare != null) SourceAttribution(source: compare.name, license: compare.license),
          if (highlight != null)
            Text(
              'Destacado: trecho proclamado na Liturgia (${highlight.label}).',
              style: t.bodySmall?.copyWith(color: cs.primary),
            ),
        ],
      ),
    );
  }
}

class _VerseTile extends StatelessWidget {
  const _VerseTile({
    super.key,
    required this.verse,
    required this.onTap,
    required this.dark,
    this.annotation,
    this.compareText,
    this.compareLabel,
    this.emphasized = false,
  });

  final BibleVerse verse;
  final VerseAnnotation? annotation;
  final String? compareText;
  final String? compareLabel;
  final bool emphasized;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = annotation?.color;
    return Semantics(
      button: true,
      label: 'Versículo ${verse.verse}. ${verse.text}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color != null ? Color(dark ? color.dark : color.light) : null,
            borderRadius: BorderRadius.circular(6),
            border: emphasized ? Border(left: BorderSide(color: cs.primary, width: 3)) : null,
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${verse.verse} ',
                        style: t.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: 0),
                      ),
                      TextSpan(text: verse.text, style: t.bodyLarge),
                      if (annotation?.favorite ?? false)
                        WidgetSpan(child: Icon(Icons.bookmark, size: 14, color: cs.secondary)),
                      if (annotation?.note != null)
                        WidgetSpan(child: Icon(Icons.sticky_note_2_outlined, size: 14, color: cs.secondary)),
                    ],
                  ),
                ),
                if (compareText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      '$compareLabel · $compareText',
                      style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.bible});
  final BibleService bible;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bíblia Sagrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VsSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✝', style: TextStyle(fontSize: 36, color: Theme.of(context).colorScheme.secondary)),
              const SizedBox(height: VsSpacing.md),
              Text(bible.progressLabel ?? 'Preparando a Bíblia para uso offline…', style: t.titleMedium),
              const SizedBox(height: VsSpacing.md),
              LinearProgressIndicator(value: bible.progress),
              const SizedBox(height: VsSpacing.sm),
              Text('Isto acontece só na primeira vez.', style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.bible});
  final BibleService bible;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: VsSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(bible.progressLabel ?? '', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: bible.progress),
      ],
    ),
  );
}
