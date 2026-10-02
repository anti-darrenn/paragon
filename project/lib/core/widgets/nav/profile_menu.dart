import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../user_avatar.dart';

/// The avatar at the end of the top bar, and the menu it opens: the
/// student's profile and settings, the studio for the content team, and
/// signing out. On a phone the same things are reached through the Me
/// tab.
///
/// A guest is offered "Save your progress" instead of "Sign out":
/// signing a guest out would abandon everything they have done, with no
/// way back in.
class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final isStaff = ref.watch(staffRoleProvider).canWrite;
    final data = ref.watch(userDataProvider).asData?.value;
    final name = (data?['displayName'] as String?)?.trim();
    final username = (data?['username'] as String?)?.trim();

    void go(String path) => context.push(path);

    MenuItemButton item(
      IconData icon,
      String label,
      VoidCallback onPressed, {
      Color? color,
      Key? key,
    }) => MenuItemButton(
      key: key,
      leadingIcon: Icon(
        icon,
        size: 18,
        color: color ?? context.palette.textSecondary,
      ),
      onPressed: onPressed,
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(240, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(
        label,
        style: AppTheme.bodyMd.copyWith(
          color: color ?? context.palette.textPrimary,
        ),
      ),
    );

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.palette.border),
          ),
        ),
      ),
      menuChildren: [
        // Who is signed in, so a shared family computer is not a puzzle.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              const UserAvatar(size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGuest
                        ? 'Guest'
                        : (name == null || name.isEmpty ? 'Student' : name),
                    style: AppTheme.bodyMd.copyWith(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isGuest
                        ? 'Progress is kept on this session'
                        : (username == null || username.isEmpty
                              ? ''
                              : '@$username'),
                    style: AppTheme.label.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.palette.border),
        const SizedBox(height: 4),
        if (isGuest)
          item(
            Icons.cloud_upload_outlined,
            'Save your progress',
            () => go('/account/upgrade'),
            color: AppColors.primary,
            key: const ValueKey('menu.upgrade'),
          ),
        item(Icons.person_outline_rounded, 'Your profile', () => go('/me')),
        item(Icons.bookmark_outline_rounded, 'Saved', () => go('/saved')),
        item(Icons.settings_outlined, 'Settings', () => go('/settings')),
        item(
          Icons.text_fields_rounded,
          'Reading & display',
          () => go('/settings/reading'),
        ),
        if (isStaff)
          item(
            Icons.edit_note_rounded,
            'Content studio',
            () => go('/admin'),
            key: const ValueKey('menu.studio'),
          ),
        item(Icons.info_outline_rounded, 'About Paragon', () => go('/about')),
        if (!isGuest) ...[
          const SizedBox(height: 4),
          Divider(height: 1, color: context.palette.border),
          const SizedBox(height: 4),
          item(
            Icons.logout_rounded,
            'Sign out',
            () => FirebaseAuth.instance.signOut(),
            key: const ValueKey('menu.signOut'),
          ),
        ],
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Your account',
        child: InkResponse(
          key: const ValueKey('topbar.avatar'),
          radius: 22,
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: controller.isOpen
                    ? AppColors.primary
                    : context.palette.border,
                width: 1.5,
              ),
            ),
            child: const UserAvatar(size: 30),
          ),
        ),
      ),
    );
  }
}
