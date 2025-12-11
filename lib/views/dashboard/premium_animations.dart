import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tesla-style premium animation system with physics-based easing
class PremiumAnimations {
  // Spring physics constants
  static const double springTension = 200.0;
  static const double springFriction = 25.0;
  static const double springMass = 1.0;
  
  // Tesla-style curve presets
  static const Curve teslaEaseOut = Curves.easeOutCubic;
  static const Curve teslaEaseIn = Curves.easeInCubic;
  static const Curve teslaSpring = Curves.elasticOut;
  static const Curve teslaBounce = Curves.bounceOut;
  
  // Custom spring curve
  static final Curve teslaPhysicsSpring = _TeslaSpringCurve();
  
  // Animation durations
  static const Duration fastTransition = Duration(milliseconds: 200);
  static const Duration mediumTransition = Duration(milliseconds: 400);
  static const Duration slowTransition = Duration(milliseconds: 600);
  static const Duration breathingDuration = Duration(milliseconds: 2000);
}

/// Custom spring curve that mimics Tesla's UI physics
class _TeslaSpringCurve extends Curve {
  const _TeslaSpringCurve();
  
  @override
  double transformInternal(double t) {
    // Tesla-style spring physics simulation
    const double tension = 0.8;
    const double friction = 0.7;
    
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    
    final double spring = math.pow(2, -10 * t) * math.sin((t - tension / 4) * (2 * math.pi) / tension) + 1;
    return spring * friction;
  }
}

/// Advanced animation controller with physics-based interpolation
class PhysicsAnimationController {
  late AnimationController _controller;
  late Animation<double> _animation;

  final double _currentValue = 0.0;
  double _targetValue = 0.0;

  PhysicsAnimationController({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    _controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: PremiumAnimations.teslaPhysicsSpring,
    );
  }
  
  /// Set target value with physics-based interpolation
  void animateTo(double target) {
    if (_targetValue == target) return;
    
    _targetValue = target;
    _controller.reset();
    _controller.forward();
  }
  
  /// Get current animated value with physics interpolation
  double get value {
    final progress = _animation.value;
    return _currentValue + (_targetValue - _currentValue) * progress;
  }
  
  Animation<double> get animation => _animation;
  
  void dispose() {
    _controller.dispose();
  }
}

/// Staggered animation system for premium reveals
class StaggeredAnimationSystem {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];
  
  StaggeredAnimationSystem({
    required TickerProvider vsync,
    required int itemCount,
    Duration itemDelay = const Duration(milliseconds: 100),
    Duration itemDuration = const Duration(milliseconds: 400),
  }) {
    for (int i = 0; i < itemCount; i++) {
      final controller = AnimationController(
        duration: itemDuration,
        vsync: vsync,
      );
      
      final animation = CurvedAnimation(
        parent: controller,
        curve: PremiumAnimations.teslaEaseOut,
      );
      
      _controllers.add(controller);
      _animations.add(animation);
    }
  }
  
  /// Start staggered animation sequence
  void start() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        _controllers[i].forward();
      });
    }
  }
  
  /// Reset all animations
  void reset() {
    for (final controller in _controllers) {
      controller.reset();
    }
  }
  
  Animation<double> getAnimation(int index) {
    return _animations[index];
  }
  
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }
}

/// Breathing animation for ambient effects
class BreathingAnimationController {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  BreathingAnimationController({
    required TickerProvider vsync,
    Duration period = PremiumAnimations.breathingDuration,
  }) {
    _controller = AnimationController(
      duration: period,
      vsync: vsync,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    // Start infinite breathing cycle
    _controller.repeat(reverse: true);
  }
  
  double get value => _animation.value;
  Animation<double> get animation => _animation;
  
  void dispose() {
    _controller.dispose();
  }
}

/// Premium scale animation with physics
class ScaleAnimationController {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  ScaleAnimationController({
    required TickerProvider vsync,
    Duration duration = PremiumAnimations.mediumTransition,
  }) {
    _controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: PremiumAnimations.teslaPhysicsSpring,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: PremiumAnimations.teslaEaseOut,
    ));
  }
  
  void show() => _controller.forward();
  void hide() => _controller.reverse();
  
  double get scale => _scaleAnimation.value;
  double get opacity => _opacityAnimation.value;
  
  Animation<double> get scaleAnimation => _scaleAnimation;
  Animation<double> get opacityAnimation => _opacityAnimation;
  
  void dispose() {
    _controller.dispose();
  }
}

/// Utility function for smooth value interpolation
class SmoothValueInterpolator {
  double _currentValue;
  double _targetValue;
  final double _smoothingFactor;
  
  SmoothValueInterpolator({
    double initialValue = 0.0,
    double smoothingFactor = 0.15,
  }) : _currentValue = initialValue,
       _targetValue = initialValue,
       _smoothingFactor = smoothingFactor;
  
  void setTarget(double target) {
    _targetValue = target;
  }
  
  double update() {
    _currentValue += (_targetValue - _currentValue) * _smoothingFactor;
    return _currentValue;
  }
  
  double get value => _currentValue;
  bool get isAtTarget => (_targetValue - _currentValue).abs() < 0.01;
}