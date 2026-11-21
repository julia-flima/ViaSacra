import '../core/liturgical_calendar.dart';
import 'models/mystery.dart';

/// Arte do header da Liturgia para [day]: uma obra da festa do dia, se houver; senão, uma do
/// tempo litúrgico. A escolha muda a cada dia e é a mesma em todos os aparelhos (sem sorteio).
SacredArt? artForDay(Iterable<SacredArt> catalog, LiturgicalDay day) {
  final withImage = catalog.where((a) => a.assetPath != null).toList();
  final celebration = _fold(day.celebration);
  final feast = withImage.where((a) => a.feasts.any((f) => celebration.contains(_fold(f)))).toList();
  final pool = feast.isNotEmpty ? feast : withImage.where((a) => a.seasons.contains(day.season.name)).toList();
  if (pool.isEmpty) return null;
  final dayNumber =
      DateTime.utc(day.date.year, day.date.month, day.date.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return pool[dayNumber % pool.length];
}

String _fold(String s) {
  const from = 'áàâãäéêèëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    buf.write(i < 0 ? ch : to[i]);
  }
  return buf.toString();
}
