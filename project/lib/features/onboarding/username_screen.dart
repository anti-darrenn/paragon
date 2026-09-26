import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import 'onboarding_scaffold.dart';
import 'username_input.dart';

/// Step 1 — pick a unique @handle.
///
/// The field and its advisory availability check are [UsernameInput],
/// shared with the change-username screen. The real uniqueness decision
/// happens in `UserRepository.reserveUsername`, which runs a transaction;
/// a `false` from it is surfaced as "already taken" rather than as an
/// error.
class OnboardingUsernameScreen extends ConsumerStatefulWidget {
  const OnboardingUsernameScreen({super.key});

  @override
  ConsumerState<OnboardingUsernameScreen> createState() =>
      _OnboardingUsernameScreenState();
}

class _OnboardingUsernameScreenState
    extends ConsumerState<OnboardingUsernameScreen> {
  final _input = UsernameInputController();
  bool _isSubmitting = false;

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

  Future<void> _submit() async {
    if (!_input.validateNow()) return;
    final raw = _input.raw;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);
    _input.setSubmitError(null);

    try {
      final reserved = await ref
          .read(userRepositoryProvider)
          .reserveUsername(
            uid: user.uid,
            raw: raw,
            key: UsernameRules.normalise(raw),
          );

      if (!mounted) return;
      if (!reserved) {
        _input.markTaken('That username was just taken. Try another.');
        return;
      }
      ref.read(analyticsProvider).onboardingStepCompleted('username');
      context.go(OnboardingStep.username.next.path);
    } catch (_) {
      if (!mounted) return;
      _input.setSubmitError("Couldn't save your username. Please try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(userRepositoryProvider);
    return OnboardingScaffold(
      step: OnboardingStep.username,
      title: 'Choose a username',
      subtitle:
          'Your unique handle. You can change it later, but only once '
          'every ${UsernameRules.changeCooldown.inDays} days, and a name '
          'you give up can never be used again.',
      errorText: _input.message,
      isLoading: _isSubmitting,
      primaryLabel: 'Continue',
      onPrimary: _input.canSubmit ? _submit : null,
      child: UsernameInput(
        controller: _input,
        isAvailable: repo.isUsernameAvailable,
        autofocus: true,
        onSubmitted: _submit,
      ),
    );
  }
}
