import 'package:flutter/material.dart';

class AmalfiTheme {
  static const turquoise = Color(0xFF079F9F);
  static const turquoiseDark = Color(0xFF087B7D);
  static const navy = Color(0xFF075B5B);
  static const background = Color(0xFF071B1B);
  static const graphite = Color(0xFF102727);
  static const input = Color(0xFF173333);
  static const muted = Color(0xFFA5BBB4);
  static const success = Color(0xFF278A4D);
  static const successDark = Color(0xFF56B879);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFB72D32);
  static const errorDark = Color(0xFFE45B60);

  static Color mutedFor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static TextStyle mutedText(BuildContext context, {double? fontSize}) =>
      TextStyle(color: mutedFor(context), fontSize: fontSize);

  static Color panelFor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color pageFor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color outlineFor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color brandFor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color deepBrandFor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  static Color successFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? successDark : success;

  static Color errorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? errorDark : error;

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    const surface = graphite;
    const border = Color(0xFF28504D);
    const text = Color(0xFFF1F7F4);
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF16B9B4),
        onPrimary: background,
        secondary: Color(0xFF075B5B),
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        surfaceContainerHighest: input,
        outlineVariant: border,
        error: errorDark,
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: input,
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        floatingLabelStyle: const TextStyle(color: Color(0xFF16B9B4)),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(9),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(9),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF16B9B4), width: 1.6),
          borderRadius: BorderRadius.circular(9),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: errorDark),
          borderRadius: BorderRadius.circular(9),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF16B9B4),
          foregroundColor: background,
          minimumSize: const Size(120, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Color(0xFF16B9B4),
          foregroundColor: background,
          minimumSize: const Size(44, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFF16B9B4),
          side: const BorderSide(color: Color(0xFF075B5B)),
          minimumSize: const Size(44, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Color(0xFF16B9B4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: background,
        selectedIconTheme: IconThemeData(color: Colors.white),
        selectedLabelTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: muted),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    const surface = Color(0xFFFFFFFF);
    const border = Color(0xFFD6E2DE);
    const mutedLight = Color(0xFF61736F);
    const text = Color(0xFF183532);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F3EB),
      canvasColor: surface,
      colorScheme: const ColorScheme.light(
        primary: turquoise,
        onPrimary: background,
        secondary: turquoiseDark,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: mutedLight,
        surfaceContainerHighest: Color(0xFFEAF2EF),
        outlineVariant: border,
        error: error,
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: const Color(0x1A075B5B),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFEAF2EF),
        hintStyle: const TextStyle(color: mutedLight),
        labelStyle: const TextStyle(color: mutedLight),
        floatingLabelStyle: const TextStyle(color: turquoiseDark),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(9),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(9),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: turquoiseDark, width: 1.6),
          borderRadius: BorderRadius.circular(9),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: error),
          borderRadius: BorderRadius.circular(9),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: turquoise,
          foregroundColor: background,
          minimumSize: const Size(120, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: turquoise,
          foregroundColor: background,
          minimumSize: const Size(44, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: turquoise,
          side: const BorderSide(color: turquoiseDark),
          minimumSize: const Size(44, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: turquoise,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
