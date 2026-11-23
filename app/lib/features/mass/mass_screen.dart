import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/models/liturgy.dart';
import '../../data/models/mass.dart';
import '../../widgets/common.dart';
import '../../widgets/reading_appearance_button.dart';

/// Acompanhar a Missa: as respostas do povo, parte por parte, com a deixa do padre.
/// Funciona offline e mantém a tela acesa enquanto aberta.
class MassScreen extends StatefulWidget {
  const MassScreen({super.key});

  @override
  State<MassScreen> createState() => _MassScreenState();
}

class _MassScreenState extends State<MassScreen> {
  late final Future<OrdinaryOfMass> _mass = context.read<AppServices>().content.mass();
  final _partKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  void _jumpTo(String partId) {
    final ctx = _partKeys[partId]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LiturgyController>();
    final today = DateUtils.isSameDay(c.date, DateTime.now()) ? c.liturgy : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhar a Missa'), actions: const [ReadingAppearanceButton()]),
      body: FutureBuilder<OrdinaryOfMass>(
        future: _mass,
        builder: (context, snap) {
          final mass = snap.data;
          if (mass == null) {
            return snap.hasError
                ? const Center(child: Text('Não foi possível abrir o Ordinário da Missa.'))
                : const Center(child: CircularProgressIndicator());
          }
          final pad = VsSpacing.page(context);
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: VsSpacing.sm),
                child: Row(
                  children: [
                    for (final p in mass.parts)
                      Padding(
                        padding: const EdgeInsets.only(right: VsSpacing.sm),
                        child: ActionChip(label: Text(p.title), onPressed: () => _jumpTo(p.id)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Em destaque, o que o povo responde. Acima, em cinza, a fala do padre que vem antes.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final p in mass.parts) ...[
                        Padding(
                          key: _partKeys.putIfAbsent(p.id, GlobalKey.new),
                          padding: const EdgeInsets.only(top: VsSpacing.lg, bottom: VsSpacing.sm),
                          child: Text(p.title, style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        for (final s in p.steps) _Step(step: s, today: today),
                      ],
                      const CrossDivider(),
                      SourceAttribution(source: mass.source, url: mass.url, license: mass.license),
                      if (today != null && today.hasReadings)
                        const SourceAttribution(source: 'CNBB — Liturgia Diária (refrão e aclamação do dia)'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.today});

  final MassStep step;
  final DailyLiturgy? today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Merriweather não tem negrito reto: o destaque vem da cor e do tamanho.
    final people = t.bodyLarge?.copyWith(color: cs.primary, fontSize: (t.bodyLarge?.fontSize ?? 16) + 2, height: 1.5);
    final prayer = step.prayerId == null ? null : context.read<AppServices>().content.prayer(step.prayerId!);
    final daily = switch (step.daily) {
      DailyText.refrain => today?.reading(ReadingKind.salmo)?.refrain,
      DailyText.acclamation => today?.gospel?.acclamation,
      null => null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: VsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.title != null) Eyebrow(step.title!),
          if (step.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(step.note!, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ),
          if (step.cue != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(step.cue!, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          if (step.people != null) Text(step.people!, style: people),
          if (prayer != null) Text(prayer.textPt, style: people),
          if (step.daily != null)
            Text(
              daily ?? 'Muda a cada dia. Abra a Liturgia de hoje com internet para vê-lo aqui.',
              style: daily == null ? t.bodyMedium : people,
            ),
          for (final (i, o) in step.options.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(step.options.length > 1 ? '${i + 1}. $o' : o, style: people),
            ),
          if (step.toCheck)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Conferir com o Missal', style: t.labelSmall?.copyWith(color: cs.error)),
            ),
          if (step.variants.isNotEmpty) _Variants(variants: step.variants, today: today),
        ],
      ),
    );
  }
}

/// Escolha da Oração Eucarística (I–IV) e as aclamações dela.
class _Variants extends StatefulWidget {
  const _Variants({required this.variants, required this.today});

  final List<MassVariant> variants;
  final DailyLiturgy? today;

  @override
  State<_Variants> createState() => _VariantsState();
}

class _VariantsState extends State<_Variants> {
  late MassVariant _selected = widget.variants.firstWhere((v) => v.isDefault, orElse: () => widget.variants.first);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: VsSpacing.sm),
        SegmentedButton<MassVariant>(
          segments: [for (final v in widget.variants) ButtonSegment(value: v, label: Text(v.title))],
          selected: {_selected},
          onSelectionChanged: (s) => setState(() => _selected = s.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: VsSpacing.md),
        for (final s in _selected.steps) _Step(step: s, today: widget.today),
      ],
    );
  }
}
