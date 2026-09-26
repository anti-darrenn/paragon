import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learn_resource.dart';
import '../providers/auth_provider.dart';
import '../repositories/flag_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_palette.dart';

/// "Report a problem" for a lesson item: an article or a video.
///
/// The question bank has [ReportProblemButton]; lessons are written by
/// people and will have mistakes too, and students finding them is how
/// they get fixed. Reports land in the reviewers' lesson-report list and
/// the digest email.
class ReportLessonButton extends ConsumerStatefulWidget {
  const ReportLessonButton({super.key, required this.resource});

  final LearnResource resource;

  @override
  ConsumerState<ReportLessonButton> createState() => _ReportLessonButtonState();
}

class _ReportLessonButtonState extends ConsumerState<ReportLessonButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _open() async {
    final reason = await showModalBottomSheet<LessonReportReason>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                "What's wrong with this lesson?",
                style: AppTheme.heading3.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Telling us is how lessons get fixed.',
                style: AppTheme.caption.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            for (final r in LessonReportReason.values)
              if (r != LessonReportReason.video ||
                  widget.resource.type == LearnResourceType.video)
                ListTile(
                  title: Text(
                    r.label,
                    style: AppTheme.bodyMd.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.of(sheet).pop(r),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(flagRepositoryProvider)
          .createLessonReport(
            userId: user.uid,
            topicId: widget.resource.topicId,
            resourceId: widget.resource.id,
            reason: reason,
          );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't send your report. Try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Thanks, we\'ll check it',
          style: AppTheme.caption.copyWith(color: AppColors.correct),
        ),
      );
    }
    return IconButton(
      tooltip: 'Report a problem with this lesson',
      onPressed: _sending ? null : _open,
      icon: Icon(
        Icons.flag_outlined,
        size: 18,
        color: context.palette.textSecondary,
      ),
    );
  }
}
