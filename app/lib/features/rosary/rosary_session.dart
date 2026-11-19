import 'package:flutter/foundation.dart';

import '../../core/liturgical_calendar.dart';
import '../../data/models/mystery.dart';

enum RosaryMode { terco, rosario }

enum RosaryStage { intro, decades, closing, finished }

enum BeadEvent { bead, decadeCompleted, stageChanged, finished }

/// Etapa de oração exibida na tela.
class RosaryStep {
  const RosaryStep(this.prayerKey, this.label);
  final String prayerKey; // chave em mysteries.json > oracoes_do_terco
  final String label;
}

/// Máquina de estados do Santo Terço / Rosário (pura, sem UI — testável).
///
/// Introdução: Sinal da Cruz + Credo, Pai-Nosso, 3 Ave-Marias, Glória.
/// Cada dezena: Pai-Nosso (conta 0), 10 Ave-Marias (1..10), Glória + Ó meu Jesus (11).
/// Encerramento: Salve-Rainha.
class RosarySession extends ChangeNotifier {
  RosarySession({required this.mode, required this.set, required this.mysteries}) : assert(mysteries.isNotEmpty);

  final RosaryMode mode;
  final MysterySetId? set; // null no Rosário completo
  final List<Mystery> mysteries;

  RosaryStage stage = RosaryStage.intro;
  int decade = 0;
  int bead = 0;

  static const introSteps = [
    RosaryStep('credo', 'Sinal da Cruz e Credo'),
    RosaryStep('pai_nosso', 'Pai-Nosso'),
    RosaryStep('ave_maria', 'Ave-Maria (pela fé)'),
    RosaryStep('ave_maria', 'Ave-Maria (pela esperança)'),
    RosaryStep('ave_maria', 'Ave-Maria (pela caridade)'),
    RosaryStep('gloria', 'Glória ao Pai'),
  ];

  static const beadsPerDecade = 12; // Pai-Nosso + 10 Ave-Marias + Glória/Ó meu Jesus

  int get totalDecades => mysteries.length;
  Mystery get currentMystery => mysteries[decade.clamp(0, mysteries.length - 1)];

  /// Ave-Marias já concluídas na dezena atual (0..10) — alimenta as 10 contas.
  int get hailMarysInDecade {
    if (stage != RosaryStage.decades || bead == 0) return 0;
    return bead <= 10 ? bead - 1 : 10;
  }

  RosaryStep get currentStep {
    switch (stage) {
      case RosaryStage.intro:
        return introSteps[bead];
      case RosaryStage.decades:
        if (bead == 0) return const RosaryStep('pai_nosso', 'Pai-Nosso');
        if (bead <= 10) return RosaryStep('ave_maria', 'Ave-Maria $bead de 10');
        return const RosaryStep('gloria_fatima', 'Glória ao Pai e Ó meu Jesus');
      case RosaryStage.closing:
        return const RosaryStep('salve_rainha', 'Salve-Rainha');
      case RosaryStage.finished:
        return const RosaryStep('oracao_final', 'Terço concluído');
    }
  }

  /// Progresso total 0..1 (para a barra discreta).
  double get progress {
    final total = introSteps.length + totalDecades * beadsPerDecade + 1;
    final done = switch (stage) {
      RosaryStage.intro => bead,
      RosaryStage.decades => introSteps.length + decade * beadsPerDecade + bead,
      RosaryStage.closing => total - 1,
      RosaryStage.finished => total,
    };
    return done / total;
  }

  /// Avança uma conta. Retorna o evento para feedback háptico.
  BeadEvent advance() {
    late BeadEvent ev;
    switch (stage) {
      case RosaryStage.intro:
        if (bead < introSteps.length - 1) {
          bead++;
          ev = BeadEvent.bead;
        } else {
          stage = RosaryStage.decades;
          bead = 0;
          ev = BeadEvent.stageChanged;
        }
      case RosaryStage.decades:
        if (bead < beadsPerDecade - 1) {
          bead++;
          ev = bead == 11 ? BeadEvent.decadeCompleted : BeadEvent.bead;
        } else if (decade < totalDecades - 1) {
          decade++;
          bead = 0;
          ev = BeadEvent.stageChanged;
        } else {
          stage = RosaryStage.closing;
          bead = 0;
          ev = BeadEvent.stageChanged;
        }
      case RosaryStage.closing:
        stage = RosaryStage.finished;
        ev = BeadEvent.finished;
      case RosaryStage.finished:
        ev = BeadEvent.finished;
    }
    notifyListeners();
    return ev;
  }

  /// Volta uma conta (toque acidental).
  void back() {
    switch (stage) {
      case RosaryStage.intro:
        if (bead > 0) bead--;
      case RosaryStage.decades:
        if (bead > 0) {
          bead--;
        } else if (decade > 0) {
          decade--;
          bead = beadsPerDecade - 1;
        } else {
          stage = RosaryStage.intro;
          bead = introSteps.length - 1;
        }
      case RosaryStage.closing:
        stage = RosaryStage.decades;
        bead = beadsPerDecade - 1;
      case RosaryStage.finished:
        stage = RosaryStage.closing;
    }
    notifyListeners();
  }

  void restoreTo({required int decade, required int bead}) {
    stage = RosaryStage.decades;
    this.decade = decade.clamp(0, totalDecades - 1);
    this.bead = bead.clamp(0, beadsPerDecade - 1);
    notifyListeners();
  }
}
