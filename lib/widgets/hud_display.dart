import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/mavlink_spoof_service.dart';

class HUDDisplay extends StatefulWidget {
  const HUDDisplay({super.key});

  @override
  State<HUDDisplay> createState() => _HUDDisplayState();
}

class _HUDDisplayState extends State<HUDDisplay> with TickerProviderStateMixin {
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();
  Timer? _updateTimer;
  
  // Animation controllers
  late AnimationController _needleController;
  late AnimationController _glowController;
  late AnimationController _startupController;
  
  // Animated values
  late Animation<double> _needleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _startupAnimation;
  
  // Data values
  double _rpm = 0.0;
  double _targetRpm = 0.0;
  double _speed = 0.0;
  double _heading = 0.0;
  double _portWing = 0.0;
  double _starboardWing = 0.0;
  
  // Speed trend tracking
  double _lastSpeed = 0.0;
  String _speedTrend = '→';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startUpdates();
    _playStartupAnimation();
  }

  void _initializeAnimations() {
    _needleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _startupController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _needleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.elasticOut),
    );
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _startupAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _startupController, curve: Curves.easeOutCubic),
    );
    
    _glowController.repeat(reverse: true);
  }

  void _playStartupAnimation() {
    _startupController.forward();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _needleController.dispose();
    _glowController.dispose();
    _startupController.dispose();
    super.dispose();
  }

  void _startUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_spoofService.isRunning) {
        setState(() {
          _targetRpm = _spoofService.currentRPM;
          
          // Track speed trend
          final newSpeed = _spoofService.currentSpeed;
          if ((newSpeed - _lastSpeed).abs() > 0.1) {
            _speedTrend = newSpeed > _lastSpeed ? '↗' : '↘';
            _lastSpeed = newSpeed;
          } else {
            _speedTrend = '→';
          }
          _speed = newSpeed;
          
          _heading = (_heading + (math.Random().nextDouble() - 0.5) * 2) % 360;
          if (_heading < 0) _heading += 360;
          
          _portWing = _spoofService.portWingPosition;
          _starboardWing = _spoofService.starboardWingPosition;
        });
        
        // Animate needle to target RPM
        if ((_targetRpm - _rpm).abs() > 50) {
          _rpm = _rpm + (_targetRpm - _rpm) * 0.15; // Smooth needle movement
          _needleController.forward(from: 0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                Color(0xFF001a2e),
                Color(0xFF000814),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.7, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _startupAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _startupAnimation.value,
                child: Transform.scale(
                  scale: 0.8 + (_startupAnimation.value * 0.2),
                  child: Stack(
                    children: [
                      // Scan lines effect
                      _buildScanLines(),
                      
                      // Main dashboard
                      _buildMainDashboard(),
                      
                      // Glass reflection overlay
                      _buildGlassOverlay(),
                      
                      // Navigation hint
                      _buildNavigationHint(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScanLines() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return CustomPaint(
            painter: ScanLinesPainter(_glowController.value),
          );
        },
      ),
    );
  }

  Widget _buildMainDashboard() {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Top brand section
            _buildTopBrand(),
            
            const SizedBox(height: 40),
            
            // Main instrument cluster
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left wing indicator
                  Expanded(
                    flex: 2,
                    child: _buildAdvancedWingIndicator('PORT', _portWing, true),
                  ),
                  
                  const SizedBox(width: 30),
                  
                  // Central RPM tachometer
                  Expanded(
                    flex: 4,
                    child: _buildCentralTachometer(),
                  ),
                  
                  const SizedBox(width: 30),
                  
                  // Right wing indicator
                  Expanded(
                    flex: 2,
                    child: _buildAdvancedWingIndicator('STBD', _starboardWing, false),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Bottom information bar
            _buildBottomInfoBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBrand() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001a2e).withValues(alpha: 0.3),
            const Color(0xFF003a5c).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Text(
        'JETSHARK',
        style: TextStyle(
          color: Color(0xFF00d4ff),
          fontSize: 22,
          fontWeight: FontWeight.w200,
          letterSpacing: 6.0,
        ),
      ),
    );
  }

  Widget _buildCentralTachometer() {
    final rpmPercent = ((_rpm - 800) / 2200).clamp(0.0, 1.0);
    final isDangerZone = _rpm > 2500;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_needleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Stack(
            alignment: Alignment.center,
            children: [
              // Main tachometer
              CustomPaint(
                size: const Size(300, 300),
                painter: TachometerPainter(
                  rpmPercent: rpmPercent,
                  isDanger: isDangerZone,
                  glowIntensity: _glowAnimation.value,
                  needleAnimation: _needleAnimation.value,
                ),
              ),
              
              // Center digital display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF000814).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDangerZone 
                      ? Color.lerp(const Color(0xFFff4444), const Color(0xFFff8888), _glowAnimation.value)!
                      : Color.lerp(const Color(0xFF00d4ff), const Color(0xFF66e0ff), _glowAnimation.value)!,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_rpm.round()}',
                      style: TextStyle(
                        color: isDangerZone 
                          ? Color.lerp(const Color(0xFFff4444), const Color(0xFFff8888), _glowAnimation.value)
                          : Color.lerp(const Color(0xFF00d4ff), const Color(0xFF66e0ff), _glowAnimation.value),
                        fontSize: 36,
                        fontWeight: FontWeight.w100,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'RPM',
                      style: TextStyle(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        );
      },
    );
  }

  Widget _buildAdvancedWingIndicator(String label, double position, bool isLeft) {
    final isWarning = position.abs() > 30;
    final normalizedPosition = ((position + 50) / 100).clamp(0.0, 1.0);
    
    return Column(
        children: [
          // Label with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF001a2e).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isWarning 
                  ? const Color(0xFFff4444).withValues(alpha: 0.5)
                  : const Color(0xFF00d4ff).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isWarning ? const Color(0xFFff4444) : const Color(0xFF00d4ff),
                fontSize: 14,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.0,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Advanced wing gauge
          Expanded(
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF001a2e).withValues(alpha: 0.2),
                    const Color(0xFF000814).withValues(alpha: 0.8),
                    const Color(0xFF001a2e).withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(
                  color: isWarning 
                    ? const Color(0xFFff4444).withValues(alpha: 0.4)
                    : const Color(0xFF00d4ff).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isWarning ? const Color(0xFFff4444) : const Color(0xFF00d4ff))
                        .withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Gauge markings
                  CustomPaint(
                    size: Size(80, MediaQuery.of(context).size.height * 0.4),
                    painter: WingGaugePainter(),
                  ),
                  
                  // Position indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    top: normalizedPosition * (MediaQuery.of(context).size.height * 0.35) + 40,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: isWarning ? const Color(0xFFff4444) : const Color(0xFF00d4ff),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: (isWarning ? const Color(0xFFff4444) : const Color(0xFF00d4ff))
                                .withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 25,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 15),
          
          // Position readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF000814).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${position.round()}°',
              style: TextStyle(
                color: isWarning ? const Color(0xFFff4444) : const Color(0xFF00d4ff),
                fontSize: 18,
                fontWeight: FontWeight.w300,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
    );
  }

  Widget _buildBottomInfoBar() {
    final speedKnots = _speed * 1.94384;
    final headingStr = _getHeadingString(_heading);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001a2e).withValues(alpha: 0.4),
            const Color(0xFF000814).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Speed with trend
          _buildInfoPanel(
            value: speedKnots.toStringAsFixed(1),
            unit: 'KT',
            label: 'SPEED',
            trend: _speedTrend,
          ),
          
          // Vertical divider
          Container(
            width: 1,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF00d4ff).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Heading
          _buildInfoPanel(
            value: _heading.round().toString(),
            unit: '°',
            label: 'HEADING',
            trend: headingStr,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel({
    required String value,
    required String unit,
    required String label,
    required String trend,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF00d4ff),
                fontSize: 32,
                fontWeight: FontWeight.w100,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trend,
              style: TextStyle(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  String _getHeadingString(double heading) {
    final dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return dirs[index];
  }

  Widget _buildGlassOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.02),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.01),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationHint() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF001a2e).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            'TAP TO RETURN TO TELEMETRY',
            style: TextStyle(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class TachometerPainter extends CustomPainter {
  final double rpmPercent;
  final bool isDanger;
  final double glowIntensity;
  final double needleAnimation;

  TachometerPainter({
    required this.rpmPercent,
    required this.isDanger,
    required this.glowIntensity,
    required this.needleAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    // Draw tachometer arc background
    _drawTachometerArc(canvas, center, radius);
    
    // Draw tick marks and numbers
    _drawTickMarks(canvas, center, radius);
    
    // Draw color zones
    _drawColorZones(canvas, center, radius);
    
    // Draw needle
    _drawNeedle(canvas, center, radius);
  }

  void _drawTachometerArc(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF001a2e).withValues(alpha: 0.6)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75; // 7 o'clock
    const sweepAngle = math.pi * 1.5; // 270 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 8; i++) {
      final angle = math.pi * 0.75 + (math.pi * 1.5 * i / 8);
      final rpm = 800 + (i * 275); // 800 to 3000 RPM
      
      // Major tick
      final startPoint = Offset(
        center.dx + (radius - 15) * math.cos(angle),
        center.dy + (radius - 15) * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawLine(startPoint, endPoint, paint);
      
      // RPM numbers
      if (i % 2 == 0) {
        final textOffset = Offset(
          center.dx + (radius - 35) * math.cos(angle),
          center.dy + (radius - 35) * math.sin(angle),
        );
        
        textPainter.text = TextSpan(
          text: '${(rpm / 100).round()}',
          style: TextStyle(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas, 
          textOffset - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  void _drawColorZones(Canvas canvas, Offset center, double radius) {
    const startAngle = math.pi * 0.75;
    const totalSweep = math.pi * 1.5;
    
    // Green zone (800-2000 RPM) - 54.5% of total
    final greenSweep = totalSweep * 0.545;
    final greenPaint = Paint()
      ..color = const Color(0xFF00ff88).withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 10),
      startAngle,
      greenSweep,
      false,
      greenPaint,
    );
    
    // Amber zone (2000-2500 RPM) - 22.7% of total
    final amberSweep = totalSweep * 0.227;
    final amberPaint = Paint()
      ..color = const Color(0xFFffd700).withValues(alpha: 0.4)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 10),
      startAngle + greenSweep,
      amberSweep,
      false,
      amberPaint,
    );
    
    // Red zone (2500+ RPM) - 22.7% of total
    final redSweep = totalSweep * 0.227;
    final redPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFFff4444).withValues(alpha: 0.4),
        const Color(0xFFff4444).withValues(alpha: 0.8),
        glowIntensity,
      )!
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 10),
      startAngle + greenSweep + amberSweep,
      redSweep,
      false,
      redPaint,
    );
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    const startAngle = math.pi * 0.75;
    const totalSweep = math.pi * 1.5;
    final needleAngle = startAngle + (totalSweep * rpmPercent);
    
    final needlePaint = Paint()
      ..color = isDanger 
        ? Color.lerp(const Color(0xFFff4444), const Color(0xFFff8888), glowIntensity)!
        : const Color(0xFF00d4ff)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // Needle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    final needleEnd = Offset(
      center.dx + (radius - 20) * math.cos(needleAngle),
      center.dy + (radius - 20) * math.sin(needleAngle),
    );
    
    final shadowEnd = Offset(
      center.dx + (radius - 18) * math.cos(needleAngle) + 2,
      center.dy + (radius - 18) * math.sin(needleAngle) + 2,
    );
    
    // Draw shadow
    canvas.drawLine(center + const Offset(2, 2), shadowEnd, shadowPaint);
    
    // Draw needle
    canvas.drawLine(center, needleEnd, needlePaint);
    
    // Center hub
    final hubPaint = Paint()
      ..color = isDanger 
        ? Color.lerp(const Color(0xFFff4444), const Color(0xFFff8888), glowIntensity)!
        : const Color(0xFF00d4ff)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 6, hubPaint);
    
    // Center hub highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center - const Offset(2, 2), 3, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WingGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw gauge marks
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (0.1 + i * 0.2);
      canvas.drawLine(
        Offset(size.width * 0.2, y),
        Offset(size.width * 0.8, y),
        paint,
      );
    }
    
    // Center reference line
    final centerPaint = Paint()
      ..color = const Color(0xFFffd700).withValues(alpha: 0.6)
      ..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.5),
      Offset(size.width * 0.9, size.height * 0.5),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanLinesPainter extends CustomPainter {
  final double animationValue;
  
  ScanLinesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.02 * animationValue)
      ..strokeWidth = 1;

    // Subtle horizontal scan lines
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}