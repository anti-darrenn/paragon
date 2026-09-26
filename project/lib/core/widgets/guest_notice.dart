import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/guest_limits.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_palette.dart';

/// Tells a guest that what they are looking at is not being kept.
///
/// Deliberately not a blocker and not a modal. A guest session is a
/// legitimate way to use Paragon — the point is that a student watching a
/// mastery ring fill should know it will be gone when they close the tab,
/// not be stopped from filling it.
///
/// Uses `warning` rather than the error colour: nothing has gone wrong,
/// and a red banner on a working screen trains people to ignore banners.
class GuestNotice extends StatelessWidget {
  const GuestNotice({super.key, this.message});

  /// Defaults to the progress warning, which is the case that matters
  /// most. Pass something else where a screen has a more specific point
  /// to make.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha((0.08 * 255).round()),
        border: Border.all(
          color: AppColors.warning.withAlpha((0.35 * 255).round()),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ?? GuestLimits.progressNotKeptMessage,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // To the upgrade screen, not `/signin`: making an account there
          // links this guest's uid, so what the notice is warning about is
          // kept rather than left behind.
          TextButton(
            onPressed: () => context.push('/account/upgrade'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Keep it',
              style: AppTheme.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
