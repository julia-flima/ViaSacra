import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_navigation.dart';
import '../../app_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/bible/bible_reference.dart';
import '../../data/liturgy_repository.dart';
import '../../data/models/liturgy.dart';
import '../../data/user_data_repository.dart';
import '../../services/bible_service.dart';
import '../../services/reading_audio_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import 'widgets/audio_player_bar.dart';
import 'widgets/homily_section.dart';
import 'widgets/liturgy_header.dart';
import 'widgets/reading_card.dart';

/// Aba 1 — Liturgia & Homilias.
class LiturgyScreen extends StatelessWidget {
  const LiturgyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LiturgyController>();
    final settings = context.read<SettingsService>();
    final audio = context.read<ReadingAudioController>();
    final services = context.read<AppServices>();
    final l = c.liturgy;
    final pad = VsSpacing.page(context);
    final key = 'liturgia-${LiturgyRepository.isoDate(c.date)}';

    Future<void> playFrom(int index) async {
      if (!l.hasReadings) return;
      await audio.playQueue(
        key,
        buildLiturgyQueue(l, preferRecorded: settings.preferRecordedAudio),
        startAt: index,
        speed: settings.ttsSpeed,
      );
    }

    void listenHomily(Homily h) => audio.playSingle(
      ReadingSegment(
        id: '$key#${h.title.hashCode}',
        title: h.work ?? h.title,
        subtitle: h.author,
        text: '${h.work ?? h.title}. ${h.author != null ? '${h.author}. ' : ''}${h.text}',
      ),
      speed: settings.ttsSpeed,
    );

    void openInBible(Reading r) {
      final ref = BibleRef.parse(r.reference ?? '');
      if (ref == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível identificar esta referência.')));
        return;
      }
      context.read<BibleService>().requestOpen(ref);
      context.read<NavigationController>().go(AppTab.biblia);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liturgia Diária'),
        leading: IconButton(
          tooltip: 'Escolher data',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => _pickDate(context, c),
        ),
        actions: [
          if (!c.isToday) TextButton(onPressed: () => c.load(DateTime.now()), child: const Text('Hoje')),
          IconButton(
            tooltip: 'Baixar semana offline',
            onPressed: c.downloadProgress != null ? null : () => _downloadWeek(context, c, services),
            icon: c.downloadProgress != null
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, value: c.downloadProgress),
                  )
                : const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => c.load(c.date, force: true),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, 0),
              sliver: SliverList.list(
                children: [
                  LiturgyHeader(day: l.day),
                  const SizedBox(height: VsSpacing.lg),
                  AudioPlayerBar(onPlayAll: () => playFrom(0), recorded: l.audio.liturgyAudioUrl != null),
                  if (c.loading && !l.hasReadings)
                    const Padding(
                      padding: EdgeInsets.all(VsSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!l.hasReadings)
                    _OfflineNotice(error: c.error, onRetry: () => c.load(c.date, force: true)),
                  if (c.origin == LiturgyOrigin.cache && c.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: VsSpacing.sm),
                      child: Text(
                        'Exibindo a versão salva no aparelho (offline).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: VsSpacing.sm),
                ],
              ),
            ),
            if (l.hasReadings)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverList.list(
                  children: [
                    for (final (i, r) in l.readings.indexed) ...[
                      if (r.isPsalm)
                        PsalmCard(
                          psalm: r,
                          audio: l.audio,
                          sourceUrl: l.originalUrl,
                          onListenFromHere: () => playFrom(i),
                          onOpenInBible: () => openInBible(r),
                        )
                      else
                        ReadingCard(
                          reading: r,
                          sourceUrl: l.originalUrl,
                          onListenFromHere: () => playFrom(i),
                          onOpenInBible: () => openInBible(r),
                        ),
                    ],
                    const SizedBox(height: VsSpacing.md),
                    const Eyebrow('Homilias e reflexões'),
                    const SizedBox(height: VsSpacing.sm),
                    HomilySection(liturgy: l, onListen: listenHomily),
                    const SizedBox(height: VsSpacing.lg),
                    _MarkAsRead(date: c.date),
                    const CrossDivider(),
                    _Credits(liturgy: l),
                    const SizedBox(height: VsSpacing.xxl),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, LiturgyController c) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: c.date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Consultar liturgia',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) await c.load(picked);
  }

  Future<void> _downloadWeek(BuildContext context, LiturgyController c, AppServices s) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await c.downloadWeek();
    await s.notifications?.reschedule(s.settings, s.liturgyRepository); // Evangelho nos lembretes
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok == 7
              ? 'Semana salva: os próximos 7 dias estão disponíveis offline.'
              : ok == 0
              ? 'Sem conexão. Tente novamente mais tarde.'
              : '$ok de 7 dias salvos (alguns ainda não foram publicados).',
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.onRetry, this.error});

  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(VsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leituras indisponíveis offline', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(
              'As leituras deste dia ainda não foram baixadas. Conecte-se à internet e toque em tentar '
              'novamente, ou use "Baixar semana" para rezar sem conexão.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkAsRead extends StatefulWidget {
  const _MarkAsRead({required this.date});
  final DateTime date;

  @override
  State<_MarkAsRead> createState() => _MarkAsReadState();
}

class _MarkAsReadState extends State<_MarkAsRead> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    if (!settings.showStreak) return const SizedBox.shrink();
    final repo = context.read<AppServices>().userData;
    final now = DateTime.now();
    final today = widget.date.year == now.year && widget.date.month == now.month && widget.date.day == now.day;
    if (!today) return const SizedBox.shrink();
    final done = repo.prayedOn(widget.date, kind: PrayerKind.liturgia);
    return Center(
      child: done
          ? Text('✓ Liturgia de hoje registrada na sua constância', style: Theme.of(context).textTheme.bodySmall)
          : OutlinedButton.icon(
              onPressed: () {
                repo.logPrayer(PrayerKind.liturgia);
                setState(() {});
              },
              icon: const Icon(Icons.check),
              label: const Text('Rezei a liturgia de hoje'),
            ),
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits({required this.liturgy});
  final DailyLiturgy liturgy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.bodySmall;
    final sources = liturgy.sources.isEmpty
        ? const [
            SourceInfo(id: 'cnbb', name: 'CNBB — Conferência Nacional dos Bispos do Brasil', url: ExternalLinks.cnbb),
          ]
        : liturgy.sources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Fontes'),
        const SizedBox(height: 6),
        for (final s in sources) SourceAttribution(source: s.name, url: s.url, license: s.note),
        const SizedBox(height: 8),
        Text('Uso devocional e sem fins lucrativos. Os textos pertencem aos seus titulares.', style: t),
      ],
    );
  }
}
