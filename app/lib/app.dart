import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_navigation.dart';
import 'app_state.dart';
import 'core/theme.dart';
import 'features/bible/bible_screen.dart';
import 'features/library/library_screen.dart';
import 'features/liturgy/liturgy_screen.dart';
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
        ChangeNotifierProvider.value(value: services.bible),
        ChangeNotifierProvider(create: (_) => NavigationController()),
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

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pages = <Widget>[LiturgyScreen(), BibleScreen(), RosaryScreen(), LibraryScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    return Scaffold(
      body: IndexedStack(index: nav.tab.index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.tab.index,
        onDestinationSelected: (i) => nav.go(AppTab.values[i]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Liturgia'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Bíblia',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_unchecked),
            selectedIcon: Icon(Icons.radio_button_checked),
            label: 'Terço',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: 'Biblioteca',
          ),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Ajustes'),
        ],
      ),
    );
  }
}
