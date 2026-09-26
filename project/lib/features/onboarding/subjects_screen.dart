import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/subject_tile.dart';
import 'onboarding_scaffold.dart';
import '../../core/theme/app_palette.dart';

/// Step 3 — pick the subjects you're studying.
///
/// Reads `courseCatalogProvider` rather than the `config/app` feature flag
/// the spec calls for. Which subjects are selectable is already derived
/// from whether a subject is seeded in Firestore, so a separate flag would
/// be a second source of truth to keep in sync — and a wrong one the first
/// time somebody forgot to flip it.
///
/// Selections are stored by catalog **slug**, not by Firestore document
/// id, so they survive a subject being reseeded.
///
/// The spec's three-subject minimum is relaxed to one: exactly three
/// subjects are live today, so a minimum of three would force everyone to
/// select all of them and the field would carry no signal at all. Tighten
/// [_minSubjects] once more content ships.
class OnboardingSubjectsScreen extends ConsumerStatefulWidget {
  const OnboardingSubjectsScreen({super.key});

  @override
  ConsumerState<OnboardingSubjectsScreen> createState() =>
      _OnboardingSubjectsScreenState();
}

class _OnboardingSubjectsScreenState
    extends ConsumerState<OnboardingSubjectsScreen> {
  static const _minSubjects = 1;

  final Set<String> _selected = {};
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _selected.length < _minSubjects) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .setSelectedSubjects(
            uid: user.uid,
            subjectKeys: _selected.toList()..sort(),
          );
      if (!mounted) return;
      // The gating steps are done here, so this is the funnel's
      // real completion point — step 4 is optional.
      ref.read(analyticsProvider).onboardingStepCompleted('subjects');
      ref
          .read(analyticsProvider)
          .onboardingCompleted(subjectCount: _selected.length);
      context.go(OnboardingStep.subjects.next.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save your subjects. Please try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(courseCatalogProvider);

    return OnboardingScaffold(
      step: OnboardingStep.subjects,
      title: 'What are you studying?',
      subtitle:
          'Pick the subjects you want to practise. You can change these '
          'any time.',
      errorText: _error,
      isLoading: _isSubmitting,
      primaryLabel: 'Continue',
      onPrimary: _selected.length >= _minSubjects ? _submit : null,
      child: catalogAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Text(
          "Couldn't load subjects. Check your connection and try again.",
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        data: (courses) {
          final live = courses.where((c) => c.isLive).toList();
          final planned = courses.where((c) => !c.isLive).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final course in live) ...[
                SubjectTile(
                  course: course,
                  isSelected: _selected.contains(course.slug),
                  onTap: () => setState(() {
                    _error = null;
                    if (!_selected.remove(course.slug)) {
                      _selected.add(course.slug);
                    }
                  }),
                ),
                const SizedBox(height: 10),
              ],

              if (planned.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'COMING SOON',
                  style: AppTheme.caption.copyWith(
                    color: context.palette.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                // Named but not selectable, so a student can see their
                // subject is planned rather than assume it's unsupported.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final course in planned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          border: Border.all(color: context.palette.border),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          course.name,
                          style: AppTheme.caption.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              Text(
                _selected.isEmpty
                    ? 'Select at least $_minSubjects to continue.'
                    : '${_selected.length} selected.',
                style: AppTheme.caption.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
