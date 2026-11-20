import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/models/imitation.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import '../../widgets/global_audio_mini_player.dart';
import '../../widgets/reading_appearance_button.dart';
import '../../widgets/sacred_art_header.dart';

/// Leitor 100% offline de "A Imitação de Cristo" (Tomás de Kempis — 4 Livros, 114 capítulos).
class ImitacaoScreen extends StatefulWidget {
  const ImitacaoScreen({super.key});

  @override
  State<ImitacaoScreen> createState() => _ImitacaoScreenState();
}

class _ImitacaoScreenState extends State<ImitacaoScreen> {
  static const favoriteKind = 'imitacao';
  ImitationOfChrist? _work;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final work = await context.read<AppServices>().content.imitation();
    if (mounted) setState(() => _work = work);
  }

  Future<void> _openChapter(ImitationOfChrist work, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImitacaoChapterScreen(work: work, initialIndex: index),
      ),
    );
    if (mounted) setState(() {}); // atualiza "Continuar lendo" e favoritos
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final work = _work;
    if (work == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('A Imitação de Cristo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final books = work.books;
    final all = work.chapters;
    final userData = context.read<AppServices>().userData;
    final favRefs = userData.favorites(favoriteKind).toSet();
    final favorites = [
      for (final (i, c) in all.indexed)
        if (favRefs.contains(c.ref)) (i, c),
    ];
    final lastRef = context.read<SettingsService>().imitationLastRef;
    final lastIdx = all.indexWhere((c) => c.ref == lastRef);
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final todayIdx = all.isEmpty ? 0 : dayOfYear % all.length;
    final today = all.isEmpty ? null : all[todayIdx];

    final art = context.read<AppServices>().content.art['header-imitacao'];

    return Scaffold(
      appBar: AppBar(title: const Text('A Imitação de Cristo'), actions: const [ReadingAppearanceButton()]),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
            sliver: SliverList.list(
              children: [
                SacredArtBanner(title: 'Tomás de Kempis', subtitle: '4 LIVROS · 114 CAPÍTULOS OFFLINE', art: art),
                const SizedBox(height: VsSpacing.md),
                if (lastIdx >= 0)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: VsSpacing.sm),
                      leading: Icon(Icons.bookmark_outline, color: Theme.of(context).colorScheme.primary),
                      title: Text('Continuar lendo · ${all[lastIdx].label}', style: t.titleSmall),
                      subtitle: Text(all[lastIdx].title, style: t.titleMedium),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => _openChapter(work, lastIdx),
                    ),
                  ),
                if (today != null)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: VsSpacing.sm),
                      leading: Icon(Icons.auto_stories_outlined, color: Theme.of(context).colorScheme.primary),
                      title: Text('Leitura sugerida de hoje · ${today.label}', style: t.titleSmall),
                      subtitle: Text(today.title, style: t.titleMedium),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => _openChapter(work, todayIdx),
                    ),
                  ),
                const SizedBox(height: VsSpacing.sm),
                if (favorites.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                    title: Text('Favoritos', style: t.titleLarge),
                    subtitle: Text('${favorites.length} capítulo(s)', style: t.bodySmall),
                    children: [
                      for (final (i, c) in favorites)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(c.title, style: t.bodyMedium),
                          subtitle: Text(c.label, style: t.bodySmall),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => _openChapter(work, i),
                        ),
                    ],
                  ),
                for (final b in books)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    title: Text(b.title, style: t.titleLarge),
                    subtitle: Text(
                      b.subtitle.isEmpty ? '${b.chapters.length} capítulos' : b.subtitle,
                      style: t.bodySmall,
                    ),
                    children: [
                      for (final c in b.chapters)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            '${c.number}',
                            style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(c.title, style: t.bodyMedium),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => _openChapter(work, all.indexOf(c)),
                        ),
                    ],
                  ),
                const CrossDivider(),
                SourceAttribution(source: work.source, license: work.license),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}

class _ImitacaoChapterScreen extends StatefulWidget {
  const _ImitacaoChapterScreen({required this.work, required this.initialIndex});

  final ImitationOfChrist work;
  final int initialIndex;

  @override
  State<_ImitacaoChapterScreen> createState() => _ImitacaoChapterScreenState();
}

class _ImitacaoChapterScreenState extends State<_ImitacaoChapterScreen> {
  late final List<ImitationChapter> _chapters = widget.work.chapters;
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _remember();
  }

  /// Guarda o capítulo atual para o "Continuar lendo".
  void _remember() => context.read<SettingsService>().imitationLastRef = _chapters[_index].ref;

  /// Troca de capítulo, guarda a posição e volta a rolagem ao topo.
  void _goTo(int index) {
    setState(() => _index = index);
    _remember();
    final scroll = PrimaryScrollController.of(context);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _listen(ImitationChapter c) {
    final settings = context.read<SettingsService>();
    final speech = '${c.label}. ${c.title}. ${c.paragraphs.join(' ')}';
    context.read<ReadingAudioController>().playSingle(
      ReadingSegment(
        id: 'imitacao-${c.bookNumber}-${c.number}',
        title: c.label,
        subtitle: c.title,
        text: speech,
        language: 'pt-BR',
      ),
      speed: settings.ttsSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _chapters[_index];
    final userData = context.read<AppServices>().userData;
    final fav = userData.isFavorite(_ImitacaoScreenState.favoriteKind, c.ref);
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.label),
        actions: [
          IconButton(
            tooltip: 'Ouvir capítulo (TTS)',
            icon: const Icon(Icons.headphones_outlined),
            onPressed: () => _listen(c),
          ),
          IconButton(
            tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(
              () => userData.toggleFavorite(_ImitacaoScreenState.favoriteKind, c.ref, label: '${c.label} — ${c.title}'),
            ),
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              final text =
                  '${c.title}\n\n${c.paragraphs.join('\n\n')}\n\n— Tomás de Kempis, A Imitação de Cristo (${c.label})';
              unawaited(SharePlus.instance.share(ShareParams(text: text)));
            },
          ),
          const ReadingAppearanceButton(),
        ],
      ),
      body: ListView(
        controller: PrimaryScrollController.of(context),
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
        children: [
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(c.label),
                const SizedBox(height: 6),
                Text(c.title, style: t.headlineSmall),
                const SizedBox(height: VsSpacing.md),
                for (var i = 0; i < c.paragraphs.length; i++) ...[
                  Text('${i + 1}. ${c.paragraphs[i]}', style: t.bodyLarge),
                  const SizedBox(height: VsSpacing.md),
                ],
              ],
            ),
          ),
          const SizedBox(height: VsSpacing.sm),
          Row(
            children: [
              if (_index > 0)
                OutlinedButton.icon(
                  onPressed: () => _goTo(_index - 1),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Anterior'),
                ),
              const Spacer(),
              if (_index < _chapters.length - 1)
                FilledButton.tonalIcon(
                  onPressed: () => _goTo(_index + 1),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Próximo'),
                ),
            ],
          ),
          const CrossDivider(),
          SourceAttribution(source: widget.work.source, license: widget.work.license),
        ],
      ),
      bottomNavigationBar: const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}
