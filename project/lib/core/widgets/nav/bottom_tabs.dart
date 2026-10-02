import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../user_avatar.dart';
import 'nav_destinations.dart';

/// The phone navigation: five tabs along the bottom, in thumb reach. The
/// Me tab is the student's own avatar rather than a generic person icon.
class BottomTabs extends StatelessWidget {
  const BottomTabs({super.key, required this.current, required this.onSelect});

  final NavTab current;
  final ValueChanged<NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 64,
          backgroundColor: context.palette.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primary.withAlpha(36),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppTheme.navLabelActive.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
                  )
                : AppTheme.navLabelInactive.copyWith(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: current.index,
          onDestinationSelected: (i) => onSelect(NavTab.values[i]),
          destinations: [
            for (final tab in NavTab.values)
              NavigationDestination(
                key: ValueKey('tabs.${tab.name}'),
                label: tab.shortLabel,
                tooltip: tab.label,
                icon: tab == NavTab.me
                    ? const _AvatarIcon(selected: false)
                    : Icon(tab.icon, color: context.palette.textSecondary),
                selectedIcon: tab == NavTab.me
                    ? const _AvatarIcon(selected: true)
                    : Icon(tab.activeIcon, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  const _AvatarIcon({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: const UserAvatar(size: 22),
    );
  }
}
