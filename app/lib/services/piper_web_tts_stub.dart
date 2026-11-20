/// Stub para plataformas nativas (Android/iOS/VM): retorna false para usar o TTS do sistema.
Future<bool> piperWebSpeak(String text, double speed) async => false;

void piperWebStop() {}
