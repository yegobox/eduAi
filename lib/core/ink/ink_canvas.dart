import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'ink_controller.dart';
import 'ink_stroke.dart';

/// The stylus drawing surface shared by Workbook, the Tutor scratchpad and the
/// Lesson annotation overlay.
///
/// Uses a raw [Listener] rather than a gesture detector so every pointer
/// sample (and its pressure) reaches the controller — gesture arenas would
/// swallow the first few moves while deciding whether this is a scroll.
class InkCanvas extends StatelessWidget {
  const InkCanvas({
    super.key,
    required this.controller,
    this.tool = InkTool.pen,
    this.color = InkColor.graphite,
    this.guide = InkGuide.plain,
    this.background,
    this.borderRadius,
  });

  final InkController controller;
  final InkTool tool;
  final InkColor color;
  final InkGuide guide;

  /// Fill painted under the ink. Pass `Colors.transparent` for the lesson
  /// annotation overlay so the text underneath stays visible.
  final Color? background;

  final BorderRadius? borderRadius;

  InkPoint _pointFor(PointerEvent event) => InkPoint(
    event.localPosition,
    InkPoint.normalisePressure(
      event.pressure,
      event.pressureMin,
      event.pressureMax,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final radius = borderRadius ?? t.cardBorderRadius;
    return ClipRRect(
      borderRadius: radius,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => controller.begin(tool, color, _pointFor(e)),
        onPointerMove: (e) => controller.extend(_pointFor(e)),
        onPointerUp: (_) => controller.end(),
        onPointerCancel: (_) => controller.end(),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: InkPainter(
              controller: controller,
              guide: guide,
              // Ink resolves against the canvas' own brightness, not the
              // ambient theme's: this surface paints its own paper.
              brightness: t.isDark ? Brightness.dark : Brightness.light,
              guideColor: t.isDark
                  ? const Color(0x14FFFFFF)
                  : const Color(0x12000000),
              background:
                  background ??
                  (t.isDark
                      ? const Color(0xFF22232C)
                      : const Color(0xFFFFFFFF)),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Paints the guide ruling, then every stroke, inside one layer so the
/// eraser's [BlendMode.clear] only removes ink laid on this surface.
@visibleForTesting
class InkPainter extends CustomPainter {
  InkPainter({
    required this.controller,
    required this.guide,
    required this.guideColor,
    required this.background,
    this.brightness = Brightness.light,
  }) : super(repaint: controller);

  final InkController controller;
  final InkGuide guide;
  final Color guideColor;
  final Color background;

  /// Brightness of the paper this ink lands on — see [InkColor.resolve].
  final Brightness brightness;

  static const double _gridStep = 24;
  static const double _lineStep = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (background.a > 0) {
      canvas.drawRect(rect, Paint()..color = background);
    }
    _paintGuide(canvas, size);

    // saveLayer bounds the eraser: without it, BlendMode.clear would punch a
    // hole through everything painted beneath this widget.
    canvas.saveLayer(rect, Paint());
    for (final stroke in controller.strokes) {
      stroke.paint(canvas, brightness);
    }
    canvas.restore();
  }

  void _paintGuide(Canvas canvas, Size size) {
    if (guide == InkGuide.plain) return;
    final paint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    if (guide == InkGuide.grid) {
      for (var x = _gridStep; x < size.width; x += _gridStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
    final step = guide == InkGuide.grid ? _gridStep : _lineStep;
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(InkPainter old) =>
      old.controller != controller ||
      old.guide != guide ||
      old.guideColor != guideColor ||
      old.background != background ||
      old.brightness != brightness;
}
