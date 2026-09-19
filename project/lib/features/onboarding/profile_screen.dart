import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_step.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_scaffold.dart';

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
/// field here may become required without revisiting that.
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState
    extends ConsumerState<OnboardingProfileScreen> {
  final _school = TextEditingController();
  final _age = TextEditingController();

  String? _classYear;
  String? _gender;
  String? _country;
  String? _state;

  bool _isSubmitting = false;
  String? _error;

  static const _classYears = ['JSS3', 'SS1', 'SS2', 'SS3', 'Graduate', 'Other'];
  static const _genders = ['Female', 'Male', 'Prefer not to say'];
  static const _countries = ['Nigeria', 'Ghana', 'Other'];

  // Placeholder list — the full 36 states + FCT belong in a data file, not
  // inline here, and only matter once country == Nigeria drives the list.
  static const _states = [
    'Abuja (FCT)',
    'Lagos',
    'Rivers',
    'Kano',
    'Oyo',
    'Enugu',
    'Kaduna',
    'Other',
  ];

  @override
  void dispose() {
    _school.dispose();
    _age.dispose();
    super.dispose();
  }

  Map<String, Object?> get _profile => {
    'school': _school.text.trim(),
    'classYear': _classYear,
    'age': int.tryParse(_age.text.trim()),
    'gender': _gender,
    'country': _country,
    'state': _state,
  };

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
            .setProfile(uid: user.uid, profile: _profile);
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
  Future<void> _skip() {
    final hasAnything = _profile.values.any(
      (v) => v != null && v != '',
    );
    return _finish(save: hasAnything);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: OnboardingStep.profile,
      title: 'Tell us a bit about you',
      subtitle:
          'All optional — skip anything you would rather not share. It '
          'helps us shape the content, and you can edit it later.',
      errorText: _error,
      isLoading: _isSubmitting,
      primaryLabel: 'Save and finish',
      onPrimary: () => _finish(save: true),
      onSkip: _skip,
      skipLabel: 'Skip for now',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingTextField(
            controller: _school,
            label: 'SCHOOL',
            hintText: 'Optional',
          ),
          const SizedBox(height: 18),
          _Dropdown(
            label: 'CLASS / YEAR',
            value: _classYear,
            items: _classYears,
            onChanged: (v) => setState(() => _classYear = v),
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            controller: _age,
            label: 'AGE',
            hintText: 'Optional',
            keyboardType: TextInputType.number,
            maxLength: 2,
          ),
          const SizedBox(height: 18),
          _Dropdown(
            label: 'GENDER',
            value: _gender,
            items: _genders,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 18),
          _Dropdown(
            label: 'COUNTRY',
            value: _country,
            items: _countries,
            onChanged: (v) => setState(() => _country = v),
          ),
          const SizedBox(height: 18),
          _Dropdown(
            label: 'STATE',
            value: _state,
            items: _states,
            onChanged: (v) => setState(() => _state = v),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceDark,
          hint: Text(
            'Optional',
            style: AppTheme.bodyLg.copyWith(
              color: AppColors.textSecondaryDark.withAlpha(
                (0.6 * 255).round(),
              ),
            ),
          ),
          style: AppTheme.bodyLg.copyWith(color: AppColors.textPrimaryDark),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondaryDark,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
