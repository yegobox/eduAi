import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ink_stroke.dart';

/// Breathing room kept around the ink, so the crop never clips the tail of a
/// descender or the top of a fraction bar.
const double _cropPadding = 28;

/// Longest side of the PNG in device pixels. Past this the extra pixels cost
/// upload time and vision tokens without making handwriting easier to read.
const double _maxRasterSide = 1600;

/// Renders a page of strokes to a PNG so it can be sent to a vision model.
///
/// Crops to the ink rather than sending the whole page: a student writes one
/// line at the top of a tall canvas, and a raster that is 90% blank paper
/// leaves the handwriting a few dozen pixels tall in the model's view.
///
/// The white background is not cosmetic either: a transparent PNG of thin dark
/// strokes is much harder for a vision model to read than the same marks on
/// paper-white. For the same reason the ink is always resolved light-mode,
/// whatever theme the student drew in — a dark-mode page's near-white ink
/// would otherwise be invisible on this white paper.
Future<Uint8List?> rasterizeStrokes(
  List<InkStroke> strokes,
  Size size, {
  Color background = const Color(0xFFFFFFFF),
  double pixelRatio = 2.0,
}) async {
  if (strokes.isEmpty || size.isEmpty) return null;

  final crop = inkCropRect(strokes, size);
  if (crop == null || crop.isEmpty) return null;

  // Never enlarge past the caller's ratio; only shrink an oversized page.
  final scale = math.min(
    pixelRatio,
    _maxRasterSide / math.max(crop.width, crop.height),
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);
  canvas.translate(-crop.left, -crop.top);
  canvas.drawRect(crop, Paint()..color = background);

  // Same layering rule as the live canvas: the eraser's BlendMode.clear must
  // be bounded, or it would erase the background too.
  canvas.saveLayer(crop, Paint());
  for (final stroke in strokes) {
    stroke.paint(canvas, Brightness.light);
  }
  canvas.restore();

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(
      (crop.width * scale).round().clamp(1, _maxRasterSide.toInt()),
      (crop.height * scale).round().clamp(1, _maxRasterSide.toInt()),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// The padded bounding box of every mark, clipped to the page.
///
/// Returns null when there is nothing to crop to. Eraser strokes are ignored:
/// they take ink away, so including them would pad the crop out towards
/// wherever the student happened to rub something out.
@visibleForTesting
Rect? inkCropRect(List<InkStroke> strokes, Size page) {
  double? left, top, right, bottom;

  for (final stroke in strokes) {
    if (stroke.tool.erases) continue;
    for (final point in stroke.points) {
      final half = stroke.widthAt(point) / 2;
      final o = point.offset;
      left = math.min(left ?? o.dx - half, o.dx - half);
      top = math.min(top ?? o.dy - half, o.dy - half);
      right = math.max(right ?? o.dx + half, o.dx + half);
      bottom = math.max(bottom ?? o.dy + half, o.dy + half);
    }
  }

  if (left == null) return null;
  final padded = Rect.fromLTRB(
    left,
    top!,
    right!,
    bottom!,
  ).inflate(_cropPadding);
  final clipped = padded.intersect(Offset.zero & page);
  // Ink drawn entirely outside the page bounds shouldn't collapse the raster.
  return clipped.isEmpty ? Offset.zero & page : clipped;
}
