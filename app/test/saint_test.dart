// Santo do dia (issue #60): JSON do coletor → modelo → cartão na Liturgia.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:via_sacra/data/models/liturgy.dart';
import 'package:via_sacra/features/liturgy/saint_screen.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/liturgia-2026-11-19.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('lê "santos" do JSON e ignora entradas vazias; JSON antigo fica sem santos', () {
    expect(DailyLiturgy.fromJson(_fixture()).saints, isEmpty);
    final l = DailyLiturgy.fromJson(
      _fixture()
        ..['santos'] = [
          {
            'nome': 'S. Cecília, virgem e mártir',
            'resumo': 'História e lenda se entrelaçam em torno da figura de Santa Cecília.',
            'url': 'https://www.vaticannews.va/pt/santo-do-dia/11/22/s--cecilia.html',
            'fonte': 'Vatican News (Português)',
            'licenca': '© Libreria Editrice Vaticana',
          },
          {'nome': '', 'resumo': 'sem nome'},
        ],
    );
    expect(l.saints.single.name, 'S. Cecília, virgem e mártir');
    expect(l.saints.single.url, endsWith('s--cecilia.html'));
  });

  testWidgets('cartão mostra o nome, o começo do resumo e quantos santos a mais', (tester) async {
    final l = DailyLiturgy.fromJson(
      _fixture()
        ..['santos'] = [
          {'nome': 'S. Clemente I, papa e mártir', 'resumo': 'Terceiro sucessor de Pedro, escreveu aos coríntios.'},
          {'nome': 'S. Columbano, abade', 'resumo': 'Monge irlandês, fundou mosteiros por toda a Europa.'},
        ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SaintCard(liturgy: l)),
      ),
    );
    expect(find.text('S. Clemente I, papa e mártir'), findsOneWidget);
    expect(find.textContaining('Terceiro sucessor de Pedro'), findsOneWidget);
    expect(find.text('e mais 1 santo hoje'), findsOneWidget);
  });
}
