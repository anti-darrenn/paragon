import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

/// One pen stroke on the scratchpad, in the overlay's local coordinates.
class ScratchStroke {
  const ScratchStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;
}

/// The scratchpad's content and its history: pure Dart, no widgets.
///
/// Immutable — every edit returns a new model — so undo and redo are
/// whole snapshots and "clear" is undoable exactly like a stroke. An edit
/// that changes nothing (erasing empty space, clearing an empty page)
/// returns `this` and records no history, so undo never has to step
/// through no-ops.
class ScratchpadModel {
  const ScratchpadModel({
    this.strokes = const [],
    this.past = const [],
    this.future = const [],
  });

  final List<ScratchStroke> strokes;

  /// Earlier versions of [strokes], most recent last.
  final List<List<ScratchStroke>> past;

  /// Versions undone and not yet redone, next redo last.
  final List<List<ScratchStroke>> future;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;
  bool get isEmpty => strokes.isEmpty;

  /// How many undo steps are kept; older ones are dropped.
  static const historyLimit = 100;

  ScratchpadModel _commit(List<ScratchStroke> next) {
    final kept = past.length >= historyLimit
        ? past.sublist(past.length - historyLimit + 1)
        : past;
    return ScratchpadModel(strokes: next, past: [...kept, strokes]);
  }

  /// Adds [stroke]. Any redo history is dropped, as in every editor.
  ScratchpadModel addStroke(ScratchStroke stroke) {
    if (stroke.points.isEmpty) return this;
    return _commit([...strokes, stroke]);
  }

  ScratchpadModel undo() {
    if (!canUndo) return this;
    return ScratchpadModel(
      strokes: past.last,
      past: past.sublist(0, past.length - 1),
      future: [...future, strokes],
    );
  }

  ScratchpadModel redo() {
    if (!canRedo) return this;
    return ScratchpadModel(
      strokes: future.last,
      past: [...past, strokes],
      future: future.sublist(0, future.length - 1),
    );
  }

  ScratchpadModel clear() => isEmpty ? this : _commit(const []);

  /// Indexes into [strokes] of every stroke the eraser [path], of the given
  /// [radius], touches. A stroke eraser: a stroke touched anywhere goes
  /// whole, which is simpler to predict than cutting strokes in two.
  Set<int> hits(List<Offset> path, double radius) {
    if (path.isEmpty) return const {};
    final result = <int>{};
    for (var i = 0; i < strokes.length; i++) {
      if (_touches(strokes[i], path, radius)) result.add(i);
    }
    return result;
  }

  /// Removes every stroke the eraser [path] touches, as one undo step.
  ScratchpadModel eraseAlong(List<Offset> path, double radius) {
    final hit = hits(path, radius);
    if (hit.isEmpty) return this;
    return _commit([
      for (var i = 0; i < strokes.length; i++)
        if (!hit.contains(i)) strokes[i],
    ]);
  }

  static bool _touches(ScratchStroke s, List<Offset> path, double radius) {
    final reach = radius + s.width / 2;
    final a = _segments(s.points);
    final b = _segments(path);
    for (final (p1, p2) in a) {
      for (final (q1, q2) in b) {
        if (segmentDistance(p1, p2, q1, q2) <= reach) return true;
      }
    }
    return false;
  }

  /// Consecutive point pairs; a single point is a zero-length segment.
  static Iterable<(Offset, Offset)> _segments(List<Offset> pts) sync* {
    if (pts.length == 1) {
      yield (pts.first, pts.first);
      return;
    }
    for (var i = 0; i + 1 < pts.length; i++) {
      yield (pts[i], pts[i + 1]);
    }
  }

  /// Shortest distance between segments p1–p2 and q1–q2.
  static double segmentDistance(Offset p1, Offset p2, Offset q1, Offset q2) {
    if (_intersect(p1, p2, q1, q2)) return 0;
    return [
      _pointToSegment(p1, q1, q2),
      _pointToSegment(p2, q1, q2),
      _pointToSegment(q1, p1, p2),
      _pointToSegment(q2, p1, p2),
    ].reduce(math.min);
  }

  static double _pointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static double _cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

  static bool _intersect(Offset p1, Offset p2, Offset q1, Offset q2) {
    final d1 = _cross(q1, q2, p1);
    final d2 = _cross(q1, q2, p2);
    final d3 = _cross(p1, p2, q1);
    final d4 = _cross(p1, p2, q2);
    // Proper crossings only; touching and collinear cases are caught by
    // the point-to-segment distances, which are then zero.
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }
}
