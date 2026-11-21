import 'package:flutter/foundation.dart' show mapEquals;

/// Estados possíveis do motor neural Kokoro-82M (Web ou Mobile).
enum NeuralTtsState { idle, downloading, loading, ready, speaking, error }

/// Motor usado para ler em voz alta. Kokoro vem no app; Piper é baixado nas Configurações (só celular).
enum TtsEngine {
  kokoro('Kokoro'),
  piper('Piper'),
  system('Sistema');

  const TtsEngine(this.label);
  final String label;

  static TtsEngine byName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => kokoro);
}

/// Vozes Piper pt-BR (sherpa-onnx, int8, ~21 MB cada), baixadas do release oficial `tts-models`.
class PiperVoice {
  const PiperVoice({
    required this.id,
    required this.label,
    required this.description,
    required this.archive,
    required this.onnx,
    required this.sha256,
    required this.license,
  });

  final String id;
  final String label;
  final String description;

  /// Nome do pacote `.tar.bz2` e da pasta que ele contém.
  final String archive;
  final String onnx;
  final String sha256;
  final String license;

  String get url => 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$archive.tar.bz2';

  static const dii = PiperVoice(
    id: 'piper_dii',
    label: 'Dii',
    description: 'Voz feminina (pt-BR)',
    archive: 'vits-piper-pt_BR-dii-high-int8',
    onnx: 'pt_BR-dii-high.onnx',
    sha256: '8a5b0195eff80a0240f18a3f1d528d4bef08f1b702126cee858d700365fc4111',
    license: 'CC BY-NC-SA 4.0 (uso não comercial)',
  );
  static const faber = PiperVoice(
    id: 'piper_faber',
    label: 'Faber',
    description: 'Voz masculina (pt-BR)',
    archive: 'vits-piper-pt_BR-faber-medium-int8',
    onnx: 'pt_BR-faber-medium.onnx',
    sha256: 'dbc8b1d7d729fd417ea78a350ed35696c928770ac93513d3f507bd4e88eee3fd',
    license: 'CC0 (domínio público)',
  );
  static const all = [dii, faber];

  static PiperVoice? byId(String? id) => all.where((v) => v.id == id).firstOrNull;
}

/// Vozes em Português do Brasil disponíveis no Kokoro-82M (Apache-2.0).
class KokoroVoice {
  const KokoroVoice({required this.id, required this.label, required this.description, required this.sid});

  final String id;
  final String label;
  final String description;
  final int sid;

  static const dora = KokoroVoice(id: 'pf_dora', label: 'Dora', description: 'Voz feminina (pt-BR)', sid: 42);
  static const alex = KokoroVoice(id: 'pm_alex', label: 'Alex', description: 'Voz masculina (pt-BR)', sid: 43);
  static const all = [dora, alex];

  static KokoroVoice byId(String? id) => all.firstWhere((v) => v.id == id, orElse: () => dora);
}

/// Especificação resolvida de locutor e idioma eSpeak-NG para o Kokoro-82M v1.0.
class KokoroSpeaker {
  const KokoroSpeaker({required this.voiceId, required this.sid, required this.espeakLang});

  final String voiceId;
  final int sid;
  final String espeakLang;
}

/// Resolve o `sid` do Kokoro-82M v1.0 e o idioma eSpeak-NG a partir da preferência
/// do usuário (`pf_dora` / `pm_alex`) e do idioma BCP-47 do trecho.
KokoroSpeaker resolveKokoroSpeaker({required String voiceId, required String language}) {
  final prefMale = KokoroVoice.byId(voiceId).id == KokoroVoice.alex.id;
  final lang = language.toLowerCase();
  if (lang.startsWith('en')) {
    return prefMale
        ? const KokoroSpeaker(voiceId: 'am_michael', sid: 16, espeakLang: 'en-us')
        : const KokoroSpeaker(voiceId: 'af_heart', sid: 3, espeakLang: 'en-us');
  }
  if (lang.startsWith('la') || lang.startsWith('it')) {
    return prefMale
        ? const KokoroSpeaker(voiceId: 'im_nicola', sid: 36, espeakLang: 'it')
        : const KokoroSpeaker(voiceId: 'if_sara', sid: 35, espeakLang: 'it');
  }
  if (lang.startsWith('es')) {
    return prefMale
        ? const KokoroSpeaker(voiceId: 'em_alex', sid: 29, espeakLang: 'es')
        : const KokoroSpeaker(voiceId: 'ef_dora', sid: 28, espeakLang: 'es');
  }
  return prefMale
      ? const KokoroSpeaker(voiceId: 'pm_alex', sid: 43, espeakLang: 'pt-br')
      : const KokoroSpeaker(voiceId: 'pf_dora', sid: 42, espeakLang: 'pt-br');
}

/// Normaliza sinais tipográficos e símbolos litúrgicos antes da síntese neural.
String normalizeTextForKokoro(String raw) => raw
    .replaceAll(RegExp(r'[«»“”]'), '"')
    .replaceAll(RegExp(r'[‘’]'), "'")
    .replaceAll(RegExp(r'[—–]'), ', ')
    .replaceAll(RegExp(r'§\s*'), 'parágrafo ')
    .replaceAll(RegExp(r'[✝✦•▪▸►]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Estado instantâneo do download, inicialização e cache offline do Kokoro-82M.
class NeuralTtsStatus {
  const NeuralTtsStatus({
    this.state = NeuralTtsState.idle,
    this.progress,
    this.label,
    this.device,
    this.cached = false,
    this.cacheBytes = 0,
    this.error,
    this.piperBytes = const {},
    this.kokoroSlow = false,
  });

  final NeuralTtsState state;
  final double? progress;
  final String? label;
  final String? device;
  final bool cached;
  final int cacheBytes;
  final String? error;

  /// Vozes Piper instaladas (id → bytes em disco).
  final Map<String, int> piperBytes;

  /// O Kokoro sintetiza mais devagar do que fala neste aparelho (haverá pausas na leitura).
  final bool kokoroSlow;

  bool get isBusy => state == NeuralTtsState.downloading || state == NeuralTtsState.loading;

  String get cacheSizeLabel => sizeLabel(cacheBytes);

  static String sizeLabel(int bytes) {
    if (bytes <= 0) return '0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  String get deviceLabel => switch (device) {
    'webgpu' => 'WebGPU',
    'wasm' => 'WebAssembly',
    'onnx-cpu' => 'ONNX CPU',
    _ => '',
  };

  @override
  bool operator ==(Object other) =>
      other is NeuralTtsStatus &&
      other.state == state &&
      other.progress == progress &&
      other.label == label &&
      other.device == device &&
      other.cached == cached &&
      other.cacheBytes == cacheBytes &&
      other.error == error &&
      mapEquals(other.piperBytes, piperBytes) &&
      other.kokoroSlow == kokoroSlow;

  @override
  int get hashCode => Object.hash(state, progress, label, device, cached, cacheBytes, error, piperBytes.length);
}
