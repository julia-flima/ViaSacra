import 'package:material_ui/material_ui.dart';

import '../catechism/catechism_screen.dart';
import '../prayers/prayers_screen.dart';

/// Aba 4 — Biblioteca: Catecismo e Devocionário em sub-abas no topo.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Catecismo'),
              Tab(text: 'Orações'),
            ],
          ),
        ),
        body: const TabBarView(children: [CatechismScreen(embedded: true), PrayersScreen(embedded: true)]),
      ),
    );
  }
}
