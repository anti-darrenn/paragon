import 'package:flutter/material.dart';

import '../repositories/course_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_palette.dart';

/// A selectable subject row with a checkbox, used wherever a student
/// chooses which subjects they study.
///
/// Extracted from the onboarding step so that the settings editor shows
/// the *same* control. Two separate pickers would be two places to change
/// the accent, the checkbox, or what a selected row looks like — and the
/// settings one exists precisely because onboarding promises the choice
/// can be revisited.
class SubjectTile extends StatelessWidget {
  const SubjectTile({
    super.key,
    required this.course,
    required this.isSelected,
    required this.onTap,
  });

  final CourseSummary course;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.forSubject(course.name);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withAlpha((0.14 * 255).round())
                : context.palette.surface,
            border: Border.all(
              color: isSelected ? accent : context.palette.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? accent : context.palette.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: AppTheme.bodyLg.copyWith(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.blurb,
                      style: AppTheme.caption.copyWith(
                        color: context.palette.textSecondary,
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
