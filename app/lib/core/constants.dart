/// Constantes globais do Via Sacra.
library;

class AppInfo {
  static const name = 'Via Sacra';
  static const author = 'Júlia Lima';
  static const version = '1.7.1';
  static const license = 'GPL-3.0';
  static const repositoryUrl = 'https://github.com/julia-flima/ViaSacra';
  static const issuesUrl = 'https://github.com/julia-flima/ViaSacra/issues';
  static const releasesUrl = 'https://github.com/julia-flima/ViaSacra/releases';
}

/// Endpoints de dados estáticos (JSON gerado pelo GitHub Actions).
///
/// Pode ser sobrescrito em tempo de build para forks:
/// `flutter run --dart-define=VIA_SACRA_DATA_URL=https://...`
class DataEndpoints {
  static const _override = String.fromEnvironment('VIA_SACRA_DATA_URL');

  static List<String> get bases => [
    if (_override.isNotEmpty) _override,
    'https://cdn.jsdelivr.net/gh/julia-flima/ViaSacra@data',
    'https://raw.githubusercontent.com/julia-flima/ViaSacra/data',
  ];

  static List<Uri> liturgy(String isoDate) => bases.map((b) => Uri.parse('$b/liturgia/$isoDate.json')).toList();

  static List<Uri> index() => bases.map((b) => Uri.parse('$b/liturgia/index.json')).toList();
}

class ExternalLinks {
  static const cnbb = 'https://liturgiadiaria.edicoescnbb.com.br';
  static const vaticanNews = 'https://www.vaticannews.va/pt.html';
  static const commons = 'https://commons.wikimedia.org';
  static const catechismVatican = 'https://www.vatican.va/archive/cathechism_po/index_new/prima-pagina-cic_po.html';
  static const compendiumCcc =
      'https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_po.html';

  /// Páginas do CIC (1992) no vatican.va. O nome de cada uma termina com a faixa de parágrafos
  /// que ela contém (ex.: `p1s1c1_26-49`), o que permite abrir a página de qualquer §.
  /// Lista tirada dos índices `index-{prima,seconda,terza,quarta}-parte_po.html`.
  static const catechismPages = [
    'prologo 1-25',
    'p1s1c1_26-49',
    'p1s1c2_50-141',
    'p1s1c3_142-184',
    'p1s2_185-197',
    'p1s2c1_198-421',
    'p1s2cap2_422-682',
    'p1s2cap3_683-1065',
    'p2s1cap1_1066-1075',
    'p2s1cap1_1076-1134',
    'p2s1cap2_1135-1209',
    'p2s2cap1_1210-1419',
    'p2s2cap1_1420-1532',
    'p2s2cap3_1533-1666',
    'p2s2cap4_1667-1690',
    'p3-intr_1691-1698',
    'p3s1cap1_1699-1876',
    'p3s1cap2_1877-1948',
    'p3s1cap3_1949-2051',
    'p3s2-intr_2052-2082',
    'p3s2cap1_2083-2195',
    'p3s2cap2_2196-2557',
    'p4-intr_2558-2565',
    'p4s1cap1_2566-2649',
    'p4s1cap2_2650-2696',
    'p4s1cap3_2697-2758',
    'p4s2_2759-2865',
  ];

  /// Página oficial que contém o § [n] do CIC (1 a 2865); fora disso, a página inicial.
  /// Na Web, o fragmento de texto (`#:~:text=`) leva o navegador até o parágrafo.
  static String catechismParagraphUrl(int n) {
    for (final page in catechismPages) {
      final m = RegExp(r'[_ ](\d+)-(\d+)$').firstMatch(page)!;
      final first = int.parse(m[1]!);
      if (n < first || n > int.parse(m[2]!)) continue;
      final url = Uri.encodeFull('https://www.vatican.va/archive/cathechism_po/index_new/${page}_po.html');
      return n == first ? url : '$url#:~:text=$n.';
    }
    return catechismVatican;
  }
}
