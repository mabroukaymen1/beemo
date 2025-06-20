import 'package:flutter/material.dart';

class ScanAnimation extends StatelessWidget {
  final bool isScanning;
  final Widget child;
  final AnimationController? controller;

  const ScanAnimation({
    Key? key,
    required this.isScanning,
    required this.child,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isScanning)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: controller ?? const AlwaysStoppedAnimation(0),
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScanLinePainter(
                    controller?.value ?? 0,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double position;
  final Paint _linePaint;
  final Paint _cornerPaint;

  _ScanLinePainter(this.position)
      : _linePaint = Paint()
          ..color = Colors.green.withOpacity(0.8)
          ..strokeWidth = 3.0,
        _cornerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * position;

    // Draw scanning line with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.green.withOpacity(0),
        Colors.green.withOpacity(0.8),
        Colors.green.withOpacity(0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    _linePaint.shader = gradient.createShader(
      Rect.fromLTWH(0, y - 10, size.width, 20),
    );

    canvas.drawLine(Offset(0, y), Offset(size.width, y), _linePaint);

    // Draw corners efficiently using a single path
    final path = Path();
    const cornerLength = 30.0;

    // Top-left
    path.moveTo(0, cornerLength);
    path.lineTo(0, 0);
    path.lineTo(cornerLength, 0);

    // Top-right
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cornerLength);

    // Bottom-left
    path.moveTo(0, size.height - cornerLength);
    path.lineTo(0, size.height);
    path.lineTo(cornerLength, size.height);

    // Bottom-right
    path.moveTo(size.width - cornerLength, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, size.height - cornerLength);

    canvas.drawPath(path, _cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return position != oldDelegate.position;
  }
}
