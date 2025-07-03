import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/mavlink_spoof_service.dart';
import 'dashboard_config.dart';
import 'ambient_lighting.dart';
import 'jetshark_branding.dart';
import 'rpm_gauge.dart';
import 'wing_indicator.dart';

/// Modular Jetshark Dashboard - maintains exact same look, feel, and functionality
/// but split into configurable components
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
      duration: DashboardConfig.rpmAnimationDuration,
      vsync: this,
    );
    
    _startupController = AnimationController(
      duration: DashboardConfig.startupAnimationDuration,
      vsync: this,
    )..forward();
    
    _pulseController = AnimationController(
      duration: DashboardConfig.pulseAnimationDuration,
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
    _updateTimer = Timer.periodic(DashboardConfig.updateInterval, (_) {
      if (_spoofService.isRunning) {
        setState(() {
          _targetRpm = _spoofService.currentRPM;
          _speed = _spoofService.currentSpeed * DashboardConfig.speedConversionFactor;
          
          _targetLeftWing = _spoofService.portWingPosition;
          _targetRightWing = _spoofService.starboardWingPosition;
          
          // Smooth RPM animation - always update
          _rpm = _rpm + (_targetRpm - _rpm) * DashboardConfig.smoothingFactor;
          if ((_targetRpm - _rpm).abs() > DashboardConfig.rpmAnimationThreshold) {
            _rpmController.forward(from: 0);
          }
          
          // Smooth wing animations
          _leftWing = _leftWing + (_targetLeftWing - _leftWing) * DashboardConfig.smoothingFactor;
          _rightWing = _rightWing + (_targetRightWing - _rightWing) * DashboardConfig.smoothingFactor;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardConfig.backgroundColor,
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
                    DashboardConfig.gradientCenter,
                    DashboardConfig.gradientEdge,
                  ],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Ambient lighting
                        AmbientLighting(pulseValue: _pulseAnimation.value),
                        
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

  Widget _buildDashboardContent(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    final centerGaugeSize = DashboardConfig.getCenterGaugeSize(screenWidth, screenHeight);
    
    return Column(
      children: [
        // Branding
        JetsharkBranding(
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        ),
        
        // Main dashboard area
        Expanded(
          child: Row(
            children: [
              // Left wing indicator
              Expanded(
                flex: DashboardConfig.leftWingFlex.round(),
                child: WingIndicator(
                  label: 'LEFT WING',
                  angle: _leftWing,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isLeft: true,
                  pulseAnimation: _pulseAnimation,
                ),
              ),
              
              // Center RPM gauge with speed
              Expanded(
                flex: DashboardConfig.centerGaugeFlex.round(),
                child: RPMGauge(
                  rpm: _rpm,
                  speed: _speed,
                  gaugeSize: centerGaugeSize,
                  rpmAnimation: _rpmAnimation,
                  pulseAnimation: _pulseAnimation,
                ),
              ),
              
              // Right wing indicator
              Expanded(
                flex: DashboardConfig.rightWingFlex.round(),
                child: WingIndicator(
                  label: 'RIGHT WING',
                  angle: _rightWing,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isLeft: false,
                  pulseAnimation: _pulseAnimation,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}