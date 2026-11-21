import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;

import 'neural_tts_types.dart';

@JS('viaSacraKokoro')
external _KokoroBridge? get _kokoro;

extension type _KokoroBridge(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> speak(
    JSString text,
    JSNumber speed,
    JSString voice,
    JSString language,
    JSString? nextText,
  );
  external void stop();
  external JSPromise<JSBoolean> preload(JSString voice);
  external JSPromise<JSBoolean> clearCache();
  external JSPromise<_JsStatus> getStatus();
  external void onStatus(JSFunction callback);
}

extension type _JsStatus(JSObject _) implements JSObject {
  external JSString? get state;
  external JSNumber? get progress;
  external JSString? get label;
  external JSString? get device;
  external JSBoolean? get cached;
  external JSNumber? get cacheBytes;
  external JSString? get error;
  external JSBoolean? get slow;
}

NeuralTtsStatus _mapStatus(_JsStatus? raw) {
  if (raw == null) return const NeuralTtsStatus();
  final stateName = raw.state?.toDart;
  final state = NeuralTtsState.values.where((s) => s.name == stateName).firstOrNull ?? NeuralTtsState.idle;
  return NeuralTtsStatus(
    state: state,
    progress: raw.progress?.toDartDouble,
    label: raw.label?.toDart,
    device: raw.device?.toDart,
    cached: raw.cached?.toDart ?? false,
    cacheBytes: raw.cacheBytes?.toDartInt ?? 0,
    error: raw.error?.toDart,
    kokoroSlow: raw.slow?.toDart ?? false,
  );
}

/// Sintetiza e reproduz fala localmente no navegador via Kokoro-82M (Web Worker).
/// Retorna `true` se o Kokoro executou (ou foi interrompido pelo usuário), ou
/// `false` quando falhar e for necessário usar o fallback `flutter_tts`.
Future<bool> webTtsSpeak(
  String text,
  double speed, {
  String voice = 'pf_dora',
  String language = 'pt-BR',
  String? nextText,
}) async {
  final bridge = _kokoro;
  if (bridge == null) return false;
  try {
    final ok = await bridge.speak(text.toJS, speed.toJS, voice.toJS, language.toJS, nextText?.toJS).toDart;
    return ok.toDart;
  } catch (e) {
    debugPrint('Kokoro Web TTS indisponível, usando fallback: $e');
    return false;
  }
}

void webTtsStop() {
  _kokoro?.stop();
}

Future<bool> webTtsPreload({String voice = 'pf_dora'}) async {
  final bridge = _kokoro;
  if (bridge == null) return false;
  try {
    final ok = await bridge.preload(voice.toJS).toDart;
    return ok.toDart;
  } catch (e) {
    debugPrint('Erro ao pré-carregar Kokoro Web TTS: $e');
    return false;
  }
}

Future<bool> webTtsClearCache() async {
  final bridge = _kokoro;
  if (bridge == null) return false;
  try {
    final ok = await bridge.clearCache().toDart;
    return ok.toDart;
  } catch (e) {
    debugPrint('Erro ao limpar cache do Kokoro Web TTS: $e');
    return false;
  }
}

Future<NeuralTtsStatus> webTtsRefreshStatus() async {
  final bridge = _kokoro;
  if (bridge == null) return const NeuralTtsStatus();
  try {
    final status = await bridge.getStatus().toDart;
    return _mapStatus(status);
  } catch (_) {
    return const NeuralTtsStatus();
  }
}

void webTtsListenStatus(void Function(NeuralTtsStatus status) onChange) {
  final bridge = _kokoro;
  if (bridge == null) return;
  bridge.onStatus(((_JsStatus status) => onChange(_mapStatus(status))).toJS);
}
