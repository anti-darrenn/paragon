import 'package:flutter/material.dart';

import '../questions/difficulty.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'question_source_badge.dart' show DifficultyBadge;

/// "How hard was this?" under a marked practice question: a small link
/// that opens the five tiers. Optional and out of the way; tapping a tier
/// records it for the session (sent once, when the session ends).
///
/// Never shown in the topic test or the WAEC exam.
class DifficultyRating extends StatefulWidget {
  const DifficultyRating({
    super.key,
    required this.selected,
    required this.onRate,
  });

  /// The level already chosen for this question, if any.
  final int? selected;
  final ValueChanged<int> onRate;

  @override
  State<DifficultyRating> createState() => _DifficultyRatingState();
}

class _DifficultyRatingState extends State<DifficultyRating> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chosen = DifficultyTier.fromLevel(widget.selected);
    if (!_open) {
      // Just the button: it sits in a row of small actions (report,
      // bookmark), and an Align here would take the whole line.
      return TextButton.icon(
        onPressed: () => setState(() => _open = true),
        icon: Icon(
          chosen == null ? Icons.speed_rounded : Icons.check_rounded,
          size: 18,
        ),
        label: Text(
          chosen == null ? 'How hard was this?' : 'You said: ${chosen.label}',
        ),
      );
    }
    return Semantics(
      container: true,
      label: 'How hard was this question?',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How hard was this? It helps us label questions honestly.',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in DifficultyTier.values)
                  ChoiceChip(
                    selected: widget.selected == t.level,
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: DifficultyBadge.colourOf(t),
                    ),
                    label: Text(t.label),
                    onSelected: (_) {
                      widget.onRate(t.level);
                      setState(() => _open = false);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
