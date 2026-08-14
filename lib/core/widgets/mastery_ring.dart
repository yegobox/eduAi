import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A circular percentage ring with a centred label — the Progress screen's
/// per-subject mastery indicator (the prototype's conic-gradient ring).
class MasteryRing extends StatelessWidget {
  const MasteryRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 74,
    this.strokeWidth = 8,
  });

  /// 0..1. Clamped, so a bad server number can't paint a >full arc.
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final clamped = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: clamped,
          color: color,
          track: t.surfaceSunken,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            '${(clamped * 100).round()}%',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: size * 0.216,
              color: t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(inset, 0, math.pi * 2, false, trackPaint);

    if (value <= 0) return;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Start at 12 o'clock and sweep clockwise, like the CSS conic gradient.
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * value, false, valuePaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
