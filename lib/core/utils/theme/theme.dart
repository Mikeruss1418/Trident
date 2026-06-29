import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:trident/core/constants/app_colors.dart';
import 'package:trident/core/utils/textStyle/text_style_utils.dart';

class AppTheme {
  AppTheme._();

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // =========================
    // Core Colors
    // =========================
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.background,

    // =========================
    // Typography
    // =========================
    textTheme: AppTypography.darkTextTheme,

    // =========================
    // AppBar
    // =========================
    appBarTheme:  AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'GoogleSans',
        fontSize: 18.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    // =========================
    // Card
    // =========================
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // =========================
    // Divider
    // =========================
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 0.5,
    ),

    // =========================
    // Input
    // =========================
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(
        fontFamily: 'GoogleSans',
        color: AppColors.textTertiary,
      ),
      labelStyle: const TextStyle(
        fontFamily: 'GoogleSans',
        color: AppColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),

    // =========================
    // Bottom Nav
    // =========================
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    ),

    // =========================
    // Splash / Feedback
    // =========================
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
}
