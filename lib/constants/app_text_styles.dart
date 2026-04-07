import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Static (dark-default, used where no context available)

  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  static TextStyle displaySmall = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static TextStyle headingLarge = GoogleFonts.dmSans(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );
  static TextStyle headingMedium = GoogleFonts.dmSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static TextStyle headingSmall = GoogleFonts.dmSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle labelLarge = GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );
  static TextStyle labelMedium = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 1.0,
  );
  static TextStyle labelSmall = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 1.2,
  );
  static TextStyle goldLabel = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.goldPrimary,
    letterSpacing: 1.2,
  );
  static TextStyle goldHeading = GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.goldPrimary,
  );
  static TextStyle weightDisplay = GoogleFonts.dmMono(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -1.0,
  );
  static TextStyle weightSmall = GoogleFonts.dmMono(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle weightUnit = GoogleFonts.dmMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Context-aware (picks light or dark text color automatically)

  static TextStyle headingLargeOf(BuildContext context) =>
      headingLarge.copyWith(color: AppTheme.of(context).textPrimary);
  static TextStyle headingMediumOf(BuildContext context) =>
      headingMedium.copyWith(color: AppTheme.of(context).textPrimary);
  static TextStyle headingSmallOf(BuildContext context) =>
      headingSmall.copyWith(color: AppTheme.of(context).textPrimary);
  static TextStyle bodyMediumOf(BuildContext context) =>
      bodyMedium.copyWith(color: AppTheme.of(context).textPrimary);
  static TextStyle bodySmallOf(BuildContext context) =>
      bodySmall.copyWith(color: AppTheme.of(context).textSecondary);
  static TextStyle labelSmallOf(BuildContext context) =>
      labelSmall.copyWith(color: AppTheme.of(context).textMuted);
  static TextStyle displaySmallOf(BuildContext context) =>
      displaySmall.copyWith(color: AppTheme.of(context).textPrimary);
  static TextStyle weightSmallOf(BuildContext context) =>
      weightSmall.copyWith(color: AppTheme.of(context).textPrimary);
}
