import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/mavlink_spoof_service.dart';

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
  late AnimationController _pulseController;
  
  // Animated values
  late Animation<double> _needleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _startupAnimation;
  late Animation<double> _pulseAnimation;
  
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
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _startupController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _needleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutBack),
    );
    
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _startupAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _startupController, curve: Curves.easeOutCubic),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _glowController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
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
    _pulseController.dispose();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 2.0,
                  colors: [
                    Color(0xFF001122),
                    Color(0xFF000814),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
              child: AnimatedBuilder(
                animation: _startupAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _startupAnimation.value,
                    child: Transform.scale(
                      scale: 0.9 + (_startupAnimation.value * 0.1),
                      child: Stack(
                        children: [
                          // Ambient lighting effects
                          _buildAmbientEffects(constraints),
                          
                          // Main automotive dashboard
                          _buildAutomotiveDashboard(constraints),
                          
                          // Glass overlay
                          _buildGlassOverlay(),
                          
                          // Navigation hint
                          _buildNavigationHint(constraints),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAmbientEffects(BoxConstraints constraints) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_glowController, _pulseController]),
        builder: (context, child) {
          return CustomPaint(
            painter: AmbientEffectsPainter(
              glowValue: _glowController.value,
              pulseValue: _pulseController.value,
              screenSize: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAutomotiveDashboard(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    final dashboardHeight = screenHeight * 0.85;
    final isWideScreen = screenWidth > screenHeight * 1.5;
    
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.02),
        child: Column(
          children: [
            // Top branding
            _buildTopBranding(screenWidth),
            
            SizedBox(height: screenHeight * 0.03),
            
            // Main instrument cluster - automotive layout
            Expanded(
              child: _buildInstrumentCluster(screenWidth, dashboardHeight, isWideScreen),
            ),
            
            SizedBox(height: screenHeight * 0.02),
            
            // Bottom status bar
            _buildStatusBar(screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBranding(double screenWidth) {
    final fontSize = (screenWidth * 0.025).clamp(18.0, 32.0);
    final padding = screenWidth * 0.04;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF001a2e).withValues(alpha: 0.4),
            const Color(0xFF002233).withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(padding * 0.8),
        border: Border.all(
          color: const Color(0xFF00d4ff).withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.15),
            blurRadius: 25,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Text(
        'JETSHARK',
        style: TextStyle(
          color: const Color(0xFF00d4ff),
          fontSize: fontSize,
          fontWeight: FontWeight.w100,
          letterSpacing: fontSize * 0.3,
          shadows: [
            Shadow(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumentCluster(double screenWidth, double dashboardHeight, bool isWideScreen) {
    return Row(
      children: [
        // Left RPM gauge (automotive style)
        Expanded(
          flex: isWideScreen ? 3 : 4,
          child: _buildLeftRPMGauge(screenWidth, dashboardHeight),
        ),
        
        SizedBox(width: screenWidth * 0.02),
        
        // Center speed display
        Expanded(
          flex: isWideScreen ? 2 : 3,
          child: _buildCenterSpeedDisplay(screenWidth, dashboardHeight),
        ),
        
        SizedBox(width: screenWidth * 0.02),
        
        // Right wing indicators
        Expanded(
          flex: isWideScreen ? 3 : 3,
          child: _buildRightWingCluster(screenWidth, dashboardHeight),
        ),
      ],
    );
  }

  Widget _buildLeftRPMGauge(double screenWidth, double dashboardHeight) {
    final rpmPercent = ((_rpm - 800) / 2200).clamp(0.0, 1.0);
    final isDangerZone = _rpm > 2500;
    final gaugeSize = (dashboardHeight * 0.7).clamp(200.0, 400.0);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_needleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Center(
          child: SizedBox(
            width: gaugeSize,
            height: gaugeSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // RPM gauge background
                CustomPaint(
                  size: Size(gaugeSize, gaugeSize),
                  painter: AutomotiveRPMPainter(
                    rpmPercent: rpmPercent,
                    isDanger: isDangerZone,
                    glowIntensity: _glowAnimation.value,
                    needleAnimation: _needleAnimation.value,
                    screenWidth: screenWidth,
                  ),
                ),
                
                // Digital RPM readout
                Positioned(
                  bottom: gaugeSize * 0.15,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.015,
                      vertical: screenWidth * 0.008,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000814).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDangerZone 
                          ? Color.lerp(const Color(0xFFff2244), const Color(0xFFff6688), _glowAnimation.value)!
                          : Color.lerp(const Color(0xFF00d4ff), const Color(0xFF44ddff), _glowAnimation.value)!,
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
                              ? Color.lerp(const Color(0xFFff2244), const Color(0xFFff6688), _glowAnimation.value)
                              : Color.lerp(const Color(0xFF00d4ff), const Color(0xFF44ddff), _glowAnimation.value),
                            fontSize: (screenWidth * 0.025).clamp(20.0, 36.0),
                            fontWeight: FontWeight.w100,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'RPM',
                          style: TextStyle(
                            color: const Color(0xFF00d4ff).withValues(alpha: 0.7),
                            fontSize: (screenWidth * 0.01).clamp(8.0, 12.0),
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterSpeedDisplay(double screenWidth, double dashboardHeight) {
    final speedKnots = _speed * 1.94384;
    final speedFontSize = (screenWidth * 0.08).clamp(48.0, 120.0);
    final labelFontSize = (screenWidth * 0.015).clamp(12.0, 20.0);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [
                const Color(0xFF001122).withValues(alpha: 0.6),
                const Color(0xFF000814).withValues(alpha: 0.9),
                const Color(0xFF000000).withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(screenWidth * 0.02),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF00d4ff),
                const Color(0xFF44ddff),
                _pulseAnimation.value,
              )!.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00d4ff).withValues(alpha: 0.2 * _pulseAnimation.value),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large speed readout
                Text(
                  speedKnots.round().toString().padLeft(3, '0'),
                  style: TextStyle(
                    color: Color.lerp(
                      const Color(0xFF00d4ff),
                      const Color(0xFF44ddff),
                      _pulseAnimation.value,
                    ),
                    fontSize: speedFontSize,
                    fontWeight: FontWeight.w100,
                    fontFamily: 'monospace',
                    shadows: [
                      Shadow(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: screenWidth * 0.005),
                
                // Speed unit and trend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'KNOTS',
                      style: TextStyle(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.8),
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3.0,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.015),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.008,
                        vertical: screenWidth * 0.004,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001122).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF00d4ff).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _speedTrend,
                        style: TextStyle(
                          color: const Color(0xFF00d4ff).withValues(alpha: 0.9),
                          fontSize: labelFontSize * 0.8,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightWingCluster(double screenWidth, double dashboardHeight) {
    return Column(
      children: [
        // Wing indicators
        Expanded(
          child: Row(
            children: [
              // Port wing
              Expanded(
                child: _buildCompactWingIndicator('PORT', _portWing, screenWidth, dashboardHeight, true),
              ),
              SizedBox(width: screenWidth * 0.01),
              // Starboard wing
              Expanded(
                child: _buildCompactWingIndicator('STBD', _starboardWing, screenWidth, dashboardHeight, false),
              ),
            ],
          ),
        ),
        
        SizedBox(height: dashboardHeight * 0.05),
        
        // Heading display
        _buildHeadingDisplay(screenWidth),
      ],
    );
  }

  Widget _buildCompactWingIndicator(String label, double position, double screenWidth, double dashboardHeight, bool isLeft) {
    final isWarning = position.abs() > 30;
    final normalizedPosition = ((position + 50) / 100).clamp(0.0, 1.0);
    final labelFontSize = (screenWidth * 0.012).clamp(10.0, 16.0);
    final valueFontSize = (screenWidth * 0.018).clamp(14.0, 24.0);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF001122).withValues(alpha: 0.4),
            const Color(0xFF000814).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.015),
        border: Border.all(
          color: isWarning 
            ? const Color(0xFFff2244).withValues(alpha: 0.6)
            : const Color(0xFF00d4ff).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Label
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.008,
            ),
            decoration: BoxDecoration(
              color: isWarning 
                ? const Color(0xFFff2244).withValues(alpha: 0.2)
                : const Color(0xFF00d4ff).withValues(alpha: 0.2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(screenWidth * 0.015),
                topRight: Radius.circular(screenWidth * 0.015),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isWarning ? const Color(0xFFff2244) : const Color(0xFF00d4ff),
                fontSize: labelFontSize,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
          ),
          
          // Gauge area
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.01),
              child: Stack(
                children: [
                  // Gauge background
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(screenWidth * 0.008),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF001122).withValues(alpha: 0.3),
                          const Color(0xFF000814).withValues(alpha: 0.7),
                          const Color(0xFF001122).withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                  
                  // Position indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    top: normalizedPosition * (dashboardHeight * 0.25),
                    left: screenWidth * 0.005,
                    right: screenWidth * 0.005,
                    child: Container(
                      height: screenWidth * 0.008,
                      decoration: BoxDecoration(
                        color: isWarning ? const Color(0xFFff2244) : const Color(0xFF00d4ff),
                        borderRadius: BorderRadius.circular(screenWidth * 0.004),
                        boxShadow: [
                          BoxShadow(
                            color: (isWarning ? const Color(0xFFff2244) : const Color(0xFF00d4ff))
                                .withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Value readout
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.008),
            child: Text(
              '${position.round()}°',
              style: TextStyle(
                color: isWarning ? const Color(0xFFff2244) : const Color(0xFF00d4ff),
                fontSize: valueFontSize,
                fontWeight: FontWeight.w300,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeadingDisplay(double screenWidth) {
    final headingStr = _getHeadingString(_heading);
    final headingFontSize = (screenWidth * 0.025).clamp(18.0, 32.0);
    final labelFontSize = (screenWidth * 0.012).clamp(10.0, 16.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenWidth * 0.015,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001122).withValues(alpha: 0.6),
            const Color(0xFF000814).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.02),
        border: Border.all(
          color: const Color(0xFF00d4ff).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            '${_heading.round()}°',
            style: TextStyle(
              color: const Color(0xFF00d4ff),
              fontSize: headingFontSize,
              fontWeight: FontWeight.w100,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: screenWidth * 0.005),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HEADING',
                style: TextStyle(
                  color: const Color(0xFF00d4ff).withValues(alpha: 0.7),
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(width: screenWidth * 0.01),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.008,
                  vertical: screenWidth * 0.003,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF001122).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  headingStr,
                  style: TextStyle(
                    color: const Color(0xFF00d4ff),
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar(double screenWidth, double screenHeight) {
    return Container(
      height: screenHeight * 0.08,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenWidth * 0.01,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF001122).withValues(alpha: 0.4),
            const Color(0xFF000814).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(screenWidth * 0.025),
        border: Border.all(
          color: const Color(0xFF00d4ff).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatusItem('ENGINE', 'ONLINE', const Color(0xFF00ff88), screenWidth),
          _buildStatusDivider(screenHeight),
          _buildStatusItem('SYSTEMS', 'NOMINAL', const Color(0xFF00d4ff), screenWidth),
          _buildStatusDivider(screenHeight),
          _buildStatusItem('COMM', 'ACTIVE', const Color(0xFF00d4ff), screenWidth),
        ],
      ),
    );
  }
  
  Widget _buildStatusItem(String label, String value, Color color, double screenWidth) {
    final fontSize = (screenWidth * 0.012).clamp(10.0, 16.0);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: fontSize * 0.8,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusDivider(double screenHeight) {
    return Container(
      width: 1,
      height: screenHeight * 0.04,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF00d4ff).withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
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

  Widget _buildNavigationHint(BoxConstraints constraints) {
    final fontSize = (constraints.maxWidth * 0.01).clamp(9.0, 14.0);
    
    return Positioned(
      bottom: constraints.maxHeight * 0.02,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 0.02,
            vertical: constraints.maxHeight * 0.01,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF001122).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(constraints.maxWidth * 0.02),
            border: Border.all(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            'TAP TO RETURN TO TELEMETRY',
            style: TextStyle(
              color: const Color(0xFF00d4ff).withValues(alpha: 0.8),
              fontSize: fontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class AutomotiveRPMPainter extends CustomPainter {
  final double rpmPercent;
  final bool isDanger;
  final double glowIntensity;
  final double needleAnimation;
  final double screenWidth;

  AutomotiveRPMPainter({
    required this.rpmPercent,
    required this.isDanger,
    required this.glowIntensity,
    required this.needleAnimation,
    required this.screenWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    
    // Draw outer ring
    _drawOuterRing(canvas, center, radius, size);
    
    // Draw main gauge background
    _drawGaugeBackground(canvas, center, radius);
    
    // Draw tick marks and numbers
    _drawTickMarks(canvas, center, radius, size);
    
    // Draw color zones (automotive style)
    _drawAutomotiveColorZones(canvas, center, radius);
    
    // Draw needle with shadow
    _drawAutomotiveNeedle(canvas, center, radius);
    
    // Draw center hub
    _drawCenterHub(canvas, center);
  }

  void _drawOuterRing(Canvas canvas, Offset center, double radius, Size size) {
    // Outer decorative ring
    final outerPaint = Paint()
      ..color = const Color(0xFF001122).withValues(alpha: 0.8)
      ..strokeWidth = (screenWidth * 0.003).clamp(2.0, 6.0)
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius + (screenWidth * 0.015), outerPaint);
    
    // Inner decorative ring with glow
    final glowPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF00d4ff).withValues(alpha: 0.3),
        const Color(0xFF44ddff).withValues(alpha: 0.6),
        glowIntensity,
      )!
      ..strokeWidth = (screenWidth * 0.002).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius + (screenWidth * 0.008), glowPaint);
  }
  
  void _drawGaugeBackground(Canvas canvas, Offset center, double radius) {
    // Main gauge background with gradient
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          const Color(0xFF001122).withValues(alpha: 0.4),
          const Color(0xFF000814).withValues(alpha: 0.8),
          const Color(0xFF000000).withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, backgroundPaint);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius, Size size) {
    final majorTickPaint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.8)
      ..strokeWidth = (screenWidth * 0.002).clamp(1.5, 3.0)
      ..strokeCap = StrokeCap.round;
    
    final minorTickPaint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.4)
      ..strokeWidth = (screenWidth * 0.001).clamp(1.0, 2.0)
      ..strokeCap = StrokeCap.round;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    const startAngle = math.pi * 0.65; // Start slightly left of bottom
    const totalSweep = math.pi * 1.7; // 306 degrees total

    // Draw major ticks and numbers
    for (int i = 0; i <= 8; i++) {
      final angle = startAngle + (totalSweep * i / 8);
      final rpm = 800 + (i * 275); // 800 to 3000 RPM
      
      // Major tick marks
      final tickStart = Offset(
        center.dx + (radius - (screenWidth * 0.012)) * math.cos(angle),
        center.dy + (radius - (screenWidth * 0.012)) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawLine(tickStart, tickEnd, majorTickPaint);
      
      // RPM numbers (every other tick)
      if (i % 2 == 0) {
        final textOffset = Offset(
          center.dx + (radius - (screenWidth * 0.025)) * math.cos(angle),
          center.dy + (radius - (screenWidth * 0.025)) * math.sin(angle),
        );
        
        final fontSize = (screenWidth * 0.012).clamp(10.0, 18.0);
        textPainter.text = TextSpan(
          text: '${(rpm / 100).round()}',
          style: TextStyle(
            color: const Color(0xFF00d4ff).withValues(alpha: 0.8),
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            fontFamily: 'monospace',
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas, 
          textOffset - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
    
    // Draw minor ticks
    for (int i = 0; i < 32; i++) {
      final angle = startAngle + (totalSweep * i / 32);
      
      if (i % 4 != 0) { // Skip positions where major ticks are
        final tickStart = Offset(
          center.dx + (radius - (screenWidth * 0.006)) * math.cos(angle),
          center.dy + (radius - (screenWidth * 0.006)) * math.sin(angle),
        );
        final tickEnd = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        
        canvas.drawLine(tickStart, tickEnd, minorTickPaint);
      }
    }
  }

  void _drawAutomotiveColorZones(Canvas canvas, Offset center, double radius) {
    const startAngle = math.pi * 0.65;
    const totalSweep = math.pi * 1.7;
    final strokeWidth = (screenWidth * 0.004).clamp(3.0, 8.0);
    final zoneRadius = radius + (screenWidth * 0.008);
    
    // Green zone (800-2000 RPM) - 54.5% of total
    final greenSweep = totalSweep * 0.545;
    final greenPaint = Paint()
      ..color = const Color(0xFF00ff88).withValues(alpha: 0.6)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: zoneRadius),
      startAngle,
      greenSweep,
      false,
      greenPaint,
    );
    
    // Amber zone (2000-2500 RPM) - 22.7% of total
    final amberSweep = totalSweep * 0.227;
    final amberPaint = Paint()
      ..color = const Color(0xFFffd700).withValues(alpha: 0.7)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: zoneRadius),
      startAngle + greenSweep,
      amberSweep,
      false,
      amberPaint,
    );
    
    // Red zone (2500+ RPM) - 22.7% of total
    final redSweep = totalSweep * 0.227;
    final redPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFFff2244).withValues(alpha: 0.6),
        const Color(0xFFff2244).withValues(alpha: 0.9),
        glowIntensity,
      )!
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: zoneRadius),
      startAngle + greenSweep + amberSweep,
      redSweep,
      false,
      redPaint,
    );
  }

  void _drawAutomotiveNeedle(Canvas canvas, Offset center, double radius) {
    const startAngle = math.pi * 0.65;
    const totalSweep = math.pi * 1.7;
    final needleAngle = startAngle + (totalSweep * rpmPercent);
    final needleLength = radius - (screenWidth * 0.015);
    
    // Needle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..strokeWidth = (screenWidth * 0.003).clamp(2.0, 5.0)
      ..strokeCap = StrokeCap.round;
    
    // Main needle
    final needlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: isDanger 
          ? [
              Color.lerp(const Color(0xFFff2244), const Color(0xFFff6688), glowIntensity)!,
              Color.lerp(const Color(0xFFff4466), const Color(0xFFffaacc), glowIntensity)!,
            ]
          : [
              const Color(0xFF00d4ff),
              const Color(0xFF66e0ff),
            ],
      ).createShader(Rect.fromCircle(center: center, radius: needleLength))
      ..strokeWidth = (screenWidth * 0.002).clamp(1.5, 4.0)
      ..strokeCap = StrokeCap.round;
    
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );
    
    final shadowOffset = Offset(screenWidth * 0.001, screenWidth * 0.001);
    
    // Draw shadow
    canvas.drawLine(center + shadowOffset, needleEnd + shadowOffset, shadowPaint);
    
    // Draw needle
    canvas.drawLine(center, needleEnd, needlePaint);
  }
  
  void _drawCenterHub(Canvas canvas, Offset center) {
    final hubRadius = (screenWidth * 0.006).clamp(4.0, 10.0);
    
    // Hub shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      center + Offset(screenWidth * 0.001, screenWidth * 0.001),
      hubRadius + 1,
      shadowPaint,
    );
    
    // Main hub
    final hubPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: isDanger 
          ? [
              Color.lerp(const Color(0xFFff2244), const Color(0xFFff6688), glowIntensity)!,
              Color.lerp(const Color(0xFFaa1122), const Color(0xFFdd4466), glowIntensity)!,
            ]
          : [
              const Color(0xFF00d4ff),
              const Color(0xFF0088cc),
            ],
      ).createShader(Rect.fromCircle(center: center, radius: hubRadius));
    
    canvas.drawCircle(center, hubRadius, hubPaint);
    
    // Hub highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      center - Offset(screenWidth * 0.002, screenWidth * 0.002),
      hubRadius * 0.4,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AmbientEffectsPainter extends CustomPainter {
  final double glowValue;
  final double pulseValue;
  final Size screenSize;
  
  AmbientEffectsPainter({
    required this.glowValue,
    required this.pulseValue,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle scan lines
    _drawScanLines(canvas, size);
    
    // Ambient glow effects
    _drawAmbientGlow(canvas, size);
  }
  
  void _drawScanLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00d4ff).withValues(alpha: 0.01 * glowValue)
      ..strokeWidth = 0.5;

    final lineSpacing = screenSize.height * 0.003;
    for (double y = 0; y < size.height; y += lineSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  void _drawAmbientGlow(Canvas canvas, Size size) {
    // Pulsing ambient corners
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 0.4,
        colors: [
          Color.lerp(
            const Color(0xFF001122),
            const Color(0xFF002244),
            pulseValue,
          )!.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

