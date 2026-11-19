/// Oração do Devocionário (`assets/data/prayers.json`).
class Prayer {
  const Prayer({
    required this.id,
    required this.category,
    required this.title,
    required this.textPt,
    this.titleLa,
    this.textLa,
    this.note,
    this.source,
  });

  final String id;
  final String category;
  final String title;
  final String textPt;
  final String? titleLa;
  final String? textLa;
  final String? note;
  final String? source;

  bool get hasLatin => textLa != null && textLa!.isNotEmpty;

  factory Prayer.fromJson(Map<String, dynamic> j) => Prayer(
    id: j['id'] as String,
    category: j['categoria'] as String,
    title: j['titulo'] as String,
    textPt: j['texto_pt'] as String,
    titleLa: j['titulo_la'] as String?,
    textLa: j['texto_la'] as String?,
    note: j['nota'] as String?,
    source: j['fonte'] as String?,
  );
}

class PrayerCategory {
  const PrayerCategory({required this.id, required this.title, required this.description});
  final String id;
  final String title;
  final String description;

  factory PrayerCategory.fromJson(Map<String, dynamic> j) =>
      PrayerCategory(id: j['id'] as String, title: j['titulo'] as String, description: j['descricao'] as String? ?? '');
}
