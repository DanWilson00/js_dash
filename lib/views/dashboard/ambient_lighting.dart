import 'package:flutter/material.dart';

/// Ambient lighting component for the dashboard background
class AmbientLighting extends StatelessWidget {
  final double pulseValue;
  
  const AmbientLighting({
    super.key,
    required this.pulseValue,
  });
  
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: AmbientLightingPainter(pulseValue: pulseValue),
      ),
    );
  }
}

/// Custom painter for ambient lighting effects
class AmbientLightingPainter extends CustomPainter {
  final double pulseValue;

  AmbientLightingPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle top lighting
    final topLight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          const Color(0xFF1a1a1a).withValues(alpha: 0.3 + (0.1 * pulseValue)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.3));
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.3),
      topLight,
    );
  }

  @override
  bool shouldRepaint(AmbientLightingPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}