import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/catechism.dart';
import '../../services/catechism_import_service.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import '../../widgets/global_audio_mini_player.dart';
import 'vatican_reader_screen.dart';

enum _CatechismView { offline, officialCic }

/// Sub-aba Catecismo (dentro da aba Biblioteca):
/// 1. Estudo Offline 100% FOSS: Catecismo Maior de São Pio X (1905), Catecismo
///    Romano (1566) e obras importadas localmente (.json), com FTS5 e TTS.
/// 2. CIC (1992) — Portal Oficial: índice das 4 Partes com atalho direto para
///    o portal oficial em português do Vaticano (vatican.va).
class CatechismScreen extends StatefulWidget {
  const CatechismScreen({super.key, this.embedded = false});

  /// Dentro da aba Biblioteca (sem AppBar própria).
  final bool embedded;

  @override
  State<CatechismScreen> createState() => _CatechismScreenState();
}

class _CatechismScreenState extends State<CatechismScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  _CatechismView _view = _CatechismView.offline;
  bool _initialized = false;
  String? _selectedWorkId;
  List<CatechismWork> _works = const [];
  List<CatechismTocNode> _toc = const [];
  List<({String part, int count})> _parts = const [];
  List<CatechismEntry> _favorites = const [];
  final Map<String, List<CatechismEntry>> _loadedParts = {};
  final Set<String> _expandedParts = {};
  List<CatechismEntry>? _results;
  double? _importProgress;
  String? _importLabel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _reloadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  CatechismWork? _resolveActiveWork(List<CatechismWork> works) {
    if (works.isEmpty) return null;
    if (_selectedWorkId != null) {
      final match = works.where((w) => w.id == _selectedWorkId).firstOrNull;
      if (match != null) return match;
    }
    return works.first;
  }

  void _reloadAll() {
    final s = context.read<AppServices>();
    _works = s.catechism.works();
    _toc = s.catechism.toc();
    final active = _resolveActiveWork(_works);
    _selectedWorkId = active?.id;
    _loadWorkData(active?.id);
  }

  void _loadWorkData(String? workId) {
    final s = context.read<AppServices>();
    _loadedParts.clear();
    _expandedParts.clear();
    if (workId == null) {
      _parts = const [];
      _favorites = const [];
      return;
    }
    _parts = s.catechism.partSummaries(workId);
    _loadFavorites(workId);
  }

  void _loadFavorites(String workId) {
    final s = context.read<AppServices>();
    final favRefs = s.userData.favorites('catechism').where((r) => r.startsWith('$workId:'));
    _favorites = [
      for (final ref in favRefs)
        if (int.tryParse(ref.split(':').last) case final n?) ?s.catechism.entryByNumber(workId, n),
    ];
  }

  void _selectWork(String workId) {
    final repo = context.read<AppServices>().catechism;
    setState(() {
      _selectedWorkId = workId;
      _loadWorkData(workId);
      _results = _query.text.trim().isEmpty ? null : repo.searchEntries(workId, _query.text);
    });
  }

  void _togglePart(String workId, String part) {
    final repo = context.read<AppServices>().catechism;
    setState(() {
      if (!_expandedParts.add(part)) {
        _expandedParts.remove(part);
      } else {
        _loadedParts.putIfAbsent(part, () => repo.entriesByPart(workId, part));
      }
    });
  }

  void _search(String q, String? workId) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final repo = context.read<AppServices>().catechism;
      setState(() => _results = (q.trim().isEmpty || workId == null) ? null : repo.searchEntries(workId, q));
    });
  }

  Future<void> _importJson() async {
    final repo = context.read<AppServices>().catechism;
    final importer = CatechismImportService(repo);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await importer.importFromFile(
        onProgress: (p, label) {
          if (mounted) {
            setState(() {
              _importProgress = p;
              _importLabel = label;
            });
          }
        },
      );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _selectedWorkId = result.id;
          _view = _CatechismView.offline;
          _query.clear();
          _results = null;
          _reloadAll();
        });
        messenger.showSnackBar(SnackBar(content: Text('“${result.name}” importado (${result.entryCount} entradas).')));
      }
    } on CatechismModuleException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Arquivo fora do padrão'),
          content: Text(
            'Não foi possível validar o arquivo JSON do catecismo:\n\n${e.message}\n\n'
            'Consulte o formato padrão documentado no README do Via Sacra.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
        ),
      );
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Não foi possível importar: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _importProgress = null;
          _importLabel = null;
        });
      }
    }
  }

  Future<void> _deleteWork(CatechismWork work) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir “${work.name}”?'),
        content: Text('As ${work.entryCount} entradas serão removidas deste aparelho para liberar espaço.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if ((ok ?? false) && mounted) {
      await CatechismImportService(context.read<AppServices>().catechism).deleteWork(work.id);
      if (mounted) {
        setState(() {
          _selectedWorkId = null;
          _results = null;
          _reloadAll();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('“${work.name}” removido.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWork = _resolveActiveWork(_works);
    final pad = VsSpacing.page(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Catecismo')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_CatechismView>(
                    segments: const [
                      ButtonSegment(
                        value: _CatechismView.offline,
                        label: Text('Estudo Offline'),
                        icon: Icon(Icons.menu_book),
                      ),
                      ButtonSegment(
                        value: _CatechismView.officialCic,
                        label: Text('CIC (1992) Oficial'),
                        icon: Icon(Icons.public),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (v) => setState(() => _view = v.first),
                  ),
                  if (_importProgress != null) ...[
                    const SizedBox(height: VsSpacing.sm),
                    Text(_importLabel ?? 'Importando…', style: t.bodySmall),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: _importProgress),
                  ],
                ],
              ),
            ),
          ),
          if (_view == _CatechismView.offline)
            ..._buildOfflineSlivers(context, pad, activeWork)
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, VsSpacing.xxl),
              sliver: SliverList.list(children: _buildOfficialCic(context)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildOfflineSlivers(BuildContext context, double pad, CatechismWork? activeWork) {
    final t = Theme.of(context).textTheme;
    final workId = activeWork?.id;

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in _works)
                    ChoiceChip(
                      label: Text(w.shortName),
                      selected: w.id == workId,
                      onSelected: (_) => _selectWork(w.id),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text('Importar (.json)'),
                    onPressed: _importProgress != null ? null : _importJson,
                  ),
                ],
              ),
              if (activeWork != null) ...[
                const SizedBox(height: VsSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${activeWork.name} · ${activeWork.license} (${activeWork.entryCount} entradas)',
                        style: t.bodySmall,
                      ),
                    ),
                    if (!activeWork.bundled)
                      IconButton(
                        tooltip: 'Excluir catecismo importado',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteWork(activeWork),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: VsSpacing.sm),
              SearchBar(
                controller: _query,
                hintText: activeWork == null
                    ? 'Buscar no Catecismo'
                    : 'Número (ex.: 1 ou §1324) ou palavra em ${activeWork.shortName}',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                side: WidgetStatePropertyAll(BorderSide(color: Theme.of(context).colorScheme.outline)),
                onChanged: (q) => _search(q, workId),
                trailing: [
                  if (_query.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _query.clear();
                        _search('', workId);
                      },
                    ),
                ],
              ),
              const SizedBox(height: VsSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  for (final topic in ['Eucaristia', 'Maria', 'Graça', 'Oração', 'Mandamentos'])
                    ActionChip(
                      label: Text(topic),
                      onPressed: () {
                        _query.text = topic;
                        _search(topic, workId);
                      },
                    ),
                ],
              ),
              const SizedBox(height: VsSpacing.md),
              if (activeWork == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: VsSpacing.xxl),
                  child: Text(
                    'Nenhum catecismo offline instalado. Toque em "Importar (.json)" para adicionar um.',
                    style: t.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (activeWork != null && _results != null) ...[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('${_results!.length} resultado${_results!.length == 1 ? '' : 's'} em ${activeWork.shortName}'),
                if (_results!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: VsSpacing.lg),
                    child: Text('Nada encontrado em ${activeWork.name}.', style: t.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, VsSpacing.xxl),
          sliver: SliverList.builder(
            itemCount: _results!.length,
            itemBuilder: (context, index) {
              final entry = _results![index];
              return _EntryTile(
                entry: entry,
                label: activeWork.entryLabel,
                onTap: () => _openEntry(context, activeWork, entry),
              );
            },
          ),
        ),
      ] else if (activeWork != null) ...[
        if (_favorites.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverList.list(
              children: [
                const Eyebrow('Favoritos'),
                for (final entry in _favorites)
                  _EntryTile(
                    entry: entry,
                    label: activeWork.entryLabel,
                    onTap: () => _openEntry(context, activeWork, entry),
                  ),
                const CrossDivider(),
              ],
            ),
          ),
        ],
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Partes — ${activeWork.shortName}'),
                const SizedBox(height: VsSpacing.sm),
              ],
            ),
          ),
        ),
        for (final summary in _parts) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverToBoxAdapter(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(summary.part, style: t.titleMedium),
                subtitle: Text('${summary.count} entrada(s)', style: t.bodySmall),
                trailing: Icon(_expandedParts.contains(summary.part) ? Icons.expand_less : Icons.expand_more),
                onTap: () => _togglePart(activeWork.id, summary.part),
              ),
            ),
          ),
          if (_expandedParts.contains(summary.part))
            Builder(
              builder: (_) {
                final entries = _loadedParts[summary.part] ?? const <CatechismEntry>[];
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverList.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) => _EntryTile(
                      entry: entries[index],
                      label: activeWork.entryLabel,
                      onTap: () => _openEntry(context, activeWork, entries[index]),
                    ),
                  ),
                );
              },
            ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, VsSpacing.xxl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CrossDivider(),
                SourceAttribution(source: activeWork.source ?? activeWork.name, license: activeWork.license),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildOfficialCic(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(VsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CIC (1992) — Portal Oficial da Santa Sé', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(
                'O texto integral do Catecismo da Igreja Católica (1992) pertence à Libreria Editrice Vaticana '
                'e não é hospedado no repositório para manter o Via Sacra 100% Open Source e compatível com o '
                'F-Droid. Toque em qualquer parte abaixo para ler diretamente no vatican.va, ou importe seu '
                'arquivo .json local para busca offline (§1324) e leitura em voz alta (TTS).',
                style: t.bodySmall,
              ),
              const SizedBox(height: VsSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => openVaticanDocument(
                      context,
                      title: 'CIC (1992) — Índice Oficial',
                      url: ExternalLinks.catechismVatican,
                    ),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Ler CIC (1992)'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => openVaticanDocument(
                      context,
                      title: 'Compêndio do CIC (2005)',
                      url: ExternalLinks.compendiumCcc,
                    ),
                    icon: const Icon(Icons.question_answer_outlined, size: 18),
                    label: const Text('Compêndio (2005)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importProgress != null ? null : _importJson,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text('Importar JSON local'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: VsSpacing.md),
      const Eyebrow('Índice das 4 Partes do CIC (1992)'),
      const SizedBox(height: VsSpacing.sm),
      for (final part in _toc)
        _OfficialTocTile(
          node: part,
          onOpen: (n) => openVaticanDocument(context, title: n.title, url: ExternalLinks.catechismPartUrl(n.id)),
        ),
    ];
  }

  Future<void> _openEntry(BuildContext context, CatechismWork work, CatechismEntry entry) async {
    final route = MaterialPageRoute<void>(
      builder: (_) => CatechismEntryScreen(work: work, entry: entry),
    );
    await Navigator.of(context).push(route);
    if (mounted) {
      setState(() {
        if (work.id == _selectedWorkId) _loadFavorites(work.id);
      });
    }
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.label, required this.onTap});

  final CatechismEntry entry;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final preview = entry.snippet ?? entry.answer;
    final hl = TextStyle(color: cs.primary, fontWeight: FontWeight.w700);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Text('$label ${entry.number}', style: t.titleSmall?.copyWith(color: cs.primary)),
      title: entry.question != null
          ? Text(entry.question!, style: t.titleSmall)
          : _Highlighted(text: preview, style: t.bodyMedium, highlight: hl),
      subtitle: entry.question != null ? _Highlighted(text: preview, style: t.bodySmall, highlight: hl) : null,
    );
  }
}

/// Renderiza trechos «destacados» retornados pelo snippet() do FTS5.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, this.style, required this.highlight});
  final String text;
  final TextStyle? style;
  final TextStyle highlight;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp('«(.*?)»');
    var last = 0;
    for (final m in re.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(1), style: highlight));
      last = m.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _OfficialTocTile extends StatelessWidget {
  const _OfficialTocTile({required this.node, required this.onOpen});

  final CatechismTocNode node;
  final void Function(CatechismTocNode) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(node.title, style: t.titleMedium),
      subtitle: Text('${node.range} · Abrir no vatican.va', style: t.bodySmall),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => onOpen(node),
    );
  }
}

/// Leitor de pergunta/parágrafo com áudio (TTS offline), favorito, anotação local e compartilhamento.
class CatechismEntryScreen extends StatefulWidget {
  const CatechismEntryScreen({super.key, required this.work, required this.entry});

  final CatechismWork work;
  final CatechismEntry entry;

  @override
  State<CatechismEntryScreen> createState() => _CatechismEntryScreenState();
}

class _CatechismEntryScreenState extends State<CatechismEntryScreen> {
  late final _note = TextEditingController(
    text: context.read<AppServices>().userData.note('catechism', widget.entry.favRef) ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _listen() {
    final e = widget.entry;
    final settings = context.read<SettingsService>();
    final speech = e.question != null ? '${e.question} ${e.answer}' : e.answer;
    context.read<ReadingAudioController>().playSingle(
      ReadingSegment(
        id: 'cat-${e.catechismId}-${e.number}',
        title: '${widget.work.shortName} · ${widget.work.entryLabel} ${e.number}',
        subtitle: e.chapter ?? e.part,
        text: speech,
        language: widget.work.language,
      ),
      speed: settings.ttsSpeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppServices>();
    final e = widget.entry;
    final fav = s.userData.isFavorite('catechism', e.favRef);
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.work.shortName} · ${widget.work.entryLabel} ${e.number}'),
        actions: [
          IconButton(tooltip: 'Ouvir (TTS)', icon: const Icon(Icons.headphones_outlined), onPressed: _listen),
          IconButton(
            tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() => s.userData.toggleFavorite('catechism', e.favRef)),
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              final q = e.question != null ? '${e.question}\n\n' : '';
              final ref = '${widget.work.name}, ${widget.work.entryLabel} ${e.number}';
              final body = '$q“${e.answer}”\n\n— $ref\n(via app Via Sacra)';
              unawaited(SharePlus.instance.share(ShareParams(text: body)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.lg, pad, VsSpacing.xxl),
        children: [
          Eyebrow(e.part),
          if (e.chapter != null) ...[const SizedBox(height: 4), Text(e.chapter!, style: t.bodySmall)],
          const SizedBox(height: VsSpacing.md),
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.question != null) ...[
                  Text(e.question!, style: t.titleLarge),
                  const SizedBox(height: VsSpacing.sm),
                ],
                Text(e.answer, style: t.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: VsSpacing.md),
          SourceAttribution(source: widget.work.source ?? widget.work.name, license: widget.work.license),
          const CrossDivider(),
          const Eyebrow('Minha anotação (somente neste aparelho)'),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Escreva sua meditação…'),
            onChanged: (v) => s.userData.saveNote('catechism', e.favRef, v),
          ),
        ],
      ),
      bottomNavigationBar: const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}

/// Parágrafo legado do CIC (mantido para compatibilidade).
class ParagraphScreen extends StatelessWidget {
  const ParagraphScreen({super.key, required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppServices>();
    final p = s.catechism.byNumber(number);
    final pad = VsSpacing.page(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('CIC § $number')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.lg, pad, VsSpacing.xxl),
        children: [
          if (p == null)
            Text('O texto deste parágrafo ainda não está disponível offline.', style: t.bodyLarge)
          else
            SelectionArea(child: Text(p.text, style: t.bodyLarge)),
        ],
      ),
      bottomNavigationBar: const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}
