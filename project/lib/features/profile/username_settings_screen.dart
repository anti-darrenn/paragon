import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../account/security_screen.dart' show formatDay;
import '../onboarding/username_input.dart';
import '../../core/theme/app_palette.dart';

/// `/settings/username` — change your @handle, once every 90 days.
///
/// The screen shows the date instead of the form while the cooldown runs,
/// so the rules' refusal is never what a student meets. The old handle is
/// never released (see `UserRepository.changeUsername`), and the screen
/// says so before they commit.
class UsernameSettingsScreen extends ConsumerStatefulWidget {
  const UsernameSettingsScreen({super.key});

  @override
  ConsumerState<UsernameSettingsScreen> createState() =>
      _UsernameSettingsScreenState();
}

class _UsernameSettingsScreenState
    extends ConsumerState<UsernameSettingsScreen> {
  final _input = UsernameInputController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _input.removeListener(_rebuild);
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(String currentKey) async {
    if (!_input.validateNow()) return;
    final raw = _input.raw;
    final key = UsernameRules.normalise(raw);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: Text(
          'Change to @$raw?',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        content: Text(
          key == currentKey
              ? 'Only the capital letters change. You will not be able to '
                    'change your username again for '
                    '${UsernameRules.changeCooldown.inDays} days.'
              : 'Your current username stays reserved to you and can never '
                    'be used by anyone, including you. You will not be able '
                    'to change your username again for '
                    '${UsernameRules.changeCooldown.inDays} days.',
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
              'Change it',
              style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    _input.setSubmitError(null);
    try {
      final ok = await ref
          .read(userRepositoryProvider)
          .changeUsername(uid: user.uid, raw: raw, key: key);
      if (!mounted) return;
      if (!ok) {
        _input.markTaken('That username was just taken. Try another.');
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('You are now @$raw.')));
      context.pop();
    } catch (_) {
      if (mounted) {
        _input.setSubmitError("Couldn't change it. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(userDataProvider).asData?.value;
    final current = (data?['username'] as String?)?.trim() ?? '';
    final currentKey = (data?['usernameKey'] as String?) ?? '';
    final changedAt = data?['usernameChangedAt'];
    final nextAllowed = UsernameRules.nextChangeAllowedAt(
      changedAt is Timestamp ? changedAt.toDate() : null,
      now: DateTime.now(),
    );
    final repo = ref.read(userRepositoryProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Username')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      current.isEmpty ? '—' : '@$current',
                      style: AppTheme.heading2.copyWith(
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can change your username once every '
                      '${UsernameRules.changeCooldown.inDays} days. A '
                      'username you give up stays reserved to you, so '
                      'nobody else can take it and pretend to be you.',
                      style: AppTheme.bodyMd.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (nextAllowed != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          border: Border.all(color: context.palette.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'You changed it recently. You can change it again '
                          'from ${formatDay(nextAllowed)}.',
                          style: AppTheme.bodyMd.copyWith(
                            color: context.palette.textPrimary,
                          ),
                        ),
                      )
                    else ...[
                      UsernameInput(
                        controller: _input,
                        // Your own handle in different capitals is yours to
                        // take, not "taken".
                        isAvailable: (key) async =>
                            key == currentKey ||
                            await repo.isUsernameAvailable(key),
                        autofocus: true,
                        onSubmitted: () => _save(currentKey),
                      ),
                      if (_input.message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _input.message!,
                          style: AppTheme.bodyMd.copyWith(
                            color: AppColors.wrong,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              _isSaving ||
                                  !_input.canSubmit ||
                                  _input.raw == current
                              ? null
                              : () => _save(currentKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: context.palette.track,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Change username',
                                  style: AppTheme.btnLabel.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
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
