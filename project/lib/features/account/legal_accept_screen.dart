import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'delete_account.dart';
import '../../core/theme/app_palette.dart';

/// `/legal/accept` — the terms changed; accept to carry on.
///
/// Reached only through the router's terms gate. Declining is a real
/// choice, not a dead end: a student can sign out, or delete the account
/// here and now, since Settings is behind the gate.
class LegalAcceptScreen extends ConsumerStatefulWidget {
  const LegalAcceptScreen({super.key});

  @override
  ConsumerState<LegalAcceptScreen> createState() => _LegalAcceptScreenState();
}

class _LegalAcceptScreenState extends ConsumerState<LegalAcceptScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _accept() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // The router sees the new version and moves on by itself.
      await ref.read(userRepositoryProvider).acceptLegal(user.uid);
    } catch (_) {
      if (mounted) setState(() => _message = "Couldn't save that. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: Text(
          'Delete your account now?',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        content: Text(
          'Your account and your entire practice history are deleted '
          'immediately. This cannot be undone.',
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
              'Delete everything',
              style: AppTheme.btnLabel.copyWith(color: AppColors.wrong),
            ),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    final message = await deleteAccountNow(context, ref);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hadEarlier =
        ref.watch(userDataProvider).asData?.value?['legalVersion'] != null;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hadEarlier
                        ? 'We have updated our terms'
                        : 'Please review our terms',
                    style: AppTheme.heading1.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Our Terms of Service and Privacy Policy were updated on '
                    '$legalLastUpdated. What changed:',
                    style: AppTheme.bodyLg.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final change in kLegalChanges)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '•  $change',
                        style: AppTheme.bodyMd.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/terms'),
                        child: const Text('Read the Terms'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/privacy'),
                        child: const Text('Read the Privacy Policy'),
                      ),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _accept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Accept and continue',
                        style: AppTheme.btnLabel.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "If you don't agree, you can sign out, or delete your "
                    'account and everything in it.',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => FirebaseAuth.instance.signOut(),
                        child: Text(
                          'Sign out',
                          style: AppTheme.bodyMd.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _delete,
                        child: Text(
                          'Delete my account',
                          style: AppTheme.bodyMd.copyWith(
                            color: AppColors.wrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
