import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../repositories/flag_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// "Report a problem" affordance shown wherever a student can see an answer.
///
/// Answers come from a third-party question bank, not an official WAEC key,
/// and spot-checking measured a low-single-digit error rate. Students
/// disagreeing with an answer is how those get found, so the wording invites
/// it rather than treating a report as an edge case.
class ReportProblemButton extends ConsumerStatefulWidget {
  const ReportProblemButton({super.key, required this.questionId});

  final String questionId;

  @override
  ConsumerState<ReportProblemButton> createState() => _ReportProblemButtonState();
}

class _ReportProblemButtonState extends ConsumerState<ReportProblemButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _report(FlagReason reason) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(flagRepositoryProvider).create(
            userId: user.uid,
            questionId: widget.questionId,
            reason: reason,
          );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send your report. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openSheet() async {
    final reason = await showModalBottomSheet<FlagReason>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                "What's wrong with this question?",
                style: TextStyle(
                  color: context.palette.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Our answers come from a public question bank, so some are wrong. '
                'Telling us is how they get fixed.',
                style: TextStyle(color: context.palette.onMedium, fontSize: 13),
              ),
            ),
            for (final reason in FlagReason.values)
              ListTile(
                title: Text(
                  reason.label,
                  style: TextStyle(color: context.palette.onHigh, fontSize: 14),
                ),
                onTap: () => Navigator.of(sheetContext).pop(reason),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (reason != null) await _report(reason);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: AppColors.correct),
          SizedBox(width: 6),
          Text(
            'Thanks — we\'ll check it',
            style: TextStyle(color: AppColors.correct, fontSize: 12),
          ),
        ],
      );
    }

    return TextButton.icon(
      onPressed: _sending ? null : _openSheet,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(Icons.flag_outlined, size: 14, color: context.palette.onLow),
      label: Text(
        'Answer look wrong? Report a problem',
        style: TextStyle(color: context.palette.onLow, fontSize: 12),
      ),
    );
  }
}
