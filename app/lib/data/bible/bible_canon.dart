// GERADO a partir de tool/bible/canon.py — não edite à mão
// (python tool/bible/build_modules.py regenera canon.json; test/bible_test.dart confere a paridade).

enum Testament {
  at('Antigo Testamento'),
  nt('Novo Testamento');

  const Testament(this.label);
  final String label;
}

class BibleBook {
  const BibleBook(
    this.id,
    this.abbreviation,
    this.name,
    this.latinName,
    this.testament, {
    this.deutero = false,
    this.aliases = const [],
  });

  final String id;
  final String abbreviation;
  final String name;
  final String latinName;
  final Testament testament;
  final bool deutero;
  final List<String> aliases;
}

/// Cânon católico: 46 livros do Antigo Testamento (com os deuterocanônicos) e 27 do Novo.
const bibleCanon = <BibleBook>[
  BibleBook('gn', 'Gn', 'Gênesis', 'Genesis', Testament.at, deutero: false, aliases: ['gen', 'genesis']),
  BibleBook('ex', 'Ex', 'Êxodo', 'Exodus', Testament.at, deutero: false, aliases: ['exo', 'exodo']),
  BibleBook('lv', 'Lv', 'Levítico', 'Leviticus', Testament.at, deutero: false, aliases: ['lev', 'levitico']),
  BibleBook('nm', 'Nm', 'Números', 'Numeri', Testament.at, deutero: false, aliases: ['num', 'numeros']),
  BibleBook(
    'dt',
    'Dt',
    'Deuteronômio',
    'Deuteronomium',
    Testament.at,
    deutero: false,
    aliases: ['deut', 'deuteronomio'],
  ),
  BibleBook('js', 'Js', 'Josué', 'Iosue', Testament.at, deutero: false, aliases: ['jos', 'josue']),
  BibleBook('jz', 'Jz', 'Juízes', 'Iudicum', Testament.at, deutero: false, aliases: ['juizes', 'jui']),
  BibleBook('rt', 'Rt', 'Rute', 'Ruth', Testament.at, deutero: false, aliases: ['rute']),
  BibleBook(
    '1sm',
    '1Sm',
    '1 Samuel',
    'I Samuelis (I Regum)',
    Testament.at,
    deutero: false,
    aliases: ['1samuel', '1 sam', '1rs reg'],
  ),
  BibleBook(
    '2sm',
    '2Sm',
    '2 Samuel',
    'II Samuelis (II Regum)',
    Testament.at,
    deutero: false,
    aliases: ['2samuel', '2 sam'],
  ),
  BibleBook('1rs', '1Rs', '1 Reis', 'III Regum', Testament.at, deutero: false, aliases: ['1reis', '1 re']),
  BibleBook('2rs', '2Rs', '2 Reis', 'IV Regum', Testament.at, deutero: false, aliases: ['2reis', '2 re']),
  BibleBook(
    '1cr',
    '1Cr',
    '1 Crônicas',
    'I Paralipomenon',
    Testament.at,
    deutero: false,
    aliases: ['1cronicas', '1par'],
  ),
  BibleBook(
    '2cr',
    '2Cr',
    '2 Crônicas',
    'II Paralipomenon',
    Testament.at,
    deutero: false,
    aliases: ['2cronicas', '2par'],
  ),
  BibleBook('esd', 'Esd', 'Esdras', 'I Esdrae', Testament.at, deutero: false, aliases: ['esdras', 'ed']),
  BibleBook('ne', 'Ne', 'Neemias', 'II Esdrae (Nehemiae)', Testament.at, deutero: false, aliases: ['neemias', 'nee']),
  BibleBook('tb', 'Tb', 'Tobias', 'Tobiae', Testament.at, deutero: true, aliases: ['tobias', 'tob']),
  BibleBook('jt', 'Jt', 'Judite', 'Iudith', Testament.at, deutero: true, aliases: ['judite', 'jdt']),
  BibleBook('est', 'Est', 'Ester', 'Esther', Testament.at, deutero: false, aliases: ['ester', 'et']),
  BibleBook('1mc', '1Mc', '1 Macabeus', 'I Machabaeorum', Testament.at, deutero: true, aliases: ['1macabeus', '1mac']),
  BibleBook('2mc', '2Mc', '2 Macabeus', 'II Machabaeorum', Testament.at, deutero: true, aliases: ['2macabeus', '2mac']),
  BibleBook('jb', 'Jó', 'Jó', 'Iob', Testament.at, deutero: false, aliases: ['job']),
  BibleBook('sl', 'Sl', 'Salmos', 'Psalmi', Testament.at, deutero: false, aliases: ['salmo', 'salmos', 'ps']),
  BibleBook('pr', 'Pr', 'Provérbios', 'Proverbia', Testament.at, deutero: false, aliases: ['proverbios', 'prov']),
  BibleBook(
    'ecl',
    'Ecl',
    'Eclesiastes',
    'Ecclesiastes (Qoheleth)',
    Testament.at,
    deutero: false,
    aliases: ['eclesiastes', 'qo', 'coelet'],
  ),
  BibleBook(
    'ct',
    'Ct',
    'Cântico dos Cânticos',
    'Canticum Canticorum',
    Testament.at,
    deutero: false,
    aliases: ['canticos', 'cant', 'cc'],
  ),
  BibleBook('sb', 'Sb', 'Sabedoria', 'Sapientiae', Testament.at, deutero: true, aliases: ['sabedoria', 'sab']),
  BibleBook(
    'eclo',
    'Eclo',
    'Eclesiástico (Sirácida)',
    'Ecclesiasticus',
    Testament.at,
    deutero: true,
    aliases: ['eclesiastico', 'sir', 'siracida'],
  ),
  BibleBook('is', 'Is', 'Isaías', 'Isaias', Testament.at, deutero: false, aliases: ['isaias']),
  BibleBook('jr', 'Jr', 'Jeremias', 'Ieremias', Testament.at, deutero: false, aliases: ['jeremias', 'jer']),
  BibleBook('lm', 'Lm', 'Lamentações', 'Lamentationes', Testament.at, deutero: false, aliases: ['lamentacoes', 'lam']),
  BibleBook('br', 'Br', 'Baruc', 'Baruch', Testament.at, deutero: true, aliases: ['baruc', 'bar']),
  BibleBook('ez', 'Ez', 'Ezequiel', 'Ezechiel', Testament.at, deutero: false, aliases: ['ezequiel']),
  BibleBook('dn', 'Dn', 'Daniel', 'Daniel', Testament.at, deutero: false, aliases: ['daniel', 'dan']),
  BibleBook('os', 'Os', 'Oseias', 'Osee', Testament.at, deutero: false, aliases: ['oseias']),
  BibleBook('jl', 'Jl', 'Joel', 'Ioel', Testament.at, deutero: false, aliases: ['joel']),
  BibleBook('am', 'Am', 'Amós', 'Amos', Testament.at, deutero: false, aliases: ['amos']),
  BibleBook('ab', 'Ab', 'Abdias', 'Abdias', Testament.at, deutero: false, aliases: ['abdias', 'obadias']),
  BibleBook('jn', 'Jn', 'Jonas', 'Ionas', Testament.at, deutero: false, aliases: ['jonas']),
  BibleBook('mq', 'Mq', 'Miqueias', 'Michaeas', Testament.at, deutero: false, aliases: ['miqueias', 'mi']),
  BibleBook('na', 'Na', 'Naum', 'Nahum', Testament.at, deutero: false, aliases: ['naum']),
  BibleBook('hab', 'Hab', 'Habacuc', 'Habacuc', Testament.at, deutero: false, aliases: ['habacuc', 'hc']),
  BibleBook('sf', 'Sf', 'Sofonias', 'Sophonias', Testament.at, deutero: false, aliases: ['sofonias']),
  BibleBook('ag', 'Ag', 'Ageu', 'Aggaeus', Testament.at, deutero: false, aliases: ['ageu']),
  BibleBook('zc', 'Zc', 'Zacarias', 'Zacharias', Testament.at, deutero: false, aliases: ['zacarias']),
  BibleBook('ml', 'Ml', 'Malaquias', 'Malachias', Testament.at, deutero: false, aliases: ['malaquias']),
  BibleBook('mt', 'Mt', 'Mateus', 'Matthaeus', Testament.nt, deutero: false, aliases: ['mateus']),
  BibleBook('mc', 'Mc', 'Marcos', 'Marcus', Testament.nt, deutero: false, aliases: ['marcos', 'mr']),
  BibleBook('lc', 'Lc', 'Lucas', 'Lucas', Testament.nt, deutero: false, aliases: ['lucas']),
  BibleBook('jo', 'Jo', 'João', 'Ioannes', Testament.nt, deutero: false, aliases: ['joao']),
  BibleBook('at', 'At', 'Atos dos Apóstolos', 'Actus Apostolorum', Testament.nt, deutero: false, aliases: ['atos']),
  BibleBook('rm', 'Rm', 'Romanos', 'ad Romanos', Testament.nt, deutero: false, aliases: ['romanos', 'rom']),
  BibleBook(
    '1cor',
    '1Cor',
    '1 Coríntios',
    'I ad Corinthios',
    Testament.nt,
    deutero: false,
    aliases: ['1corintios', '1co'],
  ),
  BibleBook(
    '2cor',
    '2Cor',
    '2 Coríntios',
    'II ad Corinthios',
    Testament.nt,
    deutero: false,
    aliases: ['2corintios', '2co'],
  ),
  BibleBook('gl', 'Gl', 'Gálatas', 'ad Galatas', Testament.nt, deutero: false, aliases: ['galatas', 'gal']),
  BibleBook('ef', 'Ef', 'Efésios', 'ad Ephesios', Testament.nt, deutero: false, aliases: ['efesios']),
  BibleBook('fl', 'Fl', 'Filipenses', 'ad Philippenses', Testament.nt, deutero: false, aliases: ['filipenses', 'fp']),
  BibleBook('cl', 'Cl', 'Colossenses', 'ad Colossenses', Testament.nt, deutero: false, aliases: ['colossenses', 'col']),
  BibleBook(
    '1ts',
    '1Ts',
    '1 Tessalonicenses',
    'I ad Thessalonicenses',
    Testament.nt,
    deutero: false,
    aliases: ['1tessalonicenses'],
  ),
  BibleBook(
    '2ts',
    '2Ts',
    '2 Tessalonicenses',
    'II ad Thessalonicenses',
    Testament.nt,
    deutero: false,
    aliases: ['2tessalonicenses'],
  ),
  BibleBook('1tm', '1Tm', '1 Timóteo', 'I ad Timotheum', Testament.nt, deutero: false, aliases: ['1timoteo']),
  BibleBook('2tm', '2Tm', '2 Timóteo', 'II ad Timotheum', Testament.nt, deutero: false, aliases: ['2timoteo']),
  BibleBook('tt', 'Tt', 'Tito', 'ad Titum', Testament.nt, deutero: false, aliases: ['tito']),
  BibleBook('fm', 'Fm', 'Filêmon', 'ad Philemonem', Testament.nt, deutero: false, aliases: ['filemon', 'flm']),
  BibleBook('hb', 'Hb', 'Hebreus', 'ad Hebraeos', Testament.nt, deutero: false, aliases: ['hebreus', 'heb']),
  BibleBook('tg', 'Tg', 'Tiago', 'Iacobi', Testament.nt, deutero: false, aliases: ['tiago']),
  BibleBook('1pd', '1Pd', '1 Pedro', 'I Petri', Testament.nt, deutero: false, aliases: ['1pedro', '1pe']),
  BibleBook('2pd', '2Pd', '2 Pedro', 'II Petri', Testament.nt, deutero: false, aliases: ['2pedro', '2pe']),
  BibleBook('1jo', '1Jo', '1 João', 'I Ioannis', Testament.nt, deutero: false, aliases: ['1joao']),
  BibleBook('2jo', '2Jo', '2 João', 'II Ioannis', Testament.nt, deutero: false, aliases: ['2joao']),
  BibleBook('3jo', '3Jo', '3 João', 'III Ioannis', Testament.nt, deutero: false, aliases: ['3joao']),
  BibleBook('jd', 'Jd', 'Judas', 'Iudae', Testament.nt, deutero: false, aliases: ['judas']),
  BibleBook(
    'ap',
    'Ap',
    'Apocalipse',
    'Apocalypsis',
    Testament.nt,
    deutero: false,
    aliases: ['apocalipse', 'apoc', 'apc'],
  ),
];

final Map<String, BibleBook> bibleBooksById = {for (final b in bibleCanon) b.id: b};

BibleBook? bookById(String id) => bibleBooksById[id];
