import 'dart:async' show unawaited;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_navigation.dart';
import 'app_state.dart';
import 'core/liturgical_color.dart';
import 'core/theme.dart';
import 'features/bible/bible_screen.dart';
import 'features/library/library_screen.dart';
import 'features/liturgy/liturgy_screen.dart';
import 'features/rosary/rosary_screen.dart';
import 'features/settings/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'services/bible_service.dart';
import 'services/settings_service.dart';
import 'widgets/global_audio_mini_player.dart';
import 'widgets/keyboard_scroll.dart';

/// Comportamento de rolagem confortável em Desktop/Web (mouse, trackpad e toque).
class _ViaSacraScrollBehavior extends MaterialScrollBehavior {
  const _ViaSacraScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

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
        ChangeNotifierProvider.value(value: services.navigation),
        ChangeNotifierProvider(create: (_) => LiturgyController(services.liturgyRepository)),
      ],
      child:
          Selector2<
            SettingsService,
            LiturgyController,
            ({LiturgicalColor color, ReadingFont font, double lineHeight, ThemeMode themeMode, bool onboardingDone})
          >(
            selector: (_, settings, liturgy) => (
              color: liturgy.color,
              font: settings.readingFont,
              lineHeight: settings.lineHeight,
              themeMode: settings.themeMode,
              onboardingDone: settings.onboardingDone,
            ),
            builder: (context, state, _) {
              ThemeData theme(Brightness b) => AppTheme.build(
                brightness: b,
                liturgicalColor: state.color,
                font: state.font,
                lineHeight: state.lineHeight,
              );
              return MaterialApp(
                title: 'Via Sacra',
                debugShowCheckedModeBanner: false,
                navigatorKey: services.navigation.navigatorKey,
                scrollBehavior: const _ViaSacraScrollBehavior(),
                theme: theme(Brightness.light),
                darkTheme: theme(Brightness.dark),
                themeMode: state.themeMode,
                themeAnimationDuration: const Duration(milliseconds: 600),
                locale: const Locale('pt', 'BR'),
                supportedLocales: const [Locale('pt', 'BR')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => Selector<SettingsService, double>(
                  selector: (_, s) => s.textScale,
                  builder: (context, textScale, child) {
                    final mq = MediaQuery.of(context);
                    return MediaQuery(
                      data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale)),
                      child: KeyboardScrollScope(child: child!),
                    );
                  },
                  child: child!,
                ),
                home: state.onboardingDone ? const HomeShell() : const OnboardingScreen(),
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
  static const _pages = <Widget>[LiturgyScreen(), BibleScreen(), RosaryScreen(), LibraryScreen(), SettingsScreen()];

  static const _items = <(IconData, IconData, String)>[
    (Icons.today_outlined, Icons.today, 'Liturgia'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Bíblia'),
    (Icons.radio_button_unchecked, Icons.radio_button_checked, 'Terço'),
    (Icons.local_library_outlined, Icons.local_library, 'Biblioteca'),
    (Icons.tune_outlined, Icons.tune, 'Ajustes'),
  ];

  static const _allPlatforms = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.fuchsia,
  };

  late final List<ScrollController> _scrollControllers = List.generate(_pages.length, (_) => ScrollController());
  NavigationController? _nav;
  bool _bibleTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<NavigationController>();
    if (_nav != nav) {
      _nav?.removeListener(_onTabChanged);
      _nav = nav;
      nav.addListener(_onTabChanged);
      _onTabChanged();
    }
  }

  void _onTabChanged() {
    if (_bibleTriggered || _nav?.tab != AppTab.biblia) return;
    _bibleTriggered = true;
    unawaited(
      context.read<BibleService>().ensureBundled().catchError((Object e) {
        _bibleTriggered = false;
        debugPrint('Erro ao preparar Bíblia: $e');
      }),
    );
  }

  @override
  void dispose() {
    _nav?.removeListener(_onTabChanged);
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event, NavigationController nav) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isAltPressed) {
      const keys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      final i = keys.indexOf(event.logicalKey);
      if (i >= 0) {
        nav.go(AppTab.values[i]);
        return KeyEventResult.handled;
      }
    }
    return KeyboardScroll.handle(event, _scrollControllers[nav.tab.index], MediaQuery.sizeOf(context).height);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final seasonLabel = context.select<LiturgyController, String>((c) => c.day.season.label);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 600;
    final extendedRail = width >= 1024;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Cada aba possui seu próprio PrimaryScrollController (habilitando setas/PageUp/Home/End)
    // e ExcludeFocus nas abas ocultas para que TAB navegue apenas nos elementos visíveis.
    final pages = IndexedStack(
      index: nav.tab.index,
      children: [
        for (var i = 0; i < _pages.length; i++)
          // TickerMode pausa animações das abas ocultas e diz a cada aba se ela está visível
          // (o botão voltar só é interceptado pela aba que está na tela).
          TickerMode(
            enabled: i == nav.tab.index,
            child: ExcludeFocus(
              excluding: i != nav.tab.index,
              child: PrimaryScrollController(
                controller: _scrollControllers[i],
                automaticallyInheritForPlatforms: _allPlatforms,
                child: _pages[i],
              ),
            ),
          ),
      ],
    );

    final body = Column(
      children: [
        Expanded(child: pages),
        GlobalAudioMiniPlayer(useSafeArea: useRail),
      ],
    );

    final scaffold = Scaffold(
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: nav.tab.index,
                  extended: extendedRail,
                  minWidth: 80,
                  minExtendedWidth: 224,
                  labelType: extendedRail ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  onDestinationSelected: (i) => nav.go(AppTab.values[i]),
                  leading: Padding(
                    padding: EdgeInsets.fromLTRB(extendedRail ? 16 : 8, 16, extendedRail ? 16 : 8, 20),
                    child: extendedRail
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('✝', style: TextStyle(fontSize: 22, color: cs.primary)),
                                  const SizedBox(width: 8),
                                  Text('Via Sacra', style: t.titleLarge),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                seasonLabel,
                                style: t.bodySmall?.copyWith(color: cs.primary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : Text('✝', style: TextStyle(fontSize: 24, color: cs.primary)),
                  ),
                  destinations: [
                    for (final (icon, selected, label) in _items)
                      NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                  ],
                ),
                VerticalDivider(width: 1, thickness: 1, color: cs.outline),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: nav.tab.index,
              onDestinationSelected: (i) => nav.go(AppTab.values[i]),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final (icon, selected, label) in _items)
                  NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
              ],
            ),
    );

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        onKeyEvent: (_, event) => _handleKey(event, nav),
        child: scaffold,
      ),
    );
  }
}
