import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/analytics_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/repositories/account_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/user_avatar.dart';
import 'account/account_help.dart';
import 'account/delete_account.dart';

/// Account settings — identity summary, legal links, sign out, and
/// account deletion.
///
/// This screen also restores sign-out to the app's home surface. Sign-out
/// used to live on the subject list, which was `/`; once the dashboard
/// became home the only way to reach it was a screen most users would
/// never open.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider).asData?.value;
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);
    final isStaff = ref.watch(staffRoleProvider).canWrite;

    final username = (userData?['username'] as String?) ?? '';
    final displayName = (userData?['displayName'] as String?) ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Card(
                      children: [
                        _ProfileHeader(
                          name: displayName.isEmpty
                              ? (isGuest ? 'Guest' : 'Student')
                              : displayName,
                          username: username,
                        ),
                        const _Divider(),
                        // Editable, unlike the two below it: a display
                        // name is not unique and nothing depends on it
                        // staying put. A guest has no user document to
                        // write to, so they get the plain row.
                        if (isGuest)
                          _Row(
                            label: 'Display name',
                            value: displayName.isEmpty ? '—' : displayName,
                            hint: 'What the app calls you. Not unique.',
                          )
                        else
                          _EditableRow(
                            label: 'Edit profile',
                            value: displayName.isEmpty ? '—' : displayName,
                            hint: 'Picture, display name and bio.',
                            onTap: () => context.push('/settings/name'),
                          ),
                        const _Divider(),
                        if (isGuest || username.isEmpty)
                          _Row(
                            label: 'Username',
                            value: username.isEmpty ? '—' : '@$username',
                            hint: 'Unique.',
                          )
                        else
                          _EditableRow(
                            label: 'Username',
                            value: '@$username',
                            hint: 'Unique. Changeable every 90 days.',
                            onTap: () => context.push('/settings/username'),
                          ),
                        const _Divider(),
                        _Row(
                          label: 'Email',
                          value: isGuest
                              ? 'Guest session'
                              : (user?.email ?? '—'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (isGuest) ...[
                      _Card(
                        children: [
                          _LinkRow(
                            label: 'Create an account to keep your progress',
                            onTap: () => context.push('/account/upgrade'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Everything a student can actually change lives
                    // here. Until this section existed, onboarding's
                    // "you can change these any time" had no way to be
                    // true — see subjects_settings_screen.dart.
                    if (!isGuest) ...[
                      _Card(
                        children: [
                          _LinkRow(
                            label: 'Your subjects',
                            onTap: () => context.push('/settings/subjects'),
                          ),
                          const _Divider(),
                          _LinkRow(
                            label: 'About you',
                            onTap: () => context.push('/settings/profile'),
                          ),
                          const _Divider(),
                          _LinkRow(
                            label: 'Sign-in and security',
                            onTap: () => context.push('/settings/security'),
                          ),
                          const _Divider(),
                          _LinkRow(
                            label: 'Download your data',
                            onTap: () => context.push('/settings/export'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Per device, so guests get it too.
                    _Card(
                      children: [
                        _LinkRow(
                          label: 'Reading and data',
                          onTap: () => context.push('/settings/reading'),
                        ),
                        const _Divider(),
                        _LinkRow(
                          label: 'Saved lessons, questions and notes',
                          onTap: () => context.push('/saved'),
                        ),
                        const _Divider(),
                        _LinkRow(
                          label: 'Saved for offline',
                          onTap: () => context.push('/settings/offline'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (isStaff) ...[
                      _Card(
                        children: [
                          _LinkRow(
                            label: 'Content studio',
                            onTap: () => context.push('/admin'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    _Card(
                      children: [
                        _LinkRow(
                          label: 'Privacy Policy',
                          onTap: () => context.push('/privacy'),
                        ),
                        const _Divider(),
                        _LinkRow(
                          label: 'Terms of Service',
                          onTap: () => context.push('/terms'),
                        ),
                        const _Divider(),
                        _LinkRow(
                          label: 'About Paragon',
                          onTap: () => context.push('/about'),
                        ),
                        const _Divider(),
                        _LinkRow(
                          label: 'Help with your account',
                          onTap: () => showAccountHelp(
                            context,
                            uid: isGuest ? null : user?.uid,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const _AnalyticsToggle(),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Sign out',
                          style: AppTheme.btnLabel.copyWith(
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                    Text(
                      'DANGER ZONE',
                      style: AppTheme.caption.copyWith(
                        color: AppColors.wrong,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _DeleteAccountPanel(),
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

enum _DeleteChoice { scheduled, now }

class _DeleteAccountPanel extends ConsumerStatefulWidget {
  const _DeleteAccountPanel();

  @override
  ConsumerState<_DeleteAccountPanel> createState() =>
      _DeleteAccountPanelState();
}

class _DeleteAccountPanelState extends ConsumerState<_DeleteAccountPanel> {
  bool _isDeleting = false;
  String? _message;

  /// A real account is scheduled for deletion in 30 days and signed out;
  /// signing back in within that time offers to restore it. A guest has
  /// no way back in, so a grace period would only keep their data longer
  /// for nobody: theirs goes at once, as before.
  Future<void> _confirmAndDelete() async {
    final isGuest = ref.read(isGuestProvider);
    final days = kDeletionGracePeriod.inDays;
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete your account?',
          style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
        ),
        content: Text(
          isGuest
              ? 'This permanently deletes this guest session and everything '
                    'in it. It cannot be undone.'
              : 'Your account and your entire practice history will be '
                    'deleted in $days days, and you will be signed out now. '
                    'Sign in again before then to change your mind.\n\n'
                    'If you would rather it went immediately, choose '
                    '"Delete now". That cannot be undone.\n\n'
                    'Your username, and any you used before it, stay '
                    'reserved and cannot be claimed by anyone else, '
                    'including you.',
          style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.btnLabel.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.now),
            child: Text(
              isGuest ? 'Delete everything' : 'Delete now',
              style: AppTheme.btnLabel.copyWith(color: AppColors.wrong),
            ),
          ),
          if (!isGuest)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_DeleteChoice.scheduled),
              child: Text(
                'Delete in $days days',
                style: AppTheme.btnLabel.copyWith(color: AppColors.wrong),
              ),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    setState(() {
      _isDeleting = true;
      _message = null;
    });
    try {
      if (choice == _DeleteChoice.now) {
        final message = await deleteAccountNow(context, ref);
        if (mounted && message != null) setState(() => _message = message);
        return;
      }
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      await ref.read(accountRepositoryProvider).scheduleDeletion(user.uid);
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = "Couldn't delete your account. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.wrong.withAlpha((0.07 * 255).round()),
        border: Border.all(
          color: AppColors.wrong.withAlpha((0.35 * 255).round()),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Delete account',
            style: AppTheme.bodyLg.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Removes your account and every question you have answered. '
            'You get 30 days to change your mind, or it can go at once.',
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _isDeleting ? null : _confirmAndDelete,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.wrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.wrong,
                      ),
                    )
                  : Text(
                      'Delete my account',
                      style: AppTheme.btnLabel.copyWith(color: AppColors.wrong),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small presentational pieces ────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

/// Avatar, name and handle, leading to `/me`.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.username});

  final String name;
  final String username;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/me'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            const UserAvatar(size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTheme.bodyLg.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    username.isEmpty ? 'View your profile' : '@$username',
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.borderDark);
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: AppTheme.caption.copyWith(
                      color: AppColors.textSecondaryDark.withAlpha(
                        (0.7 * 255).round(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.bodyMd.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [_Row] that leads somewhere. Keeps the value visible — the point of
/// the identity card is to show what is stored, and hiding it behind a tap
/// would make the screen worse in order to make it editable.
class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(
              child: _Row(label: label, value: value, hint: hint),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opt out of usage analytics.
///
/// Placed in plain sight rather than buried, because most of our users
/// are minors and the privacy policy promises this control exists.
/// Flipping it calls `setAnalyticsCollectionEnabled` on the Firebase SDK,
/// so collection actually stops rather than merely being ignored by us.
class _AnalyticsToggle extends ConsumerWidget {
  const _AnalyticsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(analyticsEnabledProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share usage data',
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anonymous statistics about which topics get practised. '
                  'Never your name, answers or anything you typed.',
                  style: AppTheme.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: AppColors.primary,
            onChanged: (v) =>
                ref.read(analyticsEnabledProvider.notifier).set(v),
          ),
        ],
      ),
    );
  }
}
