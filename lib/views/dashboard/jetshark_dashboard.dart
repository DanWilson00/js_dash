import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../models/plot_configuration.dart';
import 'dashboard_config.dart';
import 'hud_center_cluster.dart';
import 'hud_side_indicators.dart';

/// Modular Jetshark Dashboard - Fighter Jet HUD Redesign
class JetsharkDashboard extends ConsumerStatefulWidget {
  const JetsharkDashboard({super.key});

  @override
  ConsumerState<JetsharkDashboard> createState() => _JetsharkDashboardState();
}

class _JetsharkDashboardState extends ConsumerState<JetsharkDashboard>
    with TickerProviderStateMixin {
  Timer? _updateTimer;
  StreamSubscription? _dataSubscription;

  // Animation controllers
  late AnimationController _startupController;

  // Animated values
  late Animation<double> _startupAnimation;

  // Data values
  double _rpm = 0.0;
  double _targetRpm = 0.0;
  double _speed = 0.0;
  double _leftWing = 0.0;
  double _rightWing = 0.0;
  double _targetLeftWing = 0.0;
  double _targetRightWing = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _yaw = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startDataListening();
    _startUpdates();
  }

  void _startDataListening() {
    final repository = ref.read(telemetryRepositoryProvider);
    _dataSubscription = repository.dataStream.listen((dataBuffers) {
      _updateFromDataBuffers(dataBuffers);
    });
  }

  void _updateFromDataBuffers(Map<String, CircularBuffer> dataBuffers) {
    double? rpm;
    double? speed;
    double? leftWing;
    double? rightWing;
    double? pitch;
    double? roll;
    double? yaw;

    // Extract RPM
    final vfrHudThrottle = _getLatestValue(dataBuffers, 'VFR_HUD.throttle');
    if (vfrHudThrottle != null) {
      rpm = 1000 + (vfrHudThrottle * 70);
    }

    // Extract Speed
    speed =
        _getLatestValue(dataBuffers, 'VFR_HUD.groundspeed') ??
        _getLatestValue(dataBuffers, 'GLOBAL_POSITION_INT.vx');

    // Extract Attitude
    roll = _getLatestValue(dataBuffers, 'ATTITUDE.roll');
    pitch = _getLatestValue(dataBuffers, 'ATTITUDE.pitch');
    yaw = _getLatestValue(dataBuffers, 'ATTITUDE.yaw');

    if (roll != null && pitch != null) {
      // Convert radians to degrees for display
      final rollDeg = roll * 180 / 3.14159;
      final pitchDeg = pitch * 180 / 3.14159;
      final yawDeg = (yaw ?? 0) * 180 / 3.14159;

      // Simulate wing positions based on roll/pitch
      leftWing = rollDeg;
      rightWing = -rollDeg;

      setState(() {
        _pitch = pitchDeg;
        _roll = rollDeg;
        _yaw = yawDeg;
      });
    }

    if (rpm != null || speed != null || leftWing != null || rightWing != null) {
      setState(() {
        if (rpm != null) _targetRpm = rpm;
        if (speed != null) {
          _speed = speed * DashboardConfig.speedConversionFactor;
        }
        if (leftWing != null) _targetLeftWing = leftWing;
        if (rightWing != null) _targetRightWing = rightWing;
      });
    }
  }

  double? _getLatestValue(
    Map<String, CircularBuffer> dataBuffers,
    String fieldKey,
  ) {
    final buffer = dataBuffers[fieldKey];
    if (buffer != null && buffer.points.isNotEmpty) {
      return buffer.points.last.value;
    }
    return null;
  }

  void _initializeAnimations() {
    _startupController = AnimationController(
      duration: DashboardConfig.startupAnimationDuration,
      vsync: this,
    )..forward();

    _startupAnimation = CurvedAnimation(
      parent: _startupController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _dataSubscription?.cancel();
    _startupController.dispose();
    super.dispose();
  }

  void _startUpdates() {
    _updateTimer = Timer.periodic(DashboardConfig.updateInterval, (_) {
      setState(() {
        _rpm = _rpm + (_targetRpm - _rpm) * DashboardConfig.smoothingFactor;

        _leftWing =
            _leftWing +
            (_targetLeftWing - _leftWing) * DashboardConfig.smoothingFactor;
        _rightWing =
            _rightWing +
            (_targetRightWing - _rightWing) * DashboardConfig.smoothingFactor;
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
                  radius: 1.2,
                  colors: [
                    DashboardConfig.gradientCenter,
                    DashboardConfig.gradientEdge,
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // 1. Center Cluster (Attitude + RPM)
                    // We want this to take up most of the screen
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: HudCenterCluster(
                          pitch: _pitch,
                          roll: _roll,
                          yaw: _yaw,
                          rpm: _rpm,
                        ),
                      ),
                    ),

                    // 2. Side Indicators (Wings)
                    Positioned(
                      left: 80,
                      top: 80,
                      bottom: 80,
                      right: 80,
                      child: HudSideIndicators(
                        leftWingAngle: _leftWing,
                        rightWingAngle: _rightWing,
                        targetLeftWingAngle: _targetLeftWing,
                        targetRightWingAngle: _targetRightWing,
                      ),
                    ),

                    // 3. Top Speed Display
                    Positioned(
                      top: 30,
                      right: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _speed.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF00D9FF),
                              fontSize: 64,
                              fontWeight: FontWeight.w200,
                              fontFamily: 'RobotoMono',
                              shadows: [
                                Shadow(
                                  blurRadius: 20,
                                  color: Color(0xFF00D9FF),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'KNOTS',
                            style: TextStyle(
                              color: DashboardConfig.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 14,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
