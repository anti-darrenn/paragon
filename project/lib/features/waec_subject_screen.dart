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
import '../core/models/subject.dart';
import '../core/widgets/load_error.dart';
import '../core/theme/app_palette.dart';
import '../core/widgets/nav/back_navigation.dart';

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
          maxWidth: 960,
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
                    for (final subject in subjects)
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
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Wrap(
        children: [
          for (var i = 0; i < steps.length; i++)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
              child: Padding(
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
              ),
            ),
        ],
      ),
    );
  }
}

class _WaecSubjectTile extends StatelessWidget {
  final Subject subject;
  final bool isGuest;
  const _WaecSubjectTile({required this.subject, required this.isGuest});

  // Spec §2.3.3 guest config restrictions: subject picker locked for
  // guests. This app's "subject picker" is this list (there's no in-setup
  // dropdown, since the subject is already chosen by the time setup
  // opens), so the lock lives here.
  //
  // The rule itself moved to `GuestLimits` once Learning Mode started
  // enforcing the same thing — two inline copies of a product rule drift,
  // and the drift reads as a guest who can drill Physics but not sit a
  // Physics exam.
  bool get _lockedForGuest =>
      GuestLimits.locks(isGuest: isGuest, subjectName: subject.name);

  @override
  Widget build(BuildContext context) {
    final locked = _lockedForGuest;
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
      onTap: locked
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(GuestLimits.lockedSubjectMessage)),
            )
          : () => context.push('/waec/${subject.id}/setup'),
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
                  locked ? 'Make an account to unlock' : 'Past papers',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: context.palette.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
