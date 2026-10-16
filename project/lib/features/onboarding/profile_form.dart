import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_scaffold.dart';
import '../../core/theme/app_palette.dart';

/// The optional-profile form, shared by the onboarding step that first
/// asks for it and the settings screen that edits it afterwards: school
/// and class only. They tell the team which schools and classes use
/// Paragon (for working with schools and pitching content at the right
/// level); nothing in the app is gated on them.
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

  String? classYear;

  static const classYears = ['JSS3', 'SS1', 'SS2', 'SS3', 'Graduate', 'Other'];

  /// Fields Paragon used to ask for and stopped asking for on 2026-10-15
  /// (the owner's decision: data about minors with no reader). [toProfile]
  /// lists them as blank so the settings editor's save deletes any value
  /// still stored; `jobs.js --job=dropprofile` removes the rest.
  static const retiredFields = ['age', 'gender', 'country', 'state'];

  /// Fills the form from a stored `users/{uid}.profile` map.
  ///
  /// A stored class that is no longer one of the options is dropped rather
  /// than shown, because `DropdownButtonFormField` throws on a value absent
  /// from its items. Retired fields are ignored.
  void hydrate(Object? stored) {
    if (stored is! Map) return;
    school.text = _string(stored['school']);
    classYear = _oneOf(stored['classYear'], classYears);
  }

  /// What the form currently holds, in the stored shape. Blank entries are
  /// null so callers can tell "left empty" from "set to something"; the
  /// retired fields are always null, which deletes them on an editor save
  /// and is ignored by onboarding's partial save.
  Map<String, Object?> toProfile() => {
    'school': school.text.trim().isEmpty ? null : school.text.trim(),
    'classYear': classYear,
    for (final f in retiredFields) f: null,
  };

  bool get isEmpty => toProfile().values.every((v) => v == null || v == '');

  void dispose() {
    school.dispose();
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
          // firestore.rules refuses a longer one.
          maxLength: 100,
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
