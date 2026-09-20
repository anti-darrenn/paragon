import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/repositories/course_repository.dart';
import '../core/repositories/user_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/subject_tile.dart';

/// Change the subjects you study — `/settings/subjects`.
///
/// This screen exists because the app already promised it. The onboarding
/// step says "You can change these any time", and until now there was no
/// way to: nothing linked to a subject editor, and the router actively
/// bounced `/onboarding/subjects` back to `/` once onboarding was
/// complete, so even a deep link could not reach the original picker.
///
/// It is a separate screen rather than a reopened onboarding step on
/// purpose. The funnel's job is to get a new student to the app, and
/// re-entering it to change one answer would mean either sending them
/// through the remaining steps again or adding an exit that only exists
/// for returning users. A settings screen is what this is.
///
/// The minimum of one subject is kept, for the same reason onboarding has
/// it: an empty list is indistinguishable from "never answered" to
/// `selectedSubjectSlugsProvider`, whose contract is that empty means "no
/// preference expressed — show everything". A student who deselected
/// everything would silently get the no-preference experience rather than
/// the empty one they asked for, so the UI does not let them.
class SubjectsSettingsScreen extends ConsumerStatefulWidget {
  const SubjectsSettingsScreen({super.key});

  @override
  ConsumerState<SubjectsSettingsScreen> createState() =>
      _SubjectsSettingsScreenState();
}

class _SubjectsSettingsScreenState
    extends ConsumerState<SubjectsSettingsScreen> {
  static const _minSubjects = 1;

  /// Null until the stored selection has arrived. Seeding this from an
  /// empty set instead would mean a student who opened the page before the
  /// document loaded, and saved, would wipe their own choices.
  Set<String>? _selected;

  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(selectedSubjectSlugsProvider);
    final catalogAsync = ref.watch(courseCatalogProvider);
    final selected = _selected ??= {...stored};

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Your subjects')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Couldn't load subjects. Check your connection and try "
                  'again.',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              data: (courses) => _Body(
                courses: courses.where((c) => c.isLive).toList(),
                selected: selected,
                error: _error,
                isSaving: _isSaving,
                onToggle: (slug) => setState(() {
                  _error = null;
                  if (!selected.remove(slug)) selected.add(slug);
                }),
                onSave: selected.length >= _minSubjects ? _save : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    final selected = _selected;
    if (user == null || selected == null || selected.length < _minSubjects) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .setSelectedSubjects(
            uid: user.uid,
            // Sorted, matching what onboarding writes, so the stored value
            // does not depend on the order a student happened to tap.
            subjectKeys: selected.toList()..sort(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subjects updated.')));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save that. Please try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.courses,
    required this.selected,
    required this.error,
    required this.isSaving,
    required this.onToggle,
    required this.onSave,
  });

  final List<CourseSummary> courses;
  final Set<String> selected;
  final String? error;
  final bool isSaving;
  final void Function(String slug) onToggle;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(
                'These decide what appears under "Your Subjects" on your '
                'dashboard, and which courses are listed first.',
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 20),
              for (final course in courses) ...[
                SubjectTile(
                  course: course,
                  isSelected: selected.contains(course.slug),
                  onTap: () => onToggle(course.slug),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              Text(
                selected.isEmpty
                    ? 'Keep at least $_minSubjectsLabel.'
                    : '${selected.length} selected.',
                style: AppTheme.caption.copyWith(
                  color: selected.isEmpty
                      ? AppColors.warning
                      : AppColors.textSecondaryDark,
                ),
              ),
              // Changing subjects does not touch practice history, and a
              // student deselecting one might reasonably fear it does.
              const SizedBox(height: 10),
              Text(
                'Your progress is kept either way — removing a subject only '
                'hides it from your dashboard.',
                style: AppTheme.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error!,
              style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: AppTheme.btnLabel.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

const String _minSubjectsLabel = 'one subject';
