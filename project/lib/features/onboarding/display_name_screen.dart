import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_scaffold.dart';
import '../../core/theme/app_palette.dart';

/// Step 2 — what the app calls the student. 2–30 characters, not unique.
///
/// Prefilled from whatever Firebase Auth already knows (Google supplies a
/// name; an email sign-up does not), so a Google user usually just presses
/// Continue.
class OnboardingDisplayNameScreen extends ConsumerStatefulWidget {
  const OnboardingDisplayNameScreen({super.key});

  @override
  ConsumerState<OnboardingDisplayNameScreen> createState() =>
      _OnboardingDisplayNameScreenState();
}

class _OnboardingDisplayNameScreenState
    extends ConsumerState<OnboardingDisplayNameScreen> {
  static const _minLength = 2;
  static const _maxLength = 30;

  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prefer the Auth profile name; fall back to whatever is already on
    // the Firestore document (a user resuming the funnel).
    final authName = ref.read(currentUserProvider)?.displayName?.trim() ?? '';
    final storedName =
        (ref.read(userDataProvider).asData?.value?['displayName'] as String?)
            ?.trim() ??
        '';
    _controller.text = authName.isNotEmpty ? authName : storedName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final length = _controller.text.trim().length;
    return length >= _minLength && length <= _maxLength;
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null || !_isValid) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .setDisplayName(uid: user.uid, displayName: _controller.text);
      if (!mounted) return;
      ref.read(analyticsProvider).onboardingStepCompleted('displayname');
      context.go(OnboardingStep.displayName.next.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save your name. Please try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: OnboardingStep.displayName,
      title: 'What should we call you?',
      subtitle:
          'Your display name appears on your dashboard. This one you can '
          'change whenever you like.',
      errorText: _error,
      isLoading: _isSubmitting,
      primaryLabel: 'Continue',
      onPrimary: _isValid ? _submit : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingTextField(
            controller: _controller,
            label: 'DISPLAY NAME',
            hintText: 'Chidi',
            autofocus: true,
            maxLength: _maxLength,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) {
              if (_isValid) _submit();
            },
          ),
          const SizedBox(height: 10),
          Text(
            '$_minLength–$_maxLength characters.',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
