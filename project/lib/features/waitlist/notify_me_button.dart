import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/waitlist_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';

/// "Notify me" on a coming-soon subject. Adds its catalog slug to the
/// student's `waitlist/{uid}`; the studio counts sign-ups per subject,
/// which is how the team decides what to write next.
///
/// A guest has no address to be reached at, so they are sent to make an
/// account (linking keeps everything they have done).
class NotifyMeButton extends ConsumerStatefulWidget {
  const NotifyMeButton({
    super.key,
    required this.slug,
    required this.subjectName,
  });

  final String slug;
  final String subjectName;

  @override
  ConsumerState<NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends ConsumerState<NotifyMeButton> {
  bool _busy = false;

  Future<void> _toggle(Set<String> current, bool wanted) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(waitlistRepositoryProvider)
          .set(user.uid, current, widget.slug, wanted: wanted);
      if (wanted) {
        ref.read(analyticsProvider).waitlistJoin(subject: widget.slug);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final mine = ref.watch(myWaitlistProvider).asData?.value ?? const {};
    final onList = mine.contains(widget.slug);

    if (isGuest) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/account/upgrade'),
        icon: const Icon(Icons.notifications_none_rounded, size: 18),
        label: const Text('Make an account to be told when it is ready'),
      );
    }

    if (onList) {
      return Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            size: 18,
            color: AppColors.correct,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're on the list for ${widget.subjectName}.",
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => _toggle(mine, false),
            child: const Text('Leave list'),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _busy ? null : () => _toggle(mine, true),
      icon: const Icon(Icons.notifications_none_rounded, size: 18),
      label: Text('Notify me when ${widget.subjectName} is ready'),
    );
  }
}
