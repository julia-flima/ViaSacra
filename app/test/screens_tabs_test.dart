// Smoke test de tela (um teste por arquivo: cada arquivo roda em um processo
// próprio, evitando estado compartilhado de plugins entre testes).
//   flutter test test/screens_tabs_test.dart
//   GOLDENS=1 flutter test test/screens_tabs_test.dart --update-goldens
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('Todas as abas renderizam sem erros', timeout: const Timeout(Duration(seconds: 60)), (tester) async {
    await pumpApp(tester, await buildServices(onboardingDone: true));

    // Aba 1 — Liturgia
    expect(find.text('Liturgia Diária'), findsWidgets);
    expect(find.textContaining('33ª Semana do Tempo Comum'), findsWidgets);
    expect(find.text('Ouvir Liturgia'), findsOneWidget);
    expect(find.text('Ap 5,1-10'), findsOneWidget);
    await shot(tester, '1-liturgia');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await settle(tester);
    await shot(tester, '2-salmo-evangelho');

    // Aba 3 — Terço
    await tester.tap(find.text('Terço'));
    await settle(tester);
    expect(find.text('Jornada de Maria'), findsOneWidget);
    expect(find.textContaining('6 dias seguidos'), findsOneWidget);
    await shot(tester, '3-terco');
    await tester.scrollUntilVisible(find.text('Rezar o Terço'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Rezar o Terço'));
    await settle(tester);
    for (var i = 0; i < 6 + 4; i++) {
      await tester.tap(find.textContaining(RegExp(r'^(Amém ·|Ave-Maria  \d)')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    expect(find.text('Ave-Maria  4/10'), findsOneWidget); // botão do contador
    await shot(tester, '4-contador');
    await tester.tap(find.byTooltip('Encerrar'));
    await settle(tester);

    // Aba 2 — Bíblia
    await tester.tap(find.text('Bíblia'));
    await settle(tester);
    expect(find.text('Bíblia Sagrada'), findsOneWidget);
    expect(find.text('ANTIGO TESTAMENTO'), findsOneWidget);
    await shot(tester, '9-biblia');

    // Aba 4 — Biblioteca › Catecismo
    await tester.tap(find.text('Biblioteca'));
    await settle(tester);
    await tester.tap(find.text('Catecismo'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'graça');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('§ 1996'), findsOneWidget);
    await shot(tester, '5-catecismo');

    // Biblioteca › Orações
    await tester.tap(find.text('Orações'));
    await settle(tester);
    await tester.tap(find.text('Pai-Nosso'));
    await settle(tester);
    await tester.tap(find.text('Latim'));
    await settle(tester);
    expect(find.textContaining('Pater noster'), findsWidgets);
    await shot(tester, '6-oracao-latim');
    await tester.tap(find.byType(BackButton)); // pageBack() não reconhece o BackButton do material_ui
    await settle(tester);

    // Aba 5 — Ajustes
    await tester.tap(find.text('Ajustes'));
    await settle(tester);
    expect(find.text('Ativar lembretes'), findsOneWidget);
    await shot(tester, '7-ajustes');
  });
}
