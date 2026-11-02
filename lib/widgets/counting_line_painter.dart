import 'package:flutter/material.dart';

/// High-performance zero-allocation painter for the counting barrier.
class CountingLinePainter extends CustomPainter {
  final double linePosition;
  final bool isHorizontal;
  final Color accentColor;

  static final Paint _linePaint = Paint()
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  static final Paint _glowPaint = Paint()
    ..strokeWidth = 6.0
    ..style = PaintingStyle.stroke;

  CountingLinePainter({
    required this.linePosition,
    this.isHorizontal = false,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    _linePaint.color = accentColor;
    _glowPaint.color = accentColor.withValues(alpha: 0.25);

    const dashWidth = 12.0;
    const dashSpace = 8.0;

    if (isHorizontal) {
      final y = size.height * linePosition;
      double startX = 0;

      // Glow pass + dashed line pass
      while (startX < size.width) {
        final endX = (startX + dashWidth).clamp(0.0, size.width);
        final p1 = Offset(startX, y);
        final p2 = Offset(endX, y);

        canvas.drawLine(p1, p2, _glowPaint);
        canvas.drawLine(p1, p2, _linePaint);

        startX += dashWidth + dashSpace;
      }

      _paintBadge(
        canvas: canvas,
        position: Offset(16, (y - 24).clamp(8.0, size.height - 30)),
        label: 'COUNT LINE [Y: ${(linePosition * 100).toInt()}%]',
      );
    } else {
      final x = size.width * linePosition;
      double startY = 0;

      while (startY < size.height) {
        final endY = (startY + dashWidth).clamp(0.0, size.height);
        final p1 = Offset(x, startY);
        final p2 = Offset(x, endY);

        canvas.drawLine(p1, p2, _glowPaint);
        canvas.drawLine(p1, p2, _linePaint);

        startY += dashWidth + dashSpace;
      }

      _paintBadge(
        canvas: canvas,
        position: Offset(
          (x + 10 + 130 <= size.width) ? (x + 10) : (x - 140),
          16,
        ),
        label: 'COUNT LINE [X: ${(linePosition * 100).toInt()}%]',
      );
    }
  }

  void _paintBadge({
    required Canvas canvas,
    required Offset position,
    required String label,
  }) {
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: accentColor,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - 6,
        position.dy - 3,
        textPainter.width + 12,
        textPainter.height + 6,
      ),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRect, borderPaint);

    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CountingLinePainter oldDelegate) {
    return oldDelegate.linePosition != linePosition ||
        oldDelegate.isHorizontal != isHorizontal ||
        oldDelegate.accentColor != accentColor;
  }
}

