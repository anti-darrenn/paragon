import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/repositories/account_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'delete_account.dart';
import 'security_screen.dart' show formatDay;
import '../../core/theme/app_palette.dart';

/// `/account/deleting` — where the router holds an account that is
/// scheduled for deletion. Three ways out: restore it, delete it now, or
/// sign out and let the date arrive.
///
/// The account is otherwise untouched until `jobs.js --job=deletions`
/// removes it, so restoring brings everything back exactly as it was.
class DeletingScreen extends ConsumerStatefulWidget {
  const DeletingScreen({super.key});

  @override
  ConsumerState<DeletingScreen> createState() => _DeletingScreenState();
}

class _DeletingScreenState extends ConsumerState<DeletingScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _restore() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // The router notices the field has gone and sends them home.
      await ref.read(accountRepositoryProvider).cancelDeletion(user.uid);
    } catch (_) {
      if (mounted) setState(() => _message = "Couldn't restore it. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final message = await deleteAccountNow(context, ref);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requested = ref
        .watch(userDataProvider)
        .asData
        ?.value?['deletionRequestedAt'];
    final date = requested is Timestamp
        ? formatDay(deletionDateFor(requested.toDate()))
        : null;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 40,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your account is set to be deleted',
                    style: AppTheme.heading1.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    date == null
                        ? 'It will be deleted soon, with your whole practice '
                              'history.'
                        : 'It will be deleted on $date, with your whole '
                              'practice history. Until then, nothing has been '
                              'removed.',
                    style: AppTheme.bodyLg.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _restore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Keep my account',
                        style: AppTheme.btnLabel.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _deleteNow,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.wrong),
                    ),
                    child: Text(
                      'Delete it now',
                      style: AppTheme.btnLabel.copyWith(color: AppColors.wrong),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
