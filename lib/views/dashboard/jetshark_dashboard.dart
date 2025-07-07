import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/timeseries_data_manager.dart';
import '../../models/plot_configuration.dart';
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
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  Timer? _updateTimer;
  StreamSubscription? _dataSubscription;
  
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
    _startDataListening();
    _startUpdates();
  }
  
  void _startDataListening() {
    // Listen to data stream from the centralized data manager
    _dataSubscription = _dataManager.dataStream.listen((dataBuffers) {
      // Extract values we need for the dashboard
      _updateFromDataBuffers(dataBuffers);
    });
  }
  
  void _updateFromDataBuffers(Map<String, CircularBuffer> dataBuffers) {
    // Extract the latest values from data buffers for dashboard display
    // Look for fields that would contain RPM, speed, and wing position data
    
    double? rpm;
    double? speed;
    double? leftWing;
    double? rightWing;
    
    // Try to extract RPM from VFR_HUD throttle or other engine data
    final vfrHudThrottle = _getLatestValue(dataBuffers, 'VFR_HUD.throttle');
    if (vfrHudThrottle != null) {
      // Convert throttle percentage to RPM (assuming 0-100% maps to 1000-8000 RPM)
      rpm = 1000 + (vfrHudThrottle * 70); // Scale to reasonable RPM range
    }
    
    // Extract speed from VFR_HUD or GLOBAL_POSITION_INT
    speed = _getLatestValue(dataBuffers, 'VFR_HUD.groundspeed') ?? 
            _getLatestValue(dataBuffers, 'GLOBAL_POSITION_INT.vx');
    
    // For wing positions, we could use attitude data or custom fields
    // For now, simulate based on attitude data
    final roll = _getLatestValue(dataBuffers, 'ATTITUDE.roll');
    final pitch = _getLatestValue(dataBuffers, 'ATTITUDE.pitch');
    
    if (roll != null && pitch != null) {
      // Convert attitude to wing positions (this is simulated)
      leftWing = roll * 180 / 3.14159; // Convert radians to degrees
      rightWing = -roll * 180 / 3.14159; // Opposite wing for balance
    }
    
    // Update state if we have valid data
    if (rpm != null || speed != null || leftWing != null || rightWing != null) {
      setState(() {
        if (rpm != null) _targetRpm = rpm;
        if (speed != null) _speed = speed * DashboardConfig.speedConversionFactor;
        if (leftWing != null) _targetLeftWing = leftWing;
        if (rightWing != null) _targetRightWing = rightWing;
      });
    }
  }
  
  double? _getLatestValue(Map<String, CircularBuffer> dataBuffers, String fieldKey) {
    final buffer = dataBuffers[fieldKey];
    if (buffer != null && buffer.points.isNotEmpty) {
      return buffer.points.last.value;
    }
    return null;
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
    _dataSubscription?.cancel();
    _rpmController.dispose();
    _startupController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startUpdates() {
    _updateTimer = Timer.periodic(DashboardConfig.updateInterval, (_) {
      // Always update animations - data comes from stream listener
      setState(() {
        // Smooth RPM animation - always update
        _rpm = _rpm + (_targetRpm - _rpm) * DashboardConfig.smoothingFactor;
        if ((_targetRpm - _rpm).abs() > DashboardConfig.rpmAnimationThreshold) {
          _rpmController.forward(from: 0);
        }
        
        // Smooth wing animations
        _leftWing = _leftWing + (_targetLeftWing - _leftWing) * DashboardConfig.smoothingFactor;
        _rightWing = _rightWing + (_targetRightWing - _rightWing) * DashboardConfig.smoothingFactor;
      });
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