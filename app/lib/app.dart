import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'core/theme.dart';
import 'features/catechism/catechism_screen.dart';
import 'features/liturgy/liturgy_screen.dart';
import 'features/prayers/prayers_screen.dart';
import 'features/rosary/rosary_screen.dart';
import 'features/settings/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'services/settings_service.dart';

class ViaSacraApp extends StatelessWidget {
  const ViaSacraApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<SettingsService>.value(value: services.settings),
        ChangeNotifierProvider.value(value: services.audio),
        ChangeNotifierProvider(create: (_) => LiturgyController(services.liturgyRepository)),
      ],
      child: Consumer2<SettingsService, LiturgyController>(
        builder: (context, settings, liturgy, _) {
          ThemeData theme(Brightness b) => AppTheme.build(
            brightness: b,
            liturgicalColor: liturgy.color,
            font: settings.readingFont,
            lineHeight: settings.lineHeight,
          );
          return MaterialApp(
            title: 'Via Sacra',
            debugShowCheckedModeBanner: false,
            theme: theme(Brightness.light),
            darkTheme: theme(Brightness.dark),
            themeMode: settings.themeMode,
            themeAnimationDuration: const Duration(milliseconds: 600),
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * settings.textScale)),
                child: child!,
              );
            },
            home: settings.onboardingDone ? const HomeShell() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _pages = <Widget>[LiturgyScreen(), RosaryScreen(), CatechismScreen(), PrayersScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Liturgia',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_unchecked),
            selectedIcon: Icon(Icons.radio_button_checked),
            label: 'Terço',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Catecismo',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            selectedIcon: Icon(Icons.local_florist),
            label: 'Orações',
          ),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Ajustes'),
        ],
      ),
    );
  }
}
