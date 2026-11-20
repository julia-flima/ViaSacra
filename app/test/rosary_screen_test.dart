// Regressões do Terço (issue #7): voltar uma conta e confirmar ao encerrar.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('Voltar uma conta atualiza a tela e o progresso salvo; X pede confirmação', (tester) async {
    final s = await buildServices(onboardingDone: true);
    await pumpApp(tester, s);

    await tester.tap(find.text('Terço'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Rezar o Terço'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Rezar o Terço'));
    await settle(tester);

    // 6 orações iniciais + Pai-Nosso + 3 Ave-Marias → botão "Ave-Maria 4/10".
    for (var i = 0; i < 6 + 4; i++) {
      await tester.tap(find.textContaining(RegExp(r'^(Amém ·|Ave-Maria  \d)')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    expect(find.text('Ave-Maria  4/10'), findsOneWidget);
    expect(s.userData.rosaryProgress()?.bead, 4);

    await tester.tap(find.byTooltip('Voltar uma conta'));
    await settle(tester);
    expect(find.text('Ave-Maria  3/10'), findsOneWidget);
    expect(s.userData.rosaryProgress()?.bead, 3);

    // X com progresso: pede confirmação e mantém a oração ao cancelar.
    await tester.tap(find.byTooltip('Encerrar'));
    await settle(tester);
    expect(find.text('Encerrar a oração?'), findsOneWidget);
    await tester.tap(find.text('Continuar rezando'));
    await settle(tester);
    expect(find.text('Ave-Maria  3/10'), findsOneWidget);
    expect(s.userData.rosaryProgress(), isNotNull);

    await tester.tap(find.byTooltip('Encerrar'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Encerrar'));
    await settle(tester);
    expect(find.text('Jornada de Maria'), findsOneWidget); // voltou à seleção de mistérios
    expect(s.userData.rosaryProgress(), isNull);
  });
}
