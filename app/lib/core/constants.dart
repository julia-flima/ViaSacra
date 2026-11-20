/// Constantes globais do Via Sacra.
library;

class AppInfo {
  static const name = 'Via Sacra';
  static const author = 'Júlia Lima';
  static const version = '1.2.0';
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

  /// Páginas oficiais das partes do CIC (1992) em português no portal da Santa Sé.
  /// Os nós do índice (`assets/db/catechism.json`) são "prologo", "p1"…"p4" e seus
  /// filhos ("p2.s2.c1.a3"); subseções abrem a página inicial da sua parte.
  static String catechismPartUrl(String nodeId) {
    if (nodeId == 'prologo' || nodeId.startsWith('p0')) {
      return 'https://www.vatican.va/archive/cathechism_po/index_new/prologo%201-25_po.html';
    }
    if (nodeId.startsWith('p1')) {
      return 'https://www.vatican.va/archive/cathechism_po/index_new/p1s1c1_26-49_po.html';
    }
    if (nodeId.startsWith('p2')) {
      return 'https://www.vatican.va/archive/cathechism_po/index_new/p2s1cap1_1113-1134_po.html';
    }
    if (nodeId.startsWith('p3')) {
      return 'https://www.vatican.va/archive/cathechism_po/index_new/p3s1cap1_1700-1715_po.html';
    }
    if (nodeId.startsWith('p4')) {
      return 'https://www.vatican.va/archive/cathechism_po/index_new/p4s1cap1_2558-2565_po.html';
    }
    return catechismVatican;
  }
}
