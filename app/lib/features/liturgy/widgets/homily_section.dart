import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../data/models/liturgy.dart';
import '../../../widgets/common.dart';
import '../lectio_divina_screen.dart';

/// Seção abaixo do Evangelho com duas abas alternáveis:
/// "Homilia do Vaticano" e "Reflexão CNBB / Santos Padres".
class HomilySection extends StatefulWidget {
  const HomilySection({super.key, required this.liturgy, required this.onListen});

  final DailyLiturgy liturgy;
  final void Function(Homily h) onListen;

  @override
  State<HomilySection> createState() => _HomilySectionState();
}

class _HomilySectionState extends State<HomilySection> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.liturgy;
    final second = <Homily>[if (l.cnbbReflection != null) l.cnbbReflection!, ...l.patristic];
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Homilia do Vaticano'),
              Tab(text: 'CNBB / Santos Padres'),
            ],
          ),
          // A barrinha da aba desliza; o texto troca com esmaecimento e a altura se ajusta a partir
          // do topo, sem a página "pular" (issue #56). Sem animação se o sistema pedir.
          AnimatedSize(
            duration: duration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: Padding(
                key: ValueKey(_tabs.index),
                padding: const EdgeInsets.all(VsSpacing.lg),
                child: _tabs.index == 0
                    ? (l.vaticanHomily != null
                          ? _HomilyView(homily: l.vaticanHomily!, onListen: widget.onListen, date: l.date)
                          : const _Empty(
                              'A homilia ou reflexão do Santo Padre para esta data ainda não está disponível.',
                            ))
                    : (second.isEmpty
                          ? const _Empty('Nenhuma reflexão disponível para esta data.')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (i, h) in second.indexed) ...[
                                  if (i > 0) const CrossDivider(),
                                  _HomilyView(homily: h, onListen: widget.onListen, date: l.date),
                                ],
                              ],
                            )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prévia de [text] com até [max] caracteres, cortada no fim de uma palavra.
/// Retorna o texto inteiro se já couber.
String homilyPreview(String text, {int max = 700}) {
  if (text.length <= max) return text;
  var cut = text.lastIndexOf(RegExp(r'\s'), max);
  if (cut <= 0) cut = max; // palavra única gigantesca: corta onde der
  return '${text.substring(0, cut).trimRight().replaceFirst(RegExp(r'[,;:.!?—–-]+$'), '')}…';
}

class _HomilyView extends StatefulWidget {
  const _HomilyView({required this.homily, required this.onListen, required this.date});

  final Homily homily;
  final DateTime date;
  final void Function(Homily h) onListen;

  @override
  State<_HomilyView> createState() => _HomilyViewState();
}

class _HomilyViewState extends State<_HomilyView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = widget.homily;
    final onListen = widget.onListen;
    final preview = homilyPreview(h.text);
    final truncated = preview.length != h.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (h.author != null) Eyebrow(h.author!),
        const SizedBox(height: 4),
        Text(h.work ?? h.title, style: t.titleLarge),
        const SizedBox(height: 12),
        SelectionArea(child: Text(_expanded ? h.text : preview, style: t.bodyLarge)),
        if (truncated)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? 'Mostrar menos' : 'Ler completo'),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => LectioDivinaScreen(
                    title: h.work ?? h.title,
                    author: h.author,
                    text: h.text,
                    source: h.source,
                    url: h.url,
                    license: h.license,
                    noteRef: '${widget.date.toIso8601String().substring(0, 10)}|${h.work ?? h.title}',
                  ),
                ),
              ),
              icon: const Icon(Icons.fullscreen),
              label: const Text('Lectio Divina'),
            ),
            OutlinedButton.icon(
              onPressed: () => onListen(h),
              icon: const Icon(Icons.headphones_outlined),
              label: const Text('Ouvir reflexão'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SourceAttribution(source: h.source ?? 'Fonte não informada', url: h.url, license: h.license),
        if (h.note != null) Text(h.note!, style: t.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic));
}
