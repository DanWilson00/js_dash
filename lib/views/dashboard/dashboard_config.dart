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
  static double getBrandingFontSize(double screenWidth) => (screenWidth * 0.028).clamp(20.0, 36.0);
  static double getBrandingLetterSpacing(double fontSize) => fontSize * 0.3;
  
  // Colors
  static const Color backgroundColor = Color(0xFF000000);
  static const Color gradientCenter = Color(0xFF0a0a0a);
  static const Color gradientEdge = Color(0xFF000000);
  static const Color brandingColor = Color(0xFFc0c0c0);
  
  // Animation Durations
  static const Duration rpmAnimationDuration = Duration(milliseconds: 800);
  static const Duration startupAnimationDuration = Duration(milliseconds: 1500);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 3000);
  
  // Update Configuration
  static const Duration updateInterval = Duration(milliseconds: 50);
  static const double smoothingFactor = 0.08;
  static const double rpmAnimationThreshold = 5.0;
  
  // Speed Conversion
  static const double speedConversionFactor = 1.94384; // m/s to knots
  
  // Branding Text
  static const String brandingText = 'JETSHARK';
}