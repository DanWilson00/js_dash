import 'package:flutter/material.dart';
import 'dashboard_config.dart';

/// Branding component for the top of the dashboard
class DashboardBranding extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const DashboardBranding({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = DashboardConfig.getBrandingFontSize(screenWidth);

    return Container(
      height: DashboardConfig.getBrandingHeight(screenHeight),
      alignment: Alignment.center,
      child: Text(
        DashboardConfig.brandingText,
        style: TextStyle(
          color: DashboardConfig.primaryAccent,
          fontSize: fontSize,
          fontWeight: FontWeight.w300,
          letterSpacing: DashboardConfig.getBrandingLetterSpacing(fontSize),
        ),
      ),
    );
  }
}
