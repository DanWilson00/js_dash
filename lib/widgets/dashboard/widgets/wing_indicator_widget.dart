import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../base/dashboard_widget.dart';
import '../base/dashboard_config.dart';
import '../data/data_provider.dart';

/// Wing indicator widget for displaying angle/position data
class WingIndicatorWidget extends DashboardWidget {
  const WingIndicatorWidget({
    Key? key,
    required DashboardWidgetConfig config,
    required DataProvider dataProvider,
  }) : super(key: key, config: config, dataProvider: dataProvider);
  
  @override
  State<WingIndicatorWidget> createState() => _WingIndicatorWidgetState();
}

class _WingIndicatorWidgetState extends DashboardWidgetState<WingIndicatorWidget>
    {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  double _targetPosition = 0;
  double _currentPosition = 0;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(
        milliseconds: getProperty<int>('animationDuration', 500) ?? 500,
      ),
      vsync: this,
    );
    
    _positionAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Update target position when data changes
    if (currentValue != null) {
      _targetPosition = currentValue.toDouble();
      _animateToPosition(_targetPosition);
    }
    
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: WingIndicatorPainter(
            position: _positionAnimation.value,
            minValue: getProperty<double>('minValue', -20) ?? -20,
            maxValue: getProperty<double>('maxValue', 20) ?? 20,
            isLeft: getProperty<bool>('isLeft', true) ?? true,
            label: getProperty<String>('label', '') ?? '',
            units: getProperty<String>('units', '°') ?? '°',
            primaryColor: getProperty<Color>('primaryColor', const Color(0xFF4a90e2)) ?? const Color(0xFF4a90e2),
            backgroundColor: getProperty<Color>('backgroundColor', Colors.black) ?? Colors.black,
            textColor: getProperty<Color>('textColor', Colors.white) ?? Colors.white,
            warningThreshold: getProperty<double>('warningThreshold', 15) ?? 15,
            dangerThreshold: getProperty<double>('dangerThreshold', 18) ?? 18,
          ),
        );
      },
    );
  }
  
  void _animateToPosition(double newPosition) {
    _positionAnimation = Tween<double>(
      begin: _currentPosition,
      end: newPosition,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward(from: 0);
    _currentPosition = newPosition;
  }
}

/// Custom painter for the wing indicator
class WingIndicatorPainter extends CustomPainter {
  final double position;
  final double minValue;
  final double maxValue;
  final bool isLeft;
  final String label;
  final String units;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;
  final double warningThreshold;
  final double dangerThreshold;
  
  WingIndicatorPainter({
    required this.position,
    required this.minValue,
    required this.maxValue,
    required this.isLeft,
    required this.label,
    required this.units,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.warningThreshold,
    required this.dangerThreshold,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final curveRadius = size.width * 2;
    final trackWidth = size.width * 0.3;
    
    // Calculate curve parameters
    final startAngle = isLeft ? -math.pi / 6 : -5 * math.pi / 6;
    final sweepAngle = math.pi / 3;
    
    // Draw background track
    _drawCurvedTrack(
      canvas,
      size,
      curveRadius,
      trackWidth,
      startAngle,
      sweepAngle,
      backgroundColor.withOpacity(0.2),
    );
    
    // Draw gradient zones
    _drawGradientZones(
      canvas,
      size,
      curveRadius,
      trackWidth,
      startAngle,
      sweepAngle,
    );
    
    // Draw position indicator
    _drawPositionIndicator(
      canvas,
      size,
      curveRadius,
      trackWidth,
      startAngle,
      sweepAngle,
    );
    
    // Draw scale marks
    _drawScaleMarks(
      canvas,
      size,
      curveRadius,
      startAngle,
      sweepAngle,
    );
    
    // Draw value display
    _drawValueDisplay(canvas, size);
    
    // Draw label
    if (label.isNotEmpty) {
      _drawLabel(canvas, size);
    }
  }
  
  void _drawCurvedTrack(
    Canvas canvas,
    Size size,
    double radius,
    double width,
    double startAngle,
    double sweepAngle,
    Color color,
  ) {
    final rect = Rect.fromCenter(
      center: Offset(isLeft ? size.width + radius : -radius, size.height / 2),
      width: radius * 2,
      height: radius * 2,
    );
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }
  
  void _drawGradientZones(
    Canvas canvas,
    Size size,
    double radius,
    double width,
    double startAngle,
    double sweepAngle,
  ) {
    // Calculate zone angles
    final normalZone = warningThreshold / (maxValue - minValue);
    final warningZone = (dangerThreshold - warningThreshold) / (maxValue - minValue);
    
    // Draw normal zone (green to yellow gradient)
    final normalSweep = sweepAngle * normalZone;
    final normalGradient = SweepGradient(
      colors: [
        Colors.green.withOpacity(0.3),
        Colors.yellow.withOpacity(0.3),
      ],
      stops: const [0.0, 1.0],
    );
    
    _drawGradientArc(
      canvas,
      size,
      radius,
      width * 0.8,
      startAngle + sweepAngle / 2 - normalSweep / 2,
      normalSweep,
      normalGradient,
    );
    
    // Draw warning zones (yellow to orange)
    final warningSweep = sweepAngle * warningZone;
    
    // Upper warning zone
    _drawGradientArc(
      canvas,
      size,
      radius,
      width * 0.8,
      startAngle + sweepAngle / 2 + normalSweep / 2,
      warningSweep,
      const SweepGradient(
        colors: [
          Colors.yellow,
          Colors.orange,
        ],
      ),
    );
    
    // Lower warning zone
    _drawGradientArc(
      canvas,
      size,
      radius,
      width * 0.8,
      startAngle + sweepAngle / 2 - normalSweep / 2 - warningSweep,
      warningSweep,
      const SweepGradient(
        colors: [
          Colors.orange,
          Colors.yellow,
        ],
      ),
    );
  }
  
  void _drawGradientArc(
    Canvas canvas,
    Size size,
    double radius,
    double width,
    double startAngle,
    double sweepAngle,
    Gradient gradient,
  ) {
    final rect = Rect.fromCenter(
      center: Offset(isLeft ? size.width + radius : -radius, size.height / 2),
      width: radius * 2,
      height: radius * 2,
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }
  
  void _drawPositionIndicator(
    Canvas canvas,
    Size size,
    double radius,
    double width,
    double startAngle,
    double sweepAngle,
  ) {
    // Calculate position angle
    final normalizedPos = (position - minValue) / (maxValue - minValue);
    final positionAngle = startAngle + sweepAngle * normalizedPos;
    
    final center = Offset(isLeft ? size.width + radius : -radius, size.height / 2);
    
    // Calculate indicator position
    final indicatorPos = Offset(
      center.dx + radius * math.cos(positionAngle),
      center.dy + radius * math.sin(positionAngle),
    );
    
    // Draw indicator circle
    final indicatorColor = _getColorForPosition(position);
    
    // Glow effect
    canvas.drawCircle(
      indicatorPos,
      width * 0.8,
      Paint()
        ..color = indicatorColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    
    // Main indicator
    canvas.drawCircle(
      indicatorPos,
      width * 0.5,
      Paint()..color = indicatorColor,
    );
    
    // Inner highlight
    canvas.drawCircle(
      indicatorPos,
      width * 0.3,
      Paint()..color = Colors.white.withOpacity(0.8),
    );
  }
  
  void _drawScaleMarks(
    Canvas canvas,
    Size size,
    double radius,
    double startAngle,
    double sweepAngle,
  ) {
    final center = Offset(isLeft ? size.width + radius : -radius, size.height / 2);
    final numMarks = 9; // -20, -15, -10, -5, 0, 5, 10, 15, 20
    
    for (int i = 0; i < numMarks; i++) {
      final angle = startAngle + (i / (numMarks - 1)) * sweepAngle;
      final value = minValue + (i / (numMarks - 1)) * (maxValue - minValue);
      
      // Draw tick mark
      final tickStart = Offset(
        center.dx + (radius - size.width * 0.2) * math.cos(angle),
        center.dy + (radius - size.width * 0.2) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + (radius + size.width * 0.2) * math.cos(angle),
        center.dy + (radius + size.width * 0.2) * math.sin(angle),
      );
      
      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = textColor.withOpacity(0.5)
          ..strokeWidth = value.abs() < 1 ? 3 : 1,
      );
      
      // Draw value label for major marks
      if (value.abs() % 10 < 1) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: value.toStringAsFixed(0),
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: size.width * 0.12,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        final labelPos = Offset(
          center.dx + (radius - size.width * 0.4) * math.cos(angle) - textPainter.width / 2,
          center.dy + (radius - size.width * 0.4) * math.sin(angle) - textPainter.height / 2,
        );
        
        textPainter.paint(canvas, labelPos);
      }
    }
  }
  
  void _drawValueDisplay(Canvas canvas, Size size) {
    final displayRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.85),
        width: size.width * 0.8,
        height: size.height * 0.15,
      ),
      const Radius.circular(8),
    );
    
    // Background
    canvas.drawRRect(
      displayRect,
      Paint()..color = backgroundColor.withOpacity(0.8),
    );
    
    // Border
    canvas.drawRRect(
      displayRect,
      Paint()
        ..color = _getColorForPosition(position).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    
    // Value text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${position.toStringAsFixed(1)}$units',
        style: TextStyle(
          color: _getColorForPosition(position),
          fontSize: size.width * 0.18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height * 0.85 - textPainter.height / 2,
      ),
    );
  }
  
  void _drawLabel(Canvas canvas, Size size) {
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label.toUpperCase(),
        style: TextStyle(
          color: textColor.withOpacity(0.5),
          fontSize: size.width * 0.12,
          fontWeight: FontWeight.w300,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    
    labelPainter.paint(
      canvas,
      Offset(
        size.width / 2 - labelPainter.width / 2,
        size.height * 0.05,
      ),
    );
  }
  
  Color _getColorForPosition(double pos) {
    final absPos = pos.abs();
    if (absPos >= dangerThreshold) {
      return Colors.red;
    } else if (absPos >= warningThreshold) {
      return Colors.orange;
    } else {
      return primaryColor;
    }
  }
  
  @override
  bool shouldRepaint(WingIndicatorPainter oldDelegate) {
    return position != oldDelegate.position ||
           minValue != oldDelegate.minValue ||
           maxValue != oldDelegate.maxValue;
  }
}