import 'package:flutter/material.dart';

/// High-performance zero-allocation painter for the counting barrier.
class CountingLinePainter extends CustomPainter {
  final double linePosition;
  final bool isHorizontal;
  final Color accentColor;

  static const double _dashWidth = 12.0;
  static const double _dashGap = 8.0;
  static const double _dashStride = _dashWidth + _dashGap;

  static final Paint _linePaint = Paint()
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  static final Paint _glowPaint = Paint()
    ..strokeWidth = 6.0
    ..style = PaintingStyle.stroke;

  static final Paint _badgeBackgroundPaint = Paint();
  static final Paint _badgeBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // The badge text only changes when the line percentage changes, so the laid
  // out TextPainter is cached per painter instance.
  TextPainter? _cachedBadge;
  String? _cachedBadgeLabel;

  CountingLinePainter({
    required this.linePosition,
    this.isHorizontal = false,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    _linePaint.color = accentColor;
    _glowPaint.color = accentColor.withValues(alpha: 0.25);
    _badgeBackgroundPaint.color = Colors.black.withValues(alpha: 0.65);
    _badgeBorderPaint.color = accentColor.withValues(alpha: 0.4);

    // Build every dash into one path so the glow and the line are each drawn
    // with a single drawPath call instead of two drawLine calls per dash.
    final path = Path();

    if (isHorizontal) {
      final y = size.height * linePosition;
      for (var x = 0.0; x < size.width; x += _dashStride) {
        path.moveTo(x, y);
        path.lineTo((x + _dashWidth).clamp(0.0, size.width), y);
      }

      canvas.drawPath(path, _glowPaint);
      canvas.drawPath(path, _linePaint);

      _paintBadge(
        canvas: canvas,
        position: Offset(16, (y - 24).clamp(8.0, size.height - 30)),
        label: 'COUNT LINE [Y: ${(linePosition * 100).toInt()}%]',
      );
    } else {
      final x = size.width * linePosition;
      for (var y = 0.0; y < size.height; y += _dashStride) {
        path.moveTo(x, y);
        path.lineTo(x, (y + _dashWidth).clamp(0.0, size.height));
      }

      canvas.drawPath(path, _glowPaint);
      canvas.drawPath(path, _linePaint);

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
    final textPainter = _badgePainter(label);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - 6,
        position.dy - 3,
        textPainter.width + 12,
        textPainter.height + 6,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(bgRect, _badgeBackgroundPaint);
    canvas.drawRRect(bgRect, _badgeBorderPaint);

    textPainter.paint(canvas, position);
  }

  TextPainter _badgePainter(String label) {
    final cached = _cachedBadge;
    if (cached != null && _cachedBadgeLabel == label) return cached;

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: accentColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _cachedBadge = painter;
    _cachedBadgeLabel = label;
    return painter;
  }

  @override
  bool shouldRepaint(covariant CountingLinePainter oldDelegate) {
    return oldDelegate.linePosition != linePosition ||
        oldDelegate.isHorizontal != isHorizontal ||
        oldDelegate.accentColor != accentColor;
  }
}
