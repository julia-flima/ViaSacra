/// Estados possíveis do motor neural Kokoro-82M na Web.
enum WebTtsState { idle, downloading, loading, ready, speaking, error }

/// Vozes em Português do Brasil disponíveis no Kokoro-82M (Apache-2.0).
class KokoroVoice {
  const KokoroVoice({required this.id, required this.label, required this.description});

  final String id;
  final String label;
  final String description;

  static const dora = KokoroVoice(id: 'pf_dora', label: 'Dora', description: 'Voz feminina (pt-BR)');
  static const alex = KokoroVoice(id: 'pm_alex', label: 'Alex', description: 'Voz masculina (pt-BR)');
  static const all = [dora, alex];

  static KokoroVoice byId(String? id) => all.firstWhere((v) => v.id == id, orElse: () => dora);
}

/// Estado instantâneo do download, inicialização e cache offline do Kokoro Web.
class WebTtsStatus {
  const WebTtsStatus({
    this.state = WebTtsState.idle,
    this.progress,
    this.label,
    this.device,
    this.cached = false,
    this.cacheBytes = 0,
    this.error,
  });

  final WebTtsState state;
  final double? progress;
  final String? label;
  final String? device;
  final bool cached;
  final int cacheBytes;
  final String? error;

  bool get isBusy => state == WebTtsState.downloading || state == WebTtsState.loading;

  String get cacheSizeLabel {
    if (cacheBytes <= 0) return '0 MB';
    final mb = cacheBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  String get deviceLabel => switch (device) {
    'webgpu' => 'WebGPU',
    'wasm' => 'WebAssembly',
    _ => '',
  };

  @override
  bool operator ==(Object other) =>
      other is WebTtsStatus &&
      other.state == state &&
      other.progress == progress &&
      other.label == label &&
      other.device == device &&
      other.cached == cached &&
      other.cacheBytes == cacheBytes &&
      other.error == error;

  @override
  int get hashCode => Object.hash(state, progress, label, device, cached, cacheBytes, error);
}
