// Smoke test de tela (um teste por arquivo: cada arquivo roda em um processo
// próprio, evitando estado compartilhado de plugins entre testes).
//   flutter test test/screens_dark_test.dart
//   GOLDENS=1 flutter test test/screens_dark_test.dart --update-goldens
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('Modo Igreja (escuro)', timeout: const Timeout(Duration(seconds: 60)), (tester) async {
    await pumpApp(tester, await buildServices(onboardingDone: true, dark: true));
    await shot(tester, '8-modo-igreja');
  });
}
