import 'dart:math' as math;
import 'dart:ui' as ui;
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
                // Glass morphism background panel
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        // Multiple shadow layers for depth
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 60,
                          spreadRadius: -10,
                          offset: const Offset(0, 30),
                        ),
                        // Inner highlight
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: -15,
                          offset: const Offset(-5, -5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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

    // Premium sky gradient with depth
    final skyPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              const Color(0xFF001122),  // Deep sky blue
              const Color(0xFF002244),  // Mid sky
              const Color(0xFF003366),  // Horizon sky
              const Color(0xFF004488),  // Near horizon
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
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

    // Premium ground gradient with texture
    final groundPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF3D2815),  // Horizon earth
              const Color(0xFF2D1F10),  // Mid ground
              const Color(0xFF1F160A),  // Deep ground
              const Color(0xFF0F0A05),  // Shadow ground
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
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

    // Enhanced Horizon Line with premium glow
    final horizonOuterGlowPaint = Paint()
      ..color = const Color(0xFF00D9FF).withValues(alpha: 0.2)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawLine(
      Offset(-size.width * 2, pitchPixels),
      Offset(size.width * 2, pitchPixels),
      horizonOuterGlowPaint,
    );

    final horizonInnerGlowPaint = Paint()
      ..color = const Color(0xFF00D9FF).withValues(alpha: 0.4)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawLine(
      Offset(-size.width * 2, pitchPixels),
      Offset(size.width * 2, pitchPixels),
      horizonInnerGlowPaint,
    );

    final horizonPaint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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
    // Enhanced outer shadow for depth
    final outerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.drawCircle(center, radius + 12, outerShadowPaint);
    
    // Premium brushed metal bezel with multiple layers
    final bezelPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          const Color(0xFF4A4A4A),
          const Color(0xFF3A3A3A),
          const Color(0xFF2A2A2A),
          const Color(0xFF1A1A1A),
          const Color(0xFF0A0A0A),
        ],
        stops: const [0.0, 0.3, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 8));

    canvas.drawCircle(center, radius + 8, bezelPaint);

    // Brushed metal texture effect
    final brushPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-1, -1),
        end: const Alignment(1, 1),
        colors: [
          Colors.white.withValues(alpha: 0.2),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.15),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 6));

    canvas.drawCircle(center, radius + 6, brushPaint);
    
    // Inner rim with premium highlight
    final innerRimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius + 2, innerRimPaint);
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
    // Enhanced aircraft symbol with premium styling
    final outerGlowPaint = Paint()
      ..color = const Color(0xFFFFAA00).withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final innerGlowPaint = Paint()
      ..color = const Color(0xFFFFAA00).withValues(alpha: 0.6)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final mainPaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerDotPaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..style = PaintingStyle.fill;

    // Center dot with glow
    final centerGlowPaint = Paint()
      ..color = const Color(0xFFFFAA00).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, 8, centerGlowPaint);
    canvas.drawCircle(center, 4, centerDotPaint);

    final path = Path();

    // Enhanced wings with better geometry
    path.moveTo(center.dx - 70, center.dy + 3);
    path.lineTo(center.dx - 18, center.dy);
    path.moveTo(center.dx + 18, center.dy);
    path.lineTo(center.dx + 70, center.dy + 3);

    // Wing tips with slight upward angle
    path.moveTo(center.dx - 70, center.dy + 3);
    path.lineTo(center.dx - 70, center.dy + 12);
    path.moveTo(center.dx + 70, center.dy + 3);
    path.lineTo(center.dx + 70, center.dy + 12);

    // Center vertical reference line
    path.moveTo(center.dx, center.dy - 15);
    path.lineTo(center.dx, center.dy + 15);

    // Draw with multiple layers for premium effect
    canvas.drawPath(path, outerGlowPaint);
    canvas.drawPath(path, innerGlowPaint);
    canvas.drawPath(path, mainPaint);
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
    final outerRadius = size.width / 2 - 8;
    final trackWidth = 24.0;
    final innerRadius = outerRadius - trackWidth;

    // Draw premium track background with multiple layers
    _drawTrackBackground(canvas, center, outerRadius, innerRadius, trackWidth);
    
    // Draw graduated tick marks
    _drawTickMarks(canvas, center, outerRadius, innerRadius);
    
    // Draw active RPM arc with enhanced styling
    _drawActiveArc(canvas, center, outerRadius, innerRadius, trackWidth);
    
    // Add premium finishing touches
    _drawFinishingTouches(canvas, center, outerRadius, innerRadius, trackWidth);
  }

  void _drawTrackBackground(Canvas canvas, Offset center, double outerRadius, double innerRadius, double trackWidth) {
    final trackRect = Rect.fromCircle(center: center, radius: outerRadius - trackWidth/2);
    
    // Outer shadow for depth
    final outerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..strokeWidth = trackWidth + 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawCircle(center, outerRadius - trackWidth/2, outerShadowPaint);
    
    // Main track with brushed metal effect
    final trackPaint = Paint()
      ..strokeWidth = trackWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          const Color(0xFF2A2A2A),
          const Color(0xFF1A1A1A),
          const Color(0xFF0F0F0F),
          const Color(0xFF1A1A1A),
          const Color(0xFF2A2A2A),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(trackRect);
    
    canvas.drawCircle(center, outerRadius - trackWidth/2, trackPaint);
    
    // Inner highlight
    final highlightPaint = Paint()
      ..strokeWidth = trackWidth - 4
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: const Alignment(-1, -1),
        end: const Alignment(1, 1),
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
        ],
      ).createShader(trackRect);
    
    canvas.drawCircle(center, outerRadius - trackWidth/2, highlightPaint);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double outerRadius, double innerRadius) {
    const startAngle = 135 * math.pi / 180;
    const fullSweep = 270 * math.pi / 180;
    
    // Major tick marks (every 1000 RPM)
    final majorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    // Minor tick marks (every 500 RPM) 
    final minorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    // Draw 17 total marks (8 major + 9 minor)
    for (int i = 0; i <= 16; i++) {
      final isMajor = i % 2 == 0;
      final angle = startAngle + (i / 16.0) * fullSweep;
      final tickLength = isMajor ? 16.0 : 8.0;
      final paint = isMajor ? majorTickPaint : minorTickPaint;
      
      final outerTick = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final innerTick = Offset(
        center.dx + (outerRadius - tickLength) * math.cos(angle),
        center.dy + (outerRadius - tickLength) * math.sin(angle),
      );
      
      // Add glow effect to major ticks
      if (isMajor) {
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        
        canvas.drawLine(outerTick, innerTick, glowPaint);
      }
      
      canvas.drawLine(outerTick, innerTick, paint);
    }
  }

  void _drawActiveArc(Canvas canvas, Offset center, double outerRadius, double innerRadius, double trackWidth) {
    const startAngle = 135 * math.pi / 180;
    const fullSweep = 270 * math.pi / 180;
    
    final sweepAngle = (rpm / maxRpm).clamp(0.0, 1.0) * fullSweep;
    
    if (sweepAngle <= 0) return;
    
    final arcRect = Rect.fromCircle(center: center, radius: outerRadius - trackWidth/2);
    
    // Outer glow effect
    final glowPaint = Paint()
      ..strokeWidth = trackWidth + 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: _getRpmColors(rpm, maxRpm).map((c) => c.withValues(alpha: 0.3)).toList(),
      ).createShader(arcRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, glowPaint);
    
    // Main active arc
    final activePaint = Paint()
      ..strokeWidth = trackWidth - 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: _getRpmColors(rpm, maxRpm),
      ).createShader(arcRect);
    
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, activePaint);
    
    // Inner highlight on active arc
    final innerHighlightPaint = Paint()
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: _getRpmColors(rpm, maxRpm).map((c) => 
          Color.lerp(c, Colors.white, 0.4)!).toList(),
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius + 6));
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius + 6),
      startAngle, 
      sweepAngle, 
      false, 
      innerHighlightPaint
    );
  }

  void _drawFinishingTouches(Canvas canvas, Offset center, double outerRadius, double innerRadius, double trackWidth) {
    // Subtle outer rim only
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, outerRadius, rimPaint);
    canvas.drawCircle(center, innerRadius, rimPaint);
    
    // Center circle removed - leave attitude indicator visible
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
