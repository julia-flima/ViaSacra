import 'dart:async';

import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

/// Rolagem por teclado (setas, PageUp/PageDown, Espaço, Home/End) compartilhada
/// entre a HomeShell e as telas abertas por cima via `Navigator.push`.
abstract final class KeyboardScroll {
  static bool _isEditingText() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Rola [controller] conforme a tecla. Retorna `handled` se consumiu o evento.
  static KeyEventResult handle(KeyEvent event, ScrollController? controller, double viewportHeight) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (controller == null || !controller.hasClients || controller.positions.length != 1) {
      return KeyEventResult.ignored;
    }
    if (_isEditingText()) return KeyEventResult.ignored;

    final hw = HardwareKeyboard.instance;
    final page = viewportHeight * 0.8;
    final key = event.logicalKey;
    final pos = controller.position;
    double? target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = pos.pixels + 120;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = pos.pixels - 120;
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = pos.pixels + page;
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = pos.pixels - page;
    } else if (key == LogicalKeyboardKey.space && !hw.isControlPressed && !hw.isMetaPressed) {
      target = pos.pixels + (hw.isShiftPressed ? -page : page);
    } else if (key == LogicalKeyboardKey.home) {
      target = pos.minScrollExtent;
    } else if (key == LogicalKeyboardKey.end) {
      target = pos.maxScrollExtent;
    }
    if (target == null) return KeyEventResult.ignored;
    unawaited(
      controller.animateTo(
        target.clamp(pos.minScrollExtent, pos.maxScrollExtent),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      ),
    );
    return KeyEventResult.handled;
  }
}

/// Envolve o app (acima do Navigator) e rola o PrimaryScrollController da rota
/// em foco quando nenhum widget abaixo tratou a tecla — cobre telas empurradas.
class KeyboardScrollScope extends StatelessWidget {
  const KeyboardScrollScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        final focusCtx = FocusManager.instance.primaryFocus?.context;
        if (focusCtx == null || !focusCtx.mounted) return KeyEventResult.ignored;
        final controller = PrimaryScrollController.maybeOf(focusCtx);
        return KeyboardScroll.handle(event, controller, MediaQuery.sizeOf(context).height);
      },
      child: child,
    );
  }
}
