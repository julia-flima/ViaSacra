import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Indicador visual das 10 contas da dezena, dispostas em arco.
class DecadeBeads extends StatelessWidget {
  const DecadeBeads({super.key, required this.count, required this.ourFather, required this.glory});

  /// Ave-Marias já rezadas (0..10).
  final int count;

  /// Conta do Pai-Nosso ativa.
  final bool ourFather;

  /// Glória/Ó meu Jesus ativo (dezena completa).
  final bool glory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: glory ? 'Dezena concluída' : '$count de 10 Ave-Marias',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 120,
          child: CustomPaint(
            size: const Size(double.infinity, 120),
            painter: _BeadsPainter(
              count: count,
              ourFather: ourFather,
              glory: glory,
              done: cs.primary,
              todo: cs.outline,
              gold: cs.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BeadsPainter extends CustomPainter {
  _BeadsPainter({
    required this.count,
    required this.ourFather,
    required this.glory,
    required this.done,
    required this.todo,
    required this.gold,
  });

  final int count;
  final bool ourFather;
  final bool glory;
  final Color done;
  final Color todo;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.55);
    final radius = size.height * 1.3;
    final cord = Paint()
      ..color = todo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const start = math.pi + math.pi * 0.22, sweep = math.pi * 0.56;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, cord);
    for (var i = 0; i < 10; i++) {
      final a = start + sweep * (i + 0.5) / 10;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      final filled = i < count;
      final current = i == count && !glory && !ourFather;
      canvas.drawCircle(
        p,
        current ? 9 : 8,
        Paint()
          ..color = filled ? done : (current ? done.withValues(alpha: 0.18) : todo.withValues(alpha: 0.35))
          ..style = PaintingStyle.fill,
      );
      if (current) {
        canvas.drawCircle(
          p,
          11,
          Paint()
            ..color = done
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    // Conta maior do Pai-Nosso / Glória no topo do arco
    final top = Offset(size.width / 2, size.height * 0.14);
    canvas.drawCircle(top, 11, Paint()..color = (ourFather || glory) ? gold : todo.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_BeadsPainter old) =>
      old.count != count || old.ourFather != ourFather || old.glory != glory || old.done != done;
}
