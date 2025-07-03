import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../base/dashboard_widget.dart';
import '../base/dashboard_config.dart';
import '../data/data_provider.dart';

/// Circular gauge widget for displaying values like RPM, speed, etc.
class CircularGaugeWidget extends DashboardWidget {
  const CircularGaugeWidget({
    Key? key,
    required DashboardWidgetConfig config,
    required DataProvider dataProvider,
  }) : super(key: key, config: config, dataProvider: dataProvider);
  
  @override
  State<CircularGaugeWidget> createState() => _CircularGaugeWidgetState();
}

class _CircularGaugeWidgetState extends DashboardWidgetState<CircularGaugeWidget>
    {
  late AnimationController _animationController;
  late Animation<double> _valueAnimation;
  double _targetValue = 0;
  double _currentValue = 0;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(
        milliseconds: getProperty<int>('animationDuration', 800) ?? 800,
      ),
      vsync: this,
    );
    
    _valueAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Update target value when data changes
    if (currentValue != null) {
      _targetValue = currentValue.toDouble();
      _animateToValue(_targetValue);
    }
    
    return AnimatedBuilder(
      animation: _valueAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: CircularGaugePainter(
            value: _valueAnimation.value,
            minValue: getRequiredProperty<num>('minValue').toDouble(),
            maxValue: getRequiredProperty<num>('maxValue').toDouble(),
            zones: _parseZones(),
            showValue: getProperty<bool>('showValue', true) ?? true,
            label: getProperty<String>('label', '') ?? '',
            units: getProperty<String>('units', '') ?? '',
            tickInterval: (getProperty<num>('tickInterval', 1000) ?? 1000).toDouble(),
            primaryColor: getProperty<Color>('primaryColor', const Color(0xFF4a90e2)) ?? const Color(0xFF4a90e2),
            backgroundColor: getProperty<Color>('backgroundColor', Colors.black) ?? Colors.black,
            textColor: getProperty<Color>('textColor', Colors.white) ?? Colors.white,
          ),
        );
      },
    );
  }
  
  List<GaugeZone> _parseZones() {
    final zonesData = getProperty<List<dynamic>>('zones', []) ?? [];
    return zonesData.map((zone) {
      return GaugeZone(
        start: (zone['start'] ?? 0).toDouble(),
        end: zone['end'].toDouble(),
        color: zone['color'] is Color 
            ? zone['color'] 
            : Color(zone['color'] is String 
                ? int.parse(zone['color'].replaceFirst('#', '0xFF'))
                : zone['color']),
      );
    }).toList();
  }
  
  void _animateToValue(double newValue) {
    _valueAnimation = Tween<double>(
      begin: _currentValue,
      end: newValue,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _animationController.forward(from: 0);
    _currentValue = newValue;
  }
}

/// Zone configuration for the gauge
class GaugeZone {
  final double start;
  final double end;
  final Color color;
  
  const GaugeZone({
    required this.start,
    required this.end,
    required this.color,
  });
}

/// Custom painter for the circular gauge
class CircularGaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final List<GaugeZone> zones;
  final bool showValue;
  final String label;
  final String units;
  final double tickInterval;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;
  
  CircularGaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.zones,
    required this.showValue,
    required this.label,
    required this.units,
    required this.tickInterval,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.15;
      
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw zones
    final startAngle = 3 * math.pi / 4;
    final sweepAngle = 3 * math.pi / 2;
    
    for (final zone in zones) {
      final zoneStartAngle = startAngle + 
          (zone.start - minValue) / (maxValue - minValue) * sweepAngle;
      final zoneSweepAngle = 
          (zone.end - zone.start) / (maxValue - minValue) * sweepAngle;
      
      final zonePaint = Paint()
        ..color = zone.color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.15
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        zoneStartAngle,
        zoneSweepAngle,
        false,
        zonePaint,
      );
    }
    
    // Draw progress arc
    final progress = (value - minValue) / (maxValue - minValue);
    final progressAngle = progress * sweepAngle;
    
    final progressPaint = Paint()
      ..color = _getColorForValue(value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressAngle,
      false,
      progressPaint,
    );
    
    // Draw ticks
    _drawTicks(canvas, center, radius);
    
    // Draw needle
    _drawNeedle(canvas, center, radius, progress);
    
    // Draw center cap
    canvas.drawCircle(
      center,
      radius * 0.1,
      Paint()..color = primaryColor,
    );
    
    // Draw value text
    if (showValue) {
      _drawValueText(canvas, center, size);
    }
    
    // Draw label
    if (label.isNotEmpty) {
      _drawLabel(canvas, center, size);
    }
  }
  
  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = textColor.withOpacity(0.5)
      ..strokeWidth = 2;
    
    final numTicks = ((maxValue - minValue) / tickInterval).round() + 1;
    final anglePerTick = (3 * math.pi / 2) / (numTicks - 1);
    final startAngle = 3 * math.pi / 4;
    
    for (int i = 0; i < numTicks; i++) {
      final angle = startAngle + i * anglePerTick;
      final isMain = i % 2 == 0;
      final tickLength = radius * (isMain ? 0.1 : 0.05);
      
      final start = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawLine(start, end, tickPaint);
      
      // Draw tick labels
      if (isMain) {
        final value = minValue + i * tickInterval;
        final textPainter = TextPainter(
          text: TextSpan(
            text: value.toStringAsFixed(0),
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: radius * 0.08,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        final labelRadius = radius - tickLength - radius * 0.15;
        final labelOffset = Offset(
          center.dx + labelRadius * math.cos(angle) - textPainter.width / 2,
          center.dy + labelRadius * math.sin(angle) - textPainter.height / 2,
        );
        
        textPainter.paint(canvas, labelOffset);
      }
    }
  }
  
  void _drawNeedle(Canvas canvas, Offset center, double radius, double progress) {
    final angle = 3 * math.pi / 4 + progress * 3 * math.pi / 2;
    
    final needlePath = Path();
    needlePath.moveTo(
      center.dx + radius * 0.05 * math.cos(angle - math.pi / 2),
      center.dy + radius * 0.05 * math.sin(angle - math.pi / 2),
    );
    needlePath.lineTo(
      center.dx + radius * 0.9 * math.cos(angle),
      center.dy + radius * 0.9 * math.sin(angle),
    );
    needlePath.lineTo(
      center.dx + radius * 0.05 * math.cos(angle + math.pi / 2),
      center.dy + radius * 0.05 * math.sin(angle + math.pi / 2),
    );
    needlePath.close();
    
    canvas.drawPath(
      needlePath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill,
    );
    
    // Add glow effect
    canvas.drawPath(
      needlePath,
      Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  
  void _drawValueText(Canvas canvas, Offset center, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(
          color: textColor,
          fontSize: size.width * 0.15,
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
        center.dx - textPainter.width / 2,
        center.dy + size.height * 0.15,
      ),
    );
    
    // Draw units
    if (units.isNotEmpty) {
      final unitsPainter = TextPainter(
        text: TextSpan(
          text: units,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: size.width * 0.06,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      unitsPainter.layout();
      
      unitsPainter.paint(
        canvas,
        Offset(
          center.dx - unitsPainter.width / 2,
          center.dy + size.height * 0.25,
        ),
      );
    }
  }
  
  void _drawLabel(Canvas canvas, Offset center, Size size) {
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label.toUpperCase(),
        style: TextStyle(
          color: textColor.withOpacity(0.5),
          fontSize: size.width * 0.05,
          fontWeight: FontWeight.w300,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy - size.height * 0.3,
      ),
    );
  }
  
  Color _getColorForValue(double value) {
    for (final zone in zones) {
      if (value >= zone.start && value <= zone.end) {
        return zone.color;
      }
    }
    return primaryColor;
  }
  
  @override
  bool shouldRepaint(CircularGaugePainter oldDelegate) {
    return value != oldDelegate.value ||
           minValue != oldDelegate.minValue ||
           maxValue != oldDelegate.maxValue;
  }
}