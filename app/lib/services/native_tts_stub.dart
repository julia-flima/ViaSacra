import 'neural_tts_types.dart';

/// Stub para Web / ambientes sem `dart:io`.
bool nativeTtsIsSupported() => false;

void nativeTtsUsePlayer(Future<void> Function(String wavPath) play) {}

Future<bool> nativeTtsSpeak(
  String text,
  double speed, {
  String voice = 'pf_dora',
  String language = 'pt-BR',
  String? nextText,
}) async => false;

void nativeTtsStop() {}

Future<void> nativeTtsPrepare() async {}

Future<NeuralTtsStatus> nativeTtsRefreshStatus() async => const NeuralTtsStatus();

void nativeTtsListenStatus(void Function(NeuralTtsStatus status) onChange) {}

Future<bool> nativeTtsDownloadPiper(String voiceId) async => false;

void nativeTtsCancelDownload() {}

Future<void> nativeTtsRemovePiper(String voiceId) async {}
