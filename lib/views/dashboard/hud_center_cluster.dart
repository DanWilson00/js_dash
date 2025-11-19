import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dashboard_config.dart';

class HudCenterCluster extends StatelessWidget {
  final double pitch; // in degrees
  final double roll; // in degrees
  final double yaw; // in degrees
  final double rpm;
  final double maxRpm;

  const HudCenterCluster({
    super.key,
    required this.pitch,
    required this.roll,
    required this.yaw,
    required this.rpm,
    this.maxRpm = 8000.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                // Attitude Indicator (Inner)
                Positioned.fill(
                  child: CustomPaint(
                    painter: AttitudePainter(
                      pitch: pitch,
                      roll: roll,
                      yaw: yaw,
                    ),
                  ),
                ),
                // RPM Ring (Outer)
                Positioned.fill(
                  child: CustomPaint(
                    painter: RpmRingPainter(rpm: rpm, maxRpm: maxRpm),
                  ),
                ),
                // Digital RPM Readout (Bottom Center)
                Positioned(
                  bottom: size * 0.15,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rpm.toStringAsFixed(0),
                        style: TextStyle(
                          color: DashboardConfig.textPrimary,
                          fontSize: size * 0.08,
                          fontWeight: FontWeight.w300,
                          fontFamily: 'RobotoMono',
                          shadows: const [
                            Shadow(
                              blurRadius: 20,
                              color: DashboardConfig.primaryAccent,
                            ),
                            Shadow(
                              blurRadius: 40,
                              color: DashboardConfig.primaryAccent,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'RPM',
                        style: TextStyle(
                          color: DashboardConfig.textSecondary.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: size * 0.025,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AttitudePainter extends CustomPainter {
  final double pitch;
  final double roll;
  final double yaw;

  AttitudePainter({required this.pitch, required this.roll, required this.yaw});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.7;

    // Outer bezel with metallic effect
    _drawMetallicBezel(canvas, center, radius);

    // Clip to the inner circle area
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - 8));
    canvas.clipPath(clipPath);

    // Sky/Ground with enhanced gradient
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-roll * math.pi / 180);

    final pitchPixels = pitch * (radius / 30.0);

    final bgRect = Rect.fromCenter(
      center: Offset(0, pitchPixels),
      width: size.width * 3,
      height: size.height * 3,
    );

    // Enhanced sky gradient
    final skyPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              const Color(0xFF000814),
              const Color(0xFF001D3D),
              const Color(0xFF003566),
            ],
          ).createShader(
            Rect.fromLTWH(
              bgRect.left,
              bgRect.top,
              bgRect.width,
              bgRect.height / 2,
            ),
          );

    canvas.drawRect(
      Rect.fromLTWH(
        bgRect.left,
        bgRect.top,
        bgRect.width,
        bgRect.height / 2 + pitchPixels,
      ),
      skyPaint,
    );

    // Enhanced ground gradient
    final groundPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2D1B00),
              const Color(0xFF1A0F00),
              const Color(0xFF0A0500),
            ],
          ).createShader(
            Rect.fromLTWH(
              bgRect.left,
              bgRect.top + bgRect.height / 2 + pitchPixels,
              bgRect.width,
              bgRect.height / 2,
            ),
          );

    canvas.drawRect(
      Rect.fromLTWH(
        bgRect.left,
        bgRect.top + bgRect.height / 2 + pitchPixels,
        bgRect.width,
        bgRect.height / 2,
      ),
      groundPaint,
    );

    // Horizon Line with glow
    final horizonGlowPaint = Paint()
      ..color = const Color(0xFF00D9FF).withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(
      Offset(-size.width * 2, pitchPixels),
      Offset(size.width * 2, pitchPixels),
      horizonGlowPaint,
    );

    final horizonPaint = Paint()
      ..color = const Color(0xFF00D9FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(-size.width * 2, pitchPixels),
      Offset(size.width * 2, pitchPixels),
      horizonPaint,
    );

    // Enhanced Pitch Ladder
    _drawPitchLadder(canvas, pitchPixels, radius);

    canvas.restore();

    // Fixed Aircraft Symbol with premium styling
    _drawAircraftSymbol(canvas, center, radius);

    // Roll scale
    _drawRollScale(canvas, center, radius);
  }

  void _drawMetallicBezel(Canvas canvas, Offset center, double radius) {
    // Outer ring - brushed metal effect
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2A2A2A),
          const Color(0xFF1A1A1A),
          const Color(0xFF0A0A0A),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 8));

    canvas.drawCircle(center, radius + 8, outerPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A4A4A).withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 6));

    canvas.drawCircle(center, radius + 6, highlightPaint);
  }

  void _drawPitchLadder(Canvas canvas, double pitchPixels, double radius) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = -90; i <= 90; i += 5) {
      if (i == 0) continue;

      final y = pitchPixels - (i * (radius / 30.0));

      if (y < -radius || y > radius) continue;

      final isMajor = i % 10 == 0;
      final width = isMajor ? 80.0 : 40.0;

      // Line with glow
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = isMajor ? 3 : 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawLine(Offset(-width / 2, y), Offset(width / 2, y), glowPaint);

      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: isMajor ? 0.9 : 0.6)
        ..strokeWidth = isMajor ? 2 : 1
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(-width / 2, y), Offset(width / 2, y), linePaint);

      if (isMajor) {
        textPainter.text = TextSpan(
          text: i.abs().toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w300,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(width / 2 + 8, y - textPainter.height / 2),
        );
        textPainter.paint(
          canvas,
          Offset(
            -width / 2 - textPainter.width - 8,
            y - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawAircraftSymbol(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFFFFAA00)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFAA00).withValues(alpha: 0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();

    // Center dot
    path.addOval(Rect.fromCircle(center: center, radius: 4));

    // Wings - more aggressive angle
    path.moveTo(center.dx - 60, center.dy + 5);
    path.lineTo(center.dx - 15, center.dy);
    path.moveTo(center.dx + 15, center.dy);
    path.lineTo(center.dx + 60, center.dy + 5);

    // Wing tips
    path.moveTo(center.dx - 60, center.dy + 5);
    path.lineTo(center.dx - 60, center.dy + 15);
    path.moveTo(center.dx + 60, center.dy + 5);
    path.lineTo(center.dx + 60, center.dy + 15);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  void _drawRollScale(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw tick marks
    for (int i = -60; i <= 60; i += 10) {
      final angle = i * math.pi / 180;
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;

      final outer = Offset(
        center.dx + (radius - 15) * math.sin(angle),
        center.dy - (radius - 15) * math.cos(angle),
      );
      final inner = Offset(
        center.dx + (radius - 15 - tickLength) * math.sin(angle),
        center.dy - (radius - 15 - tickLength) * math.cos(angle),
      );

      canvas.drawLine(outer, inner, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AttitudePainter oldDelegate) {
    return oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.yaw != yaw;
  }
}

class RpmRingPainter extends CustomPainter {
  final double rpm;
  final double maxRpm;

  RpmRingPainter({required this.rpm, required this.maxRpm});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Background Ring with carbon fiber texture effect
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A1A1A).withValues(alpha: 0.3),
          const Color(0xFF0A0A0A).withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, bgPaint);

    // Active RPM Arc
    const startAngle = 135 * math.pi / 180;
    const fullSweep = 270 * math.pi / 180;

    final sweepAngle = (rpm / maxRpm).clamp(0.0, 1.0) * fullSweep;

    // Main arc (no glow)
    final activePaint = Paint()
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: _getRpmColors(rpm, maxRpm),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2;

    for (int i = 0; i <= 8; i++) {
      final angle = startAngle + (i / 8) * fullSweep;
      final inner = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      final outer = Offset(
        center.dx + (radius + 12) * math.cos(angle),
        center.dy + (radius + 12) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  List<Color> _getRpmColors(double rpm, double maxRpm) {
    final ratio = rpm / maxRpm;
    if (ratio < 0.6) {
      return [const Color(0xFF00FFB3), const Color(0xFF00D9FF)];
    } else if (ratio < 0.85) {
      return [const Color(0xFF00D9FF), const Color(0xFFFFAA00)];
    } else {
      return [const Color(0xFFFFAA00), const Color(0xFFFF3366)];
    }
  }

  @override
  bool shouldRepaint(covariant RpmRingPainter oldDelegate) {
    return oldDelegate.rpm != rpm;
  }
}
