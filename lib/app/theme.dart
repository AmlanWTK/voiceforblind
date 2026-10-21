import 'package:flutter/material.dart';

/// Warm, high-contrast colours. Every text/background pair used here has a
/// contrast ratio of at least 4.5:1, and no state is shown by colour alone
/// (each also has an icon and words).
class ShuniColors {
  ShuniColors._();

  static const background = Color(0xFFFFF7E8); // warm cream
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E); // near-black text
  static const inkSoft = Color(0xFF4A4A5E);
  static const primary = Color(0xFF1E3A8A); // deep blue
  static const talk = Color(0xFFC2410C); // burnt orange
  static const listening = Color(0xFF15803D); // green
  static const thinking = Color(0xFF92400E); // dark amber
  static const notice = Color(0xFFFFE4B5);
  static const outline = Color(0xFFE0CFAF);
}

ThemeData buildShuniTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ShuniColors.primary,
    primary: ShuniColors.primary,
    onPrimary: Colors.white,
    surface: ShuniColors.surface,
    onSurface: ShuniColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ShuniColors.background,
    appBarTheme: const AppBarThemeData(
      backgroundColor: ShuniColors.background,
      foregroundColor: ShuniColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ShuniColors.ink,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: ShuniColors.ink),
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ShuniColors.ink),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShuniColors.ink),
      bodyLarge: TextStyle(fontSize: 20, height: 1.5, color: ShuniColors.ink),
      bodyMedium: TextStyle(fontSize: 18, height: 1.4, color: ShuniColors.ink),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ShuniColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(88, 72),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ShuniColors.primary,
        minimumSize: const Size(88, 64),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        side: const BorderSide(color: ShuniColors.primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
