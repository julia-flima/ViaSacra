import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/catechism.dart';
import '../../widgets/common.dart';

/// Aba 3 — Catecismo da Igreja Católica (busca instantânea offline, FTS5).
class CatechismScreen extends StatefulWidget {
  const CatechismScreen({super.key});

  @override
  State<CatechismScreen> createState() => _CatechismScreenState();
}

class _CatechismScreenState extends State<CatechismScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<CatechismParagraph>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      final repo = context.read<AppServices>().catechism;
      setState(() => _results = q.trim().isEmpty ? null : repo.search(q));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppServices>();
    final repo = s.catechism;
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final toc = repo.toc();
    final favorites = s.userData.favorites('catechism');

    return Scaffold(
      appBar: AppBar(title: const Text('Catecismo')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          SearchBar(
            controller: _query,
            hintText: 'Número (ex.: 1324) ou palavra (ex.: Graça)',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            side: WidgetStatePropertyAll(BorderSide(color: Theme.of(context).colorScheme.outline)),
            onChanged: _search,
            trailing: [
              if (_query.text.isNotEmpty)
                IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _query.clear();
                    _search('');
                  },
                ),
            ],
          ),
          const SizedBox(height: VsSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              for (final topic in ['Eucaristia', 'Maria', 'Graça', 'Oração', 'Perdão'])
                ActionChip(
                  label: Text(topic),
                  onPressed: () {
                    _query.text = topic;
                    _search(topic);
                  },
                ),
            ],
          ),
          if (!repo.hasText) ...[const SizedBox(height: VsSpacing.md), _LicenseNotice(count: repo.paragraphCount)],
          const SizedBox(height: VsSpacing.md),
          if (_results != null) ...[
            Eyebrow('${_results!.length} resultado${_results!.length == 1 ? '' : 's'}'),
            if (_results!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: VsSpacing.lg),
                child: Text('Nada encontrado no texto disponível offline.', style: t.bodyMedium),
              ),
            for (final p in _results!) _ParagraphTile(paragraph: p, onTap: () => _open(context, p.number)),
          ] else ...[
            if (favorites.isNotEmpty) ...[
              const Eyebrow('Favoritos'),
              for (final f in favorites)
                if (repo.byNumber(int.parse(f)) case final p?)
                  _ParagraphTile(paragraph: p, onTap: () => _open(context, p.number)),
              const CrossDivider(),
            ],
            const Eyebrow('Índice'),
            const SizedBox(height: VsSpacing.sm),
            for (final part in toc) _TocTile(node: part, onOpenRange: (n) => _openRange(context, n)),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, int number) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParagraphScreen(number: number)));

  void _openRange(BuildContext context, CatechismTocNode node) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _RangeScreen(node: node)));
}

class _LicenseNotice extends StatelessWidget {
  const _LicenseNotice({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Texto integral sob licença', style: t.titleMedium),
            const SizedBox(height: 6),
            Text(
              'O texto do Catecismo pertence à Libreria Editrice Vaticana. Esta versão traz o índice completo '
              'e $count parágrafo(s) de exemplo; o texto integral será incluído assim que houver autorização. '
              'Enquanto isso, você pode lê-lo no site oficial da Santa Sé.',
              style: t.bodySmall,
            ),
            TextButton.icon(
              onPressed: () => openExternal(context, ExternalLinks.catechismVatican),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir no vatican.va'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParagraphTile extends StatelessWidget {
  const _ParagraphTile({required this.paragraph, required this.onTap});

  final CatechismParagraph paragraph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final preview = paragraph.snippet ?? paragraph.text;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Text('§ ${paragraph.number}', style: t.titleMedium?.copyWith(color: cs.primary)),
      title: _Highlighted(
        text: preview,
        style: t.bodyMedium,
        highlight: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
      ),
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
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TocTile extends StatelessWidget {
  const _TocTile({required this.node, required this.onOpenRange});

  final CatechismTocNode node;
  final void Function(CatechismTocNode) onOpenRange;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = Text(node.title, style: node.level == 1 ? t.titleLarge : t.bodyMedium?.copyWith(height: 1.3));
    final subtitle = Text(node.range, style: t.bodySmall);
    if (node.children.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 12.0 * (node.level - 1)),
        title: title,
        subtitle: subtitle,
        onTap: () => onOpenRange(node),
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 12.0 * (node.level - 1), right: 4),
      shape: const Border(),
      title: title,
      subtitle: subtitle,
      children: [for (final c in node.children) _TocTile(node: c, onOpenRange: onOpenRange)],
    );
  }
}

class _RangeScreen extends StatelessWidget {
  const _RangeScreen({required this.node});
  final CatechismTocNode node;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppServices>().catechism;
    final items = repo.range(node.first, node.last);
    final pad = VsSpacing.page(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(node.range)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
        children: [
          Text(node.title, style: t.headlineSmall),
          const CrossDivider(),
          if (items.isEmpty)
            Text('Texto destes parágrafos ainda não disponível offline.', style: t.bodyMedium)
          else
            for (final p in items) ...[
              _ParagraphTile(
                paragraph: p,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParagraphScreen(number: p.number))),
              ),
            ],
          TextButton.icon(
            onPressed: () => openExternal(context, ExternalLinks.catechismVatican),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ler no site da Santa Sé'),
          ),
        ],
      ),
    );
  }
}

/// Parágrafo com favorito, anotação local e compartilhamento formatado.
class ParagraphScreen extends StatefulWidget {
  const ParagraphScreen({super.key, required this.number});
  final int number;

  @override
  State<ParagraphScreen> createState() => _ParagraphScreenState();
}

class _ParagraphScreenState extends State<ParagraphScreen> {
  late final _note = TextEditingController(
    text: context.read<AppServices>().userData.note('catechism', '${widget.number}') ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppServices>();
    final p = s.catechism.byNumber(widget.number);
    final ref = '${widget.number}';
    final fav = s.userData.isFavorite('catechism', ref);
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('CIC § ${widget.number}'),
        actions: [
          IconButton(
            tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() => s.userData.toggleFavorite('catechism', ref)),
          ),
          if (p != null)
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: '“${p.text}”\n\n— Catecismo da Igreja Católica, § ${p.number}\n(via app Via Sacra)'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.lg, pad, VsSpacing.xxl),
        children: [
          if (p?.heading != null) ...[Eyebrow(p!.heading!), const SizedBox(height: 8)],
          if (p == null)
            Text('O texto deste parágrafo ainda não está disponível offline.', style: t.bodyLarge)
          else
            SelectableText(p.text, style: t.bodyLarge),
          const SizedBox(height: VsSpacing.sm),
          const SourceAttribution(source: 'Catecismo da Igreja Católica — © Libreria Editrice Vaticana'),
          const CrossDivider(),
          const Eyebrow('Minha anotação (somente neste aparelho)'),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Escreva sua meditação…'),
            onChanged: (v) => s.userData.saveNote('catechism', ref, v),
          ),
        ],
      ),
    );
  }
}
