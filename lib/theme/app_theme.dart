import 'package:flutter/material.dart';
import '../data/local_database.dart';

/// App theme constants and styles for the Music Player Dashboard.
/// Designed with the Hallmark 'Atmospheric' & 'Modern Minimal' genres in mind:
/// Deep, muted backgrounds in dark mode, crisp clean surfaces in light mode,
/// subtle borders, high-contrast typography, and restrained accent colors.
class AppTheme {
  // ThemeMode notifier & persistence
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static ThemeMode get themeMode => themeModeNotifier.value;

  static bool isDark([BuildContext? context]) {
    if (context != null) {
      return Theme.of(context).brightness == Brightness.dark;
    }
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    if (themeModeNotifier.value == ThemeMode.light) return false;
    try {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode, {bool save = true}) async {
    themeModeNotifier.value = mode;
    if (!save) return;
    String val = 'system';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    try {
      await LocalDatabase.instance.saveSetting('theme_mode', val);
    } catch (_) {}
  }

  static Future<void> init() async {
    try {
      final saved = await LocalDatabase.instance.getSetting('theme_mode');
      if (saved == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else if (saved == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (saved == 'system') {
        themeModeNotifier.value = ThemeMode.system;
      }
    } catch (_) {}
  }

  // Dark Palette Constants (Atmospheric)
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color cardSurface = Color(0xFF161616);
  static const Color cardSurfaceHover = Color(0xFF1E1E1E);
  static const Color border = Color(0xFF262626);
  static const Color borderActive = Color(0xFF3A3A3A);

  static const Color primary = Color(0xFFE2E2E2);
  static const Color secondary = Color(0xFF888888);
  static const Color accentPink = Color(0xFFD4B1B8);
  static const Color accentAmber = Color(0xFFD2BCA0);
  static const Color accentGreen = Color(0xFF9FBFA5);

  static const Color textPrimary = Color(0xFFEBEBEB);
  static const Color textSecondary = Color(0xFFA1A1A1);
  static const Color textMuted = Color(0xFF6B6B6B);

  // Light Palette Constants (Modern Minimal)
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardSurface = Color(0xFFF1F3F5);
  static const Color lightCardSurfaceHover = Color(0xFFE9ECEF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderActive = Color(0xFFCBD5E1);

  static const Color lightPrimary = Color(0xFF18181B);
  static const Color lightSecondary = Color(0xFF64748B);
  static const Color lightAccentPink = Color(0xFFBE185D);
  static const Color lightAccentAmber = Color(0xFFB45309);
  static const Color lightAccentGreen = Color(0xFF15803D);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Context-aware color resolvers
  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? background : lightBackground;
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surface : lightSurface;
  static Color cardSurfaceOf(BuildContext context) =>
      isDark(context) ? cardSurface : lightCardSurface;
  static Color cardSurfaceHoverOf(BuildContext context) =>
      isDark(context) ? cardSurfaceHover : lightCardSurfaceHover;
  static Color borderOf(BuildContext context) =>
      isDark(context) ? border : lightBorder;
  static Color borderActiveOf(BuildContext context) =>
      isDark(context) ? borderActive : lightBorderActive;
  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimary : lightTextPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;
  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? textMuted : lightTextMuted;
  static Color primaryOf(BuildContext context) =>
      isDark(context) ? primary : lightPrimary;
  static Color secondaryOf(BuildContext context) =>
      isDark(context) ? secondary : lightSecondary;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF18181B),
      Color(0xFF111111),
      Color(0xFF0A0A0A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0xFF1C1C1C), Color(0xFF111111)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.black,
        secondary: secondary,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: -1.5, color: textPrimary),
        displayMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: -1.0, color: textPrimary),
        displaySmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.5, color: textPrimary),
        headlineMedium: TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.5, color: textPrimary),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2, color: textPrimary),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0, color: textPrimary),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0, color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: border,
        thumbColor: primary,
        overlayColor: Color(0x1AE2E2E2),
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerColor: border,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: Colors.white,
        secondary: lightSecondary,
        onSecondary: Colors.black,
        surface: lightSurface,
        onSurface: lightTextPrimary,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: -1.5, color: lightTextPrimary),
        displayMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: -1.0, color: lightTextPrimary),
        displaySmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.5, color: lightTextPrimary),
        headlineMedium: TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.5, color: lightTextPrimary),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2, color: lightTextPrimary),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0, color: lightTextPrimary),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0, color: lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightTextSecondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: lightPrimary,
        inactiveTrackColor: lightBorder,
        thumbColor: lightPrimary,
        overlayColor: Color(0x1A18181B),
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
      cardTheme: CardThemeData(
        color: lightCardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      dividerColor: lightBorder,
    );
  }
}
