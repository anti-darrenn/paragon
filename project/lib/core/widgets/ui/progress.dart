import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/tokens.dart';

/// A rounded progress bar that eases to its new value instead of jumping.
/// [value] is 0 to 1; null runs an indeterminate bar.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.semanticsLabel,
  });

  final double? value;
  final double height;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colour = color ?? AppColors.primary;
    final track = context.palette.track;
    Widget bar(double? v) => ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: LinearProgressIndicator(
        value: v,
        minHeight: height,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation(colour),
        semanticsLabel: semanticsLabel,
      ),
    );
    if (value == null) return bar(null);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value!.clamp(0.0, 1.0)),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.curve,
      builder: (context, v, _) => bar(v),
    );
  }
}

/// The state of one step in a [SegmentedProgress].
enum SegmentState {
  /// Not reached yet.
  pending,

  /// Answered, verdict not shown (a test marked at the end).
  answered,

  /// Answered and right.
  right,

  /// Answered and wrong.
  wrong,
}

/// A row of segments, one per question: what a session has covered at a
/// glance, and — where feedback is instant — how it went. The [current]
/// segment is lit. Past 30 segments it becomes a plain bar, because
/// slivers that thin say nothing.
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    super.key,
    required this.states,
    this.current,
    this.height = 6,
    this.semanticsLabel,
  });

  final List<SegmentState> states;
  final int? current;
  final double height;
  final String? semanticsLabel;

  static const maxSegments = 30;

  @override
  Widget build(BuildContext context) {
    final done = states.where((s) => s != SegmentState.pending).length;
    if (states.isEmpty) return SizedBox(height: height);
    if (states.length > maxSegments) {
      return AppProgressBar(
        value: done / states.length,
        height: height,
        semanticsLabel: semanticsLabel,
      );
    }
    final p = context.palette;
    final duration = Motion.of(context, Motion.medium);
    return Semantics(
      label: semanticsLabel ?? '$done of ${states.length} done',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < states.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: duration,
                  curve: Motion.curve,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    color: switch (states[i]) {
                      SegmentState.right => AppColors.correct,
                      SegmentState.wrong => AppColors.wrong,
                      SegmentState.answered => AppColors.primary,
                      SegmentState.pending =>
                        i == current
                            ? AppColors.primary.withAlpha(110)
                            : p.track,
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
