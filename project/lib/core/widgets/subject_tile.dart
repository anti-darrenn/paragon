import 'package:flutter/material.dart';

import '../repositories/course_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_palette.dart';
import '../theme/tokens.dart';
import 'ui/illustration.dart';

/// A selectable subject row — the subject's motif, its name and blurb, and
/// a tick box — used wherever a student chooses which subjects they study.
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
    final p = context.palette;
    final radius = BorderRadius.circular(Radii.md);

    // A real control: focusable, a ripple, and read as a checkbox with its
    // state. It was a bare GestureDetector a keyboard could not reach.
    return Semantics(
      checked: isSelected,
      label: course.name,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isSelected
            ? Color.alphaBlend(accent.withAlpha(36), p.surface)
            : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isSelected ? accent : p.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            child: Row(
              children: [
                Illustration(
                  IllustrationAsset.forSubject(course.name),
                  height: 40,
                  accent: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: AppTheme.bodyLg.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course.blurb,
                        style: AppTheme.label.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accent : p.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
