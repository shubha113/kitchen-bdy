import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Theme
  static const Color bgPrimary = Color(0xFF0C0C0E);
  static const Color bgSecondary = Color(0xFF141416);
  static const Color bgCard = Color(0xFF1C1C1F);
  static const Color bgCardElevated = Color(0xFF242428);
  static const Color bgSurface = Color(0xFF2A2A2E);

  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF9B9B9B);
  static const Color textMuted = Color(0xFF5A5A5E);
  static const Color textOnGold = Color(0xFF0C0C0E);

  static const Color borderSubtle = Color(0xFF2A2A2E);
  static const Color borderGold = Color(0xFF3D3020);
  static const Color borderMedium = Color(0xFF3A3A3E);

  // Light Theme
  static const Color lightBgPrimary = Color(0xFFF9F7F2);
  static const Color lightBgSecondary = Color(0xFFF2EFE8);
  static const Color lightBgCard = Color(0xFFFFFFFF);
  static const Color lightBgCardElevated = Color(0xFFF5F2EB);
  static const Color lightBgSurface = Color(0xFFEDE9DF);

  static const Color lightTextPrimary = Color(0xFF1A1508);
  static const Color lightTextSecondary = Color(0xFF6B6455);
  static const Color lightTextMuted = Color(0xFFADA599);

  static const Color lightBorderSubtle = Color(0xFFE8E3D8);
  static const Color lightBorderGold = Color(0xFFD4B870);
  static const Color lightBorderMedium = Color(0xFFD0C9BC);

  // Gold (shared)
  static const Color goldPrimary = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8C97A);
  static const Color goldDark = Color(0xFF9A7A2E);
  static const Color goldDim = Color(0xFF3D3020);
  static const Color goldShimmer = Color(0xFFF5E0A0);

  static const Color lightGoldDim = Color(
    0xFFF5EDD0,
  ); // light version of goldDim

  // Status (shared)
  static const Color success = Color(0xFF4CAF82);
  static const Color successDim = Color(0xFF1A3D2E);
  static const Color warning = Color(0xFFE8A020);
  static const Color warningDim = Color(0xFF3D2A08);
  static const Color error = Color(0xFFE05252);
  static const Color errorDim = Color(0xFF3D1818);
  static const Color info = Color(0xFF5B8DEF);
  static const Color infoDim = Color(0xFF1A2A4D);

  static const Color lightSuccessDim = Color(0xFFD6F0E5);
  static const Color lightWarningDim = Color(0xFFFAEDD0);
  static const Color lightErrorDim = Color(0xFFFADCDC);
  static const Color lightInfoDim = Color(0xFFD6E4FA);

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFF9A7A2E), Color(0xFFC9A84C), Color(0xFFE8C97A)],
    stops: [0.0, 0.5, 1.0],
  );
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0C0C0E), Color(0xFF141416)],
  );
  static const LinearGradient cardGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C1C1F), Color(0xFF242428)],
  );

  // Category Colors
  static const Map<String, Color> categoryColors = {
    'Grains': Color(0xFFD4A843),
    'Spices': Color(0xFFE05252),
    'Dairy': Color(0xFF5B8DEF),
    'Oils': Color(0xFF8BC34A),
    'Pulses': Color(0xFFFF9800),
    'Beverages': Color(0xFF9C27B0),
    'Snacks': Color(0xFFE91E63),
    'Other': Color(0xFF9B9B9B),
  };

  static Color categoryColor(String category) =>
      categoryColors[category] ?? const Color(0xFF9B9B9B);
}

class AppTheme {
  final bool isDark;
  const AppTheme._(this.isDark);

  static AppTheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppTheme._(brightness == Brightness.dark);
  }

  Color get bgPrimary =>
      isDark ? AppColors.bgPrimary : AppColors.lightBgPrimary;
  Color get bgSecondary =>
      isDark ? AppColors.bgSecondary : AppColors.lightBgSecondary;
  Color get bgCard => isDark ? AppColors.bgCard : AppColors.lightBgCard;
  Color get bgCardElevated =>
      isDark ? AppColors.bgCardElevated : AppColors.lightBgCardElevated;
  Color get bgSurface =>
      isDark ? AppColors.bgSurface : AppColors.lightBgSurface;

  Color get textPrimary =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textMuted =>
      isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  Color get borderSubtle =>
      isDark ? AppColors.borderSubtle : AppColors.lightBorderSubtle;
  Color get borderGold =>
      isDark ? AppColors.borderGold : AppColors.lightBorderGold;
  Color get borderMedium =>
      isDark ? AppColors.borderMedium : AppColors.lightBorderMedium;

  Color get goldDim => isDark ? AppColors.goldDim : AppColors.lightGoldDim;
  Color get successDim =>
      isDark ? AppColors.successDim : AppColors.lightSuccessDim;
  Color get warningDim =>
      isDark ? AppColors.warningDim : AppColors.lightWarningDim;
  Color get errorDim => isDark ? AppColors.errorDim : AppColors.lightErrorDim;
  Color get infoDim => isDark ? AppColors.infoDim : AppColors.lightInfoDim;

  // Gold & status are same in both themes
  Color get goldPrimary => AppColors.goldPrimary;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.info;
}
