import 'package:flutter/foundation.dart';

import 'ink_stroke.dart';

/// Holds one surface's strokes plus its undo/redo history.
///
/// Deliberately Flutter-widget-free (only [ChangeNotifier]) so the Workbook can
/// own three of these — one per page — and unit tests can drive it without
/// pumping a canvas.
class InkController extends ChangeNotifier {
  final List<InkStroke> _strokes = [];
  final List<InkStroke> _redo = [];
  InkStroke? _active;

  /// Strokes in paint order, oldest first.
  List<InkStroke> get strokes => List.unmodifiable(_strokes);

  bool get isEmpty => _strokes.isEmpty;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get strokeCount => _strokes.length;

  /// Starts a new stroke. Any redo history is dropped — the classic editor
  /// rule: drawing after undoing forks the timeline.
  void begin(InkTool tool, InkColor color, InkPoint point) {
    final stroke = InkStroke(tool: tool, color: color, points: [point]);
    _active = stroke;
    _strokes.add(stroke);
    _redo.clear();
    notifyListeners();
  }

  /// Extends the in-progress stroke. A no-op when no stroke is active, so a
  /// stray move event (e.g. hover after pen-up) can't create a floating mark.
  void extend(InkPoint point) {
    final active = _active;
    if (active == null) return;
    active.add(point);
    notifyListeners();
  }

  void end() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redo.add(_strokes.removeLast());
    _active = null;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _strokes.add(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty && _redo.isEmpty) return;
    _strokes.clear();
    _redo.clear();
    _active = null;
    notifyListeners();
  }
}
