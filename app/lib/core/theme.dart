import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import 'liturgical_color.dart';

/// Design tokens do Via Sacra — "minimalismo editorial sacro".
/// Ver `docs/DESIGN_SYSTEM.md`.
class VsColors {
  // Claro — Papel Pergaminho
  static const parchment = Color(0xFFFAF8F5);
  static const parchmentSurface = Color(0xFFF3EFE8);
  static const parchmentLine = Color(0xFFE4DDD0);
  static const charcoal = Color(0xFF1E1E1E);
  static const charcoalMuted = Color(0xFF5C5852);

  // Escuro — Modo Igreja
  static const church = Color(0xFF121212);
  static const churchSurface = Color(0xFF1C1B19);
  static const churchLine = Color(0xFF2E2C28);
  static const candle = Color(0xFFEDE6D8);
  static const candleMuted = Color(0xFFA59E92);

  // Acento
  static const gold = Color(0xFFB8860B);
  static const goldSoft = Color(0xFFD9B35A);
}

enum ReadingFont { serif, sans }

class VsSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Largura da barra lateral (NavigationRail) conforme breakpoints Material 3.
  static double railWidth(double windowWidth) {
    if (windowWidth >= 1024) return 224;
    if (windowWidth >= 600) return 80;
    return 0;
  }

  /// Margem lateral "de missal": generosa e centralizada em telas grandes,
  /// descontando automaticamente a largura do NavigationRail no desktop/tablet.
  static double page(BuildContext context) {
    final full = MediaQuery.sizeOf(context).width;
    final content = full - railWidth(full);
    if (content > 820) return (content - 720) / 2;
    if (content > 600) return 40;
    return 22;
  }
}

class AppTheme {
  static const _serifFallback = ['Merriweather', 'ViaSacraSymbols', 'Noto Serif', 'Georgia', 'serif'];
  static const _sansFallback = ['Roboto', 'ViaSacraSymbols', '.SF Pro Text', 'Helvetica Neue', 'sans-serif'];

  static ThemeData build({
    required Brightness brightness,
    required LiturgicalColor liturgicalColor,
    ReadingFont font = ReadingFont.serif,
    double lineHeight = 1.6,
  }) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? VsColors.church : VsColors.parchment;
    final surface = dark ? VsColors.churchSurface : VsColors.parchmentSurface;
    final line = dark ? VsColors.churchLine : VsColors.parchmentLine;
    final fg = dark ? VsColors.candle : VsColors.charcoal;
    final muted = dark ? VsColors.candleMuted : VsColors.charcoalMuted;
    final accent = liturgicalColor.accent(brightness);
    final gold = dark ? VsColors.goldSoft : VsColors.gold;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: dark ? VsColors.church : Colors.white,
      primaryContainer: Color.alphaBlend(accent.withValues(alpha: 0.14), bg),
      onPrimaryContainer: fg,
      secondary: gold,
      onSecondary: dark ? VsColors.church : Colors.white,
      secondaryContainer: Color.alphaBlend(gold.withValues(alpha: 0.14), bg),
      onSecondaryContainer: fg,
      tertiary: gold,
      onTertiary: Colors.white,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: bg,
      onSurface: fg,
      onSurfaceVariant: muted,
      surfaceContainerLowest: bg,
      surfaceContainerLow: Color.alphaBlend(surface.withValues(alpha: 0.5), bg),
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: Color.alphaBlend(line.withValues(alpha: 0.5), surface),
      outline: line,
      outlineVariant: line,
      shadow: Colors.black,
      inverseSurface: fg,
      onInverseSurface: bg,
    );

    final reading = font == ReadingFont.serif ? _serifFallback : _sansFallback;
    final base = dark ? Typography.material2021().white : Typography.material2021().black;

    // Títulos seguem a fonte escolhida nos Ajustes, como o texto de leitura.
    TextStyle? title(TextStyle? s, {double? size, FontWeight? w, double? h, double? ls}) => s?.copyWith(
      fontFamily: reading.first,
      fontFamilyFallback: reading.sublist(1),
      fontSize: size,
      fontWeight: w,
      height: h,
      letterSpacing: ls,
      color: fg,
    );
    TextStyle? body(TextStyle? s, {double? size}) => s?.copyWith(
      fontFamily: reading.first,
      fontFamilyFallback: reading.sublist(1),
      fontSize: size,
      height: lineHeight,
      color: fg,
    );
    TextStyle? ui(TextStyle? s, {Color? c, double? ls, FontWeight? w}) => s?.copyWith(
      fontFamily: _sansFallback.first,
      fontFamilyFallback: _sansFallback.sublist(1),
      color: c ?? fg,
      letterSpacing: ls,
      fontWeight: w,
    );

    final text = base.copyWith(
      displaySmall: title(base.displaySmall, size: 34, w: FontWeight.w400, h: 1.15),
      headlineMedium: title(base.headlineMedium, size: 28, w: FontWeight.w400, h: 1.2),
      headlineSmall: title(base.headlineSmall, size: 23, w: FontWeight.w400, h: 1.25),
      titleLarge: title(base.titleLarge, size: 20, w: FontWeight.w400, h: 1.3),
      titleMedium: ui(base.titleMedium, w: FontWeight.w500),
      titleSmall: ui(base.titleSmall, c: muted, w: FontWeight.w500),
      bodyLarge: body(base.bodyLarge, size: 17),
      bodyMedium: body(base.bodyMedium, size: 16),
      bodySmall: ui(base.bodySmall, c: muted),
      labelLarge: ui(base.labelLarge, ls: 0.3, w: FontWeight.w500),
      labelMedium: ui(base.labelMedium, c: muted, ls: 1.2),
      labelSmall: ui(base.labelSmall, c: muted, ls: 1.4),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: text,
      splashFactory: kIsWeb ? InkRipple.splashFactory : InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: dark ? VsColors.churchSurface : Colors.white.withValues(alpha: 0.72),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: VsSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: VsSpacing.lg),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.14),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(ui(base.labelSmall, c: muted, ls: 0.2)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? accent : muted, size: 24),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: line),
        backgroundColor: bg,
        selectedColor: accent.withValues(alpha: 0.16),
        labelStyle: ui(base.labelLarge),
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: line),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent)),
      iconTheme: IconThemeData(color: muted, size: 22),
      listTileTheme: ListTileThemeData(iconColor: muted, textColor: fg),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : muted),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent.withValues(alpha: 0.35) : line,
        ),
      ),
      sliderTheme: SliderThemeData(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: line),
      tabBarTheme: TabBarThemeData(
        labelColor: fg,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        dividerColor: line,
        labelStyle: ui(base.labelLarge),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: bg, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: bg, surfaceTintColor: Colors.transparent),
      focusColor: accent.withValues(alpha: 0.16),
      hoverColor: accent.withValues(alpha: 0.08),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(8),
        thumbColor: WidgetStatePropertyAll(muted.withValues(alpha: 0.35)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: fg,
        contentTextStyle: ui(base.bodyMedium, c: bg),
      ),
    );
  }
}
