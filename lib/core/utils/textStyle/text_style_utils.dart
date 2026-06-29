import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:trident/core/constants/app_colors.dart';

class AppTextStyle {
  AppTextStyle._();

  static TextStyle base({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'GoogleSans',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

class AppTypography {
  AppTypography._();

  static TextTheme darkTextTheme = TextTheme(
    displayLarge: AppTextStyle.base(
      fontSize: 32.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    displayMedium: AppTextStyle.base(
      fontSize: 28.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    displaySmall: AppTextStyle.base(
      fontSize: 24.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),

    headlineLarge: AppTextStyle.base(
      fontSize: 22.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    headlineMedium: AppTextStyle.base(
      fontSize: 20.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    headlineSmall: AppTextStyle.base(
      fontSize: 18.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),

    titleLarge: AppTextStyle.base(
      fontSize: 18.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    titleMedium: AppTextStyle.base(
      fontSize: 16.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    titleSmall: AppTextStyle.base(
      fontSize: 14.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),

    bodyLarge: AppTextStyle.base(
      fontSize: 16.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    bodyMedium: AppTextStyle.base(
      fontSize: 14.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    bodySmall: AppTextStyle.base(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      letterSpacing: .2,
    ),

    labelLarge: AppTextStyle.base(
      fontSize: 14.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      letterSpacing: .2,
    ),
    labelMedium: AppTextStyle.base(
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      letterSpacing: .2,
    ),
    labelSmall: AppTextStyle.base(
      fontSize: 10.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.textTertiary,
      letterSpacing: .2,
    ),
  );
}