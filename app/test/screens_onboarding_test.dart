// Smoke test de tela (um teste por arquivo: cada arquivo roda em um processo
// próprio, evitando estado compartilhado de plugins entre testes).
//   flutter test test/screens_onboarding_test.dart
//   GOLDENS=1 flutter test test/screens_onboarding_test.dart --update-goldens
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('Onboarding', (tester) async {
    await pumpApp(tester, await buildServices(onboardingDone: false));
    expect(find.text('Deseja receber lembretes?'), findsOneWidget);
    await shot(tester, '0-onboarding');
  });
}
