import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('viaSacraPiper')
external _PiperBridge? get _piper;

extension type _PiperBridge(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> speak(JSString text, JSNumber speed);
  external void stop();
}

/// Sintetiza e reproduz fala em pt-BR localmente no navegador via Piper WASM.
/// Retorna `true` se o Piper executou com sucesso, ou `false` para cair no fallback `flutter_tts`.
Future<bool> piperWebSpeak(String text, double speed) async {
  final bridge = _piper;
  if (bridge == null) return false;
  try {
    await bridge.speak(text.toJS, speed.toJS).toDart;
    return true;
  } catch (e) {
    debugPrint('Piper Web TTS indisponível, usando fallback: $e');
    return false;
  }
}

void piperWebStop() {
  _piper?.stop();
}
