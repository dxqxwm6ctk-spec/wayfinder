import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF05070B);
  static const Color surface = Color(0xFF111318);
  static const Color surfaceSoft = Color(0xFF1A1D24);
  static const Color card = Color(0xFF0D1118);
  static const Color textPrimary = Color(0xFFF5F7FB);
  static const Color textSecondary = Color(0xFF8E94A3);
  static const Color accent = Color(0xFF2C82FF);
  static const Color accentLight = Color(0xFF84ABFF);
  static const Color critical = Color(0xFFFF5E6A);
  static const Color moderate = Color(0xFFB372FF);
  static const Color stable = Color(0xFF2C82FF);
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final Color primary =
        brightness == Brightness.dark ? AppColors.textPrimary : const Color(0xFF111827);
    final Color secondary =
        brightness == Brightness.dark ? AppColors.textSecondary : const Color(0xFF6B7280);

    return GoogleFonts.spaceGroteskTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 44,
        height: 1.06,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        color: primary,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        color: secondary,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w700,
        color: secondary,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        letterSpacing: 1.6,
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
        secondary: AppColors.accentLight,
        surface: AppColors.surface,
        error: Color(0xFFE66B7A),
      ),
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceSoft,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentLight, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      ),
    );
  }

  static ThemeData get light {
    final TextTheme textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FC),
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentLight,
        surface: Colors.white,
        error: Color(0xFFD64556),
      ),
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF111827),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEFF2F7),
        hintStyle: textTheme.bodyLarge?.copyWith(color: const Color(0xFF6B7280)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      ),
    );
  }
}
