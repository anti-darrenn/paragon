import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../onboarding/onboarding_scaffold.dart';
import 'guest_upgrade.dart';

/// `/account/upgrade` — a guest makes an account and keeps what they did.
///
/// Every "sign in to keep this" prompt a guest sees leads here rather than
/// to `/signin`, because signing in to an account starts from that account,
/// while this links the guest's own uid. On success the router takes over:
/// the account is now real and has no username, so it is sent to the first
/// onboarding step.
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailFormValid =>
      _emailRegExp.hasMatch(_email.text.trim()) &&
      _password.text.trim().length >= 6;

  Future<void> _run(
    Future<GuestUpgradeOutcome> Function() attempt, {
    required bool isGoogle,
  }) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final outcome = await attempt();
      if (!mounted) return;
      if (outcome == GuestUpgradeOutcome.accountExists) {
        await _offerExistingAccount(isGoogle: isGoogle);
      }
      // linked: the router moves on by itself. cancelled: nothing to say.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e.code));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(String code) => switch (code) {
    'weak-password' => 'Use a password of at least 6 characters.',
    'invalid-email' => 'Enter a valid email address.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No connection. Check it and try again.',
    'popup-blocked' =>
      'Your browser blocked the Google window. Allow pop-ups '
          'for this site and try again.',
    _ => "Couldn't create your account. Please try again.",
  };

  Future<void> _offerExistingAccount({required bool isGoogle}) async {
    final signIn = await confirmSignInToExistingAccount(
      context,
      isGoogle: isGoogle,
    );
    if (signIn != true || !mounted) return;
    if (isGoogle) {
      setState(() => _isLoading = true);
      try {
        await signInWithGoogle(ref);
      } on FirebaseAuthException catch (e) {
        if (mounted) setState(() => _error = _messageFor(e.code));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      context.push('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Create an account')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Keep your progress',
                      style: AppTheme.heading1.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Make an account and everything from this guest '
                      'session comes with you: topic tests, lessons you '
                      'finished, notes, highlights, bookmarks and revision '
                      'cards. It also opens drill practice and every '
                      'subject.',
                      style: AppTheme.bodyLg.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _run(
                                () => GuestUpgrade.withGoogle(ref),
                                isGoogle: true,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonLight,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icons/google_g.png',
                              width: 28,
                              height: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Continue with Google',
                              style: AppTheme.btnLabel.copyWith(
                                color: AppColors.backgroundDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: AppColors.borderDark),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or with email',
                            style: AppTheme.caption.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: AppColors.borderDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OnboardingTextField(
                      controller: _email,
                      label: 'EMAIL',
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 16),
                    OnboardingTextField(
                      controller: _password,
                      label: 'PASSWORD',
                      hintText: 'At least 6 characters',
                      obscureText: _obscure,
                      onChanged: (_) => setState(() => _error = null),
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondaryDark,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading || !_emailFormValid
                            ? null
                            : () => _run(
                                () => GuestUpgrade.withEmail(
                                  ref,
                                  email: _email.text.trim(),
                                  password: _password.text.trim(),
                                ),
                                isGoogle: false,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.trackDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Create account',
                                style: AppTheme.btnLabel.copyWith(
                                  color: _emailFormValid
                                      ? Colors.white
                                      : AppColors.textSecondaryDark,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.push('/signin'),
                      child: Text(
                        'I already have an account',
                        style: AppTheme.bodyMd.copyWith(
                          color: AppColors.textSecondaryDark,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
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

/// Asks a guest whether to sign in to the account that already owns the
/// Google login or email they tried, saying plainly what that costs. Used
/// by this screen and the welcome screen.
Future<bool> confirmSignInToExistingAccount(
  BuildContext context, {
  required bool isGoogle,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text(
        'You already have an account',
        style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
      ),
      content: Text(
        isGoogle
            ? 'That Google account is already signed up to Paragon.'
                  '\n\n'
                  'You can sign in to it, but what you did in this guest '
                  'session will not come with you. Two accounts cannot be '
                  'joined together.'
            : 'That email is already signed up to Paragon.\n\n'
                  'You can sign in to it, but what you did in this guest '
                  'session will not come with you. Two accounts cannot be '
                  'joined together.',
        style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Stay a guest',
            style: AppTheme.btnLabel.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Sign in to it',
            style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
  return answer == true;
}
