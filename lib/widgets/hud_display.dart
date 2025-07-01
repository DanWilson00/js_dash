import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/mavlink_spoof_service.dart';

class HUDDisplay extends StatefulWidget {
  const HUDDisplay({super.key});

  @override
  State<HUDDisplay> createState() => _HUDDisplayState();
}

class _HUDDisplayState extends State<HUDDisplay> {
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();
  Timer? _updateTimer;
  
  double _rpm = 0.0;
  double _speed = 0.0;
  double _portWing = 0.0;
  double _starboardWing = 0.0;

  @override
  void initState() {
    super.initState();
    _startUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startUpdates() {
    // Update HUD at 30Hz for ultra-smooth animations
    _updateTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_spoofService.isRunning) {
        setState(() {
          _rpm = _spoofService.currentRPM;
          _speed = _spoofService.currentSpeed;
          _portWing = _spoofService.portWingPosition;
          _starboardWing = _spoofService.starboardWingPosition;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF000511),
      body: SafeArea(
        child: Stack(
          children: [
            // Advanced background layers
            _buildBackgroundLayers(),
            
            // Hexagonal grid overlay
            _buildHexagonalGrid(),
            
            // Main HUD interface
            _buildMainInterface(size),
            
            // Animated scan lines
            _buildScanLines(),
            
            // Corner elements
            _buildCornerElements(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundLayers() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 2.0,
            colors: [
              Color(0xFF001133),
              Color(0xFF000511),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildHexagonalGrid() {
    return Positioned.fill(
      child: CustomPaint(
        painter: HexagonalGridPainter(),
      ),
    );
  }

  Widget _buildMainInterface(Size size) {
    return Stack(
      children: [
        // Main content area
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Main content area
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left panel - Port wing
                      Expanded(
                        flex: 2,
                        child: _buildAdvancedWingPanel('PORT', _portWing, true),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Center panel - Main gauges
                      Expanded(
                        flex: 4,
                        child: _buildCenterPanel(),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Right panel - Starboard wing
                      Expanded(
                        flex: 2,
                        child: _buildAdvancedWingPanel('STBD', _starboardWing, false),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Bottom info bar
                _buildBottomInfoBar(),
              ],
            ),
          ),
        ),
        
        // Floating status indicators
        _buildAdvancedTopBar(),
      ],
    );
  }

  Widget _buildAdvancedTopBar() {
    return Positioned(
      top: 20,
      right: 20,
      child: Row(
        children: [
          _buildStatusIndicator('SYS', _spoofService.isRunning),
          const SizedBox(width: 12),
          _buildStatusIndicator('NAV', _spoofService.isRunning),
          const SizedBox(width: 12),
          _buildStatusIndicator('PWR', true),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00FF88) : const Color(0xFF444444),
            shape: BoxShape.circle,
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFF00FF88).withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ] : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF00FF88) : const Color(0xFF444444),
            fontSize: 8,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterPanel() {
    return Column(
      children: [
        // Main RPM gauge - takes up most space
        Expanded(
          flex: 5,
          child: _buildAdvancedRPMGauge(),
        ),
        
        const SizedBox(height: 16),
        
        // Bottom row with speed and additional metrics
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(child: _buildSpeedGauge()),
              const SizedBox(width: 16),
              Expanded(child: _buildTempGauge()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedRPMGauge() {
    final rpmPercent = ((_rpm - 800) / 2200).clamp(0.0, 1.0);
    final dangerZone = _rpm > 2500;
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF001133).withValues(alpha: 0.8),
            const Color(0xFF000511).withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: dangerZone ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (dangerZone ? const Color(0xFFFF4444) : const Color(0xFF00DDFF))
                .withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Outer ring segments
          Positioned.fill(
            child: CustomPaint(
              painter: RPMRingPainter(rpmPercent, dangerZone),
            ),
          ),
          
          // Inner hexagonal frame
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00DDFF).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // RPM value
                  Text(
                    '${_rpm.round()}',
                    style: TextStyle(
                      color: dangerZone ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                      fontSize: 52,
                      fontWeight: FontWeight.w100,
                      fontFamily: 'monospace',
                    ),
                  ),
                  
                  // RPM label
                  Text(
                    'ENGINE RPM',
                    style: TextStyle(
                      color: const Color(0xFF00DDFF).withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2.0,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Status bar
                  Container(
                    width: 120,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00FF88),
                          Color(0xFFFFDD00),
                          Color(0xFFFF4444),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment(-1 + (rpmPercent * 2), 0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge() {
    final speedKnots = _speed * 1.94384;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF001133).withValues(alpha: 0.8),
            const Color(0xFF000511).withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00DDFF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  speedKnots.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFF00DDFF),
                    fontSize: 32,
                    fontWeight: FontWeight.w100,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'KT',
                  style: TextStyle(
                    color: const Color(0xFF00DDFF).withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'VELOCITY',
              style: TextStyle(
                color: const Color(0xFF00DDFF).withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // Speed bar indicator
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFF001122),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (speedKnots / 20).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00DDFF),
                        Color(0xFF00FF88),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTempGauge() {
    // Simulate engine temperature
    final temp = 85 + (_rpm / 3000 * 25); // 85-110°C based on RPM
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF001133).withValues(alpha: 0.8),
            const Color(0xFF000511).withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: temp > 105 ? const Color(0xFFFF4444) : const Color(0xFF00DDFF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  temp.round().toString(),
                  style: TextStyle(
                    color: temp > 105 ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                    fontSize: 32,
                    fontWeight: FontWeight.w100,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '°C',
                  style: TextStyle(
                    color: (temp > 105 ? const Color(0xFFFF4444) : const Color(0xFF00DDFF)).withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ENGINE TEMP',
              style: TextStyle(
                color: const Color(0xFF00DDFF).withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // Temperature bar
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFF001122),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((temp - 60) / 50).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: temp > 105 ? [
                        const Color(0xFFFF4444),
                        const Color(0xFFFF8888),
                      ] : [
                        const Color(0xFF00DDFF),
                        const Color(0xFFFFDD00),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedWingPanel(String label, double position, bool isPort) {
    final isWarning = position.abs() > 30;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF001133).withValues(alpha: 0.6),
            const Color(0xFF000511).withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'WING CONTROL',
                    style: TextStyle(
                      color: const Color(0xFF00DDFF).withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main wing indicator
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Vertical track
                      Center(
                        child: Container(
                          width: 40,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF00DDFF).withValues(alpha: 0.1),
                                const Color(0xFF001122).withValues(alpha: 0.3),
                                const Color(0xFF00DDFF).withValues(alpha: 0.1),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFF00DDFF).withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      
                      // Position markers
                      ...List.generate(5, (index) {
                        final markerPosition = (index / 4) * 0.8 + 0.1; // 10% to 90%
                        return Positioned(
                          top: markerPosition * constraints.maxHeight,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 1,
                              color: const Color(0xFF00DDFF).withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      }),
                      
                      // Center reference line
                      Positioned(
                        top: constraints.maxHeight * 0.5,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDD00),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFDD00).withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Wing position indicator
                      Positioned(
                        top: ((position + 50) / 100) * constraints.maxHeight * 0.8 + constraints.maxHeight * 0.1,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: (isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF))
                                      .withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 2,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            // Bottom value display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    '${position.round()}°',
                    style: TextStyle(
                      color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: (isWarning ? const Color(0xFFFF4444) : const Color(0xFF00FF88))
                          .withValues(alpha: 0.2),
                    ),
                    child: Text(
                      isWarning ? 'LIMIT' : 'NORMAL',
                      style: TextStyle(
                        color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00FF88),
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfoBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001122).withValues(alpha: 0.6),
            const Color(0xFF002244).withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00DDFF).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(
              Icons.touch_app,
              color: const Color(0xFF00DDFF).withValues(alpha: 0.6),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'TAP ANYWHERE TO RETURN TO TELEMETRY',
              style: TextStyle(
                color: const Color(0xFF00DDFF).withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            Text(
              'HUD MODE ACTIVE',
              style: TextStyle(
                color: const Color(0xFF00FF88).withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanLines() {
    return Positioned.fill(
      child: CustomPaint(
        painter: ScanLinesPainter(),
      ),
    );
  }

  Widget _buildCornerElements() {
    return Stack(
      children: [
        // Top left corner
        Positioned(
          top: 10,
          left: 10,
          child: CustomPaint(
            size: const Size(30, 30),
            painter: CornerFramePainter(),
          ),
        ),
        // Top right corner
        Positioned(
          top: 10,
          right: 10,
          child: Transform.rotate(
            angle: math.pi / 2,
            child: CustomPaint(
              size: const Size(30, 30),
              painter: CornerFramePainter(),
            ),
          ),
        ),
        // Bottom left corner
        Positioned(
          bottom: 10,
          left: 10,
          child: Transform.rotate(
            angle: -math.pi / 2,
            child: CustomPaint(
              size: const Size(30, 30),
              painter: CornerFramePainter(),
            ),
          ),
        ),
        // Bottom right corner
        Positioned(
          bottom: 10,
          right: 10,
          child: Transform.rotate(
            angle: math.pi,
            child: CustomPaint(
              size: const Size(30, 30),
              painter: CornerFramePainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class HexagonalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00DDFF).withValues(alpha: 0.03)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double hexSize = 40.0;
    const double hexHeight = hexSize * 0.866; // sqrt(3)/2
    
    for (double y = -hexHeight; y < size.height + hexHeight; y += hexHeight * 1.5) {
      for (double x = -hexSize; x < size.width + hexSize; x += hexSize * 1.5) {
        final offset = (y / (hexHeight * 1.5)).round() % 2 == 1 ? hexSize * 0.75 : 0.0;
        _drawHexagon(canvas, paint, Offset(x + offset, y), hexSize);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi) / 3;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RPMRingPainter extends CustomPainter {
  final double progress;
  final bool isDanger;
  
  RPMRingPainter(this.progress, this.isDanger);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    
    // Background ring segments
    final bgPaint = Paint()
      ..color = const Color(0xFF001122).withValues(alpha: 0.3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    
    // Draw background segments
    for (int i = 0; i < 12; i++) {
      final startAngle = -math.pi / 2 + (i * 2 * math.pi / 12);
      final sweepAngle = (2 * math.pi / 12) - 0.1;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        bgPaint,
      );
    }
    
    // Active progress segments
    final activePaint = Paint()
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    
    final activeSegments = (progress * 12).round();
    
    for (int i = 0; i < activeSegments; i++) {
      final segmentProgress = i / 12.0;
      Color segmentColor;
      
      if (segmentProgress < 0.6) {
        segmentColor = const Color(0xFF00DDFF);
      } else if (segmentProgress < 0.8) {
        segmentColor = const Color(0xFFFFDD00);
      } else {
        segmentColor = const Color(0xFFFF4444);
      }
      
      activePaint.color = segmentColor;
      
      final startAngle = -math.pi / 2 + (i * 2 * math.pi / 12);
      final sweepAngle = (2 * math.pi / 12) - 0.1;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! RPMRingPainter ||
           oldDelegate.progress != progress ||
           oldDelegate.isDanger != isDanger;
  }
}

class ScanLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00DDFF).withValues(alpha: 0.02)
      ..strokeWidth = 1;
    
    // Horizontal scan lines
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CornerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00DDFF).withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path()
      ..moveTo(0, 20)
      ..lineTo(0, 0)
      ..lineTo(20, 0);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}