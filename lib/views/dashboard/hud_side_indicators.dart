import 'package:flutter/material.dart';
import 'dashboard_config.dart';

class HudSideIndicators extends StatelessWidget {
  final double leftWingAngle;
  final double rightWingAngle;
  final double targetLeftWingAngle;
  final double targetRightWingAngle;

  const HudSideIndicators({
    super.key,
    required this.leftWingAngle,
    required this.rightWingAngle,
    required this.targetLeftWingAngle,
    required this.targetRightWingAngle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Indicator
        _buildIndicator(context, leftWingAngle, targetLeftWingAngle, true),
        // Right Indicator
        _buildIndicator(context, rightWingAngle, targetRightWingAngle, false),
      ],
    );
  }

  Widget _buildIndicator(
    BuildContext context,
    double current,
    double target,
    bool isLeft,
  ) {
    return Container(
      width: 120,
      height: 500,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            isLeft ? 'L-WING' : 'R-WING',
            style: TextStyle(
              color: DashboardConfig.textSecondary.withValues(alpha: 0.7),
              fontSize: 11,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CustomPaint(
              painter: WingIndicatorPainter(
                current: current,
                target: target,
                isLeft: isLeft,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Digital readout with styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: DashboardConfig.primaryAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${current.toStringAsFixed(1)}°',
              style: const TextStyle(
                color: DashboardConfig.primaryAccent,
                fontSize: 18,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w400,
                shadows: [
                  Shadow(blurRadius: 8, color: DashboardConfig.primaryAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WingIndicatorPainter extends CustomPainter {
  final double current;
  final double target;
  final bool isLeft;

  WingIndicatorPainter({
    required this.current,
    required this.target,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Draw background track with carbon fiber effect
    _drawTrack(canvas, size);

    // Draw center line (0 degrees)
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(isLeft ? width - 25 : 25, centerY),
      Offset(isLeft ? width : 0, centerY),
      centerLinePaint,
    );

    // Draw scale marks
    _drawScaleMarks(canvas, size, centerY);

    // Draw target indicator (ghost)
    _drawTargetIndicator(canvas, size, centerY, target);

    // Draw current indicator (solid with glow)
    _drawCurrentIndicator(canvas, size, centerY, current);
  }

  void _drawTrack(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(isLeft ? size.width - 10 : 0, 0, 10, size.height),
      const Radius.circular(5),
    );

    // Background with gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1A1A1A).withValues(alpha: 0.5),
          const Color(0xFF0A0A0A).withValues(alpha: 0.7),
          const Color(0xFF1A1A1A).withValues(alpha: 0.5),
        ],
      ).createShader(trackRect.outerRect);

    canvas.drawRRect(trackRect, bgPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        colors: [Colors.white.withValues(alpha: 0.1), Colors.transparent],
      ).createShader(trackRect.outerRect);

    canvas.drawRRect(trackRect, highlightPaint);
  }

  void _drawScaleMarks(Canvas canvas, Size size, double centerY) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw marks every 15 degrees
    for (int i = -45; i <= 45; i += 15) {
      final y = centerY - (i * size.height / 90);

      if (y < 0 || y > size.height) continue;

      final isMajor = i % 30 == 0;
      final markWidth = isMajor ? 15.0 : 8.0;

      canvas.drawLine(
        Offset(isLeft ? size.width - markWidth : 0, y),
        Offset(isLeft ? size.width : markWidth, y),
        paint,
      );
    }
  }

  void _drawTargetIndicator(
    Canvas canvas,
    Size size,
    double centerY,
    double angle,
  ) {
    final y = centerY - (angle.clamp(-45.0, 45.0) * size.height / 90);

    final path = Path();
    if (isLeft) {
      path.moveTo(size.width - 20, y);
      path.lineTo(size.width - 5, y - 10);
      path.lineTo(size.width - 5, y + 10);
      path.close();
    } else {
      path.moveTo(20, y);
      path.lineTo(5, y - 10);
      path.lineTo(5, y + 10);
      path.close();
    }

    final paint = Paint()
      ..color = const Color(0xFF00D9FF).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final outlinePaint = Paint()
      ..color = const Color(0xFF00D9FF).withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, outlinePaint);
  }

  void _drawCurrentIndicator(
    Canvas canvas,
    Size size,
    double centerY,
    double angle,
  ) {
    final y = centerY - (angle.clamp(-45.0, 45.0) * size.height / 90);

    // Glow effect
    final glowPath = Path();
    if (isLeft) {
      glowPath.moveTo(size.width - 20, y);
      glowPath.lineTo(size.width - 5, y - 12);
      glowPath.lineTo(size.width - 5, y + 12);
      glowPath.close();
    } else {
      glowPath.moveTo(20, y);
      glowPath.lineTo(5, y - 12);
      glowPath.lineTo(5, y + 12);
      glowPath.close();
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF00FFB3).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(glowPath, glowPaint);

    // Main indicator
    final path = Path();
    if (isLeft) {
      path.moveTo(size.width - 20, y);
      path.lineTo(size.width - 5, y - 11);
      path.lineTo(size.width - 5, y + 11);
      path.close();
    } else {
      path.moveTo(20, y);
      path.lineTo(5, y - 11);
      path.lineTo(5, y + 11);
      path.close();
    }

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF00FFB3), const Color(0xFF00D9FF)],
      ).createShader(path.getBounds());

    canvas.drawPath(path, paint);

    // Connecting line to track
    final linePaint = Paint()
      ..color = const Color(0xFF00FFB3)
      ..strokeWidth = 2
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          const Color(0xFF00FFB3),
          const Color(0xFF00FFB3).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(isLeft ? size.width - 20 : 5, y - 1, 15, 2));

    canvas.drawLine(
      Offset(isLeft ? size.width - 20 : 20, y),
      Offset(isLeft ? size.width - 5 : 5, y),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant WingIndicatorPainter oldDelegate) {
    return oldDelegate.current != current || oldDelegate.target != target;
  }
}
