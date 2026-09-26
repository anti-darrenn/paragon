import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'scratchpad_model.dart';
import 'scratchpad_provider.dart';
import '../../../core/theme/app_palette.dart';

/// Ink colours on offer: the theme's text colour first, so the default ink
/// reads clearly over the question underneath in either theme.
List<Color> scratchpadInksFor(AppPalette palette) => [
  palette.textPrimary,
  AppColors.accentBlue,
  AppColors.primary,
];

/// Pen thicknesses: fine for working, bold for circling.
const scratchpadWidths = [2.5, 6.0];

/// Radius of the stroke eraser, in logical pixels.
const scratchpadEraserRadius = 12.0;

enum _Tool { pen, eraser }

/// Rough-work paper drawn over the current screen, like scrap paper in
/// the exam hall. The screen stays visible through a light scrim.
///
/// "See through" lets pointers pass to the screen underneath so the
/// student can scroll or read the question, then toggle back to draw; the
/// toolbar stays live in both modes.
class ScratchpadOverlay extends StatefulWidget {
  const ScratchpadOverlay({super.key, required this.close});

  final VoidCallback close;

  @override
  State<ScratchpadOverlay> createState() => _ScratchpadOverlayState();
}

class _ScratchpadOverlayState extends State<ScratchpadOverlay> {
  _Tool _tool = _Tool.pen;
  int _ink = 0;
  int _width = 0;
  bool _seeThrough = false;

  /// The pointer currently drawing; other fingers are ignored so a palm
  /// or second touch cannot start a second stroke.
  int? _pointer;
  List<Offset> _live = const [];

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    setState(() {
      _pointer = e.pointer;
      _live = [e.localPosition];
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    setState(() => _live = [..._live, e.localPosition]);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    final points = _live;
    final pad = ScratchpadController.of(context);
    if (e is PointerUpEvent && points.isNotEmpty) {
      if (_tool == _Tool.pen) {
        pad.addStroke(
          ScratchStroke(
            points: points,
            color: scratchpadInksFor(context.palette)[_ink],
            width: scratchpadWidths[_width],
          ),
        );
      } else {
        pad.eraseAlong(points, scratchpadEraserRadius);
      }
    }
    setState(() {
      _pointer = null;
      _live = const [];
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: const Text('Clear the scratchpad?'),
        content: const Text('You can undo this.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) ScratchpadController.of(context).clear();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScratchpadModel>(
      valueListenable: ScratchpadController.of(context),
      builder: (context, model, _) => _buildWith(model),
    );
  }

  Widget _buildWith(ScratchpadModel model) {
    final erasing = _tool == _Tool.eraser && _live.isNotEmpty;
    final hidden = erasing
        ? model.hits(_live, scratchpadEraserRadius)
        : const <int>{};

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _seeThrough,
            child: Listener(
              key: const Key('scratchpad-canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: CustomPaint(
                painter: _ScratchPainter(
                  strokes: model.strokes,
                  hidden: hidden,
                  live: _tool == _Tool.pen ? _live : const [],
                  liveColor: scratchpadInksFor(context.palette)[_ink],
                  liveWidth: scratchpadWidths[_width],
                  eraser: erasing ? _live.last : null,
                  scrim: AppColors.overlay.withAlpha(_seeThrough ? 25 : 70),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _toolbar(model),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(ScratchpadModel model) {
    final pad = ScratchpadController.of(context);
    return Material(
      color: context.palette.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.palette.border),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < scratchpadInksFor(context.palette).length; i++)
              _ToolButton(
                tooltip: 'Pen colour ${i + 1}',
                selected: _tool == _Tool.pen && _ink == i,
                onPressed: () => setState(() {
                  _tool = _Tool.pen;
                  _ink = i;
                  _seeThrough = false;
                }),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: scratchpadInksFor(context.palette)[i],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            _ToolButton(
              tooltip: _width == 0 ? 'Thick pen' : 'Thin pen',
              selected: false,
              onPressed: () => setState(() => _width = 1 - _width),
              child: Icon(
                _width == 0 ? Icons.line_weight : Icons.horizontal_rule,
                size: 20,
              ),
            ),
            _ToolButton(
              tooltip: 'Eraser',
              selected: _tool == _Tool.eraser,
              onPressed: () => setState(() {
                _tool = _Tool.eraser;
                _seeThrough = false;
              }),
              child: const Icon(Icons.auto_fix_normal_outlined, size: 20),
            ),
            _ToolButton(
              tooltip: 'Undo',
              selected: false,
              onPressed: model.canUndo ? pad.undo : null,
              child: const Icon(Icons.undo, size: 20),
            ),
            _ToolButton(
              tooltip: 'Redo',
              selected: false,
              onPressed: model.canRedo ? pad.redo : null,
              child: const Icon(Icons.redo, size: 20),
            ),
            _ToolButton(
              tooltip: 'Clear',
              selected: false,
              onPressed: model.isEmpty ? null : _confirmClear,
              child: const Icon(Icons.delete_outline, size: 20),
            ),
            _ToolButton(
              tooltip: _seeThrough ? 'Draw' : 'See through',
              selected: _seeThrough,
              onPressed: () => setState(() => _seeThrough = !_seeThrough),
              child: Icon(
                _seeThrough
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
            ),
            _ToolButton(
              tooltip: 'Close scratchpad',
              selected: false,
              onPressed: widget.close,
              child: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: context.palette.textPrimary,
      disabledColor: context.palette.border,
      style: IconButton.styleFrom(
        backgroundColor: selected ? context.palette.track : null,
        side: selected ? const BorderSide(color: AppColors.primary) : null,
      ),
      icon: child,
    );
  }
}

class _ScratchPainter extends CustomPainter {
  _ScratchPainter({
    required this.strokes,
    required this.hidden,
    required this.live,
    required this.liveColor,
    required this.liveWidth,
    required this.eraser,
    required this.scrim,
  });

  final List<ScratchStroke> strokes;

  /// Strokes the eraser in progress is over: left out so the student sees
  /// what lifting the eraser will remove.
  final Set<int> hidden;
  final List<Offset> live;
  final Color liveColor;
  final double liveWidth;
  final Offset? eraser;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim);
    for (var i = 0; i < strokes.length; i++) {
      if (hidden.contains(i)) continue;
      final s = strokes[i];
      _stroke(canvas, s.points, s.color, s.width);
    }
    if (live.isNotEmpty) _stroke(canvas, live, liveColor, liveWidth);
    final e = eraser;
    if (e != null) {
      canvas.drawCircle(
        e,
        scratchpadEraserRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.textSecondaryDark,
      );
    }
  }

  /// Quadratic smoothing: each input point becomes a control point and the
  /// curve passes through the midpoints between them, so a jagged run of
  /// pointer samples draws as one smooth line.
  static void _stroke(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double width,
  ) {
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, width / 2, Paint()..color = color);
      return;
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ScratchPainter old) =>
      old.strokes != strokes ||
      old.live != live ||
      old.hidden.length != hidden.length ||
      old.eraser != eraser ||
      old.scrim != scrim ||
      old.liveColor != liveColor ||
      old.liveWidth != liveWidth;
}
