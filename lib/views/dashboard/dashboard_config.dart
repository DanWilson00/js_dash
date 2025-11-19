import 'package:flutter/material.dart';

/// Configuration for the Jetshark Dashboard layout and appearance
class DashboardConfig {
  // Layout Configuration
  static const double leftWingFlex = 2.0;
  static const double centerGaugeFlex = 4.0;
  static const double rightWingFlex = 2.0;

  // Gauge Sizing
  static double getCenterGaugeSize(double screenWidth, double screenHeight) {
    return (screenWidth * 0.75).clamp(0, screenHeight * 0.85);
  }

  // Branding Configuration
  static double getBrandingHeight(double screenHeight) => screenHeight * 0.06;
  static double getBrandingFontSize(double screenWidth) =>
      (screenWidth * 0.028).clamp(20.0, 36.0);
  static double getBrandingLetterSpacing(double fontSize) => fontSize * 0.3;

  // Colors
  static const Color backgroundColor = Color(0xFF050510); // Deep blue-black
  static const Color gradientCenter = Color(0xFF0a1020);
  static const Color gradientEdge = Color(0xFF000000);
  static const Color primaryAccent = Color(0xFF00F0FF); // Neon Cyan
  static const Color secondaryAccent = Color(0xFF0080FF); // Deep Blue
  static const Color warningColor = Color(0xFFFF3366); // Neon Red/Pink
  static const Color successColor = Color(0xFF00FF99); // Neon Green
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8899AA);

  // Animation Durations
  static const Duration rpmAnimationDuration = Duration(milliseconds: 800);
  static const Duration startupAnimationDuration = Duration(milliseconds: 1500);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 3000);
  static const Duration gaugeAnimationDuration = Duration(milliseconds: 300);

  // Update Configuration - sync with other UI components
  static const Duration updateInterval = Duration(
    milliseconds: 50,
  ); // Faster updates for smoother feel
  static const double smoothingFactor = 0.15; // More responsive
  static const double rpmAnimationThreshold = 5.0;

  // Speed Conversion
  static const double speedConversionFactor = 1.94384; // m/s to knots

  // Branding Text
  static const String brandingText = 'JETSHARK';
}
