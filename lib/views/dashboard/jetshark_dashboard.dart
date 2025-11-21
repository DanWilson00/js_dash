import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../models/plot_configuration.dart';
import 'dashboard_config.dart';
import 'hud_center_cluster.dart';
import 'hud_side_indicators.dart';
import 'shader_background.dart';

/// Modular Jetshark Dashboard - Fighter Jet HUD Redesign
class JetsharkDashboard extends ConsumerStatefulWidget {
  const JetsharkDashboard({super.key});

  @override
  ConsumerState<JetsharkDashboard> createState() => _JetsharkDashboardState();
}

class _JetsharkDashboardState extends ConsumerState<JetsharkDashboard>
    with TickerProviderStateMixin {
  StreamSubscription? _dataSubscription;

  // Animation controllers
  late AnimationController _startupController;
  late AnimationController _smoothDataController;

  // Animated values
  late Animation<double> _startupAnimation;

  // Data values (Raw Targets)
  double _targetRpm = 0.0;
  double _targetSpeed = 0.0;
  double _targetPitch = 0.0;
  double _targetRoll = 0.0;
  double _targetYaw = 0.0;
  double _targetLeftWing = 0.0;
  double _targetRightWing = 0.0;

  // Smoothed Data Values (for 60fps animation)
  double _smoothRpm = 0;
  double _smoothSpeed = 0;
  double _smoothPitch = 0;
  double _smoothRoll = 0;
  double _smoothYaw = 0;
  double _smoothLeftWing = 0;
  double _smoothRightWing = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startDataListening();

    // Setup smooth data animation loop (60fps)
    _smoothDataController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..addListener(_updateSmoothData)
          ..repeat();
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
        _targetPitch = pitchDeg;
        _targetRoll = rollDeg;
        _targetYaw = yawDeg;
      });
    }

    if (rpm != null || speed != null || leftWing != null || rightWing != null) {
      setState(() {
        if (rpm != null) _targetRpm = rpm;
        if (speed != null) {
          _targetSpeed = speed * DashboardConfig.speedConversionFactor;
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

  void _updateSmoothData() {
    // Smooth interpolation factor (adjust for responsiveness vs smoothness)
    const double lerpFactor = 0.1;

    setState(() {
      _smoothRpm += (_targetRpm - _smoothRpm) * lerpFactor;
      _smoothSpeed += (_targetSpeed - _smoothSpeed) * lerpFactor;
      _smoothPitch += (_targetPitch - _smoothPitch) * lerpFactor;
      _smoothRoll += (_targetRoll - _smoothRoll) * lerpFactor;
      _smoothYaw += (_targetYaw - _smoothYaw) * lerpFactor;
      _smoothLeftWing += (_targetLeftWing - _smoothLeftWing) * lerpFactor;
      _smoothRightWing += (_targetRightWing - _smoothRightWing) * lerpFactor;
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _startupController.dispose();
    _smoothDataController.dispose();
    super.dispose();
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background Layer - GLSL Shader
                const Positioned.fill(child: ShaderBackground()),

                // 2. Center Cluster (Attitude + RPM)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: HudCenterCluster(
                      pitch: _smoothPitch,
                      roll: _smoothRoll,
                      yaw: _smoothYaw,
                      rpm: _smoothRpm,
                    ),
                  ),
                ),

                // 3. Side Indicators (Wings)
                Positioned(
                  left: 80,
                  top: 80,
                  bottom: 80,
                  right: 80,
                  child: HudSideIndicators(
                    leftWingAngle: _smoothLeftWing,
                    rightWingAngle: _smoothRightWing,
                    targetLeftWingAngle: _targetLeftWing,
                    targetRightWingAngle: _targetRightWing,
                  ),
                ),

                // 4. Top Speed Display
                Positioned(
                  top: 30,
                  right: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _smoothSpeed.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFF00D9FF),
                          fontSize: 64,
                          fontWeight: FontWeight.w200,
                          fontFamily: 'RobotoMono',
                          shadows: [
                            Shadow(blurRadius: 20, color: Color(0xFF00D9FF)),
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
          );
        },
      ),
    );
  }
}
