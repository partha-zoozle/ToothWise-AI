import 'dart:math';
import 'package:flutter/material.dart';

class VoiceWaveform extends StatefulWidget {
  final bool isListening;
  const VoiceWaveform({super.key, required this.isListening});

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> _barHeights = List.generate(20, (_) => 10.0);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_updateBars);
    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
      setState(() {
        _barHeights = List.generate(20, (_) => 10.0);
      });
    }
  }

  void _updateBars() {
    if (widget.isListening) {
      setState(() {
        _barHeights = List.generate(20, (_) => 10.0 + _random.nextDouble() * 40);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: 200,
      child: CustomPaint(
        painter: _WaveformPainter(_barHeights),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> barHeights;
  _WaveformPainter(this.barHeights);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blueAccent, Colors.purpleAccent],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final barWidth = size.width / (barHeights.length * 1.5);
    for (int i = 0; i < barHeights.length; i++) {
      final x = i * barWidth * 1.5;
      final y = size.height - barHeights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeights[i]),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
} 