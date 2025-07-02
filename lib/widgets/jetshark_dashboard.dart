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
          
          // Smooth RPM animation
          if ((_targetRpm - _rpm).abs() > 10) {
            _rpm = _rpm + (_targetRpm - _rpm) * 0.1;
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
    final centerGaugeSize = math.min(screenWidth * 0.5, screenHeight * 0.6);
    
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
                flex: 3,
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
      height: screenHeight * 0.1,
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
    final rpmPercent = (_rpm / 3000).clamp(0.0, 1.0);
    
    return Center(
      child: AnimatedBuilder(
        animation: _rpmAnimation,
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
                    rpmPercent: rpmPercent * _rpmAnimation.value,
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
                        fontSize: gaugeSize * 0.22,
                        fontWeight: FontWeight.w100,
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
    final normalizedAngle = (angle + 50) / 100; // -50 to +50 becomes 0 to 1
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenHeight * 0.05,
      ),
      child: Column(
        children: [
          // Wing gauge
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: WingIndicatorPainter(
                angle: normalizedAngle,
                isLeft: isLeft,
                label: label,
                degrees: angle.round(),
              ),
            ),
          ),
        ],
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
      ..strokeWidth = radius * 0.03
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
        ..strokeWidth = radius * 0.03
        ..strokeCap = StrokeCap.round;
      
      // Color based on RPM
      if (rpmPercent < 0.7) {
        progressPaint.color = const Color(0xFF4a90e2); // Blue
      } else if (rpmPercent < 0.85) {
        progressPaint.color = const Color(0xFFf5a623); // Orange
      } else {
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
    const tickCount = 11; // 0 to 100 in increments of 10
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (int i = 0; i < tickCount; i++) {
      final angle = startAngle + (totalAngle * i / (tickCount - 1));
      final tickRadius = radius * 0.88;
      
      // Draw tick marks
      final tickPaint = Paint()
        ..color = const Color(0xFF606060)
        ..strokeWidth = 1.5;
      
      final tickLength = radius * 0.04;
      final start = Offset(
        center.dx + (tickRadius + tickLength) * math.cos(angle),
        center.dy + (tickRadius + tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + tickRadius * math.cos(angle),
        center.dy + tickRadius * math.sin(angle),
      );
      
      canvas.drawLine(start, end, tickPaint);
      
      // Draw numbers
      final value = (i * 300).toString(); // 0 to 3000 RPM
      textPainter.text = TextSpan(
        text: value,
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
    
    // RPM label
    textPainter.text = TextSpan(
      text: 'RPM',
      style: TextStyle(
        color: const Color(0xFF606060),
        fontSize: radius * 0.05,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center + Offset(-textPainter.width / 2, radius * 0.35),
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

  @override
  void paint(Canvas canvas, Size size) {
    // Draw curved scale
    _drawCurvedScale(canvas, size);
    
    // Draw position indicator
    _drawPositionIndicator(canvas, size);
    
    // Draw label and value
    _drawLabelAndValue(canvas, size);
  }

  void _drawCurvedScale(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width * 0.4;
    final startAngle = isLeft ? math.pi * 0.7 : math.pi * 0.3;
    final sweepAngle = isLeft ? math.pi * 0.5 : -math.pi * 0.5;
    
    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );
    
    // Draw scale marks
    final tickPaint = Paint()
      ..color = const Color(0xFF404040)
      ..strokeWidth = 1;
    
    for (int i = 0; i <= 10; i++) {
      final tickAngle = startAngle + (sweepAngle * i / 10);
      final innerRadius = radius - size.width * 0.04;
      final outerRadius = radius + size.width * 0.04;
      
      final start = Offset(
        center.dx + innerRadius * math.cos(tickAngle),
        center.dy + innerRadius * math.sin(tickAngle),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(tickAngle),
        center.dy + outerRadius * math.sin(tickAngle),
      );
      
      canvas.drawLine(start, end, tickPaint);
    }
  }

  void _drawPositionIndicator(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width * 0.4;
    final startAngle = isLeft ? math.pi * 0.7 : math.pi * 0.3;
    final sweepAngle = isLeft ? math.pi * 0.5 : -math.pi * 0.5;
    final currentAngle = startAngle + (sweepAngle * angle);
    
    // Position arc
    final progressPaint = Paint()
      ..color = degrees.abs() > 30 ? const Color(0xFFd0021b) : const Color(0xFF4a90e2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentAngle - startAngle,
      false,
      progressPaint,
    );
    
    // Indicator dot
    final dotRadius = size.width * 0.05;
    final dotX = center.dx + radius * math.cos(currentAngle);
    final dotY = center.dy + radius * math.sin(currentAngle);
    
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
  }

  void _drawLabelAndValue(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Label
    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(
        color: const Color(0xFF808080),
        fontSize: size.width * 0.08,
        fontWeight: FontWeight.w300,
        letterSpacing: 1,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.05),
    );
    
    // Value
    textPainter.text = TextSpan(
      text: '${degrees.abs()}°',
      style: TextStyle(
        color: Colors.white,
        fontSize: size.width * 0.12,
        fontWeight: FontWeight.w200,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.85),
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