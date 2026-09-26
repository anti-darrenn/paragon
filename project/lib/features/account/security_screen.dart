import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/repositories/account_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'reauth.dart';
import '../../core/theme/app_palette.dart';

/// `/settings/security` — how you sign in, and the controls that go with
/// it: verify or change your email, change or add a password, link Google,
/// see recent activity, and sign out everywhere.
///
/// Every change goes through Firebase Auth directly; the only Firestore
/// write is the sign-out-everywhere request. `users/{uid}.email` is kept in
/// step with Auth by `accountEmailSyncProvider`, not here.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _busy = false;

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs [action], asking the student to confirm who they are and
  /// retrying once if Firebase says the sign-in is too old.
  Future<void> _guarded(Future<void> Function(User user) action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      try {
        await action(user);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login' || !mounted) rethrow;
        if (!await reauthenticate(context, user)) return;
        await action(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _say(_messageFor(e.code));
    } catch (_) {
      if (mounted) _say('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(String code) => switch (code) {
    'weak-password' => 'Use a password of at least 6 characters.',
    'invalid-email' => 'That is not a valid email address.',
    'email-already-in-use' => 'Another account already uses that email.',
    'credential-already-in-use' =>
      'That Google account belongs to another Paragon account.',
    'provider-already-linked' => 'That is already linked.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No connection. Check it and try again.',
    'popup-closed-by-user' || 'cancelled-popup-request' => 'Cancelled.',
    _ => 'Something went wrong. Please try again.',
  };

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _sendVerification() => _guarded((user) async {
    await user.sendEmailVerification();
    if (mounted) {
      _say('Sent. Open the link in the email, then come back here.');
    }
  });

  Future<void> _checkVerified() => _guarded((user) async {
    // Reload re-reads emailVerified; authStateProvider re-emits on the
    // change, so this screen redraws on its own.
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser;
    if (mounted && fresh?.emailVerified != true) {
      _say('Not verified yet. Open the link in the email first.');
    }
  });

  Future<void> _changePassword() async {
    final next = await _askNewPassword(title: 'Change password');
    if (next == null) return;
    await _guarded((user) async {
      await user.updatePassword(next);
      if (mounted) _say('Password changed.');
    });
  }

  Future<void> _addPassword() async {
    final next = await _askNewPassword(title: 'Add a password');
    if (next == null) return;
    await _guarded((user) async {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: user.email ?? '', password: next),
      );
      if (mounted) {
        _say('Password added. You can now sign in with your email too.');
      }
    });
  }

  Future<void> _linkGoogle() => _guarded((user) async {
    await user.linkWithPopup(GoogleAuthProvider());
    if (mounted) _say('Google linked. You can now sign in with it too.');
  });

  Future<void> _changeEmail() async {
    final email = await _askNewEmail();
    if (email == null) return;
    await _guarded((user) async {
      await user.verifyBeforeUpdateEmail(email);
      if (mounted) {
        _say('We sent a link to $email. Your email changes when you open it.');
      }
    });
  }

  Future<void> _signOutEverywhere() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: Text(
          'Sign out everywhere?',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        content: Text(
          'Every device signed in to this account will be signed out, this '
          'one included — this one straight away, the others within about '
          'an hour. Use it if you signed in on a computer that is not '
          'yours, or think someone else has your password (change it too).',
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTheme.btnLabel.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sign out everywhere',
              style: AppTheme.btnLabel.copyWith(color: AppColors.wrong),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .requestSignOutEverywhere(user.uid);
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        _say("Couldn't send that. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────

  Future<String?> _askNewPassword({required String title}) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NewPasswordDialog(title: title),
    );
  }

  Future<String?> _askNewEmail() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: Text(
          'Change email',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We will send a link to the new address. Nothing changes '
              'until you open it, and you keep signing in with the old one '
              'until then.',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: context.palette.textPrimary),
              decoration: InputDecoration(
                labelText: 'New email',
                labelStyle: TextStyle(color: context.palette.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AppTheme.btnLabel.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final email = controller.text.trim();
              if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                Navigator.of(context).pop(email);
              }
            },
            child: Text(
              'Send link',
              style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold();
    final methods = SignInMethods.of(user);
    final email = user.email ?? '';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Sign-in and security')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_busy) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                      ],

                      // ── Email ──────────────────────────────────────────
                      _Card(
                        children: [
                          _Line(
                            label: 'Email',
                            value: email.isEmpty ? '—' : email,
                            badge: email.isEmpty
                                ? null
                                : user.emailVerified
                                ? const _Badge('Verified', AppColors.correct)
                                : const _Badge(
                                    'Not verified',
                                    AppColors.warning,
                                  ),
                          ),
                          if (!user.emailVerified && methods.password) ...[
                            const _Divider(),
                            _Action(
                              label: 'Send verification email',
                              hint:
                                  'Proves the address is yours, so you can '
                                  'get back in if you forget your password.',
                              onTap: _sendVerification,
                            ),
                            const _Divider(),
                            _Action(
                              label: "I've opened the link",
                              onTap: _checkVerified,
                            ),
                          ],
                          if (methods.password) ...[
                            const _Divider(),
                            _Action(label: 'Change email', onTap: _changeEmail),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Sign-in methods ────────────────────────────────
                      const _Heading('How you sign in'),
                      _Card(
                        children: [
                          _Line(
                            label: 'Google',
                            value: methods.google ? 'Linked' : 'Not linked',
                          ),
                          if (!methods.google) ...[
                            const _Divider(),
                            _Action(label: 'Link Google', onTap: _linkGoogle),
                          ],
                          const _Divider(),
                          _Line(
                            label: 'Password',
                            value: methods.password ? 'Set' : 'Not set',
                          ),
                          const _Divider(),
                          methods.password
                              ? _Action(
                                  label: 'Change password',
                                  onTap: _changePassword,
                                )
                              : _Action(
                                  label: 'Add a password',
                                  hint:
                                      'Sign in with your email as well as '
                                      'Google.',
                                  onTap: email.isEmpty ? null : _addPassword,
                                ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Activity ───────────────────────────────────────
                      const _Heading('Recent activity'),
                      _Card(
                        children: [
                          _Line(
                            label: 'Account created',
                            value: formatAccountDate(
                              user.metadata.creationTime,
                            ),
                          ),
                          const _Divider(),
                          _Line(
                            label: 'Last sign-in',
                            value: formatAccountDate(
                              user.metadata.lastSignInTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _Card(
                        children: [
                          _Action(
                            label: 'Sign out everywhere',
                            hint:
                                'Ends every session on every device, this '
                                'one included.',
                            danger: true,
                            onTap: _signOutEverywhere,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "26 Sep 2026, 14:05", in the device's time zone. `—` when unknown.
String formatAccountDate(DateTime? when) {
  if (when == null) return '—';
  final t = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${formatDay(t)}, ${two(t.hour)}:${two(t.minute)}';
}

/// "26 Sep 2026", in the device's time zone.
String formatDay(DateTime when) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final t = when.toLocal();
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({required this.title});
  final String title;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final error = newPasswordProblem(_first.text, _second.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_first.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(
        widget.title,
        style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordField(
            controller: _first,
            label: 'New password',
            autofocus: true,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _second,
            label: 'Type it again',
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppTheme.caption.copyWith(color: AppColors.wrong),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTheme.btnLabel.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'Save',
            style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// Null when [first] is an acceptable new password and [second] matches
/// it; otherwise what to tell the student. Firebase's minimum is 6.
String? newPasswordProblem(String first, String second) {
  if (first.length < 6) return 'Use at least 6 characters.';
  if (first != second) return 'The two passwords are different.';
  return null;
}

// ─── Small pieces ────────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text.toUpperCase(),
      style: AppTheme.caption.copyWith(
        color: context.palette.textSecondary,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.palette.border);
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha((0.12 * 255).round()),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: AppTheme.caption.copyWith(color: color)),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.badge});

  final String label;
  final String value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Text(
          label,
          style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (badge != null) ...[const SizedBox(width: 8), badge!],
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    this.hint,
    this.danger = false,
  });

  final String label;
  final String? hint;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? context.palette.textSecondary
        : danger
        ? AppColors.wrong
        : AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.bodyMd.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      style: AppTheme.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
