import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ShaderBackground extends StatefulWidget {
  const ShaderBackground({super.key});

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0.0;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/grid_terrain.frag',
      );
      if (mounted) {
        setState(() {
          _program = program;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading shader: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Shader unavailable';
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Container(color: Colors.black);
    }

    // Show fallback gradient if shader failed to load
    if (_program == null || _errorMessage != null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0a0a1a),
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
            ],
          ),
        ),
      );
    }

    return CustomPaint(
      painter: ShaderPainter(program: _program!, time: _time),
      size: Size.infinite,
    );
  }
}

class ShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;

  ShaderPainter({required this.program, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Uniforms:
    // uResolution (vec2) -> 0, 1
    // uTime (float) -> 2

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.program != program;
  }
}
