import 'package:flutter/material.dart';

/// Application theme constants
class AppColors {
  // Primary colors
  static Color get primaryOrange => Colors.orange.shade700;
  static Color get primaryOrangeDark => Colors.orange.shade800;
  static Color get primaryOrangeLight => Colors.orange.shade300;

  // Status colors
  static Color get successGreen => Colors.green;
  static Color get warningOrange => Colors.orange;
  static Color get errorRed => Colors.red;

  // Neutral colors
  static Color get textPrimary => Colors.black;
  static Color get textSecondary => Colors.grey.shade700;
  static Color get textTertiary => Colors.grey.shade500;
  static Color get backgroundLight => Colors.grey.shade50;
  static Color get borderLight => Colors.grey.shade300;

  // Category colors
  static Color get categoryBlue => Colors.blue.shade700;
  static Color get categoryBlueLightBg => Colors.blue.shade50;
  static Color get categoryPurple => Colors.purple.shade700;
  static Color get categoryPurpleLightBg => Colors.purple.shade50;
}

/// Application spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Application text styles
class AppTextStyles {
  static TextStyle get largeTitle => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get subtitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyText => TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 12,
        color: AppColors.textTertiary,
      );
}

/// Animation durations
class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}
