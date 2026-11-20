import 'package:flutter/widgets.dart';

/// Abas principais (barra inferior limpa, 5 destinos).
enum AppTab { liturgia, biblia, terco, biblioteca, ajustes }

/// Permite que uma aba peça para abrir outra (ex.: Liturgia → Bíblia).
class NavigationController extends ChangeNotifier {
  AppTab tab = AppTab.liturgia;

  /// Navigator raiz (para fechar telas abertas por cima ao vir de um lembrete).
  final navigatorKey = GlobalKey<NavigatorState>();

  /// Abre a aba correspondente ao payload do lembrete ('liturgia' ou 'terco').
  void openFromNotification(String? payload) {
    final target = switch (payload) {
      'liturgia' => AppTab.liturgia,
      'terco' => AppTab.terco,
      _ => null,
    };
    if (target == null) return;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    go(target);
  }

  void go(AppTab t) {
    if (tab == t) return;
    tab = t;
    notifyListeners();
  }
}
