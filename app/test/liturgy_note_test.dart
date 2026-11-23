// Anotação por leitura na Liturgia Diária (issue #61).
// (Arquivo próprio: o harness não suporta dois buildServices no mesmo arquivo.)
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();
  testWidgets('botão Anotar abre a folha, grava a nota e o ícone passa a indicar que há anotação', (tester) async {
    final s = await buildServices(onboardingDone: true);
    await pumpApp(tester, s);
    await settle(tester);

    final anotar = find.byTooltip('Anotar');
    expect(anotar, findsWidgets); // uma por leitura
    await tester.tap(anotar.first);
    await settle(tester);
    expect(find.text('Minha anotação (somente neste aparelho)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Deus cuida de cada ovelha.');
    Navigator.of(tester.element(find.byType(TextField).last)).pop(); // fecha a folha
    await settle(tester);

    final rows = s.database.db.select("SELECT ref, body FROM note WHERE kind = 'liturgy'");
    expect(rows.single['ref'], '2026-11-19#primeira_leitura'); // data da liturgia exibida
    expect(rows.single['body'], 'Deus cuida de cada ovelha.');
    expect(find.byTooltip('Ver anotação'), findsOneWidget);
  });
}
