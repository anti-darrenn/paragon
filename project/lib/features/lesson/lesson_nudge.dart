import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/learn/lesson_progress.dart';
import '../../core/repositories/learn_progress_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'lesson_screen.dart';
import '../../core/theme/app_palette.dart';

/// "You've done 3 of 6 lesson items" above the topic test — a nudge, never
/// a gate. The test stays open regardless: WAEC revision often starts by
/// testing, and a strong student should not be made to sit through a
/// lesson they don't need (decided 2026-09-26).
///
/// Shows nothing when the topic has no lesson, when every item is done, or
/// while either is loading.
class LessonNudge extends ConsumerStatefulWidget {
  const LessonNudge({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<LessonNudge> createState() => _LessonNudgeState();
}

class _LessonNudgeState extends ConsumerState<LessonNudge> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final resources = ref
        .watch(topicResourcesProvider(widget.topicId))
        .asData
        ?.value;
    if (resources == null) return const SizedBox.shrink();
    final completed = ref
        .watch(lessonProgressProvider)
        .forTopic(widget.topicId)
        .completed;
    final total = availableCount(resources);
    final done = completedCount(resources, completed);
    final next = continueTarget(resources, completed);
    if (total == 0 || done >= total || next == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withAlpha(28),
        border: Border.all(color: AppColors.accentBlue.withAlpha(120)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 18,
            color: AppColors.accentBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              done == 0
                  ? "You haven't started this topic's lesson. You can take the test anyway."
                  : "You've done $done of $total lesson items. You can take the test anyway.",
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go(lessonPath(next.topicId, next.id)),
            child: Text(done == 0 ? 'Start lesson' : 'Continue lesson'),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}
