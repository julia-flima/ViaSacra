// Botão voltar na Web: a tela inicial não pode "sair" do app, senão o PWA fica com a tela preta (issue #50).
// (Arquivo próprio: o harness não suporta dois buildServices no mesmo arquivo.)
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:via_sacra/app.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('Na Web, voltar na tela inicial não sai do app', (tester) async {
    ViaSacraApp.rootCanPop = false; // como na Web
    addTearDown(() => ViaSacraApp.rootCanPop = true);
    final s = await buildServices(onboardingDone: true);
    await pumpApp(tester, s);

    // Mesmo caminho do voltar do navegador: o framework só sai do app se o Navigator raiz não tratar.
    final handled = await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await settle(tester);
    expect(handled, isTrue);
    expect(find.text('Liturgia Diária'), findsOneWidget);
  });
}
