import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bgPrimary = Color(0xFF0C0C0E);
  static const Color bgSecondary = Color(0xFF141416);
  static const Color bgCard = Color(0xFF1C1C1F);
  static const Color bgCardElevated = Color(0xFF242428);
  static const Color bgSurface = Color(0xFF2A2A2E);

  // Gold Palette
  static const Color goldPrimary = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8C97A);
  static const Color goldDark = Color(0xFF9A7A2E);
  static const Color goldDim = Color(0xFF3D3020);
  static const Color goldShimmer = Color(0xFFF5E0A0);

  // Text
  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF9B9B9B);
  static const Color textMuted = Color(0xFF5A5A5E);
  static const Color textOnGold = Color(0xFF0C0C0E);

  // Status
  static const Color success = Color(0xFF4CAF82);
  static const Color successDim = Color(0xFF1A3D2E);
  static const Color warning = Color(0xFFE8A020);
  static const Color warningDim = Color(0xFF3D2A08);
  static const Color error = Color(0xFFE05252);
  static const Color errorDim = Color(0xFF3D1818);
  static const Color info = Color(0xFF5B8DEF);
  static const Color infoDim = Color(0xFF1A2A4D);

  // Borders
  static const Color borderSubtle = Color(0xFF2A2A2E);
  static const Color borderGold = Color(0xFF3D3020);
  static const Color borderMedium = Color(0xFF3A3A3E);

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

  static Color categoryColor(String category) {
    return categoryColors[category] ?? const Color(0xFF9B9B9B);
  }
}
