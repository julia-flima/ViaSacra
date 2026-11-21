import 'dart:async' show unawaited;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/bible/bible_canon.dart';
import '../../data/bible/bible_models.dart';
import '../../data/bible/psalm_numbering.dart';
import '../../data/bible/bible_reference.dart';
import '../../services/bible_service.dart';
import '../../services/reading_audio_service.dart';
import '../../widgets/common.dart';
import '../../widgets/reading_appearance_button.dart';
import '../../widgets/sacred_art_header.dart';
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
  int _highlightChapter = 0; // capítulo (já na numeração da tradução) onde o trecho começa
  int? _scrollTargetVerse;
  final _targetVerseKey = GlobalKey();
  // Usa o PrimaryScrollController da aba/rota para que setas, PageUp/PageDown,
  // Home/End e Espaço (HomeShell / KeyboardScroll) rolem o leitor.
  ScrollController get _scroll => PrimaryScrollController.of(context);

  (String trId, int version, int verseCount)? _booksCacheKey;
  List<BibleBook> _cachedBooks = const [];
  _ChapterCache? _chapterCache;

  BibleService get _bible => context.read<BibleService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final b = _bible;
      if (!b.autoInstallBundled && b.bundledCatalog.isEmpty && !b.ready) {
        unawaited(
          b.ensureCatalog().catchError((Object e) {
            debugPrint('Erro ao carregar catálogo da Bíblia: $e');
            return const <BundledTranslationInfo>[];
          }),
        );
      }
    });
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
      _highlightChapter = chapter;
      _scrollTargetVerse = verse;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTargetVerse(verse));
  }

  void _scrollToTargetVerse(int? verse, {int attempts = 0}) {
    if (!mounted) return;
    if (verse == null || verse <= 1) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    final ctx = _targetVerseKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 250));
      return;
    }
    if (!_scroll.hasClients || attempts >= 4) return;
    final verses = _chapterCache?.verses ?? const <BibleVerse>[];
    final idx = verses.indexWhere((v) => v.verse == verse);
    if (idx < 0) return;
    final pos = _scroll.position;
    final est = verses.length > 1 && pos.maxScrollExtent > 0
        ? (idx / (verses.length - 1)) * pos.maxScrollExtent
        : idx * 68.0;
    _scroll.jumpTo(est.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTargetVerse(verse, attempts: attempts + 1));
  }

  List<BibleBook> _booksFor(BibleService bible, BibleTranslation tr) {
    final key = (tr.id, tr.moduleVersion, tr.verseCount);
    if (_booksCacheKey != key) {
      _booksCacheKey = key;
      _cachedBooks = bible.repo.books(tr.id);
    }
    return _cachedBooks;
  }

  _ChapterCache _chapterData(
    BibleService bible,
    BibleTranslation tr,
    String bookId,
    int chapter,
    BibleTranslation? compare,
  ) {
    final key = (
      trId: tr.id,
      trVersion: tr.moduleVersion,
      trVerses: tr.verseCount,
      bookId: bookId,
      chapter: chapter,
      compareId: compare?.id,
      compareVersion: compare?.moduleVersion,
    );
    if (_chapterCache?.key == key) return _chapterCache!;
    final compareChapter = compare == null ? chapter : _alignedChapter(tr, compare, bookId, chapter);
    final data = _ChapterCache(
      key: key,
      verses: bible.repo.chapter(tr.id, bookId, chapter),
      totalChapters: bible.repo.chapterCount(tr.id, bookId),
      compareVerses: compare == null
          ? const {}
          : {for (final v in bible.repo.chapter(compare.id, bookId, compareChapter)) v.verse: v.text},
      annotations: bible.repo.annotations(bookId, chapter),
    );
    return _chapterCache = data;
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

  Future<void> _downloadBundled(String id, {bool switchTo = false}) async {
    final b = _bible;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await b.installBundled(id);
      if (!mounted) return;
      if (switchTo) {
        final p = b.position;
        if (p != null) {
          final count = b.repo.chapterCount(id, p.bookId);
          _open(p.bookId, p.chapter.clamp(1, count < 1 ? 1 : count), verse: p.verse, translationId: id);
        } else {
          b.open(id, 'mt', 1);
        }
        if (_compareId == id) setState(() => _compareId = null);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Baixar tradução: $e');
        messenger.showSnackBar(
          const SnackBar(content: Text('Não foi possível baixar a tradução. Confira a internet e tente de novo.')),
        );
      }
    }
  }

  Future<void> _pickTranslation() async {
    final b = _bible;
    await b.ensureCatalog();
    if (!mounted) return;
    final choice = await showTranslationSelector(
      context,
      translations: b.translations,
      availableBundled: b.availableBundled,
      currentId: b.currentTranslationId,
      compareId: _compareId,
    );
    if (choice == null || !mounted) return;
    if (choice.manage) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TranslationsScreen()));
      _booksCacheKey = null;
      _chapterCache = null;
      return;
    }
    if (choice.downloadBundledId != null) {
      await _downloadBundled(choice.downloadBundledId!, switchTo: true);
      return;
    }
    if (choice.clearCompare) setState(() => _compareId = null);
    if (choice.compareId != null) setState(() => _compareId = choice.compareId);
    if (choice.translationId != null) {
      final p = b.position;
      if (p != null) {
        final count = b.repo.chapterCount(choice.translationId!, p.bookId);
        _open(p.bookId, p.chapter.clamp(1, count < 1 ? 1 : count), verse: p.verse, translationId: choice.translationId);
      } else {
        b.open(choice.translationId!, 'mt', 1);
      }
      if (_compareId == choice.translationId) setState(() => _compareId = null);
    }
  }

  void _toggleCompare(BibleService bible) {
    if (_compareId != null) {
      setState(() => _compareId = null);
      return;
    }
    final others = bible.translations.where((t) => t.id != bible.currentTranslationId).toList();
    if (others.isEmpty) {
      _pickTranslation();
      return;
    }
    if (others.length == 1) {
      setState(() => _compareId = others.first.id);
      return;
    }
    // Se houver Vulgata entre as demais, ou múltiplas, abre o seletor rápido.
    _pickTranslation();
  }

  /// Alinha o capítulo dos Salmos quando as duas traduções comparadas usam
  /// numerações diferentes (grega vs hebraica).
  int _alignedChapter(BibleTranslation primary, BibleTranslation compare, String bookId, int chapter) => bookId == 'sl'
      ? PsalmNumbering.convert(chapter, from: primary.psalmNumbering, to: compare.psalmNumbering)
      : chapter;

  void _listen(BibleTranslation tr, String bookId, int chapter, List<BibleVerse> verses) {
    final book = bookById(bookId)!;
    context.read<ReadingAudioController>().playSingle(
      ReadingSegment(
        id: 'biblia-${tr.id}-$bookId-$chapter',
        title: '${book.name} $chapter',
        subtitle: tr.name,
        text: '${book.name}, capítulo $chapter. ${verses.map((v) => v.text).join(' ')}',
        language: tr.language,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bible = context.watch<BibleService>();
    if (!bible.ready) {
      if (!bible.autoInstallBundled && bible.progress == null) {
        return _WebBibleCatalog(
          bible: bible,
          onDownload: (id) => _downloadBundled(id),
          onOpenTranslations: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TranslationsScreen())),
        );
      }
      return _Preparing(bible: bible);
    }
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
    final art = context.read<AppServices>().content.art['header-biblia'];
    final books = _booksFor(bible, tr);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia Sagrada'),
        actions: [
          TextButton.icon(
            onPressed: _pickTranslation,
            icon: const Icon(Icons.translate, size: 18),
            label: Text(tr.abbreviation),
          ),
          const ReadingAppearanceButton(),
          IconButton(tooltip: 'Buscar na Bíblia', icon: const Icon(Icons.search), onPressed: () => _search(bible)),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
            sliver: SliverList.list(
              children: [
                SacredArtBanner(title: tr.name, subtitle: 'CÂNON CATÓLICO · 73 LIVROS', art: art),
                const SizedBox(height: VsSpacing.md),
                if (bible.progress != null) _ProgressBanner(bible: bible),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.library_add_outlined),
                  title: const Text('Gerenciar e Importar Traduções'),
                  subtitle: Text('${bible.translations.length} instalada(s) neste aparelho'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TranslationsScreen()));
                    if (mounted) {
                      setState(() {
                        _booksCacheKey = null;
                        _chapterCache = null;
                      });
                    }
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
                      for (final b in books.where((b) => b.testament == te))
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
                SourceAttribution(
                  source: tr.name,
                  license: '${tr.license}${tr.source != null ? ' · ${tr.source}' : ''}',
                ),
              ],
            ),
          ),
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
    final compare = _compareId == null ? null : bible.translation(_compareId!);
    final data = _chapterData(bible, tr, book.id, pos.chapter, compare);
    final verses = data.verses;
    final total = data.totalChapters;
    final compareVerses = data.compareVerses;
    final notes = data.annotations;
    final highlight = _highlightRef?.book.id == book.id ? _highlightRef : null;

    void backToHome() => setState(() {
      _reading = false;
      _chapterCache = null;
    });

    // Botão voltar do Android: volta ao início da Bíblia em vez de sair do app.
    return PopScope(
      canPop: !TickerMode.valuesOf(context).enabled,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backToHome();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Início da Bíblia', icon: const Icon(Icons.arrow_back), onPressed: backToHome),
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
            // Em celulares (< 600dp) as ações secundárias vão para o menu ⋮,
            // para o título caber em 360dp.
            if (MediaQuery.sizeOf(context).width >= 600) ...[
              if (bible.translations.length > 1)
                IconButton(
                  tooltip: compare == null ? 'Ativar leitura comparada' : 'Desativar leitura comparada',
                  icon: Icon(Icons.compare_arrows, color: compare != null ? cs.primary : null),
                  onPressed: () => _toggleCompare(bible),
                ),
              const ReadingAppearanceButton(),
              IconButton(tooltip: 'Buscar', icon: const Icon(Icons.search), onPressed: () => _search(bible)),
            ] else
              PopupMenuButton<void Function()>(
                tooltip: 'Mais opções',
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  if (bible.translations.length > 1)
                    PopupMenuItem(
                      value: () => _toggleCompare(bible),
                      child: ListTile(
                        leading: Icon(Icons.compare_arrows, color: compare != null ? cs.primary : null),
                        title: Text(compare == null ? 'Leitura comparada' : 'Desativar comparação'),
                      ),
                    ),
                  PopupMenuItem(
                    value: () => showReadingAppearanceSheet(context),
                    child: const ListTile(
                      leading: Icon(Icons.text_fields_rounded),
                      title: Text('Aparência da leitura'),
                    ),
                  ),
                  PopupMenuItem(
                    value: () => _search(bible),
                    child: const ListTile(leading: Icon(Icons.search), title: Text('Buscar')),
                  ),
                ],
              ),
          ],
        ),
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(book.testament.label),
                    const SizedBox(height: 4),
                    Text('${book.name} ${pos.chapter}', style: t.headlineMedium),
                    if (book.id == 'sl')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Numeração ${tr.psalmNumbering} dos Salmos', style: t.bodySmall),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverList.builder(
                itemCount: verses.length,
                itemBuilder: (context, index) {
                  final v = verses[index];
                  final key = v.verse == _scrollTargetVerse
                      ? _targetVerseKey
                      : ValueKey('${tr.id}-${book.id}-${pos.chapter}-${v.verse}');
                  return _VerseTile(
                    key: key,
                    verse: v,
                    annotation: notes[v.verse],
                    compareText: compareVerses[v.verse],
                    compareLabel: compare?.abbreviation,
                    emphasized: highlight?.containsAt(pos.chapter - _highlightChapter, v.verse) ?? false,
                    dark: dark,
                    onTap: () async {
                      bible.rememberVerse(tr.id, book.id, pos.chapter, v.verse);
                      final r = await showVerseActions(
                        context,
                        verse: v,
                        translation: tr,
                        annotation: notes[v.verse] ?? const VerseAnnotation(),
                      );
                      if (r != null) {
                        bible.repo.saveAnnotation(book.id, pos.chapter, v.verse, r);
                        if (mounted) {
                          setState(() {
                            final updated = Map<int, VerseAnnotation>.of(data.annotations);
                            if (r.isEmpty) {
                              updated.remove(v.verse);
                            } else {
                              updated[v.verse] = r;
                            }
                            _chapterCache = data.copyWithAnnotations(updated);
                          });
                        }
                      }
                    },
                  );
                },
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, VsSpacing.lg, pad, VsSpacing.xxl),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _ChapterCacheKey = ({
  String trId,
  int trVersion,
  int trVerses,
  String bookId,
  int chapter,
  String? compareId,
  int? compareVersion,
});

class _ChapterCache {
  const _ChapterCache({
    required this.key,
    required this.verses,
    required this.totalChapters,
    required this.compareVerses,
    required this.annotations,
  });

  final _ChapterCacheKey key;
  final List<BibleVerse> verses;
  final int totalChapters;
  final Map<int, String> compareVerses;
  final Map<int, VerseAnnotation> annotations;

  _ChapterCache copyWithAnnotations(Map<int, VerseAnnotation> next) => _ChapterCache(
    key: key,
    verses: verses,
    totalChapters: totalChapters,
    compareVerses: compareVerses,
    annotations: next,
  );
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

class _WebBibleCatalog extends StatelessWidget {
  const _WebBibleCatalog({required this.bible, required this.onDownload, required this.onOpenTranslations});

  final BibleService bible;
  final ValueChanged<String> onDownload;
  final VoidCallback onOpenTranslations;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final art = context.read<AppServices>().content.art['header-biblia'];
    final catalog = bible.bundledCatalog;

    return Scaffold(
      appBar: AppBar(title: const Text('Bíblia Sagrada'), actions: const [ReadingAppearanceButton()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          SacredArtBanner(title: 'Bíblia Sagrada', subtitle: 'CÂNON CATÓLICO · 73 LIVROS', art: art),
          const SizedBox(height: VsSpacing.md),
          Text(
            'Na versão Web, cada tradução é baixada e indexada uma única vez ao clicar e fica salva offline no navegador.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: VsSpacing.md),
          const Eyebrow('Traduções disponíveis (domínio público)'),
          const SizedBox(height: VsSpacing.sm),
          if (catalog.isEmpty)
            const Padding(
              padding: EdgeInsets.all(VsSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final item in catalog)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(VsSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            child: Text(item.abbreviation, style: t.labelSmall?.copyWith(letterSpacing: 0)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: t.titleMedium),
                                Text(
                                  '${item.language} · ${item.license}'
                                  '${item.sizeSuffix}',
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: VsSpacing.sm),
                        Text(item.description!, style: t.bodyMedium),
                      ],
                      const SizedBox(height: VsSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: bible.progress != null ? null : () => onDownload(item.id),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Baixar e ler'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: VsSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenTranslations,
              icon: const Icon(Icons.file_open_outlined, size: 18),
              label: const Text('Importar arquivo (.json)'),
            ),
          ),
        ],
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
