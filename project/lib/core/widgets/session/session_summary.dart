import 'package:flutter/material.dart';

import '../../sound/sfx.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../motion/confetti.dart';
import '../motion/score_ring.dart';

/// The end of a session: the score as a ring that fills, a title, what
/// changed, and what to do next.
///
/// [celebrate] adds confetti and the celebration sound — only for a
/// result worth it (80% or more, a test passed, a level up; see
/// [isWorthCelebrating]). Confetti on 2 out of 10 would read as mockery.
/// Every finish plays the gentler finish sound unless [sound] is false
/// (results of a test marked at the end still get one; the WAEC exam
/// never uses this widget's sound).
///
/// Not scrollable itself: put it in a scroll view (or a lesson's).
class SessionSummary extends StatefulWidget {
  const SessionSummary({
    super.key,
    required this.title,
    required this.correct,
    required this.total,
    this.scoreLabel,
    this.subtitle,
    this.details = const [],
    required this.primary,
    this.secondary,
    this.tertiary,
    this.celebrate = false,
    this.sound = true,
  });

  final String title;
  final int correct;
  final int total;

  /// In the ring; "$correct / $total" when not given.
  final String? scoreLabel;

  /// Under the title: "100% correct · 1 with hints".
  final String? subtitle;

  /// Between the score and the buttons: the mastery change, notices.
  final List<Widget> details;

  final Widget primary;
  final Widget? secondary;
  final Widget? tertiary;
  final bool celebrate;
  final bool sound;

  /// The rule for confetti: a high score, or something gained.
  static bool isWorthCelebrating({
    required int correct,
    required int total,
    bool passed = false,
    bool levelledUp = false,
  }) => passed || levelledUp || (total > 0 && correct * 100 >= total * 80);

  @override
  State<SessionSummary> createState() => _SessionSummaryState();
}

class _SessionSummaryState extends State<SessionSummary> {
  @override
  void initState() {
    super.initState();
    if (widget.sound) {
      Sfx.play(widget.celebrate ? SfxCue.celebrate : SfxCue.finish);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final w = widget;
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ScoreRing(
                fraction: w.total == 0 ? 0 : w.correct / w.total,
                label: w.scoreLabel ?? '${w.correct} / ${w.total}',
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                w.title,
                textAlign: TextAlign.center,
                style: AppTheme.heading2.copyWith(color: p.textStrong),
              ),
            ),
            if (w.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                w.subtitle!,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(color: p.textSecondary),
              ),
            ],
            if (w.details.isNotEmpty) ...[
              const SizedBox(height: 20),
              for (final c in w.details) ...[c, const SizedBox(height: 12)],
            ] else
              const SizedBox(height: 24),
            const SizedBox(height: 4),
            w.primary,
            if (w.secondary != null) ...[const SizedBox(height: 10), w.secondary!],
            if (w.tertiary != null) ...[const SizedBox(height: 6), w.tertiary!],
          ],
        ),
      ),
    );
    if (!w.celebrate) return body;
    return Stack(
      children: [
        body,
        const Positioned.fill(child: Confetti(pieces: 70)),
      ],
    );
  }
}
