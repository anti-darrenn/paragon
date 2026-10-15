import 'package:flutter/material.dart';

import '../data/quota_status.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// "Paragon is very busy today", shown above every route while Firestore's
/// daily quota is spent (see [QuotaStatus]).
///
/// The tree has the same shape whether or not the banner shows: the strip
/// collapses to zero height instead of being removed, because inserting a
/// parent above the navigator would rebuild every page and restart a
/// lesson video.
class QuotaBanner extends StatelessWidget {
  const QuotaBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: QuotaStatus.instance,
          builder: (context, spent, _) => AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: spent
                ? const _Strip()
                : const SizedBox(width: double.infinity),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.palette.border)),
          ),
          child: Text(
            quotaSpentMessage(),
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Also used by `LoadError`, so a screen that failed for this reason says
/// the same thing as the banner instead of "check your connection".
String quotaSpentMessage([DateTime? now]) {
  final reset = quotaResetUtc(now ?? DateTime.now()).toLocal();
  final h = reset.hour % 12 == 0 ? 12 : reset.hour % 12;
  final m = reset.minute.toString().padLeft(2, '0');
  final ampm = reset.hour < 12 ? 'am' : 'pm';
  return 'Paragon is very busy today and has reached its daily limit. '
      'It will be back by $h:$m $ampm. Lessons you have already opened '
      'may still work.';
}
