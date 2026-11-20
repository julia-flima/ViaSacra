import 'web_tts_types.dart';

/// Stub para plataformas nativas (Android/iOS/VM): retorna false para usar o TTS do sistema.
Future<bool> webTtsSpeak(
  String text,
  double speed, {
  String voice = 'pf_dora',
  String language = 'pt-BR',
  String? nextText,
}) async => false;

void webTtsStop() {}

Future<bool> webTtsPreload({String voice = 'pf_dora'}) async => false;

Future<bool> webTtsClearCache() async => false;

Future<WebTtsStatus> webTtsRefreshStatus() async => const WebTtsStatus();

void webTtsListenStatus(void Function(WebTtsStatus status) onChange) {}
