import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/repositories/course_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_top_nav.dart';
import '../core/theme/app_palette.dart';

/// Course catalog — `/courses`.
///
/// The entry point to every course index page. It lists all ten subjects
/// from `SubjectCatalog`, not just the three that are seeded, because the
/// unseeded ones have no Firestore document and would otherwise be
/// unreachable. Each card is tinted with that subject's colour from
/// `AppColors.forSubject`, which is the same accent its course page uses.
///
/// `/` (SubjectListScreen) is untouched and still lists the live subjects.
class CourseCatalogScreen extends ConsumerWidget {
  const CourseCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(courseCatalogProvider);
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;

    return ParagonPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isCompact ? 24 : 40),
          Text(
            'Courses',
            style: AppTheme.displayLg.copyWith(
              color: context.palette.textPrimary,
              fontSize: isCompact ? 28 : 40,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Every WAEC subject Paragon covers. Pick one to see its modules '
            'and topics.',
            style: AppTheme.bodyLg.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          SizedBox(height: isCompact ? 28 : 40),

          catalogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  "Courses couldn't be loaded. Check your connection and try "
                  'again.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            ),
            data: (courses) => _CourseGrid(
              courses: courses,
              selected: ref.watch(selectedSubjectSlugsProvider),
            ),
          ),

          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.courses, required this.selected});

  final List<CourseSummary> courses;

  /// Catalog slugs the student chose during onboarding. Until this
  /// existed, onboarding asked which subjects they study and then ignored
  /// the answer entirely — the field had no reader anywhere in the app.
  final Set<String> selected;

  static const double _gap = 20;

  int _columnsFor(double width) {
    if (width < 560) return 1;
    if (width < 900) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;

        // Their subjects first, each order otherwise preserved, so the
        // page opens on what they actually study without hiding anything.
        final mine = courses.where((c) => selected.contains(c.slug)).toList();
        final rest = courses.where((c) => !selected.contains(c.slug)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mine.isNotEmpty) ...[
              _GroupLabel('YOUR SUBJECTS'),
              const SizedBox(height: 12),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final course in mine)
                    SizedBox(
                      width: cardWidth,
                      child: _CourseCard(course: course),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              _GroupLabel('EVERYTHING ELSE'),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final course in rest)
                  SizedBox(
                    width: cardWidth,
                    child: _CourseCard(course: course),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CourseCard extends StatefulWidget {
  const _CourseCard({required this.course});

  final CourseSummary course;

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final accent = AppColors.forSubject(course.name);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.push('/subject/${course.key}/course'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: accent.withAlpha(
              ((_isHovered ? 0.18 : 0.10) * 255).round(),
            ),
            border: Border.all(
              color: accent.withAlpha(((_isHovered ? 0.7 : 0.35) * 255).round()),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  if (!course.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(
                          (0.14 * 255).round(),
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Coming soon',
                        style: AppTheme.caption.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                course.name,
                style: AppTheme.heading2.copyWith(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                course.blurb,
                style: AppTheme.bodyMd.copyWith(
                  color: context.palette.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    course.moduleCount == 0
                        ? 'Outline in progress'
                        : '${course.moduleCount} '
                              '${course.moduleCount == 1 ? 'module' : 'modules'}'
                              '${course.isLive ? '' : ' planned'}',
                    style: AppTheme.label.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 140),
                    offset: Offset(_isHovered ? 0.18 : 0, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.caption.copyWith(
        color: context.palette.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
