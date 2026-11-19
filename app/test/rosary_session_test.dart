import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/liturgical_calendar.dart';
import 'package:via_sacra/data/models/mystery.dart';
import 'package:via_sacra/features/rosary/rosary_session.dart';

List<Mystery> _mysteries(int n) => [
  for (var i = 1; i <= n; i++)
    Mystery(
      id: 'm$i',
      set: MysterySetId.gozosos,
      order: i,
      title: 'Mistério $i',
      fruit: 'Fruto',
      reference: 'Lc 1,1',
      reading: '…',
    ),
];

void main() {
  test('Terço completo: introdução, 5 dezenas, Salve-Rainha', () {
    final s = RosarySession(mode: RosaryMode.terco, set: MysterySetId.gozosos, mysteries: _mysteries(5));
    final events = <BeadEvent>[];
    while (s.stage != RosaryStage.finished) {
      events.add(s.advance());
    }
    expect(events.where((e) => e == BeadEvent.decadeCompleted), hasLength(5));
    expect(events.last, BeadEvent.finished);
    // 6 passos iniciais + 5×12 contas + Salve-Rainha
    expect(events, hasLength(6 + 5 * 12 + 1));
    expect(s.progress, 1.0);
  });

  test('Contas da dezena e voltar', () {
    final s = RosarySession(mode: RosaryMode.terco, set: MysterySetId.gozosos, mysteries: _mysteries(5));
    for (var i = 0; i < RosarySession.introSteps.length; i++) {
      s.advance();
    }
    expect(s.stage, RosaryStage.decades);
    expect(s.currentStep.prayerKey, 'pai_nosso');
    s.advance(); // 1ª Ave-Maria
    expect(s.currentStep.prayerKey, 'ave_maria');
    expect(s.hailMarysInDecade, 0);
    for (var i = 0; i < 10; i++) {
      s.advance();
    }
    expect(s.hailMarysInDecade, 10);
    expect(s.currentStep.prayerKey, 'gloria_fatima');
    s.back();
    expect(s.currentStep.label, 'Ave-Maria 10 de 10');
  });

  test('Rosário completo tem 20 dezenas', () {
    final s = RosarySession(mode: RosaryMode.rosario, set: null, mysteries: _mysteries(20));
    expect(s.totalDecades, 20);
    s.restoreTo(decade: 19, bead: 11);
    expect(s.advance(), BeadEvent.stageChanged);
    expect(s.stage, RosaryStage.closing);
  });
}
