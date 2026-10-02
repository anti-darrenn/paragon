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
import '../../core/widgets/ui/ui.dart';
import '../../core/widgets/user_avatar.dart';
import '../dashboard_screen.dart';
import '../onboarding/profile_form.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/nav/back_navigation.dart';

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

    final isStaff = ref.watch(staffRoleProvider).canWrite;
    final name = displayName.isEmpty
        ? (isGuest ? 'Guest' : 'Student')
        : displayName;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          // ── Identity ─────────────────────────────────────────────────
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const UserAvatar(size: 72),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTheme.heading2.copyWith(
                              color: context.palette.textStrong,
                            ),
                          ),
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: AppTheme.bodyMd.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          if (joined != null && !isGuest)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                joined,
                                style: AppTheme.caption.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    bio,
                    style: AppTheme.bodyLg.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isGuest)
                  const GuestNotice()
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/settings/name'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        bio.isEmpty
                            ? 'Edit profile · add a bio'
                            : 'Edit profile',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: kSectionGap),

          // ── Numbers ──────────────────────────────────────────────────
          // Counts of work done, never a score against anyone.
          const SectionHeader('Your practice'),
          _StatGrid(
            stats: [
              ('${progress.startedTopicCount}', 'Topics practised'),
              ('${progress.completedTopicCount}', 'At proficient'),
              ('${tests?.passedCount ?? 0}', 'Topic tests passed'),
              ('${lessons.completedCount}', 'Lessons finished'),
              (weekly == null ? '—' : '$weekly', 'Questions this week'),
            ],
          ),
          const SizedBox(height: kSectionGap),

          const YourSubjects(),

          if (!isGuest) ...[
            _AboutYou(profile: data?['profile']),
            const SizedBox(height: kSectionGap),
          ],

          // ── Shortcuts ────────────────────────────────────────────────
          // On a phone this tab is the way to everything the wide top
          // bar's avatar menu holds.
          const SectionHeader('Shortcuts'),
          RowGroup(
            children: [
              ListRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Account, subjects, privacy',
                onTap: () => context.push('/settings'),
              ),
              ListRow(
                icon: Icons.bookmark_outline_rounded,
                iconColor: AppColors.accentBlue,
                title: 'Saved',
                subtitle: 'Bookmarks and notes',
                onTap: () => context.push('/saved'),
              ),
              ListRow(
                icon: Icons.text_fields_rounded,
                title: 'Reading & display',
                subtitle: 'Text size, font, low-data mode',
                onTap: () => context.push('/settings/reading'),
              ),
              if (isStaff)
                ListRow(
                  icon: Icons.edit_note_rounded,
                  iconColor: AppColors.secondary,
                  title: 'Content studio',
                  subtitle: 'Write and review lessons',
                  onTap: () => context.push('/admin'),
                ),
              ListRow(
                icon: Icons.info_outline_rounded,
                title: 'About Paragon',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
        ],
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
        SectionHeader(
          'About you',
          subtitle: 'Optional. Only you can see it.',
          action: TextButton(
            onPressed: () => context.push('/settings/profile'),
            child: Text(rows.isEmpty ? 'Add' : 'Edit'),
          ),
        ),
        if (rows.isEmpty)
          SurfaceCard(
            child: Text(
              'Nothing added yet.',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          )
        else
          RowGroup(
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppTheme.bodyMd.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        value,
                        style: AppTheme.bodyMd.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The practice counts as an even grid: as many columns as fit, every
/// tile the same width, so a row never ends ragged.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final columns = box.maxWidth >= 600 ? 5 : (box.maxWidth >= 380 ? 3 : 2);
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (value, label) in stats)
              SizedBox(
                width: width,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: AppTheme.heading1.copyWith(
                          color: context.palette.textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 2,
                        style: AppTheme.caption.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
