import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/liturgical_calendar.dart';
import '../../../widgets/common.dart';

/// Cabeçalho: data, Tempo Litúrgico, cor do dia e celebração.
class LiturgyHeader extends StatelessWidget {
  const LiturgyHeader({super.key, required this.day});

  final LiturgicalDay day;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(day.date);
    final cycle = day.rank == 'domingo' || day.rank == 'solenidade'
        ? 'Ano ${day.sundayCycle}'
        : 'Ano ${day.sundayCycle} · Ano ${day.weekdayCycle}';
    return Semantics(
      header: true,
      label: '$date. ${day.celebration}. ${day.season.label}. Cor litúrgica: ${day.color.label}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(date[0].toUpperCase() + date.substring(1), color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(day.celebration, style: t.headlineMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Pill(
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: day.color.swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.outline),
                    ),
                  ),
                  label: day.color.label,
                ),
                _Pill(label: day.season.label),
                _Pill(label: cycle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 0.3)),
        ],
      ),
    );
  }
}
