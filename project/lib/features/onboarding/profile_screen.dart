import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import 'onboarding_scaffold.dart';
import 'profile_form.dart';

/// Step 4 — optional profile.
///
/// **Genuinely optional.** Nothing here gates completion
/// (`resolveOnboardingStep` never returns this step), Skip is as
/// prominent as Save, every field can be left blank, and
/// `UserRepository.setProfile` merges only the fields actually filled in —
/// so skipping with two boxes completed saves those two rather than
/// discarding them.
///
/// This step collects data about students who are largely minors. The
/// privacy policy at `/privacy` has to describe it accurately, and no
/// field here may become required without revisiting that. The fields
/// themselves live in `profile_form.dart`, shared with the settings
/// screen that edits them later — which is what makes the subtitle's "you
/// can edit it later" true.
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState
    extends ConsumerState<OnboardingProfileScreen> {
  final _form = ProfileFormController();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool save}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) context.go('/');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (save) {
        await ref
            .read(userRepositoryProvider)
            .setProfile(uid: user.uid, profile: _form.toProfile());
      }
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = "Couldn't save that. You can add it later in settings.",
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Skip still persists anything already typed — a partial save, per spec.
  Future<void> _skip() => _finish(save: !_form.isEmpty);

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: OnboardingStep.profile,
      title: 'Tell us a bit about you',
      subtitle:
          'All optional — skip anything you would rather not share. It '
          'helps us shape the content, and you can edit it later in '
          'settings.',
      errorText: _error,
      isLoading: _isSubmitting,
      primaryLabel: 'Save and finish',
      onPrimary: () => _finish(save: true),
      onSkip: _skip,
      skipLabel: 'Skip for now',
      child: ProfileFormFields(
        controller: _form,
        onChanged: () => setState(() {}),
      ),
    );
  }
}
