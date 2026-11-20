import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/models/prayer.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import '../../widgets/global_audio_mini_player.dart';
import 'imitacao_screen.dart';
import 'via_sacra_screen.dart';

/// Aba 4 — Devocionário & Orações (100% offline).
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key, this.embedded = false});

  /// Dentro da aba Biblioteca (sem AppBar própria).
  final bool embedded;

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppServices>();
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final favorites = s.userData.favorites('prayer').map(s.content.prayer).whereType<Prayer>().toList();

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Devocionário')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: VsSpacing.sm),
              leading: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
              title: Text('Via Sacra (14 Estações)', style: t.titleMedium),
              subtitle: const Text('Meditações de Santo Afonso de Ligório · guiada e com áudio'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ViaSacraScreen())),
            ),
          ),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: VsSpacing.md, vertical: VsSpacing.sm),
              leading: Icon(Icons.auto_stories_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text('A Imitação de Cristo', style: t.titleMedium),
              subtitle: const Text('Tomás de Kempis · 4 Livros, 114 capítulos offline'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ImitacaoScreen())),
            ),
          ),
          const SizedBox(height: VsSpacing.sm),
          if (favorites.isNotEmpty) ...[
            const Eyebrow('Favoritas'),
            for (final p in favorites) _PrayerTile(prayer: p, onReturn: () => setState(() {})),
            const CrossDivider(),
          ],
          for (final c in s.content.categories) ...[
            Padding(
              padding: const EdgeInsets.only(top: VsSpacing.md),
              child: Text(c.title, style: t.titleLarge),
            ),
            if (c.description.isNotEmpty) Text(c.description, style: t.bodySmall),
            const SizedBox(height: 4),
            for (final p in s.content.prayersIn(c.id)) _PrayerTile(prayer: p, onReturn: () => setState(() {})),
          ],
        ],
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.prayer, required this.onReturn});
  final Prayer prayer;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(prayer.title, style: t.bodyLarge?.copyWith(height: 1.3)),
      subtitle: prayer.titleLa != null
          ? Text(prayer.titleLa!, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic))
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrayerScreen(prayer: prayer)));
        onReturn();
      },
    );
  }
}

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key, required this.prayer});
  final Prayer prayer;

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  late bool _latin = widget.prayer.hasLatin && context.read<SettingsService>().preferLatin;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppServices>();
    final p = widget.prayer;
    final fav = s.userData.isFavorite('prayer', p.id);
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final title = _latin ? (p.titleLa ?? p.title) : p.title;
    final text = _latin ? p.textLa! : p.textPt;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => setState(() => s.userData.toggleFavorite('prayer', p.id, label: p.title)),
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => SharePlus.instance.share(ShareParams(text: '$title\n\n$text\n\n(via app Via Sacra)')),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
        children: [
          Text(title, style: t.headlineMedium),
          if (p.hasLatin) ...[
            const SizedBox(height: VsSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Português')),
                  ButtonSegment(value: true, label: Text('Latim')),
                ],
                selected: {_latin},
                onSelectionChanged: (v) => setState(() => _latin = v.first),
              ),
            ),
          ],
          const CrossDivider(),
          SelectionArea(child: Text(text, style: t.bodyLarge)),
          if (p.note != null) ...[
            const SizedBox(height: VsSpacing.lg),
            Text(p.note!, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (p.source != null) SourceAttribution(source: p.source!),
        ],
      ),
      bottomNavigationBar: const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}
