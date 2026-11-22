import '../../core/liturgical_calendar.dart';
import '../../core/liturgical_color.dart';

/// Modelos do JSON diário gerado por `scraper/scraper.py` (schema_version 1).
/// Ver `docs/exemplo-liturgia-2026-11-19.json`.

String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

class SourceInfo {
  const SourceInfo({required this.id, required this.name, this.url, this.note});

  final String id;
  final String name;
  final String? url;
  final String? note;

  factory SourceInfo.fromJson(Map<String, dynamic> j) =>
      SourceInfo(id: _s(j['id']) ?? '', name: _s(j['nome']) ?? '', url: _s(j['url']), note: _s(j['nota']));
}

enum ReadingKind {
  primeiraLeitura('1ª Leitura', 'primeira_leitura'),
  salmo('Salmo Responsorial', 'salmo'),
  segundaLeitura('2ª Leitura', 'segunda_leitura'),
  evangelho('Evangelho', 'evangelho');

  const ReadingKind(this.label, this.jsonKey);
  final String label;
  final String jsonKey;
}

class Reading {
  const Reading({
    required this.kind,
    required this.text,
    this.reference,
    this.introduction,
    this.acclamation,
    this.refrain,
    this.stanzas = const [],
    this.source = 'CNBB',
  });

  final ReadingKind kind;
  final String text;
  final String? reference;
  final String? introduction;
  final String? acclamation;
  final String? refrain; // somente Salmo
  final List<String> stanzas; // somente Salmo
  final String source;

  bool get isPsalm => kind == ReadingKind.salmo;

  factory Reading.fromJson(ReadingKind kind, Map<String, dynamic> j) => Reading(
    kind: kind,
    text: _s(j['texto']) ?? '',
    reference: _s(j['referencia']),
    introduction: _s(j['introducao']),
    acclamation: _s(j['aclamacao']),
    refrain: _s(j['refrao']),
    stanzas: (j['estrofes'] as List?)?.whereType<String>().toList() ?? const [],
    source: _s(j['fonte']) ?? 'CNBB',
  );

  /// Texto preparado para leitura em voz alta (TTS), com as fórmulas
  /// litúrgicas de abertura e conclusão.
  String toSpeech() {
    final b = StringBuffer();
    switch (kind) {
      case ReadingKind.salmo:
        b.writeln('Salmo Responsorial.');
        if (refrain != null) b.writeln('Refrão: $refrain');
        for (final s in stanzas.isEmpty ? [text] : stanzas) {
          b.writeln(s);
          if (refrain != null) b.writeln(refrain);
        }
      case ReadingKind.evangelho:
        if (acclamation != null) b.writeln(acclamation);
        b.writeln(introduction ?? 'Proclamação do Evangelho.');
        b.writeln(text);
        b.writeln('Palavra da Salvação.');
      default:
        b.writeln(introduction ?? '${kind.label}.');
        b.writeln(text);
        b.writeln('Palavra do Senhor.');
    }
    return b.toString();
  }
}

class Homily {
  const Homily({
    required this.title,
    required this.text,
    this.author,
    this.work,
    this.url,
    this.source,
    this.license,
    this.note,
  });

  final String title;
  final String text;
  final String? author;
  final String? work;
  final String? url;
  final String? source;
  final String? license;
  final String? note;

  factory Homily.fromJson(Map<String, dynamic> j) => Homily(
    title: _s(j['titulo']) ?? _s(j['obra']) ?? 'Reflexão',
    text: _s(j['texto']) ?? '',
    author: _s(j['autor']),
    work: _s(j['obra']),
    url: _s(j['url']),
    source: _s(j['fonte']),
    license: _s(j['licenca']),
    note: _s(j['observacao']) ?? _s(j['nota']),
  );
}

class AudioCredit {
  const AudioCredit({this.field, this.performer, this.channel, this.sourceUrl, this.license});
  final String? field;
  final String? performer;
  final String? channel;
  final String? sourceUrl;
  final String? license;

  factory AudioCredit.fromJson(Map<String, dynamic> j) => AudioCredit(
    field: _s(j['campo']),
    performer: _s(j['interprete']),
    channel: _s(j['canal']),
    sourceUrl: _s(j['url_fonte']),
    license: _s(j['licenca']),
  );
}

/// MP3 pré-gerado numa voz: o endereço e, na Liturgia, onde começa cada leitura.
class VoiceAudio {
  const VoiceAudio(this.url, [this.marks = const {}]);

  final String url;

  /// Início de cada leitura (chave = `ReadingKind.jsonKey`).
  final Map<String, Duration> marks;
}

Map<String, Duration> _marks(Object? raw) => {
  for (final e in ((raw as Map?) ?? const {}).entries)
    if (e.value is num) '${e.key}': Duration(milliseconds: ((e.value as num) * 1000).round()),
};

/// `liturgia_vozes`/`homilia_vozes`: {voz: {url, marcas}}. Sem eles (JSON antigo), usa os campos
/// de uma voz só, mas apenas se forem da voz Kokoro Dora: MP3 antigos com outra voz (ex.: Piper
/// Cadu) não tocam, para a voz ouvida ser sempre a escolhida.
Map<String, VoiceAudio> _byVoice(Map<String, dynamic> j, String field, String legacyUrl, Object? legacyMarks) {
  final raw = j[field];
  if (raw is Map) {
    return {
      for (final e in raw.entries)
        if (e.value is Map && (e.value as Map)['url'] is String)
          '${e.key}': VoiceAudio((e.value as Map)['url'] as String, _marks((e.value as Map)['marcas'])),
    };
  }
  final url = _s(j[legacyUrl]);
  final credit = ((j['creditos'] as List?) ?? const []).whereType<Map<String, dynamic>>().where(
    (c) => c['campo'] == legacyUrl,
  );
  final kokoro = credit.any((c) => '${c['canal']}'.contains('Kokoro'));
  return url == null || !kokoro ? const {} : {'pf_dora': VoiceAudio(url, _marks(legacyMarks))};
}

class LiturgyAudio {
  const LiturgyAudio({
    this.psalmAudioUrl,
    this.psalmChordsOrMelody,
    this.psalmVideoId,
    this.psalmVideoTitle,
    this.liturgyAudioUrl,
    this.homilyAudioUrl,
    this.liturgyAudioMarks = const {},
    this.liturgyByVoice = const {},
    this.homilyByVoice = const {},
    this.credits = const [],
  });

  final String? psalmAudioUrl;
  final String? psalmChordsOrMelody;
  final String? psalmVideoId;
  final String? psalmVideoTitle;
  final String? liturgyAudioUrl;
  final String? homilyAudioUrl;

  /// Onde começa cada leitura no MP3 da Liturgia (chave = `ReadingKind.jsonKey`).
  /// Permite avançar/voltar entre leituras e começar de qualquer uma sem voz sintetizada.
  final Map<String, Duration> liturgyAudioMarks;

  /// MP3 da Liturgia e da Homilia em cada voz Kokoro (`pf_dora`, `pm_alex`).
  final Map<String, VoiceAudio> liturgyByVoice;
  final Map<String, VoiceAudio> homilyByVoice;
  final List<AudioCredit> credits;

  factory LiturgyAudio.fromJson(Map<String, dynamic>? j) => j == null
      ? const LiturgyAudio()
      : LiturgyAudio(
          psalmAudioUrl: _s(j['salmo_audio_url']),
          psalmChordsOrMelody: _s(j['salmo_cifra_ou_melodia']),
          psalmVideoId: _s(j['salmo_video_id']),
          psalmVideoTitle: _s(j['salmo_video_titulo']),
          liturgyAudioUrl: _s(j['liturgia_audio_url']),
          homilyAudioUrl: _s(j['homilia_audio_url']),
          liturgyAudioMarks: _marks(j['liturgia_audio_marcas']),
          liturgyByVoice: _byVoice(j, 'liturgia_vozes', 'liturgia_audio_url', j['liturgia_audio_marcas']),
          homilyByVoice: _byVoice(j, 'homilia_vozes', 'homilia_audio_url', null),
          credits:
              (j['creditos'] as List?)?.whereType<Map<String, dynamic>>().map(AudioCredit.fromJson).toList() ??
              const [],
        );

  AudioCredit? creditFor(String field) => credits.where((c) => c.field == field).firstOrNull;
}

class DailyLiturgy {
  const DailyLiturgy({
    required this.date,
    required this.day,
    required this.readings,
    required this.audio,
    this.vaticanHomily,
    this.cnbbReflection,
    this.patristic = const [],
    this.sources = const [],
    this.originalUrl,
    this.fromNetwork = true,
  });

  final DateTime date;
  final LiturgicalDay day;
  final List<Reading> readings;
  final LiturgyAudio audio;
  final Homily? vaticanHomily;
  final Homily? cnbbReflection;
  final List<Homily> patristic;
  final List<SourceInfo> sources;
  final String? originalUrl;

  /// `false` quando o conteúdo é apenas o calendário calculado localmente.
  final bool fromNetwork;

  bool get hasReadings => readings.isNotEmpty;
  Reading? reading(ReadingKind k) => readings.where((r) => r.kind == k).firstOrNull;
  Reading? get gospel => reading(ReadingKind.evangelho);

  /// Dia sem conteúdo baixado: somente o calendário local (offline).
  factory DailyLiturgy.calendarOnly(DateTime date) => DailyLiturgy(
    date: date,
    day: LiturgicalCalendar.compute(date),
    readings: const [],
    audio: const LiturgyAudio(),
    fromNetwork: false,
  );

  factory DailyLiturgy.fromJson(Map<String, dynamic> j) {
    final date = DateTime.parse(j['data'] as String);
    final computed = LiturgicalCalendar.compute(date);
    final cal = (j['calendario'] as Map?)?.cast<String, dynamic>() ?? const {};
    final day = LiturgicalDay(
      date: computed.date,
      weekdayName: _s(cal['dia_semana']) ?? computed.weekdayName,
      season: cal['tempo'] != null ? LiturgicalSeason.fromName(cal['tempo'] as String) : computed.season,
      week: (cal['semana'] as num?)?.toInt() ?? computed.week,
      color: cal['cor'] != null ? LiturgicalColor.fromName(cal['cor'] as String) : computed.color,
      celebration: _s(cal['celebracao']) ?? computed.celebration,
      rank: _s(cal['grau']) ?? computed.rank,
      sundayCycle: _s(cal['ciclo_dominical']) ?? computed.sundayCycle,
      weekdayCycle: _s(cal['ciclo_ferial']) ?? computed.weekdayCycle,
      mysteries: computed.mysteries,
    );

    final leituras = (j['leituras'] as Map?)?.cast<String, dynamic>() ?? const {};
    final readings = <Reading>[
      for (final k in ReadingKind.values)
        if (leituras[k.jsonKey] is Map) Reading.fromJson(k, (leituras[k.jsonKey] as Map).cast<String, dynamic>()),
    ].where((r) => r.text.isNotEmpty || r.stanzas.isNotEmpty).toList();

    final hom = (j['homilias'] as Map?)?.cast<String, dynamic>() ?? const {};
    Homily? h(String k) => hom[k] is Map ? Homily.fromJson((hom[k] as Map).cast<String, dynamic>()) : null;

    return DailyLiturgy(
      date: date,
      day: day,
      readings: readings,
      audio: LiturgyAudio.fromJson((j['audio'] as Map?)?.cast<String, dynamic>()),
      vaticanHomily: h('vaticano'),
      cnbbReflection: h('cnbb'),
      patristic:
          (hom['patristica'] as List?)
              ?.whereType<Map<dynamic, dynamic>>()
              .map((m) => Homily.fromJson(m.cast<String, dynamic>()))
              .toList() ??
          const [],
      sources:
          (j['fontes'] as List?)
              ?.whereType<Map<dynamic, dynamic>>()
              .map((m) => SourceInfo.fromJson(m.cast<String, dynamic>()))
              .toList() ??
          const [],
      originalUrl: _s(j['url_original']),
    );
  }
}
