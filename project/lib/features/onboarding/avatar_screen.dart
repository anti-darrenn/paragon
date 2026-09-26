import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/avatar.dart';
import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/widgets/user_avatar.dart';
import '../profile/avatar_picker.dart';
import 'onboarding_scaffold.dart';

/// Step 3 — optional. Pick a picture or keep your initials.
///
/// Skipping writes nothing: the initials fallback in [Avatar.parse] is
/// already what the student sees, so there is nothing to record.
class OnboardingAvatarScreen extends ConsumerStatefulWidget {
  const OnboardingAvatarScreen({super.key});

  @override
  ConsumerState<OnboardingAvatarScreen> createState() =>
      _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState
    extends ConsumerState<OnboardingAvatarScreen> {
  Avatar? _avatar;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _continue() async {
    final user = ref.read(currentUserProvider);
    final avatar = _avatar;
    if (user == null || avatar == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref
          .read(userRepositoryProvider)
          .setAvatar(uid: user.uid, avatar: avatar.storageValue);
      if (!mounted) return;
      ref.read(analyticsProvider).onboardingStepCompleted('avatar');
      context.go(OnboardingStep.avatar.next.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save that. Please try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final data = ref.watch(userDataProvider).asData?.value;
    final initials = initialsFor(
      data?['displayName'] as String?,
      fallback: data?['username'] as String?,
    );
    final shown =
        _avatar ?? Avatar.parse(data?['avatar'], seed: user?.uid ?? '');

    return OnboardingScaffold(
      step: OnboardingStep.avatar,
      title: 'Pick a picture',
      subtitle:
          'It shows on your dashboard and profile, and only you see it. '
          'You can change it any time in settings.',
      errorText: _error,
      isLoading: _isSubmitting,
      primaryLabel: 'Continue',
      onPrimary: _avatar == null ? null : _continue,
      onSkip: () => context.go(OnboardingStep.avatar.next.path),
      skipLabel: 'Keep my initials',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AvatarDisc(avatar: shown, initials: initials, size: 80),
          ),
          const SizedBox(height: 24),
          AvatarPicker(
            selected: shown,
            initials: initials,
            onChanged: (a) => setState(() => _avatar = a),
          ),
        ],
      ),
    );
  }
}
