import '../../core/liturgical_calendar.dart';

/// Obra de arte sacra em domínio público (`assets/data/sacred_art.json`).
class SacredArt {
  const SacredArt({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.collection,
    this.assetPath,
    this.commonsFile,
    this.commonsPage,
    this.license = 'Domínio público',
    this.seasons = const [],
    this.feasts = const [],
  });

  final String id;
  final String title;
  final String artist;
  final String year;
  final String collection;
  final String? assetPath;
  final String? commonsFile;
  final String? commonsPage;
  final String license;

  /// Tempos litúrgicos (`LiturgicalSeason.name`) em que a obra entra no rodízio do header da Liturgia.
  final List<String> seasons;

  /// Trechos do nome de celebrações em que a obra tem prioridade (ex.: "pentecostes").
  final List<String> feasts;

  factory SacredArt.fromJson(Map<String, dynamic> j) => SacredArt(
    id: j['id'] as String,
    title: j['titulo'] as String,
    artist: j['artista'] as String,
    year: j['ano'] as String? ?? '',
    collection: j['acervo'] as String? ?? '',
    assetPath: j['imagem'] as String?,
    commonsFile: j['arquivo_commons'] as String?,
    commonsPage: j['pagina_commons'] as String?,
    license: j['licenca'] as String? ?? 'Domínio público',
    seasons: (j['tempos'] as List?)?.cast<String>() ?? const [],
    feasts: (j['festas'] as List?)?.cast<String>() ?? const [],
  );
}

class Mystery {
  const Mystery({
    required this.id,
    required this.set,
    required this.order,
    required this.title,
    required this.fruit,
    required this.reference,
    required this.reading,
    this.art,
  });

  final String id;
  final MysterySetId set;
  final int order; // 1..5
  final String title;
  final String fruit;
  final String reference;
  final String reading;
  final SacredArt? art;

  factory Mystery.fromJson(Map<String, dynamic> j, {SacredArt? art}) => Mystery(
    id: j['id'] as String,
    set: MysterySetId.fromName(j['conjunto'] as String),
    order: j['ordem'] as int,
    title: j['titulo'] as String,
    fruit: j['fruto'] as String,
    reference: j['referencia'] as String,
    reading: j['leitura'] as String,
    art: art,
  );
}
