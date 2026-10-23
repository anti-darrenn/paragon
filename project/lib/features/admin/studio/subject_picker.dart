import 'package:flutter/material.dart';

import '../../../core/models/subject.dart';
import '../../../core/theme/app_colors.dart';

/// The studio's one subject picker: a chip per subject with its colour,
/// the chosen one selected. It replaced three (a dropdown on Lessons,
/// plain chips on the Question bank, a dropdown in the question browser).
///
/// [readOnly] marks subjects outside the account's own, which it can open
/// but not change.
class StudioSubjectPicker extends StatelessWidget {
  const StudioSubjectPicker({
    super.key,
    required this.subjects,
    required this.selected,
    required this.onSelected,
    this.readOnly,
  });

  final List<Subject> subjects;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool Function(String subjectId)? readOnly;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in subjects)
          ChoiceChip(
            avatar: CircleAvatar(
              radius: 5,
              backgroundColor: AppColors.forSubject(s.name),
            ),
            label: Text(
              readOnly?.call(s.id) ?? false ? '${s.name} (read-only)' : s.name,
            ),
            selected: s.id == selected,
            onSelected: (_) => onSelected(s.id),
          ),
      ],
    );
  }
}
