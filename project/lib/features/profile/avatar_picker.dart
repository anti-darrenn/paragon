import 'package:flutter/material.dart';

import '../../core/models/avatar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';

/// Choose a preset or an initials colour. Used by Edit profile and by the
/// onboarding avatar step, so both offer exactly the same choices.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.initials,
    required this.onChanged,
  });

  final Avatar selected;
  final String initials;
  final ValueChanged<Avatar> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PICTURES',
          style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in AvatarPreset.all)
              _Choice(
                avatar: Avatar.forPreset(preset),
                initials: initials,
                isSelected: selected == Avatar.forPreset(preset),
                label: 'Picture: ${preset.id}',
                onTap: onChanged,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'OR YOUR INITIALS',
          style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final key in AppColors.avatarSwatches.keys)
              _Choice(
                avatar: Avatar.initials(key),
                initials: initials,
                isSelected: selected == Avatar.initials(key),
                label: 'Initials on $key',
                onTap: onChanged,
              ),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.avatar,
    required this.initials,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final Avatar avatar;
  final String initials;
  final bool isSelected;
  final String label;
  final ValueChanged<Avatar> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: () => onTap(avatar),
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.textPrimaryDark : Colors.transparent,
              width: 2,
            ),
          ),
          child: AvatarDisc(avatar: avatar, initials: initials, size: 44),
        ),
      ),
    );
  }
}
