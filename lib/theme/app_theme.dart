import 'dart:io';
import 'package:flutter/material.dart';

class AppTheme {
  // Theme Tokens from UI_AND_DESIGN_PRINCIPLES.md
  static const Color windowBackground = Color(0xFF141414);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLow = Color(0xFF1A1A1A);
  static const Color surfaceHigh = Color(0xFF222222);
  static const Color surfaceHigher = Color(0xFF282828);
  static const Color surfaceHighest = Color(0xFF323232);
  static const Color inputFill = Color(0xFF252526);
  static const Color border = Color(0xFF2C2C2C);
  static const Color inputBorder = Color(0xFF3E3E42);

  static const Color primaryAccent = Color(0xFF007ACC);
  static const Color secondaryCyan = Color(0xFF38BDF8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // CLI Command Preview Card Tokens
  static const Color cliCardBackground = Color(0xFF0F141C);
  static const Color cliCardBorder = Color(0xFF30363D);

  // Text Colors
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6E7681);

  static String get sansFontFamily {
    if (Platform.isWindows) return 'Segoe UI';
    if (Platform.isMacOS) return '.AppleSystemUIFont';
    return 'sans-serif';
  }

  static String get monoFontFamily {
    if (Platform.isWindows) return 'Consolas';
    if (Platform.isMacOS) return 'Menlo';
    return 'monospace';
  }

  static TextStyle monoStyle({
    double fontSize = 11.5,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: const ['Consolas', 'Menlo', 'DejaVu Sans Mono', 'monospace'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: sansFontFamily,
      scaffoldBackgroundColor: windowBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: Brightness.dark,
        primary: primaryAccent,
        surface: surface,
        surfaceContainerLowest: windowBackground,
        surfaceContainerLow: surfaceLow,
        surfaceContainer: surfaceHigh,
        surfaceContainerHigh: surfaceHigher,
        surfaceContainerHighest: surfaceHighest,
        error: error,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: const TextStyle(color: textMuted, fontSize: 12),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: error),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: inputBorder),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
