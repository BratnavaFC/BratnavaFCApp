import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness:   brightness,
      primary:      isDark ? Colors.white       : AppColors.slate900,
      onPrimary:    isDark ? AppColors.slate900 : Colors.white,
      secondary:    AppColors.slate600,
      onSecondary:  Colors.white,
      surface:      isDark ? AppColors.slate800 : Colors.white,
      onSurface:    isDark ? Colors.white       : AppColors.slate900,
      error:        AppColors.rose600,
      onError:      Colors.white,
      surfaceContainerHighest:
                    isDark ? AppColors.slate700 : AppColors.slate100,
      outline:      isDark ? AppColors.slate600 : AppColors.slate300,
    );

    final base = ThemeData(
      useMaterial3:  true,
      colorScheme:   colorScheme,
      scaffoldBackgroundColor:
                     isDark ? AppColors.slate900 : AppColors.slate50,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor:  isDark ? AppColors.slate900 : Colors.white,
        foregroundColor:  isDark ? Colors.white       : AppColors.slate900,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.slate900,
        ),
      ),
      cardTheme: CardThemeData(
        color:     isDark ? AppColors.slate800 : Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: isDark ? AppColors.slate800 : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate600 : AppColors.slate300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate600 : AppColors.slate300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.rose500),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.rose500, width: 2),
        ),
        hintStyle: TextStyle(
          color:    isDark ? AppColors.slate500 : AppColors.slate400,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color:    isDark ? AppColors.slate400 : AppColors.slate600,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.slate700 : AppColors.slate200,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.slate900 : Colors.white,
        indicatorColor:
            isDark ? AppColors.slate700 : AppColors.slate100,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
