import 'dart:async';
import 'dart:math' show pi;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../core/circular_buffer.dart';
import 'dashboard_config.dart';
import 'hud_center_cluster.dart';
import 'hud_side_indicators.dart';
import 'shader_background.dart';
import 'premium_animations.dart';

/// Modular Jetshark Dashboard - Fighter Jet HUD Redesign
class JetsharkDashboard extends ConsumerStatefulWidget {
  const JetsharkDashboard({super.key});

  @override
  ConsumerState<JetsharkDashboard> createState() => _JetsharkDashboardState();
}

class _JetsharkDashboardState extends ConsumerState<JetsharkDashboard>
    with TickerProviderStateMixin {
  StreamSubscription? _dataSubscription;

  // Animation controllers - upgraded to physics-based system
  late AnimationController _startupController;
  late AnimationController _smoothDataController;
  late StaggeredAnimationSystem _staggeredSystem;

  // Animated values
  late Animation<double> _startupAnimation;

  // Physics-based interpolators for smooth data transitions
  late SmoothValueInterpolator _rpmInterpolator;
  late SmoothValueInterpolator _speedInterpolator;
  late SmoothValueInterpolator _pitchInterpolator;
  late SmoothValueInterpolator _rollInterpolator;
  late SmoothValueInterpolator _yawInterpolator;
  late SmoothValueInterpolator _leftWingInterpolator;
  late SmoothValueInterpolator _rightWingInterpolator;

  // Data values (Raw Targets) - used by HudSideIndicators
  // Note: These remain at initial values; smoothed values come from interpolators
  final double _targetLeftWing = 0.0;
  final double _targetRightWing = 0.0;

  // Note: Smoothed values now handled by physics interpolators

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePhysicsInterpolators();
    _startDataListening();

    // Setup enhanced smooth data animation loop (60fps)
    _smoothDataController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updatePhysicsBasedData)..repeat();
  }

  void _startDataListening() {
    final dataManager = ref.read(timeSeriesDataManagerProvider);
    _dataSubscription = dataManager.dataStream.listen((dataBuffers) {
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

    // Extract RPM from throttle using configured conversion
    final vfrHudThrottle = _getLatestValue(dataBuffers, 'VFR_HUD.throttle');
    if (vfrHudThrottle != null) {
      rpm = DashboardConfig.rpmBaseValue +
          (vfrHudThrottle * DashboardConfig.rpmThrottleMultiplier);
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
      final rollDeg = roll * 180 / pi;
      final pitchDeg = pitch * 180 / pi;
      final yawDeg = (yaw ?? 0) * 180 / pi;

      // Simulate wing positions based on roll/pitch
      leftWing = rollDeg;
      rightWing = -rollDeg;

      // Update physics interpolators for attitude data
      _pitchInterpolator.setTarget(pitchDeg);
      _rollInterpolator.setTarget(rollDeg);
      _yawInterpolator.setTarget(yawDeg);
    }

    if (rpm != null || speed != null || leftWing != null || rightWing != null) {
      // Update physics interpolator targets instead of direct setState
      if (rpm != null) _rpmInterpolator.setTarget(rpm);
      if (speed != null) {
        _speedInterpolator.setTarget(speed * DashboardConfig.speedConversionFactor);
      }
      if (leftWing != null) _leftWingInterpolator.setTarget(leftWing);
      if (rightWing != null) _rightWingInterpolator.setTarget(rightWing);
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
    // Enhanced startup animation with Tesla-style physics
    _startupController = AnimationController(
      duration: PremiumAnimations.slowTransition,
      vsync: this,
    );

    _startupAnimation = CurvedAnimation(
      parent: _startupController,
      curve: PremiumAnimations.teslaPhysicsSpring,
    );


    // Initialize staggered system for element reveals
    _staggeredSystem = StaggeredAnimationSystem(
      vsync: this,
      itemCount: 4, // Speed, RPM, wings, attitude
      itemDelay: const Duration(milliseconds: 150),
    );

    // Start the premium startup sequence
    _startupController.forward().then((_) {
      _staggeredSystem.start();
    });
  }

  void _initializePhysicsInterpolators() {
    // Initialize all physics-based interpolators with Tesla-style smoothing
    _rpmInterpolator = SmoothValueInterpolator(smoothingFactor: 0.12);
    _speedInterpolator = SmoothValueInterpolator(smoothingFactor: 0.08);
    _pitchInterpolator = SmoothValueInterpolator(smoothingFactor: 0.15);
    _rollInterpolator = SmoothValueInterpolator(smoothingFactor: 0.15);
    _yawInterpolator = SmoothValueInterpolator(smoothingFactor: 0.10);
    _leftWingInterpolator = SmoothValueInterpolator(smoothingFactor: 0.12);
    _rightWingInterpolator = SmoothValueInterpolator(smoothingFactor: 0.12);
  }

  void _updatePhysicsBasedData() {
    // Update all physics interpolators for smooth Tesla-style transitions
    setState(() {
      _rpmInterpolator.update();
      _speedInterpolator.update();
      _pitchInterpolator.update();
      _rollInterpolator.update();
      _yawInterpolator.update();
      _leftWingInterpolator.update();
      _rightWingInterpolator.update();
    });
  }

  // Getter methods for smooth values
  double get _smoothRpm => _rpmInterpolator.value;
  double get _smoothSpeed => _speedInterpolator.value;
  double get _smoothPitch => _pitchInterpolator.value;
  double get _smoothRoll => _rollInterpolator.value;
  double get _smoothYaw => _yawInterpolator.value;
  double get _smoothLeftWing => _leftWingInterpolator.value;
  double get _smoothRightWing => _rightWingInterpolator.value;

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _startupController.dispose();
    _smoothDataController.dispose();
    _staggeredSystem.dispose();
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


                // 2. Center Cluster (Attitude + RPM) with staggered animation
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _staggeredSystem.getAnimation(1),
                    builder: (context, child) {
                      final animation = _staggeredSystem.getAnimation(1);
                      return Transform.scale(
                        scale: 0.9 + (0.1 * animation.value),
                        child: Opacity(
                          opacity: animation.value,
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
                      );
                    },
                  ),
                ),

                // 3. Side Indicators (Wings) with staggered animation
                Positioned(
                  left: 20,
                  top: 80,
                  bottom: 80,
                  right: 20,
                  child: AnimatedBuilder(
                    animation: _staggeredSystem.getAnimation(2),
                    builder: (context, child) {
                      final animation = _staggeredSystem.getAnimation(2);
                      return Transform.scale(
                        scale: 0.95 + (0.05 * animation.value),
                        child: Opacity(
                          opacity: animation.value,
                          child: HudSideIndicators(
                            leftWingAngle: _smoothLeftWing,
                            rightWingAngle: _smoothRightWing,
                            targetLeftWingAngle: _targetLeftWing,
                            targetRightWingAngle: _targetRightWing,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. Premium Glass Speed Display
                Positioned(
                  top: 40,
                  right: 40,
                  child: AnimatedBuilder(
                    animation: _staggeredSystem.getAnimation(0),
                    builder: (context, child) {
                      final animation = _staggeredSystem.getAnimation(0);
                      return Transform.scale(
                        scale: 0.8 + (0.2 * animation.value),
                        child: Opacity(
                          opacity: animation.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: const Alignment(-0.5, -1),
                                end: const Alignment(0.5, 1),
                                colors: [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _smoothSpeed.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        fontSize: 52,
                                        fontWeight: FontWeight.w200,
                                        fontFamily: 'SF Pro Display',
                                        letterSpacing: -1.0,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 15,
                                            color: Color(0xFF00D9FF),
                                          ),
                                          Shadow(
                                            blurRadius: 30,
                                            color: Color(0xFF00D9FF),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'KNOTS',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        letterSpacing: 2.0,
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'SF Pro Text',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 5. Subtle Bottom RPM Display
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _staggeredSystem.getAnimation(3),
                    builder: (context, child) {
                      final animation = _staggeredSystem.getAnimation(3);
                      return Opacity(
                        opacity: animation.value,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _smoothRpm.toStringAsFixed(0),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w200,
                                  fontFamily: 'SF Pro Display',
                                  letterSpacing: -1.0,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Color(0xFF00D9FF),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RPM',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w300,
                                  fontFamily: 'SF Pro Text',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
