import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// How a student can sign in, read from Firebase's provider list.
class SignInMethods {
  const SignInMethods({required this.password, required this.google});

  factory SignInMethods.of(User user) => SignInMethods.fromProviderIds([
    for (final p in user.providerData) p.providerId,
  ]);

  factory SignInMethods.fromProviderIds(Iterable<String> ids) => SignInMethods(
    password: ids.contains(EmailAuthProvider.PROVIDER_ID),
    google: ids.contains(GoogleAuthProvider.PROVIDER_ID),
  );

  final bool password;
  final bool google;
}

/// Confirms it is really the student before something sensitive —
/// changing a password or email, deleting the account. Firebase demands a
/// recent sign-in for those, and until now the only answer the app had was
/// "sign out and sign in again".
///
/// A password account is asked for its password; a Google-only account
/// gets the Google window. Returns true once confirmed, false if the
/// student backed out. Wrong-password errors are shown in the dialog, not
/// thrown.
Future<bool> reauthenticate(BuildContext context, User user) async {
  final methods = SignInMethods.of(user);
  if (!methods.password) {
    try {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return false;
      }
      rethrow;
    }
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _PasswordDialog(user: user),
  );
  return ok == true;
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.user});
  final User user;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: widget.user.email ?? '',
          password: _password.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'wrong-password' || 'invalid-credential' => 'That password is wrong.',
          'too-many-requests' => 'Too many attempts. Try again later.',
          _ => "Couldn't check that. Please try again.",
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text(
        'Confirm it is you',
        style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter your current password to continue.',
            style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 14),
          PasswordField(
            controller: _password,
            label: 'Current password',
            autofocus: true,
            onSubmitted: (_) => _busy ? null : _confirm(),
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTheme.btnLabel.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _confirm,
          child: Text(
            'Continue',
            style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// A password box with a show/hide toggle, for the account dialogs.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      autofocus: widget.autofocus,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(color: AppColors.textPrimaryDark),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        filled: true,
        fillColor: AppColors.backgroundDark,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondaryDark,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
