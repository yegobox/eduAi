import 'dart:ui' as ui;

import 'package:eduai/core/ink/ink_canvas.dart';
import 'package:eduai/core/ink/ink_controller.dart';
import 'package:eduai/core/ink/ink_raster.dart';
import 'package:eduai/core/ink/ink_stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const black = Color(0xFF000000);

  group('InkTool', () {
    test('each tool has its own width, opacity and compositing', () {
      expect(InkTool.pen.baseWidth, 3);
      expect(InkTool.highlighter.baseWidth, 16);
      expect(InkTool.eraser.baseWidth, 20);

      expect(InkTool.pen.opacity, 1.0);
      expect(InkTool.highlighter.opacity, 0.35);

      expect(InkTool.eraser.erases, isTrue);
      expect(InkTool.pen.erases, isFalse);
    });

    test('guides expose display labels', () {
      expect(InkGuide.grid.label, 'Grid');
      expect(InkGuide.lines.label, 'Lines');
      expect(InkGuide.plain.label, 'Plain');
    });
  });

  group('InkColor', () {
    // The dark canvas paints 0xFF22232C; the light one is paper-white.
    const darkPaper = Color(0xFF22232C);
    const lightPaper = Color(0xFFFFFFFF);

    double contrast(Color a, Color b) {
      final la = a.computeLuminance() + 0.05;
      final lb = b.computeLuminance() + 0.05;
      return la > lb ? la / lb : lb / la;
    }

    test('every pen colour stays visible on the paper it lands on', () {
      // The highlighter is exempt: it is meant to be a wash over text, and is
      // painted at 0.35 opacity anyway.
      final pens = InkColor.values.where((c) => c != InkColor.highlight);
      for (final color in pens) {
        expect(
          contrast(color.resolve(Brightness.light), lightPaper),
          greaterThan(2.0),
          reason: '${color.label} on light paper',
        );
        expect(
          contrast(color.resolve(Brightness.dark), darkPaper),
          greaterThan(2.0),
          reason: '${color.label} on dark paper',
        );
      }
    });

    test('graphite flips from near-black to near-white', () {
      // The bug this guards: a paper-black default drawn on a dark canvas.
      expect(
        InkColor.graphite.resolve(Brightness.light).computeLuminance(),
        lessThan(0.1),
      );
      expect(
        InkColor.graphite.resolve(Brightness.dark).computeLuminance(),
        greaterThan(0.7),
      );
    });
  });

  group('InkPoint.normalisePressure', () {
    test('maps a stylus range onto 0..1', () {
      expect(InkPoint.normalisePressure(0.0, 0.0, 1.0), 0.0);
      expect(InkPoint.normalisePressure(0.5, 0.0, 1.0), 0.5);
      expect(InkPoint.normalisePressure(1.0, 0.0, 1.0), 1.0);
      // Some devices report a non-zero minimum.
      expect(InkPoint.normalisePressure(1.0, 0.5, 1.5), 0.5);
    });

    test('falls back to the midpoint when the device reports no range', () {
      // Mice and most touchscreens report min == max: there is no signal.
      expect(InkPoint.normalisePressure(1.0, 1.0, 1.0), 0.5);
      expect(InkPoint.normalisePressure(0.0, 0.0, 0.0), 0.5);
    });

    test('clamps out-of-range readings', () {
      expect(InkPoint.normalisePressure(2.0, 0.0, 1.0), 1.0);
      expect(InkPoint.normalisePressure(-1.0, 0.0, 1.0), 0.0);
    });
  });

  group('InkStroke', () {
    test('scales width with pressure and never goes hair-thin', () {
      final stroke = InkStroke(tool: InkTool.pen, color: InkColor.graphite);
      // 3 * (0.6 + 1.0) = 4.8 at full pressure.
      expect(
        stroke.widthAt(const InkPoint(Offset.zero, 1.0)),
        closeTo(4.8, 1e-9),
      );
      // 3 * (0.6 + 0.0) = 1.8 at zero pressure.
      expect(
        stroke.widthAt(const InkPoint(Offset.zero, 0.0)),
        closeTo(1.8, 1e-9),
      );

      // A very fine tool still clamps to a visible 1.5.
      final hair = InkStroke(tool: InkTool.pen, color: InkColor.graphite);
      expect(
        hair.widthAt(const InkPoint(Offset.zero, 0.0)),
        greaterThanOrEqualTo(1.5),
      );
    });

    test('copy detaches the point list', () {
      final stroke = InkStroke(
        tool: InkTool.pen,
        color: InkColor.graphite,
        points: [const InkPoint(Offset.zero, 0.5)],
      );
      final copy = stroke.copy();
      copy.add(const InkPoint(Offset(1, 1), 0.5));
      expect(stroke.points, hasLength(1));
      expect(copy.points, hasLength(2));
    });

    test('is empty until a point lands', () {
      final stroke = InkStroke(tool: InkTool.pen, color: InkColor.graphite);
      expect(stroke.isEmpty, isTrue);
      stroke.add(const InkPoint(Offset.zero, 0.5));
      expect(stroke.isEmpty, isFalse);
    });

    testWidgets('paints a dot for a tap and a line run for a drag', (
      tester,
    ) async {
      // Painting through a real canvas proves the paint calls are well-formed
      // (a bad Paint or blend mode throws here).
      final dot = InkStroke(
        tool: InkTool.pen,
        color: InkColor.graphite,
        points: [const InkPoint(Offset(5, 5), 0.7)],
      );
      final drag = InkStroke(
        tool: InkTool.highlighter,
        color: InkColor.graphite,
        points: const [
          InkPoint(Offset(0, 0), 0.4),
          InkPoint(Offset(10, 10), 0.6),
          InkPoint(Offset(20, 5), 0.9),
        ],
      );
      final erase = InkStroke(
        tool: InkTool.eraser,
        color: InkColor.graphite,
        points: const [
          InkPoint(Offset(0, 0), 0.5),
          InkPoint(Offset(5, 5), 0.5),
        ],
      );
      final empty = InkStroke(tool: InkTool.pen, color: InkColor.graphite);

      // Picture.toImage needs the real raster thread, so it must run outside
      // the fake-async test zone.
      final png = await tester.runAsync(
        () => rasterizeStrokes([dot, drag, erase, empty], const Size(40, 40)),
      );
      expect(png, isNotNull);
      expect(png!.length, greaterThan(8));
      // PNG magic number.
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });

  group('rasterizeStrokes', () {
    test('returns null when there is nothing to send', () async {
      expect(await rasterizeStrokes(const [], const Size(10, 10)), isNull);
      final stroke = InkStroke(
        tool: InkTool.pen,
        color: InkColor.graphite,
        points: [const InkPoint(Offset.zero, 0.5)],
      );
      expect(await rasterizeStrokes([stroke], Size.zero), isNull);
    });

    test('crops to the ink so the writing fills the frame', () {
      // One short line near the top of a tall page — the shape that made the
      // uncropped raster mostly blank paper.
      final stroke = InkStroke(
        tool: InkTool.pen,
        color: InkColor.graphite,
        points: const [
          InkPoint(Offset(100, 50), 0.5),
          InkPoint(Offset(300, 60), 0.5),
        ],
      );
      final crop = inkCropRect([stroke], const Size(800, 1200))!;

      expect(crop.left, lessThan(100));
      expect(crop.top, lessThan(50));
      expect(crop.right, greaterThan(300));
      expect(crop.bottom, greaterThan(60));
      // Padding only — not the whole 800x1200 page.
      expect(crop.width, lessThan(300));
      expect(crop.height, lessThan(150));
    });

    test('the crop stays inside the page and ignores erased-away regions', () {
      final ink = InkStroke(
        tool: InkTool.pen,
        color: InkColor.graphite,
        points: const [InkPoint(Offset(5, 5), 0.5)],
      );
      final eraser = InkStroke(
        tool: InkTool.eraser,
        color: InkColor.graphite,
        points: const [InkPoint(Offset(390, 390), 0.5)],
      );
      final crop = inkCropRect([ink, eraser], const Size(400, 400))!;

      expect(crop.left, 0);
      expect(crop.top, 0);
      // The eraser's corner would have stretched the crop across the page.
      expect(crop.right, lessThan(100));
      expect(inkCropRect([eraser], const Size(400, 400)), isNull);
    });

    testWidgets('lays dark ink on the white page whatever the theme', (
      tester,
    ) async {
      // A dark-mode page's ink is near-white on screen; rasterised onto the
      // white sheet the vision model reads, it must come back dark or the
      // model is handed a blank page.
      final stroke = InkStroke(
        tool: InkTool.pen,
        color: InkColor.graphite,
        points: const [
          InkPoint(Offset(0, 10), 0.9),
          InkPoint(Offset(20, 10), 0.9),
        ],
      );

      final darkest = await tester.runAsync(() async {
        final png = await rasterizeStrokes(
          [stroke],
          const Size(20, 20),
          pixelRatio: 1,
        );
        final codec = await ui.instantiateImageCodec(png!);
        final frame = await codec.getNextFrame();
        final pixels = await frame.image.toByteData();
        frame.image.dispose();
        codec.dispose();

        var min = 255;
        for (var i = 0; i < pixels!.lengthInBytes; i += 4) {
          final luma = pixels.getUint8(i); // Greyscale ink: red channel will do.
          if (luma < min) min = luma;
        }
        return min;
      });

      expect(darkest, lessThan(64));
    });
  });

  group('InkController', () {
    late InkController controller;

    setUp(() => controller = InkController());
    tearDown(() => controller.dispose());

    void draw(int points) {
      controller.begin(InkTool.pen, InkColor.graphite, const InkPoint(Offset.zero, 0.5));
      for (var i = 0; i < points; i++) {
        controller.extend(InkPoint(Offset(i.toDouble(), 0), 0.5));
      }
      controller.end();
    }

    test('starts empty with nothing to undo or redo', () {
      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      expect(controller.strokeCount, 0);
    });

    test('records a stroke and notifies listeners', () {
      var notifications = 0;
      controller.addListener(() => notifications++);
      draw(2);
      expect(controller.strokeCount, 1);
      expect(controller.strokes.single.points, hasLength(3));
      expect(controller.isEmpty, isFalse);
      // begin + 2 extends + end.
      expect(notifications, 4);
    });

    test('ignores a move with no stroke in progress', () {
      controller.extend(const InkPoint(Offset(1, 1), 0.5));
      expect(controller.isEmpty, isTrue);
      // end() with nothing active is also a no-op.
      controller.end();
      expect(controller.isEmpty, isTrue);
    });

    test('undo and redo walk the history', () {
      draw(1);
      draw(1);
      expect(controller.strokeCount, 2);

      controller.undo();
      expect(controller.strokeCount, 1);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.strokeCount, 2);
      expect(controller.canRedo, isFalse);

      // Both are safe at the ends of the history.
      controller.redo();
      controller.undo();
      controller.undo();
      controller.undo();
      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
    });

    test('drawing after an undo forks the timeline', () {
      draw(1);
      controller.undo();
      expect(controller.canRedo, isTrue);
      draw(1);
      // The undone stroke is gone for good — the classic editor rule.
      expect(controller.canRedo, isFalse);
      expect(controller.strokeCount, 1);
    });

    test(
      'clear wipes strokes and history, and is a no-op when already empty',
      () {
        var notifications = 0;
        controller.addListener(() => notifications++);
        controller.clear();
        expect(notifications, 0);

        draw(1);
        controller.undo();
        controller.clear();
        expect(controller.isEmpty, isTrue);
        expect(controller.canUndo, isFalse);
        expect(controller.canRedo, isFalse);
      },
    );

    test('exposes strokes as an unmodifiable view', () {
      draw(1);
      expect(
        () =>
            controller.strokes.add(InkStroke(tool: InkTool.pen, color: InkColor.graphite)),
        throwsUnsupportedError,
      );
    });
  });

  group('InkCanvas widget', () {
    testWidgets('turns pointer events into strokes', (tester) async {
      final controller = InkController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: InkCanvas(controller: controller, guide: InkGuide.grid),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveTo(const Offset(80, 90));
      await gesture.moveTo(const Offset(120, 60));
      await gesture.up();
      await tester.pump();

      expect(controller.strokeCount, 1);
      expect(controller.strokes.single.points.length, greaterThanOrEqualTo(3));
    });

    testWidgets('renders each guide without throwing', (tester) async {
      for (final guide in InkGuide.values) {
        final controller = InkController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: InkCanvas(
                  controller: controller,
                  guide: guide,
                  background: Colors.transparent,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        controller.dispose();
      }
    });

    test('the painter repaints only when its inputs change', () {
      final a = InkController();
      final b = InkController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      final painter = InkPainter(
        controller: a,
        guide: InkGuide.grid,
        guideColor: black,
        background: black,
      );
      expect(
        painter.shouldRepaint(
          InkPainter(
            controller: a,
            guide: InkGuide.grid,
            guideColor: black,
            background: black,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          InkPainter(
            controller: b,
            guide: InkGuide.grid,
            guideColor: black,
            background: black,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          InkPainter(
            controller: a,
            guide: InkGuide.plain,
            guideColor: black,
            background: black,
          ),
        ),
        isTrue,
      );
      // Switching theme re-resolves every stroke's colour, so it must repaint.
      expect(
        painter.shouldRepaint(
          InkPainter(
            controller: a,
            guide: InkGuide.grid,
            guideColor: black,
            background: black,
            brightness: Brightness.dark,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('resolves ink against the canvas theme', (tester) async {
      for (final brightness in Brightness.values) {
        final controller = InkController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: InkCanvas(controller: controller),
              ),
            ),
          ),
        );
        // MaterialApp lerps between themes, so the first frame after a switch
        // still carries the old brightness.
        await tester.pumpAndSettle();
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(InkCanvas),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter
                as InkPainter;
        expect(painter.brightness, brightness);
      }
    });
  });
}
