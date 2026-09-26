import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/repositories/learn_progress_repository.dart';
import '../../core/repositories/progress_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_notice.dart';
import '../../core/widgets/user_avatar.dart';
import '../dashboard_screen.dart';
import '../onboarding/profile_form.dart';

/// Your own profile — `/me`.
///
/// **Private, and display-only.** Nobody else can open anyone's `/me`: it
/// reads `users/{uid}`, which only its owner can read. It reads
/// `progress/{uid}` too, which CLAUDE.md allows only because nothing here
/// is competitive or rewarding — these are the same counts the dashboard
/// shows, gathered in one place. Put a rank, a badge or anything earned on
/// this screen and that read becomes the bug.
///
/// **No new reads.** `users`, `progress` and `learn` are already streamed
/// for the dashboard, and the weekly total is one `count()`.
///
/// This is also the first screen that shows the optional `profile` map
/// back to the student who filled it in — until now it was collected and
/// read by nothing.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final data = ref.watch(userDataProvider).asData?.value;
    final progress =
        ref.watch(userProgressProvider).asData?.value ?? UserProgress.empty;
    final tests = ref.watch(topicTestProgressProvider).asData?.value;
    final lessons = ref.watch(lessonProgressProvider);
    final weekly = ref.watch(weeklyAttemptsCountProvider).asData?.value;

    final displayName = (data?['displayName'] as String?)?.trim() ?? '';
    final username = (data?['username'] as String?)?.trim() ?? '';
    final bio = (data?['bio'] as String?)?.trim() ?? '';
    final created = data?['createdAt'];
    final joined = created is Timestamp ? joinedLabel(created.toDate()) : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Identity ─────────────────────────────────────────
                    const Center(child: UserAvatar(size: 96)),
                    const SizedBox(height: 14),
                    Text(
                      displayName.isEmpty
                          ? (isGuest ? 'Guest' : 'Student')
                          : displayName,
                      textAlign: TextAlign.center,
                      style: AppTheme.heading2.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMd.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyLg.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ],
                    if (joined != null && !isGuest) ...[
                      const SizedBox(height: 8),
                      Text(
                        joined,
                        textAlign: TextAlign.center,
                        style: AppTheme.caption.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (isGuest)
                      const GuestNotice()
                    else
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/settings/name'),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(
                            bio.isEmpty ? 'Edit profile · add a bio' : 'Edit profile',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimaryDark,
                            side: const BorderSide(color: AppColors.borderDark),
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),

                    // ── Numbers ──────────────────────────────────────────
                    // Counts of work done, never a score against anyone.
                    _Section('Your practice'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Stat(
                          value: '${progress.startedTopicCount}',
                          label: 'Topics practised',
                        ),
                        _Stat(
                          value: '${progress.completedTopicCount}',
                          label: 'At proficient',
                        ),
                        _Stat(
                          value: '${tests?.passedCount ?? 0}',
                          label: 'Topic tests passed',
                        ),
                        _Stat(
                          value: '${lessons.completedCount}',
                          label: 'Lessons finished',
                        ),
                        _Stat(
                          value: weekly == null ? '—' : '$weekly',
                          label: 'Questions this week',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    const YourSubjects(),

                    if (!isGuest) ...[
                      const SizedBox(height: 28),
                      _AboutYou(profile: data?['profile']),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Joined September 2026". Month and year only: the day adds nothing and
/// is one more detail about a minor on screen.
String joinedLabel(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return 'Joined ${months[date.month - 1]} ${date.year}';
}

/// The optional profile, read back. Rows only for what was answered; the
/// labels come from the same form the student filled in.
class _AboutYou extends StatelessWidget {
  const _AboutYou({required this.profile});

  final Object? profile;

  @override
  Widget build(BuildContext context) {
    final form = ProfileFormController()..hydrate(profile);
    final values = form.toProfile();
    form.dispose();

    const labels = {
      'school': 'School',
      'classYear': 'Class',
      'age': 'Age',
      'gender': 'Gender',
      'country': 'Country',
      'state': 'State',
    };
    final rows = [
      for (final entry in labels.entries)
        if (values[entry.key] != null) (entry.value, '${values[entry.key]}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _Section('About you')),
            TextButton(
              onPressed: () => context.push('/settings/profile'),
              child: Text(
                rows.isEmpty ? 'Add' : 'Edit',
                style: AppTheme.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            border: Border.all(color: AppColors.borderDark),
            borderRadius: BorderRadius.circular(10),
          ),
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Nothing added. All of it is optional, and only you can '
                    'see it.',
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final (label, value) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: AppTheme.bodyMd.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ),
                            Text(
                              value,
                              style: AppTheme.bodyMd.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
