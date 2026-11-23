import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/liturgical_art.dart';
import '../../data/models/liturgy.dart';
import '../../widgets/common.dart';
import '../../widgets/reading_appearance_button.dart';
import '../../widgets/sacred_art_header.dart';

/// Santo(s) do dia: o resumo do Vatican News, a arte sacra do dia e o link para a história completa.
class SaintScreen extends StatelessWidget {
  const SaintScreen({super.key, required this.liturgy});

  final DailyLiturgy liturgy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final content = context.read<AppServices>().content;
    return Scaffold(
      appBar: AppBar(title: const Text('Santo do dia'), actions: const [ReadingAppearanceButton()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          SacredArtBanner(
            title: 'Santo do dia',
            subtitle: liturgy.day.celebration,
            art: artForDay(content.art.values, liturgy.day) ?? content.art['header-tempo-comum'],
          ),
          for (final (i, s) in liturgy.saints.indexed) ...[
            if (i > 0) const CrossDivider(),
            const SizedBox(height: VsSpacing.lg),
            Text(s.name, style: t.headlineSmall),
            const SizedBox(height: VsSpacing.md),
            SelectionArea(child: Text(s.summary, style: t.bodyLarge)),
            if (s.url != null) ...[
              const SizedBox(height: VsSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => openExternal(context, s.url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ler a história completa'),
                ),
              ),
            ],
            const SizedBox(height: VsSpacing.sm),
            SourceAttribution(source: s.source ?? 'Vatican News', url: s.url, license: s.license),
          ],
        ],
      ),
    );
  }
}

/// Cartão curto na aba Liturgia: nome e começo do resumo; toque abre a [SaintScreen].
class SaintCard extends StatelessWidget {
  const SaintCard({super.key, required this.liturgy});

  final DailyLiturgy liturgy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = liturgy.saints.first;
    final more = liturgy.saints.length - 1;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaintScreen(liturgy: liturgy))),
        child: Padding(
          padding: const EdgeInsets.all(VsSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: t.titleMedium),
                    const SizedBox(height: 6),
                    Text(s.summary, style: t.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (more > 0) ...[
                      const SizedBox(height: 6),
                      Text('e mais $more ${more == 1 ? 'santo' : 'santos'} hoje', style: t.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: VsSpacing.sm),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
