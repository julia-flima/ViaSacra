import 'package:flutter/foundation.dart';

/// Abas principais (barra inferior limpa, 5 destinos).
enum AppTab { liturgia, biblia, terco, biblioteca, ajustes }

/// Permite que uma aba peça para abrir outra (ex.: Liturgia → Bíblia).
class NavigationController extends ChangeNotifier {
  AppTab tab = AppTab.liturgia;

  void go(AppTab t) {
    if (tab == t) return;
    tab = t;
    notifyListeners();
  }
}
