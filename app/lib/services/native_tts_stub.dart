import 'neural_tts_types.dart';

/// Stub para Web / ambientes sem `dart:io`.
bool nativeTtsIsSupported() => false;

Future<bool> nativeTtsSpeak(
  String text,
  double speed, {
  String voice = 'pf_dora',
  String language = 'pt-BR',
  String? nextText,
}) async => false;

void nativeTtsStop() {}

Future<bool> nativeTtsPreload({String voice = 'pf_dora'}) async => false;

Future<bool> nativeTtsClearCache() async => false;

Future<NeuralTtsStatus> nativeTtsRefreshStatus() async => const NeuralTtsStatus();

void nativeTtsListenStatus(void Function(NeuralTtsStatus status) onChange) {}
