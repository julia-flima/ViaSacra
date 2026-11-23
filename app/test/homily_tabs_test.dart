// Troca de abas em "Homilias e reflexões" (issue #56): esmaece em vez de trocar de golpe.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/features/liturgy/widgets/homily_section.dart';

void main() {
  testWidgets('troca de aba esmaece o texto e termina só com a aba nova', (tester) async {
    final json = jsonDecode(File('test/fixtures/liturgia-2026-11-19.json').readAsStringSync());
    final l = DailyLiturgy.fromJson(json as Map<String, dynamic>);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomilySection(liturgy: l, onListen: (_) {}),
          ),
        ),
      ),
    );
    final vatican = find.text(l.vaticanHomily!.title);
    final cnbb = find.text(l.cnbbReflection!.title);
    expect(vatican, findsOneWidget);
    expect(cnbb, findsNothing);

    await tester.tap(find.text('CNBB / Santos Padres'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // No meio da transição, as duas estão na tela (uma sumindo, outra aparecendo).
    expect(vatican, findsOneWidget);
    expect(cnbb, findsOneWidget);
    final fades = tester.widgetList<FadeTransition>(find.ancestor(of: vatican, matching: find.byType(FadeTransition)));
    expect(fades.any((f) => f.opacity.value > 0 && f.opacity.value < 1), isTrue);

    await tester.pumpAndSettle();
    expect(vatican, findsNothing);
    expect(cnbb, findsOneWidget);
  });
}
