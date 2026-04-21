import 'package:flutter/material.dart';

ThemeData buildClinDiaryTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;

  final background = isDark ? const Color(0xFF0F131A) : const Color(0xFFF5F7FA);
  final surface = isDark ? const Color(0xFF171C24) : Colors.white;
  final primary = isDark ? const Color(0xFF97B0E8) : const Color(0xFF334155);
  final accent = isDark ? const Color(0xFFD0A27C) : const Color(0xFF8B6C55);
  final ink = isDark ? const Color(0xFFF2F4F8) : const Color(0xFF20262F);
  final outline = isDark ? const Color(0xFF313A48) : const Color(0xFFD9DEE6);
  final fill = isDark ? const Color(0xFF202634) : const Color(0xFFF4F6F9);

  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          secondary: accent,
          surface: surface,
          onSurface: ink,
          onPrimary: isDark ? const Color(0xFF11141E) : Colors.white,
          outline: outline,
          surfaceTint: Colors.transparent,
        ),
  );

  final textTheme = baseTheme.textTheme
      .apply(bodyColor: ink, displayColor: ink)
      .copyWith(
        headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(height: 1.42),
        bodySmall: baseTheme.textTheme.bodySmall?.copyWith(height: 1.38),
        labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );

  return baseTheme.copyWith(
    scaffoldBackgroundColor: background,
    canvasColor: background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: isDark ? 0.28 : 0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? primary : ink.withValues(alpha: 0.7),
        );
      }),
      labelTextStyle: WidgetStateProperty.all(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: outline.withValues(alpha: 0.72),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: primary, width: 2.2),
        insets: const EdgeInsets.symmetric(horizontal: 10),
      ),
      labelColor: primary,
      unselectedLabelColor: ink.withValues(alpha: 0.62),
      labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      unselectedLabelStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: isDark ? 0.22 : 0.12);
          }
          return fill;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return ink.withValues(alpha: 0.82);
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return ink.withValues(alpha: 0.76);
        }),
        textStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelLarge?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
          );
        }),
        side: WidgetStatePropertyAll(BorderSide(color: outline)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: outline),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outline, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fill,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      side: BorderSide(color: outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: outline),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      dense: false,
      visualDensity: VisualDensity(horizontal: 0, vertical: -1),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    ),
  );
}
