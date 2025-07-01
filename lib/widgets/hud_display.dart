import 'dart:async';
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
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF001122),
                Color(0xFF000000),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Main dashboard frame
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: CustomPaint(
                    painter: DashboardFramePainter(),
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          // Top section - JETSHARK title
                          _buildTopSection(),
                          
                          const SizedBox(height: 30),
                          
                          // Main gauges row
                          Expanded(
                            child: Row(
                              children: [
                                // Left wing indicator
                                Expanded(
                                  flex: 2,
                                  child: _buildWingGauge('PORT', _portWing, true),
                                ),
                                
                                const SizedBox(width: 40),
                                
                                // Center RPM display
                                Expanded(
                                  flex: 3,
                                  child: _buildCentralRPMDisplay(),
                                ),
                                
                                const SizedBox(width: 40),
                                
                                // Right wing indicator
                                Expanded(
                                  flex: 2,
                                  child: _buildWingGauge('STBD', _starboardWing, false),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Bottom speed display
                          _buildBottomSpeedDisplay(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Tap to return hint
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001122).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00DDFF).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'TAP TO RETURN TO TELEMETRY',
                      style: TextStyle(
                        color: const Color(0xFF00DDFF).withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00DDFF).withValues(alpha: 0.1),
                const Color(0xFF00DDFF).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00DDFF).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Text(
            'JETSHARK',
            style: TextStyle(
              color: Color(0xFF00DDFF),
              fontSize: 24,
              fontWeight: FontWeight.w300,
              letterSpacing: 4.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCentralRPMDisplay() {
    final rpmPercent = ((_rpm - 800) / 2200).clamp(0.0, 1.0);
    final isDanger = _rpm > 2500;
    
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large RPM number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF001122).withValues(alpha: 0.3),
                  const Color(0xFF000000).withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDanger ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDanger ? const Color(0xFFFF4444) : const Color(0xFF00DDFF))
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${_rpm.round()}',
                  style: TextStyle(
                    color: isDanger ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                    fontSize: 72,
                    fontWeight: FontWeight.w100,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'RPM',
                  style: TextStyle(
                    color: const Color(0xFF00DDFF).withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3.0,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // RPM progress bar
          Container(
            width: 300,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF001122),
            ),
            child: Stack(
              children: [
                // Background segments
                Row(
                  children: List.generate(10, (index) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF001122),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                // Active progress
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: rpmPercent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: rpmPercent > 0.8 ? [
                          const Color(0xFFFF4444),
                          const Color(0xFFFF8888),
                        ] : rpmPercent > 0.6 ? [
                          const Color(0xFFFFDD00),
                          const Color(0xFFFFFF88),
                        ] : [
                          const Color(0xFF00DDFF),
                          const Color(0xFF88DDFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }

  Widget _buildWingGauge(String label, double position, bool isLeft) {
    final isWarning = position.abs() > 30;
    final normalizedPosition = ((position + 50) / 100).clamp(0.0, 1.0);
    
    return Column(
        children: [
          // Wing label
          Text(
            label,
            style: TextStyle(
              color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 2.0,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Wing gauge
          Expanded(
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF001122).withValues(alpha: 0.3),
                    const Color(0xFF000000).withValues(alpha: 0.8),
                  ],
                ),
                border: Border.all(
                  color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  // Gauge marks
                  ...List.generate(5, (index) {
                    final markPosition = 0.1 + (index * 0.2);
                    return Positioned(
                      top: markPosition * MediaQuery.of(context).size.height * 0.4,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 1,
                        color: const Color(0xFF00DDFF).withValues(alpha: 0.3),
                      ),
                    );
                  }),
                  
                  // Center reference
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.2,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDD00),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFDD00).withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Wing position indicator
                  Positioned(
                    top: normalizedPosition * MediaQuery.of(context).size.height * 0.3 + 50,
                    left: 30,
                    right: 30,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
                        borderRadius: BorderRadius.circular(8),
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
                          width: 40,
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Position value
          Text(
            '${position.round()}°',
            style: TextStyle(
              color: isWarning ? const Color(0xFFFF4444) : const Color(0xFF00DDFF),
              fontSize: 24,
              fontWeight: FontWeight.w300,
              fontFamily: 'monospace',
            ),
          ),
        ],
    );
  }

  Widget _buildBottomSpeedDisplay() {
    final speedKnots = _speed * 1.94384;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001122).withValues(alpha: 0.3),
            const Color(0xFF000000).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFF00DDFF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speedKnots.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF00DDFF),
              fontSize: 48,
              fontWeight: FontWeight.w100,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'KT',
            style: TextStyle(
              color: const Color(0xFF00DDFF).withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00DDFF).withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final glowPaint = Paint()
      ..color = const Color(0xFF00DDFF).withValues(alpha: 0.1)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    // Create rounded rectangle path
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(30),
    );
    
    // Draw glow effect
    canvas.drawRRect(rect, glowPaint);
    
    // Draw main frame
    canvas.drawRRect(rect, paint);
    
    // Draw corner accent lines
    _drawCornerAccents(canvas, size);
  }

  void _drawCornerAccents(Canvas canvas, Size size) {
    final accentPaint = Paint()
      ..color = const Color(0xFF00DDFF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    const double accentLength = 30;
    
    // Top left
    canvas.drawLine(
      const Offset(30, 30),
      const Offset(30 + accentLength, 30),
      accentPaint,
    );
    canvas.drawLine(
      const Offset(30, 30),
      const Offset(30, 30 + accentLength),
      accentPaint,
    );
    
    // Top right
    canvas.drawLine(
      Offset(size.width - 30, 30),
      Offset(size.width - 30 - accentLength, 30),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width - 30, 30),
      Offset(size.width - 30, 30 + accentLength),
      accentPaint,
    );
    
    // Bottom left
    canvas.drawLine(
      Offset(30, size.height - 30),
      Offset(30 + accentLength, size.height - 30),
      accentPaint,
    );
    canvas.drawLine(
      Offset(30, size.height - 30),
      Offset(30, size.height - 30 - accentLength),
      accentPaint,
    );
    
    // Bottom right
    canvas.drawLine(
      Offset(size.width - 30, size.height - 30),
      Offset(size.width - 30 - accentLength, size.height - 30),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width - 30, size.height - 30),
      Offset(size.width - 30, size.height - 30 - accentLength),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}