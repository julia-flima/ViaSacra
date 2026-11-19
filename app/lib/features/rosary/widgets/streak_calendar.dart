import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

/// Pequeno calendário mensal de constância (salvo só no aparelho).
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({super.key, required this.month, required this.prayedDays});

  final DateTime month;
  final Set<int> prayedDays;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7; // domingo primeiro
    final today = DateTime.now();
    const weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    return Semantics(
      label:
          'Calendário de constância: ${prayedDays.length} dias de oração em '
          '${DateFormat.MMMM('pt_BR').format(month)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(toBeginningOfSentenceCase(DateFormat.yMMMM('pt_BR').format(month)), style: t.titleSmall),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final w in weekdays) Center(child: Text(w, style: t.labelSmall)),
                for (var i = 0; i < offset; i++) const SizedBox.shrink(),
                for (var d = 1; d <= daysInMonth; d++)
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: prayedDays.contains(d) ? cs.primary.withValues(alpha: 0.85) : null,
                      border: (today.year == month.year && today.month == month.month && today.day == d)
                          ? Border.all(color: cs.secondary, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      '$d',
                      style: t.labelSmall?.copyWith(
                        color: prayedDays.contains(d) ? cs.onPrimary : t.labelSmall?.color,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
