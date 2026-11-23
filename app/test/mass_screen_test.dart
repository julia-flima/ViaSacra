// Acompanhar a Missa: dados do Ordinário e fluxo a partir da Liturgia.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:via_sacra/data/models/mass.dart';

import 'support/app_harness.dart';

void main() {
  setUpScreens();

  test('Ordinário: comuns resolvidos, Orações Eucarísticas I–IV e oração do Credo existente', () {
    final mass = OrdinaryOfMass.fromJson(
      jsonDecode(File('assets/data/ordinario_missa.json').readAsStringSync()) as Map<String, dynamic>,
    );
    final prayers = (jsonDecode(File('assets/data/prayers.json').readAsStringSync())['oracoes'] as List)
        .map((p) => p['id'])
        .toSet();
    final steps = [for (final p in mass.parts) ...p.steps];
    final eucharistic = steps.singleWhere((s) => s.variants.isNotEmpty).variants;

    expect(eucharistic.map((v) => v.id), ['I', 'II', 'III', 'IV']);
    expect(eucharistic.where((v) => v.isDefault).single.id, 'II');
    for (final v in eucharistic) {
      expect(v.steps.where((s) => s.title == 'Mistério da fé').single.options, hasLength(3));
      expect(v.steps.last.people, 'Amém.');
    }
    for (final s in [...steps, for (final v in eucharistic) ...v.steps]) {
      final hasText = s.people != null || s.options.isNotEmpty || s.prayerId != null || s.daily != null;
      expect(hasText || s.variants.isNotEmpty, isTrue, reason: 'passo sem resposta: ${s.title ?? s.cue}');
      if (s.prayerId != null) expect(prayers, contains(s.prayerId));
    }
  });

  testWidgets('Da Liturgia para a Missa: refrão do dia e troca de Oração Eucarística', (tester) async {
    final s = await buildServices(onboardingDone: true);
    await pumpApp(tester, s);

    await tester.tap(find.text('Acompanhar a Missa: respostas do povo'));
    await settle(tester);
    expect(find.text('Acompanhar a Missa'), findsOneWidget);
    expect(find.text('Fizestes de nós, para Deus, sacerdotes e povo de reis.'), findsOneWidget);

    final chip = find.widgetWithText(ActionChip, 'Liturgia Eucarística');
    await tester.ensureVisible(chip);
    await settle(tester);
    await tester.tap(chip);
    await settle(tester);
    expect(find.text('Enviai o vosso Espírito Santo!'), findsOneWidget); // II por padrão
    await tester.ensureVisible(find.text('III'));
    await settle(tester);
    await tester.tap(find.text('III'));
    await settle(tester);
    expect(find.text('Santificai e reuni o vosso povo!'), findsOneWidget);
  });
}
