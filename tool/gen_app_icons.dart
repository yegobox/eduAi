// Rebuilds the launcher-icon source variants in assets/icon/ from the single
// master artwork in assets/akili_icon_512.png.
//
// Usage, from the project root:
//
//   dart run tool/gen_app_icons.dart
//   dart run flutter_launcher_icons
//   dart run tool/gen_app_icons.dart --maskable-only
//
// The third step is required: flutter_launcher_icons writes the maskable web
// icons as plain copies of the standard icon, which ignores the PWA maskable
// safe zone, so it undoes what the first step produced.
//
// Why the variants exist at all -- the source artwork is a rounded square with
// white corners and the glyph baked on top of a gradient, but:
//   * iOS and macOS apply their own mask, so their art must be full-bleed with
//     no rounded corners of its own and no alpha channel;
//   * Android's adaptive icon needs the gradient and the glyph as two separate
//     layers, with the glyph fitted to the 66dp safe circle.

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main(List<String> args) {
  const srcPath = 'assets/akili_icon_512.png';
  const outDir = 'assets/icon';
  const webIconDir = 'web/icons';

  if (args.contains('--maskable-only')) {
    writeWebMaskables('$outDir/akili_icon_maskable_1024.png', webIconDir);
    return;
  }

  Directory(outDir).createSync(recursive: true);
  final src = img.decodePng(File(srcPath).readAsBytesSync())!;
  final w = src.width, h = src.height;

  // --- 1. Flood-fill from the corners to find the area outside the rounded rect.
  final outside = List<bool>.filled(w * h, false);
  bool nearWhite(int x, int y) {
    final p = src.getPixel(x, y);
    return p.r > 245 && p.g > 245 && p.b > 245;
  }

  final stack = <int>[];
  for (final c in [[0, 0], [w - 1, 0], [0, h - 1], [w - 1, h - 1]]) {
    if (nearWhite(c[0], c[1])) stack.add(c[1] * w + c[0]);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    if (outside[i]) continue;
    final x = i % w, y = i ~/ w;
    if (!nearWhite(x, y)) continue;
    outside[i] = true;
    if (x > 0) stack.add(i - 1);
    if (x < w - 1) stack.add(i + 1);
    if (y > 0) stack.add(i - w);
    if (y < h - 1) stack.add(i + w);
  }

  // --- 2. Build the gradient lookup: colour is a function of (x + y).
  // Average every non-glyph, non-corner pixel within each diagonal band.
  final bands = w + h - 1;
  final sumR = List<double>.filled(bands, 0);
  final sumG = List<double>.filled(bands, 0);
  final sumB = List<double>.filled(bands, 0);
  final count = List<int>.filled(bands, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (outside[y * w + x]) continue;
      final p = src.getPixel(x, y);
      // Skip anything the glyph could have lightened.
      if (p.r > 150 && p.g > 150) continue;
      final d = x + y;
      sumR[d] += p.r.toDouble();
      sumG[d] += p.g.toDouble();
      sumB[d] += p.b.toDouble();
      count[d]++;
    }
  }
  // Least-squares fit each channel against t = d / (bands - 1); the source
  // gradient is linear, and a fit extrapolates cleanly into the corner bands
  // that the rounded rect left with no samples.
  List<double> fit(List<double> sum) {
    var sw = 0.0, st = 0.0, sv = 0.0, stt = 0.0, stv = 0.0;
    for (var d = 0; d < bands; d++) {
      if (count[d] < 8) continue;
      final t = d / (bands - 1), v = sum[d] / count[d], cw = count[d].toDouble();
      sw += cw; st += cw * t; sv += cw * v; stt += cw * t * t; stv += cw * t * v;
    }
    final denom = sw * stt - st * st;
    final slope = (sw * stv - st * sv) / denom;
    final intercept = (sv - slope * st) / sw;
    return [intercept, slope];
  }

  final fr = fit(sumR), fg = fit(sumG), fb = fit(sumB);
  double clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v);
  List<double> gradAt(double t) =>
      [clamp255(fr[0] + fr[1] * t), clamp255(fg[0] + fg[1] * t), clamp255(fb[0] + fb[1] * t)];

  String hex(List<double> c) =>
      '#${c.map((v) => v.round().toRadixString(16).padLeft(2, '0')).join()}';
  stdout.writeln('gradient start ${hex(gradAt(0))} -> end ${hex(gradAt(1))}');

  // --- 3. Recover the glyph as a soft alpha mask.
  // The source composited white over the gradient: c = a*255 + (1-a)*g,
  // so a = (c - g) / (255 - g). Use the channel with the most headroom.
  final glyph = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (outside[y * w + x]) {
        glyph.setPixelRgba(x, y, 255, 255, 255, 0);
        continue;
      }
      final p = src.getPixel(x, y);
      final g = gradAt((x + y) / (bands - 1));
      var best = 0.0, bestHead = 0.0;
      for (var ch = 0; ch < 3; ch++) {
        final head = 255 - g[ch];
        if (head < 40 || head < bestHead) continue;
        final c = [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()][ch];
        best = (c - g[ch]) / head;
        bestHead = head;
      }
      final a = (best.clamp(0.0, 1.0) * 255).round();
      glyph.setPixelRgba(x, y, 255, 255, 255, a);
    }
  }

  // --- 4. Render outputs at 1024.
  const size = 1024;
  img.Image gradientSquare(int s) {
    final out = img.Image(width: s, height: s, numChannels: 4);
    final maxD = 2 * (s - 1);
    for (var y = 0; y < s; y++) {
      for (var x = 0; x < s; x++) {
        final c = gradAt((x + y) / maxD);
        out.setPixelRgba(x, y, c[0].round(), c[1].round(), c[2].round(), 255);
      }
    }
    return out;
  }

  final glyphBig =
      img.copyResize(glyph, width: size, height: size, interpolation: img.Interpolation.cubic);

  // Master: full-bleed gradient + glyph. iOS/macOS apply their own mask, so the
  // source's own rounded corners (and their white surround) must not survive.
  final master = gradientSquare(size);
  img.compositeImage(master, glyphBig);
  File('$outDir/akili_icon_master_1024.png').writeAsBytesSync(img.encodePng(master));

  // Master without alpha, for iOS/macOS (App Store rejects an alpha channel).
  final masterOpaque = master.convert(numChannels: 3);
  File('$outDir/akili_icon_ios_1024.png').writeAsBytesSync(img.encodePng(masterOpaque));

  // Adaptive background: gradient only.
  File('$outDir/akili_adaptive_background.png')
      .writeAsBytesSync(img.encodePng(gradientSquare(size)));

  // Adaptive foreground: glyph scaled into the 66% safe zone of the 108dp canvas.
  // Measure the glyph's own bounds first so the visual mark, not its padding,
  // is what gets fitted.
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (glyph.getPixel(x, y).a > 24) {
        minX = math.min(minX, x); maxX = math.max(maxX, x);
        minY = math.min(minY, y); maxY = math.max(maxY, y);
      }
    }
  }
  stdout.writeln('glyph bounds ($minX,$minY)-($maxX,$maxY) in ${w}x$h');
  final cropped = img.copyCrop(glyph,
      x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  // Fit the glyph's *enclosing circle*, not its bounding box: the A's two feet
  // sit at the bbox corners, so a box-fit at 66/108 would push them outside the
  // 66dp safe circle and a round launcher mask would clip them off.
  final cx = (cropped.width - 1) / 2, cy = (cropped.height - 1) / 2;
  var maxR = 0.0;
  for (var y = 0; y < cropped.height; y++) {
    for (var x = 0; x < cropped.width; x++) {
      if (cropped.getPixel(x, y).a <= 24) continue;
      final r = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      if (r > maxR) maxR = r;
    }
  }
  // flutter_launcher_icons wraps the foreground in <inset android:inset="16%">,
  // so the drawable is redrawn into the middle 68% of the 108dp layer. Pre-size
  // the glyph so that AFTER that inset its circle lands just inside the 66dp
  // (61%) safe zone -- fitting to 61% here would shrink it twice over.
  const insetFactor = 0.68;
  const safeDiameter = 0.61 / insetFactor;
  final scale = (size * safeDiameter / 2) / maxR;
  stdout.writeln('glyph enclosing radius ${maxR.toStringAsFixed(1)}px '
      '-> scale ${scale.toStringAsFixed(3)}');
  final resized = img.copyResize(cropped,
      width: (cropped.width * scale).round(),
      height: (cropped.height * scale).round(),
      interpolation: img.Interpolation.cubic);
  final fgImg = img.Image(width: size, height: size, numChannels: 4);
  img.compositeImage(fgImg, resized,
      dstX: (size - resized.width) ~/ 2, dstY: (size - resized.height) ~/ 2);
  File('$outDir/akili_adaptive_foreground.png').writeAsBytesSync(img.encodePng(fgImg));

  // Web maskable icon: PWA maskable art must survive a circle crop of the inner
  // 80%, and the A's own enclosing circle is ~87% of the master, so it needs its
  // own render rather than a copy of the full-bleed master.
  const maskableSafe = 0.80;
  final mScale = (size * maskableSafe / 2) / maxR;
  final mGlyph = img.copyResize(cropped,
      width: (cropped.width * mScale).round(),
      height: (cropped.height * mScale).round(),
      interpolation: img.Interpolation.cubic);
  final maskable = gradientSquare(size);
  img.compositeImage(maskable, mGlyph,
      dstX: (size - mGlyph.width) ~/ 2, dstY: (size - mGlyph.height) ~/ 2);
  File('$outDir/akili_icon_maskable_1024.png').writeAsBytesSync(img.encodePng(maskable));

  stdout.writeln('wrote 5 files to $outDir');

  writeWebMaskables('$outDir/akili_icon_maskable_1024.png', webIconDir);
}

/// flutter_launcher_icons emits the maskable web icons as plain copies of the
/// standard icon; overwrite them with the safe-zone-fitted render.
void writeWebMaskables(String masterPath, String webIconDir) {
  final master = img.decodePng(File(masterPath).readAsBytesSync())!;
  for (final size in [192, 512]) {
    final out = img.copyResize(master,
        width: size, height: size, interpolation: img.Interpolation.cubic);
    File('$webIconDir/Icon-maskable-$size.png').writeAsBytesSync(img.encodePng(out));
    stdout.writeln('wrote $webIconDir/Icon-maskable-$size.png');
  }
}
