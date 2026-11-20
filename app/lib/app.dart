import 'dart:async' show unawaited;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
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
import 'services/bible_service.dart';
import 'services/settings_service.dart';

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
            scrollBehavior: const _ViaSacraScrollBehavior(),
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

  bool _isEditingText() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _scrollActive(int tabIndex, double delta, {bool toStart = false, bool toEnd = false}) {
    final ctrl = _scrollControllers[tabIndex];
    if (!ctrl.hasClients) return;
    final pos = ctrl.position;
    final target = toStart
        ? pos.minScrollExtent
        : toEnd
        ? pos.maxScrollExtent
        : (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    unawaited(ctrl.animateTo(target, duration: const Duration(milliseconds: 140), curve: Curves.easeOut));
  }

  KeyEventResult _handleKey(KeyEvent event, NavigationController nav) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_isEditingText()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final hw = HardwareKeyboard.instance;
    final viewport = MediaQuery.sizeOf(context).height * 0.8;
    final idx = nav.tab.index;

    if (hw.isAltPressed) {
      if (key == LogicalKeyboardKey.digit1) {
        nav.go(AppTab.liturgia);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit2) {
        nav.go(AppTab.biblia);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit3) {
        nav.go(AppTab.terco);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit4) {
        nav.go(AppTab.biblioteca);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit5) {
        nav.go(AppTab.ajustes);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollActive(idx, 120);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _scrollActive(idx, -120);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      _scrollActive(idx, viewport);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      _scrollActive(idx, -viewport);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && !hw.isControlPressed && !hw.isMetaPressed) {
      _scrollActive(idx, hw.isShiftPressed ? -viewport : viewport);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _scrollActive(idx, 0, toStart: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _scrollActive(idx, 0, toEnd: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final liturgy = context.watch<LiturgyController>();
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 600;
    final extendedRail = width >= 1024;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Cada aba possui seu próprio PrimaryScrollController (habilitando setas/PageUp/Home/End)
    // e ExcludeFocus nas abas ocultas para que TAB navegue apenas nos elementos visíveis.
    final body = IndexedStack(
      index: nav.tab.index,
      children: [
        for (var i = 0; i < _pages.length; i++)
          ExcludeFocus(
            excluding: i != nav.tab.index,
            child: PrimaryScrollController(
              controller: _scrollControllers[i],
              automaticallyInheritForPlatforms: _allPlatforms,
              child: _pages[i],
            ),
          ),
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
                                liturgy.day.season.label,
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
