import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sacred_art_header.dart';
import '../catechism/catechism_screen.dart';
import '../prayers/imitacao_screen.dart';
import '../prayers/prayers_screen.dart';
import '../prayers/via_sacra_screen.dart';

/// Aba 4 — Biblioteca: vitrine visual com arte sacra + Catecismo e Devocionário.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Explorar'),
            Tab(text: 'Catecismo'),
            Tab(text: 'Orações'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LibraryShowcase(onOpenTab: (i) => _tabs.animateTo(i)),
          const CatechismScreen(embedded: true),
          const PrayersScreen(embedded: true),
        ],
      ),
    );
  }
}

class _LibraryShowcase extends StatelessWidget {
  const _LibraryShowcase({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final art = context.read<AppServices>().content.art;
    final pad = VsSpacing.page(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final cards = [
      SacredArtCard(
        title: 'Catecismo',
        subtitle: 'São Pio X (978 perguntas), Catecismo Romano e CIC (1992)',
        badge: 'Doutrina',
        icon: Icons.menu_book_outlined,
        art: art['header-catecismo'],
        onTap: () => onOpenTab(1),
      ),
      SacredArtCard(
        title: 'Orações & Ladainhas',
        subtitle: 'Devocionário tradicional em Português e Latim + Exame de Consciência',
        badge: 'Devocionário',
        icon: Icons.volunteer_activism_outlined,
        art: art['header-oracoes'],
        onTap: () => onOpenTab(2),
      ),
      SacredArtCard(
        title: 'Via Sacra',
        subtitle: '14 estações guiadas por Santo Afonso Maria de Ligório com áudio',
        badge: '14 Estações',
        icon: Icons.church_outlined,
        art: art['dolorosos-4'],
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ViaSacraScreen())),
      ),
      SacredArtCard(
        title: 'A Imitação de Cristo',
        subtitle: 'Tomás de Kempis — 4 Livros, 114 capítulos offline e leitura do dia',
        badge: '114 Capítulos',
        icon: Icons.auto_stories_outlined,
        art: art['header-imitacao'],
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImitacaoScreen())),
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, VsSpacing.md, pad, VsSpacing.xxl),
      children: [
        const Eyebrow('FORMAÇÃO E DEVOÇÃO OFFLINE'),
        const SizedBox(height: VsSpacing.xs),
        Text(
          'Escolha uma obra ou devoção para rezar e estudar sem internet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: VsSpacing.md),
        if (wide)
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: VsSpacing.md,
            crossAxisSpacing: VsSpacing.md,
            childAspectRatio: 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cards,
          )
        else
          for (final card in cards) ...[card, const SizedBox(height: VsSpacing.md)],
      ],
    );
  }
}
