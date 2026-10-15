import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/page_layout.dart';
import '../core/widgets/ui/ui.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/learning_repository.dart';
import '../core/auth/guest_limits.dart';
import '../core/theme/app_colors.dart';
import '../core/content/question_counts.dart';
import '../core/models/subject.dart';
import '../core/content/subject_catalog.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/nav/back_navigation.dart';
import '../core/theory/theory_question.dart';

/// [subjects] in the order WAEC Prep lists them: papers that can be sat
/// first, then any a guest can't open, then those with no past questions
/// yet. Each group keeps the catalog order. Chemistry and Government were
/// listed first, both disabled (audit C6, 2026-10-15).
List<Subject> waecSubjectOrder(List<Subject> subjects, bool isGuest) {
  int rank(Subject s) {
    if (GuestLimits.locks(isGuest: isGuest, subjectName: s.name)) return 1;
    if (s.counts.isSplit && s.pastQuestionCount == 0) return 2;
    return 0;
  }

  final indexed = [for (var i = 0; i < subjects.length; i++) (i, subjects[i])];
  indexed.sort((a, b) {
    final byRank = rank(a.$2).compareTo(rank(b.$2));
    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });
  return [for (final (_, s) in indexed) s];
}

class WaecSubjectScreen extends ConsumerWidget {
  const WaecSubjectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: const ParagonAppBar(
        title: Text('WAEC Prep'),
        collapseWhenWide: true,
        actions: [SearchAction()],
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadError(
          error: e,
          onRetry: () => ref.invalidate(subjectsProvider),
        ),
        data: (subjects) => PageBody(
          maxWidth: kContentMaxWidth,
          children: [
            const PageIntro(
              title: 'WAEC Prep',
              subtitle:
                  'Sit a timed paper built from past WAEC questions. Like '
                  'the real exam, you see your results at the end.',
              wideOnly: true,
            ),
            const _HowItWorks(),
            const SizedBox(height: kSectionGap),
            const SectionHeader('Choose a subject'),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 720
                    ? 3
                    : (box.maxWidth >= 460 ? 2 : 1);
                const gap = 12.0;
                final width = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final subject in waecSubjectOrder(subjects, isGuest))
                      SizedBox(
                        width: width,
                        child: _WaecSubjectTile(
                          subject: subject,
                          isGuest: isGuest,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Three steps, so a student knows what they are starting before they
/// start it — and that there is no feedback until the end.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.tune_rounded, 'Set it up', 'Pick the years and how long.'),
      (Icons.timer_outlined, 'Sit the paper', 'Timed, with no answers shown.'),
      (
        Icons.fact_check_outlined,
        'Review',
        'Every answer marked, with an estimated grade.',
      ),
    ];
    Widget step(int i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(
                      icon: steps[i].$1,
                      color: AppColors.accentBlue,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${steps[i].$2}',
                            style: AppTheme.bodyMd.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            steps[i].$3,
                            style: AppTheme.label.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              
    );

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 640
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(child: step(i)),
                ],
              )
            : Column(
                children: [for (var i = 0; i < steps.length; i++) step(i)],
              ),
      ),
    );
  }
}

class _WaecSubjectTile extends StatelessWidget {
  final Subject subject;
  final bool isGuest;
  const _WaecSubjectTile({required this.subject, required this.isGuest});

  // Whether a guest may sit this subject is the policy table's call
  // (`canUse(Feature.waecUntimed)` via `GuestLimits.locks`) — all of them
  // since 2026-10-14.
  bool get _lockedForGuest =>
      GuestLimits.locks(isGuest: isGuest, subjectName: subject.name);

  // A subject with practice questions but no past ones (Chemistry and
  // Government, so far) has no paper to sit. Known only once
  // `jobs.js --job=counts` has split the subject's count; until then the
  // tile stays open, as it always was.
  bool get _noPastQuestions =>
      subject.counts.isSplit && subject.pastQuestionCount == 0;

  bool get _hasTheory => subject.theoryCount >= kTheoryMinQuestions;

  @override
  Widget build(BuildContext context) {
    final locked = _lockedForGuest;
    final empty = !locked && _noPastQuestions;
    final color = locked
        ? context.palette.textSecondary
        : AppColors.forSubject(subject.name);
    final initials = subject.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: empty
          ? null
          : locked
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(GuestLimits.lockedSubjectMessage)),
            )
          : () => context.push('/waec/${SubjectCatalog.slugify(subject.name)}/setup'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(34),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              initials,
              style: AppTheme.bodyMd.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: AppTheme.bodyMd.copyWith(
                    color: locked
                        ? context.palette.textSecondary
                        : context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                Text(
                  locked
                      ? 'Make an account to unlock'
                      : empty
                      ? 'No past questions yet'
                      : subject.pastQuestionCount > 0
                      ? 'Past papers · '
                            '${groupThousands(subject.pastQuestionCount)} '
                            'questions'
                      : 'Past papers',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                // Paper 2, once there is enough of it to practise.
                if (_hasTheory && !locked)
                  TextButton(
                    onPressed: () =>
                        context.push('/waec/${SubjectCatalog.slugify(subject.name)}/theory'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      'Theory practice · ${subject.theoryCount} questions',
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            locked
                ? Icons.lock_outline_rounded
                : empty
                ? Icons.hourglass_empty_rounded
                : Icons.chevron_right_rounded,
            color: context.palette.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
