import 'package:flutter/material.dart';

/// The three drawing tools shared by the Workbook, the Tutor scratchpad and
/// the Lesson annotation overlay.
enum InkTool {
  pen,
  highlighter,
  eraser;

  /// Base stroke width in logical pixels, before pressure scaling.
  double get baseWidth => switch (this) {
    InkTool.pen => 3,
    InkTool.highlighter => 16,
    InkTool.eraser => 20,
  };

  /// Highlighter ink is translucent so underlying text stays readable.
  double get opacity => this == InkTool.highlighter ? 0.35 : 1.0;

  /// The eraser clears previously laid ink instead of adding its own.
  bool get erases => this == InkTool.eraser;
}

/// A pen colour held as an identity rather than a hex.
///
/// The canvas is paper-white in light mode and near-black in dark, so a fixed
/// hex cannot serve both: the paper-black default disappeared entirely on the
/// dark surface. Strokes therefore store the *identity* and resolve it against
/// the surface they are being painted on, which also means a mid-session theme
/// switch recolours ink already on the page.
enum InkColor {
  graphite,
  blue,
  red,
  green,
  amber,

  /// The lesson-annotation highlighter; not offered as a pen colour.
  highlight;

  /// Ink tuned for the surface it lands on. The dark variants are the brighter
  /// accents from the dark token set, so they stay legible at highlighter
  /// opacity too.
  Color resolve(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      InkColor.graphite => dark
          ? const Color(0xFFEDEEF5)
          : const Color(0xFF1A1B22),
      InkColor.blue => dark ? const Color(0xFF8992FF) : const Color(0xFF4A54E8),
      InkColor.red => dark ? const Color(0xFFF17685) : const Color(0xFFD6455A),
      InkColor.green => dark
          ? const Color(0xFF3FCB90)
          : const Color(0xFF1E9D6C),
      InkColor.amber => dark
          ? const Color(0xFFE3A23A)
          : const Color(0xFFB5720E),
      InkColor.highlight => dark
          ? const Color(0xFFFFD54A)
          : const Color(0xFFF5C518),
    };
  }

  /// Spoken name, used for the swatch's accessibility label.
  String get label => switch (this) {
    InkColor.graphite => 'Graphite',
    InkColor.blue => 'Blue',
    InkColor.red => 'Red',
    InkColor.green => 'Green',
    InkColor.amber => 'Amber',
    InkColor.highlight => 'Highlighter',
  };
}

/// Optional ruling drawn behind the ink.
enum InkGuide {
  grid,
  lines,
  plain;

  String get label => switch (this) {
    InkGuide.grid => 'Grid',
    InkGuide.lines => 'Lines',
    InkGuide.plain => 'Plain',
  };
}

/// One sampled pointer position plus its normalised pressure (0..1).
@immutable
class InkPoint {
  const InkPoint(this.offset, this.pressure);

  final Offset offset;

  /// 0..1. Non-stylus devices report a flat 0.5 so lines stay even.
  final double pressure;

  /// Normalises a raw [PointerEvent] pressure against the device's reported
  /// range. Mice and most touchscreens report a constant, in which case
  /// `min == max` and there is no useful signal — fall back to the midpoint.
  static double normalisePressure(double pressure, double min, double max) {
    if (!(max > min)) return 0.5;
    return ((pressure - min) / (max - min)).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is InkPoint && other.offset == offset && other.pressure == pressure;

  @override
  int get hashCode => Object.hash(offset, pressure);
}

/// A single continuous pen-down → pen-up mark.
class InkStroke {
  InkStroke({required this.tool, required this.color, List<InkPoint>? points})
    : points = points ?? <InkPoint>[];

  final InkTool tool;
  final InkColor color;
  final List<InkPoint> points;

  bool get isEmpty => points.isEmpty;

  void add(InkPoint point) => points.add(point);

  InkStroke copy() =>
      InkStroke(tool: tool, color: color, points: List<InkPoint>.from(points));

  /// Pressure-scaled width for the segment ending at [point].
  double widthAt(InkPoint point) {
    final scaled = tool.baseWidth * (0.6 + point.pressure);
    return scaled < 1.5 ? 1.5 : scaled;
  }

  /// Paints this stroke against a surface of the given [brightness], which
  /// picks the ink's actual hex. The caller must have pushed a layer when the
  /// stroke [InkTool.erases], otherwise [BlendMode.clear] would punch through
  /// the whole canvas rather than only the ink above it.
  void paint(Canvas canvas, Brightness brightness) {
    if (points.length < 2) {
      // A tap with no drag still deserves a dot, so the mark isn't lost.
      if (points.length == 1) {
        final p = points.single;
        canvas.drawCircle(p.offset, widthAt(p) / 2, _paintFor(p, brightness));
      }
      return;
    }
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      canvas.drawLine(a.offset, b.offset, _paintFor(b, brightness));
    }
  }

  Paint _paintFor(InkPoint point, Brightness brightness) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = widthAt(point);
    if (tool.erases) {
      paint
        ..blendMode = BlendMode.clear
        ..color = const Color(0xFF000000);
    } else {
      paint.color = color.resolve(brightness).withValues(alpha: tool.opacity);
    }
    return paint;
  }
}
