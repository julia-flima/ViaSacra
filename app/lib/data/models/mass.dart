/// Ordinário da Missa (`assets/data/ordinario_missa.json`): só o que o povo responde,
/// com a deixa do padre para saber a hora de responder.
class OrdinaryOfMass {
  const OrdinaryOfMass({required this.source, required this.license, required this.url, required this.parts});

  final String source;
  final String license;
  final String? url;
  final List<MassPart> parts;

  factory OrdinaryOfMass.fromJson(Map<String, dynamic> j) {
    final common = (j['comuns'] as Map? ?? const {}).cast<String, dynamic>();
    return OrdinaryOfMass(
      source: j['fonte'] as String,
      license: j['licenca'] as String,
      url: j['url'] as String?,
      parts: [for (final p in j['partes'] as List) MassPart.fromJson((p as Map).cast<String, dynamic>(), common)],
    );
  }
}

class MassPart {
  const MassPart({required this.id, required this.title, required this.steps});

  final String id;
  final String title;
  final List<MassStep> steps;

  factory MassPart.fromJson(Map<String, dynamic> j, Map<String, dynamic> common) =>
      MassPart(id: j['id'] as String, title: j['titulo'] as String, steps: MassStep.listFrom(j['passos'], common));
}

/// Texto do dia que vem da Liturgia Diária (refrão do salmo, aclamação ao Evangelho).
enum DailyText { refrain, acclamation }

class MassStep {
  const MassStep({
    this.title,
    this.cue,
    this.people,
    this.note,
    this.options = const [],
    this.prayerId,
    this.daily,
    this.variants = const [],
    this.toCheck = false,
  });

  final String? title;

  /// Fala do padre (ou o momento) que antecede a resposta.
  final String? cue;

  /// O que o povo diz.
  final String? people;
  final String? note;
  final List<String> options;

  /// Oração de `prayers.json` (ex.: Credo), para não repetir o texto.
  final String? prayerId;
  final DailyText? daily;

  /// Escolha entre formas (ex.: Orações Eucarísticas I–IV).
  final List<MassVariant> variants;

  /// Texto ainda não conferido com o Missal impresso.
  final bool toCheck;

  static List<MassStep> listFrom(Object? raw, Map<String, dynamic> common) => [
    for (final s in raw as List? ?? const []) MassStep.fromJson((s as Map).cast<String, dynamic>(), common),
  ];

  factory MassStep.fromJson(Map<String, dynamic> j, Map<String, dynamic> common) {
    final ref = j['comum'] as String?;
    if (ref != null) return MassStep.fromJson((common[ref] as Map).cast<String, dynamic>(), common);
    return MassStep(
      title: j['titulo'] as String?,
      cue: j['deixa'] as String?,
      people: j['povo'] as String?,
      note: j['nota'] as String?,
      options: (j['opcoes'] as List? ?? const []).cast<String>(),
      prayerId: j['oracao'] as String?,
      daily: switch (j['do_dia']) {
        'refrao' => DailyText.refrain,
        'aclamacao' => DailyText.acclamation,
        _ => null,
      },
      variants: [
        for (final v in j['variantes'] as List? ?? const [])
          MassVariant(
            id: (v as Map)['id'] as String,
            title: v['titulo'] as String,
            steps: MassStep.listFrom(v['passos'], common),
            isDefault: v['padrao'] == true,
          ),
      ],
      toCheck: j['conferir'] == true,
    );
  }
}

class MassVariant {
  const MassVariant({required this.id, required this.title, required this.steps, this.isDefault = false});

  final String id;
  final String title;
  final List<MassStep> steps;

  /// Forma mostrada ao abrir a tela.
  final bool isDefault;
}
