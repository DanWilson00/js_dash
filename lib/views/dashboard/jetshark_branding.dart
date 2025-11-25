import 'package:flutter/material.dart';
import 'dashboard_config.dart';

/// Jetshark branding component for the top of the dashboard
class JetsharkBranding extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const JetsharkBranding({
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
