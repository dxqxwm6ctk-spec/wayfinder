import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF060B16);
  static const Color backgroundElevated = Color(0xFF0B1323);
  static const Color surface = Color(0xFF121D32);
  static const Color surfaceSoft = Color(0xFF1A2640);
  static const Color glass = Color(0xFF20314D);
  static const Color card = Color(0xFF101B31);
  static const Color textPrimary = Color(0xFFF4F8FF);
  static const Color textSecondary = Color(0xFF9CAFD1);
  static const Color textMuted = Color(0xFF6E7FA1);
  static const Color accent = Color(0xFF3A7BFF);
  static const Color accentLight = Color(0xFF71C8FF);
  static const Color accentElectric = Color(0xFF4EA6FF);
  static const Color lightBackground = Color(0xFFF4F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF0F4FA);
  static const Color lightTextPrimary = Color(0xFF142033);
  static const Color lightTextSecondary = Color(0xFF5F6D85);
  static const Color critical = Color(0xFFFF5E6A);
  static const Color moderate = Color(0xFF7AB8FF);
  static const Color stable = Color(0xFF34C3FF);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF7CD6FF), Color(0xFF3A7BFF)],
  );

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF0B1731), Color(0xFF060C18)],
  );
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final Color primary =
        brightness == Brightness.dark ? AppColors.textPrimary : const Color(0xFF111827);
    final Color secondary =
        brightness == Brightness.dark ? AppColors.textSecondary : const Color(0xFF6B7280);

    return GoogleFonts.notoSansArabicTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.notoSansArabic(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineLarge: GoogleFonts.notoSansArabic(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: GoogleFonts.notoSansArabic(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: GoogleFonts.notoSansArabic(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.notoSansArabic(
        fontSize: 15,
        height: 1.45,
        color: primary,
      ),
      bodyMedium: GoogleFonts.notoSansArabic(
        fontSize: 14,
        height: 1.45,
        color: secondary,
      ),
      bodySmall: GoogleFonts.notoSansArabic(
        fontSize: 12,
        height: 1.4,
        color: secondary,
      ),
      labelLarge: GoogleFonts.notoSansArabic(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: secondary,
      ),
      labelMedium: GoogleFonts.notoSansArabic(
        fontSize: 10,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: secondary,
      ),
    );
  }

  static ThemeData get dark {
    final TextTheme textTheme = _textTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentElectric,
        surface: AppColors.surface,
        error: Color(0xFFE66B7A),
      ),
      textTheme: textTheme,
      cardColor: AppColors.card,
      dividerColor: Colors.white.withValues(alpha: 0.08),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accentLight.withValues(alpha: 0.55);
            }
            return Colors.white.withValues(alpha: 0.15);
          },
        ),
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textPrimary;
            }
            return AppColors.textSecondary;
          },
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glass.withValues(alpha: 0.45),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
        labelStyle: textTheme.bodySmall,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.accentLight, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  static ThemeData get light {
    final TextTheme textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentElectric,
        surface: AppColors.lightSurface,
        error: Color(0xFFD64556),
      ),
      textTheme: textTheme,
      cardColor: AppColors.lightSurface,
      dividerColor: Colors.black.withValues(alpha: 0.08),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2A3D),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent.withValues(alpha: 0.35);
            }
            return const Color(0xFFD7DFED);
          },
        ),
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accent;
            }
            return const Color(0xFF9AA7C0);
          },
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceSoft,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.lightTextSecondary),
        labelStyle: textTheme.bodySmall,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD6DEEB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          side: const BorderSide(color: Color(0xFFD1DAEA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}
