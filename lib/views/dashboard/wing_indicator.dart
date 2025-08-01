import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wing indicator component for displaying wing angle position
class WingIndicator extends StatelessWidget {
  final String label;
  final double angle;
  final double screenWidth;
  final double screenHeight;
  final bool isLeft;
  final Animation<double> pulseAnimation;
  
  const WingIndicator({
    super.key,
    required this.label,
    required this.angle,
    required this.screenWidth,
    required this.screenHeight,
    required this.isLeft,
    required this.pulseAnimation,
  });
  
  @override
  Widget build(BuildContext context) {
    // Clamp angle to ±20 degrees and normalize: 0 degrees at center (0.5)
    final clampedAngle = angle.clamp(-20.0, 20.0);
    final normalizedAngle = (clampedAngle + 20) / 40;
    
    return Container(
      height: screenHeight * 0.88,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.005,
        vertical: screenHeight * 0.01,
      ),
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: WingIndicatorPainter(
              angle: normalizedAngle,
              isLeft: isLeft,
              label: label,
              degrees: clampedAngle.round(),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for curved wing indicators
class WingIndicatorPainter extends CustomPainter {
  final double angle;
  final bool isLeft;
  final String label;
  final int degrees;

  WingIndicatorPainter({
    required this.angle,
    required this.isLeft,
    required this.label,
    required this.degrees,
  });
  
  // Shared curve calculation to ensure perfect alignment
  Offset _getCurvePosition(double t, Size size) {
    final trackHeight = size.height * 0.75;
    final centerX = size.width / 2;
    final startY = size.height * 0.12;
    final curveAmount = isLeft ? -size.width * 0.08 : size.width * 0.08;
    
    final y = startY + (trackHeight * t);
    final curveProgress = 4 * t * (1 - t);
    final x = centerX + (curveAmount * curveProgress);
    
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw vertical scale
    _drawVerticalScale(canvas, size);
    
    // Draw position indicator
    _drawPositionIndicator(canvas, size);
    
    // Draw label and value
    _drawLabelAndValue(canvas, size);
  }

  void _drawVerticalScale(Canvas canvas, Size size) {
    final trackWidth = size.width * 0.09;
    
    // Create sophisticated curved track using shared curve calculation
    final bgPath = Path();
    
    // Left edge of track
    final leftEdgePoints = <Offset>[];
    final rightEdgePoints = <Offset>[];
    
    for (int i = 0; i <= 50; i++) {
      final t = i / 50.0;
      final centerPos = _getCurvePosition(t, size);
      leftEdgePoints.add(Offset(centerPos.dx - trackWidth/2, centerPos.dy));
      rightEdgePoints.add(Offset(centerPos.dx + trackWidth/2, centerPos.dy));
    }
    
    // Build path
    bgPath.moveTo(leftEdgePoints.first.dx, leftEdgePoints.first.dy);
    for (final point in leftEdgePoints.skip(1)) {
      bgPath.lineTo(point.dx, point.dy);
    }
    for (final point in rightEdgePoints.reversed) {
      bgPath.lineTo(point.dx, point.dy);
    }
    bgPath.close();
    
    // Background with sophisticated gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1a1a1a),
          const Color(0xFF0d0d0d),
          const Color(0xFF1a1a1a),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(
        size.width / 2 - trackWidth,
        size.height * 0.12,
        trackWidth * 2,
        size.height * 0.75,
      ))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(bgPath, bgPaint);
    
    // Inner shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 3);
    
    canvas.drawPath(bgPath, shadowPaint);
    
    // Draw sophisticated scale marks with degree labels
    _drawScaleMarks(canvas, size);
    
    // Subtle border highlights
    final borderPaint = Paint()
      ..color = const Color(0xFF2a2a2a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawPath(bgPath, borderPaint);
    
    // Zero degree center line
    _drawCenterLine(canvas, size);
  }
  
  void _drawScaleMarks(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Define degree marks: -20 to +20 in 5 degree increments
    final degreeMarks = [-20, -15, -10, -5, 0, 5, 10, 15, 20];
    
    for (int i = 0; i < degreeMarks.length; i++) {
      final degree = degreeMarks[i];
      final t = (degree + 20) / 40.0; // Convert to 0-1 range
      final curvePos = _getCurvePosition(t, size);
      
      final isZero = degree == 0;
      final isMajor = degree % 10 == 0 || isZero;
      
      // Subtle tick mark styling
      final tickPaint = Paint()
        ..color = isZero 
            ? const Color(0xFF808080)
            : isMajor 
                ? const Color(0xFF606060) 
                : const Color(0xFF404040)
        ..strokeWidth = isZero ? 2.0 : isMajor ? 1.5 : 1.0;
      
      final tickLength = isZero 
          ? size.width * 0.035 
          : isMajor 
              ? size.width * 0.025 
              : size.width * 0.015;
      
      canvas.drawLine(
        Offset(curvePos.dx - tickLength, curvePos.dy),
        Offset(curvePos.dx + tickLength, curvePos.dy),
        tickPaint,
      );
      
      // Add degree labels for major marks only
      if (isMajor && degree != 0) {
        textPainter.text = TextSpan(
          text: '${degree.abs()}',
          style: TextStyle(
            color: const Color(0xFF606060),
            fontSize: size.width * 0.035,
            fontWeight: FontWeight.w300,
          ),
        );
        textPainter.layout();
        
        final textX = curvePos.dx + (isLeft ? -size.width * 0.07 : size.width * 0.04);
        final textY = curvePos.dy - textPainter.height / 2;
        
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }
  
  void _drawCenterLine(Canvas canvas, Size size) {
    // Subtle zero degree reference line
    final centerLinePaint = Paint()
      ..color = const Color(0xFF707070)
      ..strokeWidth = 1.2;
    
    // Get center position using shared curve calculation
    final centerPos = _getCurvePosition(0.5, size);
    
    canvas.drawLine(
      Offset(centerPos.dx - size.width * 0.05, centerPos.dy),
      Offset(centerPos.dx + size.width * 0.05, centerPos.dy),
      centerLinePaint,
    );
    
    // Understated zero degree text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          color: const Color(0xFF707070),
          fontSize: size.width * 0.04,
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final textX = centerPos.dx + (isLeft ? -size.width * 0.1 : size.width * 0.065);
    final textY = centerPos.dy - textPainter.height / 2;
    
    textPainter.paint(canvas, Offset(textX, textY));
  }

  void _drawPositionIndicator(Canvas canvas, Size size) {
    final trackWidth = size.width * 0.09;
    
    // Calculate positions using shared curve calculation
    final t = angle;
    final currentPos = _getCurvePosition(t, size);
    final centerT = 0.5;
    final centerPos = _getCurvePosition(centerT, size);
    
    // Draw progress fill from center to current position
    if ((t - centerT).abs() > 0.01) { // Only draw if not at center
      final fillPath = Path();
      
      // Determine fill range
      final startT = math.min(t, centerT);
      final endT = math.max(t, centerT);
      
      // Build fill path using exact curve positions
      final leftEdgePoints = <Offset>[];
      final rightEdgePoints = <Offset>[];
      
      final segments = math.max(20, ((endT - startT) * 100).ceil());
      
      for (int i = 0; i <= segments; i++) {
        final segmentT = startT + ((endT - startT) * i / segments);
        final pos = _getCurvePosition(segmentT, size);
        leftEdgePoints.add(Offset(pos.dx - trackWidth/2, pos.dy));
        rightEdgePoints.add(Offset(pos.dx + trackWidth/2, pos.dy));
      }
      
      // Build fill path
      fillPath.moveTo(leftEdgePoints.first.dx, leftEdgePoints.first.dy);
      for (final point in leftEdgePoints.skip(1)) {
        fillPath.lineTo(point.dx, point.dy);
      }
      for (final point in rightEdgePoints.reversed) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.close();
      
      // Subtle progress color
      Color progressColor;
      if (degrees.abs() > 15) {
        progressColor = const Color(0xFF909090);
      } else {
        progressColor = const Color(0xFF606060);
      }
      
      // Calculate proper gradient bounds
      final gradientStart = math.min(centerPos.dy, currentPos.dy);
      final gradientHeight = (centerPos.dy - currentPos.dy).abs();
      
      final progressPaint = Paint()
        ..shader = LinearGradient(
          begin: t < centerT ? Alignment.bottomCenter : Alignment.topCenter,
          end: t < centerT ? Alignment.topCenter : Alignment.bottomCenter,
          colors: [
            progressColor.withValues(alpha: 0.8),
            progressColor.withValues(alpha: 0.6),
            progressColor.withValues(alpha: 0.4),
          ],
        ).createShader(Rect.fromLTWH(
          currentPos.dx - trackWidth,
          gradientStart,
          trackWidth * 2,
          math.max(gradientHeight, 1),
        ));
      
      canvas.drawPath(fillPath, progressPaint);
    }
    
    // Refined position indicator
    final indicatorSize = size.width * 0.04;
    
    // Subtle indicator with minimal color variation
    final indicatorColor = degrees.abs() > 15 
        ? const Color(0xFFc0c0c0)
        : const Color(0xFFa0a0a0);
    
    // Minimal outer highlight
    final highlightPaint = Paint()
      ..color = indicatorColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      currentPos, 
      indicatorSize * 1.8, 
      highlightPaint,
    );
    
    // Main indicator with subtle gradient
    final indicatorPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          indicatorColor,
          indicatorColor.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromCircle(
        center: currentPos,
        radius: indicatorSize,
      ));
    
    canvas.drawCircle(
      currentPos, 
      indicatorSize, 
      indicatorPaint,
    );
    
    // Refined border
    final borderPaint = Paint()
      ..color = const Color(0xFF505050)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    canvas.drawCircle(
      currentPos, 
      indicatorSize, 
      borderPaint,
    );
  }

  void _drawLabelAndValue(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Sophisticated label at top
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(
        color: const Color(0xFF909090),
        fontSize: size.width * 0.055,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.02),
    );
    
    // Subtle value color coding
    Color valueColor;
    if (degrees.abs() > 15) {
      valueColor = const Color(0xFFb0b0b0); // Slightly dimmed for high angles
    } else {
      valueColor = Colors.white; // White for normal range
    }
    
    // Show signed value with proper formatting
    final displayValue = degrees >= 0 ? '+$degrees' : '$degrees';
    
    textPainter.text = TextSpan(
      text: '$displayValue°',
      style: TextStyle(
        color: valueColor,
        fontSize: size.width * 0.09,
        fontWeight: FontWeight.w300,
        fontFamily: 'monospace',
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.905),
    );
    
    // Subtle range indicators at extremes
    final extremePaint = Paint()
      ..color = const Color(0xFF404040)
      ..strokeWidth = 0.8;
    
    // +20 degree line (top)
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.12),
      Offset(size.width * 0.8, size.height * 0.12),
      extremePaint,
    );
    
    // -20 degree line (bottom)
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.87),
      Offset(size.width * 0.8, size.height * 0.87),
      extremePaint,
    );
    
    // Understated range labels
    textPainter.text = TextSpan(
      text: '+20',
      style: TextStyle(
        color: const Color(0xFF505050),
        fontSize: size.width * 0.03,
        fontWeight: FontWeight.w300,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width * 0.05, size.height * 0.11),
    );
    
    textPainter.text = TextSpan(
      text: '-20',
      style: TextStyle(
        color: const Color(0xFF505050),
        fontSize: size.width * 0.03,
        fontWeight: FontWeight.w300,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width * 0.05, size.height * 0.87),
    );
  }

  @override
  bool shouldRepaint(WingIndicatorPainter oldDelegate) {
    return oldDelegate.angle != angle ||
           oldDelegate.degrees != degrees;
  }
}