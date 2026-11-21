// Botão voltar do Android: não pode sair do app no meio da oração.
// (Arquivo próprio: o harness não suporta dois buildServices no mesmo arquivo.)
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('Botão voltar do Android durante a oração pede confirmação em vez de sair', (tester) async {
    final s = await buildServices(onboardingDone: true);
    await pumpApp(tester, s);
    await tester.tap(find.text('Terço'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Rezar o Terço'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Rezar o Terço'));
    await settle(tester);
    await tester.tap(find.textContaining(RegExp(r'^Amém ·')));
    await settle(tester);

    // Mesmo caminho do botão voltar do sistema: o Navigator raiz tenta sair da tela.
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await settle(tester);
    expect(find.text('Encerrar a oração?'), findsOneWidget);
    await tester.tap(find.text('Continuar rezando'));
    await settle(tester);
    expect(find.byTooltip('Encerrar'), findsOneWidget); // continua na oração
  });
}
