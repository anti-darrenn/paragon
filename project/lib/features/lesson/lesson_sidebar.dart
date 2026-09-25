import 'package:flutter/material.dart';

import '../../core/models/learn_resource.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'video_pane.dart';

/// The topic's lesson sequence: what the student is on, what is done,
/// what comes next. The wide layout's left column; the compact layout
/// shows the same list in a bottom sheet.
class LessonSequenceList extends StatelessWidget {
  const LessonSequenceList({
    super.key,
    required this.resources,
    required this.currentId,
    required this.completed,
    required this.onOpen,
  });

  final List<LearnResource> resources;
  final String currentId;
  final Set<String> completed;
  final ValueChanged<LearnResource> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in resources)
          _Row(
            resource: r,
            isCurrent: r.id == currentId,
            isDone: completed.contains(r.id),
            onTap: r.isAvailable && r.id != currentId ? () => onOpen(r) : null,
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.resource,
    required this.isCurrent,
    required this.isDone,
    required this.onTap,
  });

  final LearnResource resource;
  final bool isCurrent;
  final bool isDone;
  final VoidCallback? onTap;

  IconData get _icon => switch (resource.type) {
    LearnResourceType.video => Icons.play_circle_outline_rounded,
    LearnResourceType.article => Icons.article_outlined,
    _ => Icons.edit_note_rounded,
  };

  String get _meta {
    final r = resource;
    if (!r.isAvailable) return 'Not available yet';
    return switch (r.type) {
      LearnResourceType.video when (r.durationSeconds ?? 0) > 0 =>
        'Video · ${formatDuration(r.durationSeconds!)}',
      LearnResourceType.exercise => 'Exercise',
      _ => r.type.label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final muted = !resource.isAvailable;
    final fg = muted ? AppColors.textSecondaryDark : AppColors.textPrimaryDark;

    return Semantics(
      selected: isCurrent,
      label: '${resource.title}, $_meta${isDone ? ', completed' : ''}',
      excludeSemantics: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withAlpha(26)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isCurrent ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : _icon,
                size: 20,
                color: isDone
                    ? AppColors.correct
                    : muted
                    ? AppColors.borderDark
                    : AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMd.copyWith(
                        color: fg,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _meta,
                      style: AppTheme.caption.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
