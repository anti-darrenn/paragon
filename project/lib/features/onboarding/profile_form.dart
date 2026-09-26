import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_scaffold.dart';
import '../../core/theme/app_palette.dart';

/// The optional-profile form, shared by the onboarding step that first
/// asks for it and the settings screen that edits it afterwards.
///
/// Extracted rather than duplicated for the same reason as the subject
/// tile: the settings screen exists *because* onboarding promised it, so
/// the two showing different fields would be the specific way this feature
/// fails. Adding a field here adds it to both, and — since this is data
/// about students who are largely minors — obliges a matching change to
/// `legal_documents.dart`, which enumerates every one of these fields.
///
/// State lives in [ProfileFormController] so either screen can own it
/// without either owning the layout.
class ProfileFormController {
  final school = TextEditingController();
  final age = TextEditingController();

  String? classYear;
  String? gender;
  String? country;
  String? state;

  static const classYears = ['JSS3', 'SS1', 'SS2', 'SS3', 'Graduate', 'Other'];
  static const genders = ['Female', 'Male', 'Prefer not to say'];
  static const countries = ['Nigeria', 'Ghana', 'Other'];

  // Placeholder list — the full 36 states + FCT belong in a data file, not
  // inline here, and only matter once country == Nigeria drives the list.
  static const states = [
    'Abuja (FCT)',
    'Lagos',
    'Rivers',
    'Kano',
    'Oyo',
    'Enugu',
    'Kaduna',
    'Other',
  ];

  /// Fills the form from a stored `users/{uid}.profile` map.
  ///
  /// A stored value that is no longer one of the options above — a state
  /// list that has since changed, say — is dropped rather than shown,
  /// because `DropdownButtonFormField` throws on a value absent from its
  /// items. Losing one field on screen is better than a screen that will
  /// not build.
  void hydrate(Object? stored) {
    if (stored is! Map) return;
    school.text = _string(stored['school']);
    age.text = _string(stored['age']);
    classYear = _oneOf(stored['classYear'], classYears);
    gender = _oneOf(stored['gender'], genders);
    country = _oneOf(stored['country'], countries);
    state = _oneOf(stored['state'], states);
  }

  /// What the form currently holds, in the stored shape. Blank entries are
  /// null so callers can tell "left empty" from "set to something".
  Map<String, Object?> toProfile() => {
    'school': school.text.trim().isEmpty ? null : school.text.trim(),
    'classYear': classYear,
    'age': int.tryParse(age.text.trim()),
    'gender': gender,
    'country': country,
    'state': state,
  };

  bool get isEmpty => toProfile().values.every((v) => v == null || v == '');

  void dispose() {
    school.dispose();
    age.dispose();
  }

  static String _string(Object? v) => v == null ? '' : '$v';

  static String? _oneOf(Object? v, List<String> options) =>
      v is String && options.contains(v) ? v : null;
}

/// The fields themselves. [onChanged] is called whenever a dropdown moves,
/// so the owning screen can rebuild.
class ProfileFormFields extends StatelessWidget {
  const ProfileFormFields({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final ProfileFormController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingTextField(
          controller: controller.school,
          label: 'SCHOOL',
          hintText: 'Optional',
        ),
        const SizedBox(height: 18),
        _Dropdown(
          label: 'CLASS / YEAR',
          value: controller.classYear,
          items: ProfileFormController.classYears,
          onChanged: (v) {
            controller.classYear = v;
            onChanged();
          },
        ),
        const SizedBox(height: 18),
        OnboardingTextField(
          controller: controller.age,
          label: 'AGE',
          hintText: 'Optional',
          keyboardType: TextInputType.number,
          maxLength: 2,
        ),
        const SizedBox(height: 18),
        _Dropdown(
          label: 'GENDER',
          value: controller.gender,
          items: ProfileFormController.genders,
          onChanged: (v) {
            controller.gender = v;
            onChanged();
          },
        ),
        const SizedBox(height: 18),
        _Dropdown(
          label: 'COUNTRY',
          value: controller.country,
          items: ProfileFormController.countries,
          onChanged: (v) {
            controller.country = v;
            onChanged();
          },
        ),
        const SizedBox(height: 18),
        _Dropdown(
          label: 'STATE',
          value: controller.state,
          items: ProfileFormController.states,
          onChanged: (v) {
            controller.state = v;
            onChanged();
          },
        ),
      ],
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
          style: AppTheme.label.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: context.palette.surface,
          hint: Text(
            'Optional',
            style: AppTheme.bodyLg.copyWith(
              color: context.palette.textSecondary.withAlpha(
                (0.6 * 255).round(),
              ),
            ),
          ),
          style: AppTheme.bodyLg.copyWith(color: context.palette.textPrimary),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.palette.textSecondary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.palette.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.palette.border),
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
