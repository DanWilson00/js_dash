import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/mavlink_spoof_service.dart';

class JetsharkDashboard extends StatefulWidget {
  const JetsharkDashboard({super.key});

  @override
  State<JetsharkDashboard> createState() => _JetsharkDashboardState();
}

class _JetsharkDashboardState extends State<JetsharkDashboard> with TickerProviderStateMixin {
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();
  Timer? _updateTimer;
  
  // Animation controllers
  late AnimationController _rpmController;
  late AnimationController _startupController;
  late AnimationController _pulseController;
  
  // Animated values
  late Animation<double> _rpmAnimation;
  late Animation<double> _startupAnimation;
  late Animation<double> _pulseAnimation;
  
  // Data values
  double _rpm = 0.0;
  double _targetRpm = 0.0;
  double _speed = 0.0;
  double _leftWing = 0.0;
  double _rightWing = 0.0;
  double _targetLeftWing = 0.0;
  double _targetRightWing = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startUpdates();
  }

  void _initializeAnimations() {
    _rpmController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _startupController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    _rpmAnimation = CurvedAnimation(
      parent: _rpmController,
      curve: Curves.easeInOutCubic,
    );
    
    _startupAnimation = CurvedAnimation(
      parent: _startupController,
      curve: Curves.easeOut,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _rpmController.dispose();
    _startupController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_spoofService.isRunning) {
        setState(() {
          _targetRpm = _spoofService.currentRPM;
          _speed = _spoofService.currentSpeed * 1.94384; // Convert to knots
          
          
          _targetLeftWing = _spoofService.portWingPosition;
          _targetRightWing = _spoofService.starboardWingPosition;
          
          // Smooth RPM animation - always update
          _rpm = _rpm + (_targetRpm - _rpm) * 0.08;
          if ((_targetRpm - _rpm).abs() > 5) {
            _rpmController.forward(from: 0);
          }
          
          // Smooth wing animations
          _leftWing = _leftWing + (_targetLeftWing - _leftWing) * 0.08;
          _rightWing = _rightWing + (_targetRightWing - _rightWing) * 0.08;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AnimatedBuilder(
        animation: _startupAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _startupAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    const Color(0xFF0a0a0a),
                    const Color(0xFF000000),
                  ],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Subtle ambient lighting
                        _buildAmbientLighting(constraints),
                        
                        // Main dashboard content
                        _buildDashboardContent(constraints),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmbientLighting(BoxConstraints constraints) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: AmbientLightingPainter(
              pulseValue: _pulseAnimation.value,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    final centerGaugeSize = math.min(screenWidth * 0.75, screenHeight * 0.85);
    
    return Column(
      children: [
        // JETSHARK branding at top
        _buildJetsharkBranding(screenWidth, screenHeight),
        
        // Main dashboard area
        Expanded(
          child: Row(
            children: [
              // Left wing indicator
              Expanded(
                flex: 2,
                child: _buildWingIndicator(
                  'LEFT WING',
                  _leftWing,
                  screenWidth,
                  screenHeight,
                  true,
                ),
              ),
              
              // Center RPM gauge with speed
              Expanded(
                flex: 4,
                child: _buildCentralRPMGauge(centerGaugeSize),
              ),
              
              // Right wing indicator
              Expanded(
                flex: 2,
                child: _buildWingIndicator(
                  'RIGHT WING',
                  _rightWing,
                  screenWidth,
                  screenHeight,
                  false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJetsharkBranding(double screenWidth, double screenHeight) {
    final fontSize = (screenWidth * 0.028).clamp(20.0, 36.0);
    
    return Container(
      height: screenHeight * 0.06,
      alignment: Alignment.center,
      child: Text(
        'JETSHARK',
        style: TextStyle(
          color: const Color(0xFFc0c0c0),
          fontSize: fontSize,
          fontWeight: FontWeight.w300,
          letterSpacing: fontSize * 0.3,
        ),
      ),
    );
  }

  Widget _buildCentralRPMGauge(double gaugeSize) {
    // RPM range: 0 to 7000 RPM
    final rpmPercent = (_rpm / 7000).clamp(0.0, 1.0);
    
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rpmAnimation, _pulseAnimation]),
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
                    rpmPercent: rpmPercent, // Remove animation multiplication
                    rpm: _rpm,
                    pulseValue: _pulseAnimation.value,
                  ),
                ),
                
                // Central speed display
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _speed.round().toString().padLeft(2, '0'),
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
                      '${_rpm.round()} RPM',
                      style: TextStyle(
                        color: const Color(0xFF4a90e2),
                        fontSize: gaugeSize * 0.05,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWingIndicator(String label, double angle, double screenWidth, double screenHeight, bool isLeft) {
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
        animation: _pulseAnimation,
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

// Custom painter for the RPM gauge
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
      
      // Color based on RPM percentage - restored blue styling
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

// Custom painter for curved wing indicators
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

// Ambient lighting painter
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