import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_scaffold.dart';

/// Step 1 — pick a unique @handle.
///
/// The availability check here is **advisory**. It is debounced by 300ms
/// (spec §2.1) and can always be stale by the time the user submits, so
/// the real uniqueness decision happens in
/// `UserRepository.reserveUsername`, which runs a transaction. A `false`
/// return from that is surfaced as "already taken" rather than as an
/// error.
class OnboardingUsernameScreen extends ConsumerStatefulWidget {
  const OnboardingUsernameScreen({super.key});

  @override
  ConsumerState<OnboardingUsernameScreen> createState() =>
      _OnboardingUsernameScreenState();
}

enum _Availability { unknown, checking, free, taken }

class _OnboardingUsernameScreenState
    extends ConsumerState<OnboardingUsernameScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _debounceTimer;

  /// Guards against a slow earlier check landing after a newer one and
  /// overwriting its result.
  int _checkSequence = 0;

  _Availability _availability = _Availability.unknown;
  String? _validationError;
  String? _submitError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounceTimer?.cancel();
    setState(() {
      _submitError = null;
      _validationError = raw.trim().isEmpty
          ? null // don't scold someone mid-type on an empty field
          : UsernameRules.validate(raw);
      _availability = _Availability.unknown;
    });

    if (_validationError != null || raw.trim().isEmpty) return;
    _debounceTimer = Timer(_debounce, () => _checkAvailability(raw));
  }

  Future<void> _checkAvailability(String raw) async {
    final key = UsernameRules.normalise(raw);
    final sequence = ++_checkSequence;
    setState(() => _availability = _Availability.checking);

    try {
      final free = await ref
          .read(userRepositoryProvider)
          .isUsernameAvailable(key);
      if (!mounted || sequence != _checkSequence) return;
      setState(
        () => _availability = free ? _Availability.free : _Availability.taken,
      );
    } catch (_) {
      // A failed check is not a failed username — stay quiet and let the
      // transaction at submit time be the judge.
      if (!mounted || sequence != _checkSequence) return;
      setState(() => _availability = _Availability.unknown);
    }
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    final error = UsernameRules.validate(raw);
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

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
        setState(() {
          _availability = _Availability.taken;
          _submitError = 'That username was just taken. Try another.';
        });
        return;
      }
      ref.read(analyticsProvider).onboardingStepCompleted('username');
      context.go(OnboardingStep.username.next.path);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _submitError = "Couldn't save your username. Please try again.",
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget? _suffixIcon() => switch (_availability) {
    _Availability.checking => const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textSecondaryDark,
        ),
      ),
    ),
    _Availability.free => const Icon(
      Icons.check_circle_rounded,
      color: AppColors.correct,
      size: 20,
    ),
    _Availability.taken => const Icon(
      Icons.cancel_rounded,
      color: AppColors.wrong,
      size: 20,
    ),
    _Availability.unknown => null,
  };

  String? get _message {
    if (_submitError != null) return _submitError;
    if (_validationError != null) return _validationError;
    if (_availability == _Availability.taken) {
      return 'That username is already taken.';
    }
    return null;
  }

  bool get _canSubmit =>
      _controller.text.trim().isNotEmpty &&
      _validationError == null &&
      _availability != _Availability.taken &&
      _availability != _Availability.checking;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: OnboardingStep.username,
      title: 'Choose a username',
      subtitle:
          "This is how other students will see you. You can't change it "
          'later, so pick one you like.',
      errorText: _message,
      isLoading: _isSubmitting,
      primaryLabel: 'Continue',
      onPrimary: _canSubmit ? _submit : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingTextField(
            controller: _controller,
            label: 'USERNAME',
            hintText: 'chidi_99',
            prefixText: '@',
            autofocus: true,
            maxLength: UsernameRules.maxLength,
            onChanged: _onChanged,
            onSubmitted: (_) {
              if (_canSubmit) _submit();
            },
            suffix: _suffixIcon(),
          ),
          const SizedBox(height: 10),
          Text(
            '${UsernameRules.minLength}–${UsernameRules.maxLength} characters. '
            'Letters, numbers and underscores.',
            style: AppTheme.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          if (_availability == _Availability.free) ...[
            const SizedBox(height: 8),
            Text(
              '@${_controller.text.trim()} is available.',
              style: AppTheme.caption.copyWith(color: AppColors.correct),
            ),
          ],
        ],
      ),
    );
  }
}
