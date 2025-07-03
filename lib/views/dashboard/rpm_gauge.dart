import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Central RPM gauge with speed display
class RPMGauge extends StatelessWidget {
  final double rpm;
  final double speed;
  final double gaugeSize;
  final Animation<double> rpmAnimation;
  final Animation<double> pulseAnimation;
  
  const RPMGauge({
    super.key,
    required this.rpm,
    required this.speed,
    required this.gaugeSize,
    required this.rpmAnimation,
    required this.pulseAnimation,
  });
  
  @override
  Widget build(BuildContext context) {
    // RPM range: 0 to 7000 RPM
    final rpmPercent = (rpm / 7000).clamp(0.0, 1.0);
    
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([rpmAnimation, pulseAnimation]),
        builder: (context, child) {
          return SizedBox(
            width: gaugeSize,
            height: gaugeSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // RPM gauge
                CustomPaint(
                  size: Size(gaugeSize, gaugeSize),
                  painter: RPMGaugePainter(
                    rpmPercent: rpmPercent,
                    rpm: rpm,
                    pulseValue: pulseAnimation.value,
                  ),
                ),
                
                // Central speed display
                _buildSpeedDisplay(),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSpeedDisplay() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          speed.round().toString().padLeft(2, '0'),
          style: TextStyle(
            color: Colors.white,
            fontSize: gaugeSize * 0.24,
            fontWeight: FontWeight.w200,
            fontFamily: 'monospace',
          ),
        ),
        SizedBox(height: gaugeSize * 0.02),
        Text(
          'km/h',
          style: TextStyle(
            color: const Color(0xFF808080),
            fontSize: gaugeSize * 0.045,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: gaugeSize * 0.04),
        // Show actual RPM value below speed
        Text(
          '${rpm.round()} RPM',
          style: TextStyle(
            color: const Color(0xFF4a90e2),
            fontSize: gaugeSize * 0.05,
            fontWeight: FontWeight.w300,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the RPM gauge
class RPMGaugePainter extends CustomPainter {
  final double rpmPercent;
  final double rpm;
  final double pulseValue;

  RPMGaugePainter({
    required this.rpmPercent,
    required this.rpm,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    
    // Draw background circle
    _drawBackground(canvas, center, radius);
    
    // Draw tick marks
    _drawTickMarks(canvas, center, radius);
    
    // Draw RPM arc
    _drawRPMArc(canvas, center, radius);
    
    // Draw center decorations
    _drawCenterDecorations(canvas, center, radius);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    // Dark background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF0a0a0a)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, bgPaint);
    
    // Subtle inner shadow
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, shadowPaint);
  }

  void _drawRPMArc(Canvas canvas, Offset center, double radius) {
    const startAngle = -math.pi * 1.25;
    const totalAngle = math.pi * 1.5;
    final sweepAngle = totalAngle * rpmPercent;
    
    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      startAngle,
      totalAngle,
      false,
      trackPaint,
    );
    
    // Progress arc
    if (rpmPercent > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.04
        ..strokeCap = StrokeCap.round;
      
      // Color based on RPM percentage
      if (rpmPercent < 0.6) { // Under 4200 RPM
        progressPaint.color = const Color(0xFF4a90e2); // Blue
      } else if (rpmPercent < 0.85) { // 4200-5950 RPM  
        progressPaint.color = const Color(0xFFf5a623); // Orange
      } else { // Over 5950 RPM
        progressPaint.color = const Color(0xFFd0021b); // Red
      }
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.88),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    const startAngle = -math.pi * 1.25;
    const totalAngle = math.pi * 1.5;
    const tickCount = 15; // 0 to 7000 in increments of 500
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (int i = 0; i < tickCount; i++) {
      final angle = startAngle + (totalAngle * i / (tickCount - 1));
      final tickRadius = radius * 0.88;
      final rpmValue = i * 500; // 0, 500, 1000, ..., 7000
      final isMajor = rpmValue % 1000 == 0;
      
      // Draw tick marks
      final tickPaint = Paint()
        ..color = const Color(0xFF606060)
        ..strokeWidth = isMajor ? 2.5 : 1.5;
      
      final tickLength = isMajor ? radius * 0.05 : radius * 0.025;
      final start = Offset(
        center.dx + (tickRadius + tickLength) * math.cos(angle),
        center.dy + (tickRadius + tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + tickRadius * math.cos(angle),
        center.dy + tickRadius * math.sin(angle),
      );
      
      canvas.drawLine(start, end, tickPaint);
      
      // Draw numbers only for major ticks (every 1000 RPM)
      if (isMajor) {
        final displayValue = rpmValue >= 1000 ? (rpmValue / 1000).round() : 0;
        textPainter.text = TextSpan(
          text: displayValue.toString(),
          style: TextStyle(
            color: const Color(0xFF808080),
            fontSize: radius * 0.06,
            fontWeight: FontWeight.w300,
          ),
        );
        textPainter.layout();
        
        final textRadius = radius * 0.72;
        final textOffset = Offset(
          center.dx + textRadius * math.cos(angle) - textPainter.width / 2,
          center.dy + textRadius * math.sin(angle) - textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
    
    // RPM label
    textPainter.text = TextSpan(
      text: 'RPM x1000',
      style: TextStyle(
        color: const Color(0xFF606060),
        fontSize: radius * 0.04,
        fontWeight: FontWeight.w300,
        letterSpacing: 1,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center + Offset(-textPainter.width / 2, radius * 0.4),
    );
  }

  void _drawCenterDecorations(Canvas canvas, Offset center, double radius) {
    // Center dot
    final centerPaint = Paint()
      ..color = const Color(0xFF303030)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.025, centerPaint);
  }

  @override
  bool shouldRepaint(RPMGaugePainter oldDelegate) {
    return oldDelegate.rpmPercent != rpmPercent ||
           oldDelegate.pulseValue != pulseValue;
  }
}