import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/liturgical_calendar.dart';
import '../../core/theme.dart';
import '../../data/models/mystery.dart';
import '../../data/user_data_repository.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';
import '../../widgets/sacred_art_image.dart';
import 'rosary_session.dart';
import 'widgets/rosary_counter.dart';
import 'widgets/streak_calendar.dart';

/// Aba 2 — Santo Terço & Rosário (Jornada de Maria + Constância).
class RosaryScreen extends StatefulWidget {
  const RosaryScreen({super.key});

  @override
  State<RosaryScreen> createState() => _RosaryScreenState();
}

class _RosaryScreenState extends State<RosaryScreen> with WidgetsBindingObserver {
  RosarySession? _session;
  DateTime _today = DateUtils.dateOnly(DateTime.now());
  late MysterySetId _set = LiturgicalCalendar.mysteriesFor(_today);
  RosaryMode _mode = RosaryMode.terco;
  Timer? _midnight;

  AppServices get _s => context.read<AppServices>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncDay();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final next = DateUtils.addDaysToDate(_today, 1);
    _midnight = Timer(next.difference(DateTime.now()) + const Duration(seconds: 1), _syncDay);
  }

  /// Vira o dia se o app ficou aberto após a meia-noite: atualiza os mistérios
  /// sugeridos, a menos que o usuário tenha escolhido outro conjunto.
  void _syncDay() {
    final now = DateUtils.dateOnly(DateTime.now());
    if (!mounted || now == _today) return;
    final oldDefault = LiturgicalCalendar.mysteriesFor(_today);
    setState(() {
      if (_session == null && _set == oldDefault) _set = LiturgicalCalendar.mysteriesFor(now);
      _today = now;
    });
    _scheduleMidnight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) {
      final saved = _s.userData.rosaryProgress();
      if (saved != null) {
        _mode = RosaryMode.values.byName(saved.mode);
        if (saved.set != 'completo') _set = MysterySetId.fromName(saved.set);
        _start(restore: (decade: saved.decade, bead: saved.bead));
      }
    }
  }

  List<Mystery> _mysteries() => _mode == RosaryMode.rosario ? _s.content.fullRosary : _s.content.mysteriesOf(_set);

  void _start({({int decade, int bead})? restore}) {
    final session = RosarySession(mode: _mode, set: _mode == RosaryMode.terco ? _set : null, mysteries: _mysteries());
    if (restore != null) session.restoreTo(decade: restore.decade, bead: restore.bead);
    setState(() => _session = session);
  }

  Future<void> _advance() async {
    final session = _session!;
    final settings = context.read<SettingsService>();
    final ev = session.advance();
    if (settings.haptics) {
      switch (ev) {
        case BeadEvent.bead:
        case BeadEvent.stageChanged:
          unawaited(HapticFeedback.lightImpact());
        case BeadEvent.decadeCompleted:
          // Vibração dupla ao concluir a dezena
          unawaited(HapticFeedback.mediumImpact());
          unawaited(Future.delayed(const Duration(milliseconds: 140), HapticFeedback.mediumImpact));
        case BeadEvent.finished:
          unawaited(HapticFeedback.heavyImpact());
      }
    }
    _saveProgress(session);
    if (ev == BeadEvent.finished) {
      _s.userData.logPrayer(
        _mode == RosaryMode.rosario ? PrayerKind.rosario : PrayerKind.terco,
        mysterySet: _mode == RosaryMode.rosario ? 'completo' : _set.name,
        decades: session.totalDecades,
      );
      _s.userData.clearRosaryProgress();
    }
    setState(() {});
  }

  void _saveProgress(RosarySession session) {
    if (session.stage != RosaryStage.decades) return;
    _s.userData.saveRosaryProgress(
      mode: _mode.name,
      set: _mode == RosaryMode.rosario ? 'completo' : _set.name,
      decade: session.decade,
      bead: session.bead,
    );
  }

  void _back() {
    final session = _session!;
    session.back();
    if (session.stage == RosaryStage.intro) {
      _s.userData.clearRosaryProgress();
    } else {
      _saveProgress(session);
    }
    setState(() {});
  }

  /// Encerra a oração. Se houver progresso, pede confirmação antes de apagá-lo.
  Future<void> _close() async {
    final session = _session;
    final started = session != null && (session.stage != RosaryStage.intro || session.bead > 0);
    if (started && session.stage != RosaryStage.finished) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Encerrar a oração?'),
          content: const Text('O progresso desta oração será perdido.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar rezando')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encerrar')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _s.userData.clearRosaryProgress();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(session == null ? 'Santo Terço' : (_mode == RosaryMode.rosario ? 'Rosário' : _set.label)),
        leading: session == null
            ? null
            : IconButton(tooltip: 'Encerrar', icon: const Icon(Icons.close), onPressed: _close),
      ),
      body: session == null ? _buildChooser(context) : _buildPraying(context, session),
    );
  }

  // ---------------------------------------------------------------------------
  // Seleção de mistérios + constância
  // ---------------------------------------------------------------------------
  Widget _buildChooser(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final settings = context.watch<SettingsService>();
    final today = LiturgicalCalendar.mysteriesFor(_today);
    final first = _s.content.mysteriesOf(_set).firstOrNull;
    final streak = settings.showStreak ? _s.userData.streak() : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
      children: [
        if (streak != null)
          Align(
            alignment: Alignment.centerLeft,
            child: StreakBadge(days: streak.current),
          ),
        const SizedBox(height: VsSpacing.lg),
        Eyebrow('Hoje: ${today.label}'),
        const SizedBox(height: 8),
        Text('Jornada de Maria', style: t.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Contemple com Maria os mistérios da vida de Jesus. Os mistérios do dia já estão selecionados.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: VsSpacing.lg),
        SegmentedButton<RosaryMode>(
          segments: const [
            ButtonSegment(value: RosaryMode.terco, label: Text('Terço (5)'), icon: Icon(Icons.looks_5_outlined)),
            ButtonSegment(value: RosaryMode.rosario, label: Text('Rosário (20)'), icon: Icon(Icons.all_inclusive)),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        if (_mode == RosaryMode.terco) ...[
          const SizedBox(height: VsSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in MysterySetId.values)
                ChoiceChip(
                  label: Text(s.label.replaceFirst('Mistérios ', '') + (s == today ? ' · hoje' : '')),
                  selected: _set == s,
                  onSelected: (_) => setState(() => _set = s),
                ),
            ],
          ),
        ],
        const SizedBox(height: VsSpacing.lg),
        if (first != null) SacredArtImage(art: first.art, height: 300),
        const SizedBox(height: VsSpacing.md),
        for (final m in (_mode == RosaryMode.rosario ? _s.content.fullRosary : _s.content.mysteriesOf(_set)))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text('${m.order}', style: t.labelMedium?.copyWith(letterSpacing: 0)),
            ),
            title: Text(m.title, style: t.bodyMedium?.copyWith(height: 1.3)),
            subtitle: Text('Fruto: ${m.fruit}', style: t.bodySmall),
          ),
        const SizedBox(height: VsSpacing.lg),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(_mode == RosaryMode.rosario ? 'Rezar o Rosário' : 'Rezar o Terço'),
        ),
        if (streak != null) ...[
          const CrossDivider(),
          const Eyebrow('Constância'),
          const SizedBox(height: VsSpacing.sm),
          StreakCalendar(month: _today, prayedDays: streak.daysThisMonth),
          const SizedBox(height: VsSpacing.sm),
          Text(
            streak.best > 1
                ? 'Sua maior sequência: ${streak.best} dias. Cada dia é um recomeço — sem pressa e sem cobrança.'
                : 'Cada dia é um recomeço — sem pressa e sem cobrança.',
            style: t.bodySmall,
          ),
          Text('Registro salvo apenas neste aparelho. Pode ser ocultado em Ajustes.', style: t.bodySmall),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Oração em andamento
  // ---------------------------------------------------------------------------
  Widget _buildPraying(BuildContext context, RosarySession session) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final pad = VsSpacing.page(context);
    final prayers = _s.content.rosaryPrayers;
    final step = session.currentStep;
    final m = session.currentMystery;

    if (session.stage == RosaryStage.finished) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✝', style: TextStyle(fontSize: 40, color: cs.secondary)),
              const SizedBox(height: VsSpacing.md),
              Text(_mode == RosaryMode.rosario ? 'Rosário concluído' : 'Terço concluído', style: t.headlineSmall),
              const SizedBox(height: VsSpacing.sm),
              Text(prayers['oracao_final'] ?? '', style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: VsSpacing.lg),
              FilledButton(onPressed: _close, child: const Text('Amém')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        LinearProgressIndicator(value: session.progress, minHeight: 2, backgroundColor: cs.outline),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.lg),
            children: [
              if (session.stage == RosaryStage.decades) ...[
                Eyebrow(
                  '${m.order}º Mistério ${m.set.label.replaceFirst('Mistérios ', '')} · '
                  'dezena ${session.decade + 1} de ${session.totalDecades}',
                ),
                const SizedBox(height: 6),
                Text(m.title, style: t.headlineSmall),
                const SizedBox(height: VsSpacing.md),
                SacredArtImage(art: m.art, height: 220),
                const SizedBox(height: VsSpacing.md),
                Text('Fruto do mistério: ${m.fruit}', style: t.titleSmall),
                const SizedBox(height: 6),
                Text('«${m.reading}» (${m.reference})', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: VsSpacing.md),
                DecadeBeads(count: session.hailMarysInDecade, ourFather: session.bead == 0, glory: session.bead == 11),
              ] else ...[
                Eyebrow(session.stage == RosaryStage.intro ? 'Orações iniciais' : 'Encerramento'),
                const SizedBox(height: VsSpacing.md),
              ],
              Semantics(liveRegion: true, child: Text(step.label, style: t.titleLarge)),
              const SizedBox(height: VsSpacing.sm),
              Text(prayers[step.prayerKey] ?? '', style: t.bodyLarge),
            ],
          ),
        ),
        // Botão ergonômico inferior: rezar sem olhar para a tela.
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.md),
            child: Row(
              children: [
                IconButton.outlined(tooltip: 'Voltar uma conta', onPressed: _back, icon: const Icon(Icons.undo)),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Avançar: ${step.label}',
                    child: SizedBox(
                      height: 72,
                      child: FilledButton(
                        onPressed: _advance,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                        ),
                        child: Text(
                          session.stage == RosaryStage.decades && session.bead >= 1 && session.bead <= 10
                              ? 'Ave-Maria  ${session.bead}/10'
                              : 'Amém · continuar',
                          style: t.titleMedium?.copyWith(color: cs.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
