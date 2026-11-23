import '../data/bible/bible_canon.dart';

/// Texto como deve ser falado: tira marcas que só servem à leitura com os olhos e
/// lê referências bíblicas por extenso. Vale para todas as vozes (neural e do sistema).
/// `scraper/generate_audio.py` (`speakable_text`) segue as mesmas regras nos MP3.
///
/// Ex.: "Lc 19,41-44" → "Lucas 19, versículos 41 a 44"; "Sl 22(23),1-2a.5" → "Salmo 22, versículos 1 a 2 e 5".
String speakableText(String raw) {
  var t = raw
      // Marcas do Salmo e das orações: "*" e "†" (pausas do canto), "R." e "V." (resposta e verso).
      .replaceAll(RegExp(r'[*†+]'), ' ')
      .replaceAll(RegExp(r'^[ \t]*[RV]\.[ \t]*', multiLine: true), '')
      .replaceAll(RegExp(r'[ \t]+R\.[ \t]*$', multiLine: true), '')
      // Abreviações comuns nos textos litúrgicos.
      .replaceAll(RegExp(r'\bN\.\s?Sra\.'), 'Nossa Senhora')
      .replaceAll(RegExp(r'\bN\.\s?S(?:r|enhor)\.'), 'Nosso Senhor')
      .replaceAll(RegExp(r'\bSto\.\s?'), 'Santo ')
      .replaceAll(RegExp(r'\bSta\.\s?'), 'Santa ')
      .replaceAll(RegExp(r'\bS\.\s(?=[A-ZÁÉÍÓÚ])'), 'São ')
      .replaceAll(RegExp(r'\bcf\.\s?', caseSensitive: false), 'conforme ');
  t = t.replaceAllMapped(_reference, (m) {
    final book = _spokenBooks[m.group(1)!.replaceAll(' ', '')]!;
    return '$book ${m.group(2)}, ${_spokenVerses(m.group(3)!)}';
  });
  return t.replaceAll(RegExp(r'[ \t]+(?=\n)'), '').replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
}

/// "1Cor" e "1 Coríntios" → "Primeira Coríntios"; "Sl" → "Salmo"; "Eclesiástico (Sirácida)" → "Eclesiástico".
final Map<String, String> _spokenBooks = () {
  final map = <String, String>{};
  for (final b in bibleCanon) {
    var name = b.name.replaceAll(RegExp(r'\s*\(.*\)'), '');
    final ordinal = RegExp(r'^([1-3]) (.+)$').firstMatch(name);
    if (ordinal != null) {
      final n = int.parse(ordinal.group(1)!) - 1;
      // Cartas do Novo Testamento: "Primeira Coríntios"; livros do Antigo: "Primeiro Reis".
      final words = b.testament == Testament.nt
          ? const ['Primeira', 'Segunda', 'Terceira']
          : const ['Primeiro', 'Segundo', 'Terceiro'];
      name = '${words[n]} ${ordinal.group(2)}';
    }
    if (b.id == 'sl') name = 'Salmo';
    map[b.abbreviation] = name;
    map[b.name.replaceAll(RegExp(r'\s*\(.*\)'), '').replaceAll(' ', '')] = name;
  }
  map['Salmo'] = 'Salmo';
  return map;
}();

/// Livro (abreviação ou nome) + capítulo (+ capítulo hebraico) + versículos: "Lc 19,41-44", "Ezequiel 34,11-12.15-17",
/// "Sl 22(23),1-2a.2b-3", "Is 52,13-53,12", "Sl 149,1-2.5-6a e 9b". Exige vírgula/dois-pontos e versículo.
final RegExp _reference = () {
  final keys = _spokenBooks.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final alts = keys.map((k) => RegExp.escape(k).replaceFirstMapped(RegExp(r'^([1-3])'), (m) => '${m[1]} ?')).join('|');
  const v = r'\d{1,3}[a-z]{0,2}';
  return RegExp(
    '(?<![\\wÀ-ÿ])($alts)\\s?(\\d{1,3})(?:\\(\\d{1,3}\\))?\\s?[,:]\\s?'
    '($v(?:\\s?[-–]\\s?(?:\\d{1,3},)?$v)?(?:(?:\\s?\\.\\s?|\\s(?:e|ou)\\s)$v(?:\\s?[-–]\\s?(?:\\d{1,3},)?$v)?)*)',
  );
}();

/// "41-44" → "versículos 41 a 44"; "16" → "versículo 16"; "1-2a.5" → "versículos 1 a 2 e 5";
/// "13-53,12" → "versículo 13 ao capítulo 53, versículo 12"; "1-4.11-21,2" → "versículos 1 a 4 e 11 ao capítulo 21, versículo 2".
String _spokenVerses(String spec) {
  String n(String s) => s.replaceAll(RegExp(r'[a-z]'), '').trim();
  final items = spec.split(RegExp(r'\s?\.\s?|\s(?:e|ou)\s')).where((s) => s.trim().isNotEmpty).toList();
  // Trecho que atravessa o capítulo: "13-53,12".
  final cross = RegExp(r'^(\S+?)\s?[-–]\s?(\d{1,3}),(\S+)$');
  final spoken = [
    for (final it in items)
      if (cross.firstMatch(it.trim()) case final c?)
        '${n(c[1]!)} ao capítulo ${c[2]}, versículo ${n(c[3]!)}'
      else
        switch (it.split(RegExp(r'\s?[-–]\s?'))) {
          [final a, final b] when n(a) != n(b) => '${n(a)} a ${n(b)}',
          final parts => n(parts.first),
        },
  ];
  final single = spoken.first;
  if (spoken.length == 1 && (!single.contains(' a ') || single.contains(' ao '))) return 'versículo $single';
  final last = spoken.removeLast();
  return 'versículos ${spoken.isEmpty ? last : '${spoken.join(', ')} e $last'}';
}
