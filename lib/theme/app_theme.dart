import 'dart:io';
import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  /// Global runtime toggle updated when `SharedDeviceDatabase` changes.
  static bool isDark = true;

  // --- Surface & Structural Tokens ---
  static Color get scaffoldBg =>
      isDark ? const Color(0xFF141414) : const Color(0xFFF3F4F6);

  static Color get windowBackground => scaffoldBg;

  static Color get surface =>
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);

  static Color get surfaceLow =>
      isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB);

  static Color get surfaceHigh =>
      isDark ? const Color(0xFF252526) : const Color(0xFFF9FAFB);

  static Color get surfaceHigher =>
      isDark ? const Color(0xFF282828) : const Color(0xFFF3F4F6);

  static Color get surfaceHighest =>
      isDark ? const Color(0xFF323232) : const Color(0xFFE5E7EB);

  static Color get surfaceElevated =>
      isDark ? const Color(0xFF2D2D2D) : const Color(0xFFFFFFFF);

  static Color get inputFill =>
      isDark ? const Color(0xFF252526) : const Color(0xFFF9FAFB);

  static Color get border =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB);

  static Color get inputBorder =>
      isDark ? const Color(0xFF3E3E42) : const Color(0xFFD1D5DB);

  // --- Typography Tokens ---
  static Color get textPrimary =>
      isDark ? const Color(0xFFE0E0E0) : const Color(0xFF111827);

  static Color get textSecondary =>
      isDark ? const Color(0xFF9E9E9E) : const Color(0xFF4B5563);

  static Color get textMuted =>
      isDark ? const Color(0xFF6E6E6E) : const Color(0xFF6B7280);

  // --- Semantic & Action Tokens ---
  static Color get accent =>
      isDark ? const Color(0xFF007ACC) : const Color(0xFF0284C7);

  static Color get primaryAccent => accent;

  static Color get secondaryCyan =>
      isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

  static Color get success =>
      isDark ? const Color(0xFF10B981) : const Color(0xFF059669);

  static Color get warning =>
      isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);

  static Color get error =>
      isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  static Color get info =>
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

  // --- CLI Command Preview Card Tokens ---
  static Color get cliCardBackground =>
      isDark ? const Color(0xFF0F141C) : const Color(0xFFF8FAFC);

  static Color get cliCardBorder =>
      isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1);

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
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: const [
        'Consolas',
        'Menlo',
        'DejaVu Sans Mono',
        'monospace',
      ],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      height: height,
    );
  }

  // --- ThemeData Builders ---
  static ThemeData get currentTheme => isDark ? darkTheme() : lightTheme();

  static ThemeData darkTheme() {
    final prev = isDark;
    isDark = true;
    final theme = _buildTheme(Brightness.dark);
    isDark = prev;
    return theme;
  }

  static ThemeData lightTheme() {
    final prev = isDark;
    isDark = false;
    final theme = _buildTheme(Brightness.light);
    isDark = prev;
    return theme;
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryAccent,
      brightness: brightness,
      primary: primaryAccent,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerLowest: scaffoldBg,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceHigh,
      surfaceContainerHigh: surfaceHigher,
      surfaceContainerHighest: surfaceHighest,
      error: error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: sansFontFamily,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme,
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: textMuted, fontSize: 12),
        labelStyle: TextStyle(color: textSecondary, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: primaryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: error),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: inputBorder),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
