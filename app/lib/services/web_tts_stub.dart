import 'neural_tts_types.dart';

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

Future<NeuralTtsStatus> webTtsRefreshStatus() async => const NeuralTtsStatus();

void webTtsListenStatus(void Function(NeuralTtsStatus status) onChange) {}
