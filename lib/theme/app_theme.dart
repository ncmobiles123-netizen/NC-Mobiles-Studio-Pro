import 'package:flutter/material.dart';

/// Design tokens — mirrors the approved "Design Preview v2 (Light)" mockup.
/// Keep every raw color reference in the app funneled through here so the
/// theme can be re-skinned from one file.
class AppColors {
  AppColors._();

  static const canvas = Color(0xFFFFFFFF);
  static const scaffold = Color(0xFFFAFBFC);
  static const card = Color(0xFFF5F6F8);
  static const cardAlt = Color(0xFFEEF0F3);
  static const border = Color(0xFFE5E8EC);

  static const accent = Color(0xFF2F6FED);
  static const accentSoft = Color(0xFFEAF1FF);
  static const accentGlow = Color(0xFF5FC9E8);

  static const signalAmber = Color(0xFFFF9F43);
  static const danger = Color(0xFFE5484D);

  static const textHi = Color(0xFF12151C);
  static const textMid = Color(0xFF6B7280);
  static const textLow = Color(0xFF9AA1AC);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // No custom font is bundled in this drop (see README — add one
      // via pubspec's `fonts:` section and set fontFamily here if you
      // want a custom typeface instead of the platform default).
      scaffoldBackgroundColor: AppColors.scaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        primary: AppColors.accent,
        surface: AppColors.canvas,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textHi,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textHi,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textHi,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textLow,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textHi,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Reusable premium shadow (kept subtle — perf: shadows are cheap, blurred
  // gradients are not, so we favor these over glow effects).
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.textHi.withOpacity(0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
