import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/a11y/speech_text.dart';
import '../../core/rooms/room.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/math_text.dart';

export '../../core/theme/tokens.dart' show reduceMotion;
export '../../core/widgets/motion/confetti.dart';

/// The look of a live quiz (2026-10-17): coloured shapes for the options,
/// a countdown ring, a leaderboard that moves, a podium with confetti.
/// Every animation stops when the device asks for reduced motion
/// ([reduceMotion] and [Confetti] live in core and are re-exported here).

/// Confetti in the option tiles' colours.
final kRoomConfettiColours = [for (final s in roomShapes) s.color];

/// One shape and colour per option, A to E.
const roomShapes = <({IconData icon, Color color, String name})>[
  (icon: Icons.change_history_rounded, color: AppColors.roomRed, name: 'triangle'),
  (icon: Icons.diamond_rounded, color: AppColors.roomBlue, name: 'diamond'),
  (icon: Icons.circle, color: AppColors.roomYellow, name: 'circle'),
  (icon: Icons.square_rounded, color: AppColors.roomGreen, name: 'square'),
  (icon: Icons.star_rounded, color: AppColors.roomPurple, name: 'star'),
];

const _letters = 'ABCDE';

enum TileState { idle, selected, correct, wrong, faded }

/// An answer as a coloured tile with its shape, letter and text. Heard as
/// one node, like every answer option ("Option B, blue diamond: 4,
/// selected"), with its own tap action.
class ShapeTile extends StatelessWidget {
  const ShapeTile({
    super.key,
    required this.index,
    required this.text,
    this.state = TileState.idle,
    this.onTap,
    this.count,
    this.countMax = 1,
  });

  final int index;
  final String text;
  final TileState state;
  final VoidCallback? onTap;

  /// At the reveal, how many chose it (a bar fills behind the text).
  final int? count;
  final int countMax;

  @override
  Widget build(BuildContext context) {
    final shape = roomShapes[index % roomShapes.length];
    final dim = state == TileState.faded || state == TileState.wrong;
    final verdict = switch (state) {
      TileState.selected => ', selected',
      TileState.correct => ', correct',
      TileState.wrong => ', incorrect',
      _ => '',
    };
    final base = dim ? shape.color.withAlpha(90) : shape.color;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: state == TileState.selected,
      inMutuallyExclusiveGroup: true,
      label:
          'Option ${_letters[index % 5]}, ${shape.name}: ${speakText(text)}'
          '$verdict${count == null ? '' : ', $count chose it'}',
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: state == TileState.selected ? 1.03 : 1,
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        child: Material(
          color: base,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                if (count != null)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: countMax == 0
                          ? 0
                          : (count! / countMax).clamp(0.0, 1.0),
                      child: ColoredBox(color: Colors.white.withAlpha(40)),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: state == TileState.selected ||
                            state == TileState.correct
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(shape.icon, color: Colors.white, size: 26),
                      const SizedBox(width: 6),
                      Text(
                        _letters[index % 5],
                        style: AppTheme.bodyLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MathText(
                          text: text,
                          useLightRenderer: true,
                          style: AppTheme.bodyLg.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (count != null)
                        Text(
                          '$count',
                          style: AppTheme.heading3.copyWith(color: Colors.white),
                        ),
                      if (state == TileState.correct)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The options as a grid of tiles: two columns when there is room.
class ShapeGrid extends StatelessWidget {
  const ShapeGrid({super.key, required this.count, required this.tile});
  final int count;
  final Widget Function(int index) tile;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final two = box.maxWidth >= 560;
      if (!two) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: tile(i)),
          ],
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(width: (box.maxWidth - 12) / 2, child: tile(i)),
        ],
      );
    },
  );
}

/// Seconds left of a timed question, as a ring that empties. Counts from
/// [startedAt] (the server's stamp, read on this device); [onDone] fires
/// once at zero.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.startedAt,
    required this.seconds,
    this.size = 84,
    this.onDone,
  });

  final DateTime startedAt;
  final int seconds;
  final double size;
  final VoidCallback? onDone;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted) return;
      setState(() {});
      if (!_fired && _left <= Duration.zero) {
        _fired = true;
        widget.onDone?.call();
      }
    })..start();
  }

  @override
  void didUpdateWidget(CountdownRing old) {
    super.didUpdateWidget(old);
    if (old.startedAt != widget.startedAt) _fired = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Duration get _left {
    final end = widget.startedAt.add(Duration(seconds: widget.seconds));
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final f = widget.seconds == 0
        ? 0.0
        : (left.inMilliseconds / (widget.seconds * 1000)).clamp(0.0, 1.0);
    final secs = (left.inMilliseconds / 1000).ceil();
    final colour = f > 0.5
        ? AppColors.correct
        : f > 0.2
        ? AppColors.warning
        : AppColors.wrong;
    return Semantics(
      label: '$secs seconds left',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: f,
            colour: colour,
            track: context.palette.track,
          ),
          child: Center(
            child: Text(
              '$secs',
              style: AppTheme.heading2.copyWith(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.colour, required this.track});
  final double fraction;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(stroke / 2), 0, 2 * pi, false, paint..color = track);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -pi / 2,
      2 * pi * fraction,
      false,
      paint..color = colour,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.colour != colour;
}

/// The top of the scores between questions: bars that grow to each
/// player's total, with the points just earned.
class Leaderboard extends StatelessWidget {
  const Leaderboard({
    super.key,
    required this.scores,
    required this.names,
    this.before = const {},
    this.limit = 5,
    this.highlight,
  });

  final Map<String, int> scores;
  final Map<String, int> before;
  final Map<String, String> names;
  final int limit;

  /// This phone's player, shown even when outside the top [limit].
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = standings(scores);
    final top = rows.take(limit).toList();
    final mine = rows.where((r) => r.uid == highlight).firstOrNull;
    if (mine != null && !top.contains(mine)) top.add(mine);
    final best = rows.isEmpty ? 1 : max(1, rows.first.score);
    final still = reduceMotion(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${r.place}',
                    style: AppTheme.bodyLg.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: r.score / best),
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
                          widthFactor: v.clamp(0.04, 1.0),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: (r.uid == highlight
                                      ? AppColors.primary
                                      : AppColors.accentBlue)
                                  .withAlpha(r.uid == highlight ? 200 : 140),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  names[r.uid] ?? 'Player',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.bodyMd.copyWith(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if ((r.score - (before[r.uid] ?? 0)) > 0)
                                Text(
                                  '+${r.score - (before[r.uid] ?? 0)}  ',
                                  style: AppTheme.caption.copyWith(
                                    color: context.palette.successFg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                '${r.score}',
                                style: AppTheme.bodyLg.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The first three on steps that rise, with confetti behind.
class PodiumSteps extends StatelessWidget {
  const PodiumSteps({super.key, required this.scores, required this.names, required this.avatar});

  final Map<String, int> scores;
  final Map<String, String> names;
  final Widget Function(String uid, double size) avatar;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = standings(scores).take(3).toList();
    final still = reduceMotion(context);
    // Second, first, third, as a podium stands.
    final order = [
      if (rows.length > 1) (rows[1], 110.0, 1),
      if (rows.isNotEmpty) (rows[0], 150.0, 0),
      if (rows.length > 2) (rows[2], 80.0, 2),
    ];
    const medals = [
      AppColors.medalGold,
      AppColors.medalSilver,
      AppColors.medalBronze,
    ];
    return SizedBox(
      height: 290,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (r, height, rank) in order)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  avatar(r.uid, rank == 0 ? 64 : 48),
                  const SizedBox(height: 6),
                  Text(
                    names[r.uid] ?? 'Player',
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMd.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${r.score}',
                    style: AppTheme.caption.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: still ? height : 0, end: height),
                    duration: Duration(milliseconds: still ? 0 : 600 + rank * 300),
                    curve: Curves.easeOutBack,
                    builder: (context, h, _) => Container(
                      height: h.clamp(0, height),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: medals[rank],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${rank + 1}',
                        style: AppTheme.heading2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "3, 2, 1" before the first question; then [onDone]. With reduced motion
/// it is a single "Get ready" for a second.
class GetReady extends StatefulWidget {
  const GetReady({super.key, required this.onDone, this.title});
  final VoidCallback onDone;
  final String? title;

  @override
  State<GetReady> createState() => _GetReadyState();
}

class _GetReadyState extends State<GetReady> {
  int _n = 3;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted && _n > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _n--);
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null)
            Text(
              widget.title!,
              textAlign: TextAlign.center,
              style: AppTheme.heading2.copyWith(color: context.palette.textPrimary),
            ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 350),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Text(
              still ? 'Get ready' : (_n > 0 ? '$_n' : 'Go!'),
              key: ValueKey(_n),
              style: AppTheme.heading1.copyWith(
                fontSize: still ? 48 : 120,
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
