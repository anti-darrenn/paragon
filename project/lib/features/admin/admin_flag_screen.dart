import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/repositories/admin_flag_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/math_text.dart';
import '../../core/theme/app_palette.dart';

/// Deep link to one flagged question. The report digest email links here;
/// keep `tools/admin/notify_drafts.js` in step if it changes.
String adminFlagPath(String questionId) => '/admin/flag/$questionId';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];
String _letter(int i) => i >= 0 && i < _letters.length ? _letters[i] : '#$i';

/// `/admin/flag/:questionId`: one question, every report on it, and the
/// three ways to resolve them: change the answer, retire the question, or
/// dismiss the reports because the answer is right.
///
/// Every change is written through `AdminFlagRepository`, which the rules
/// refuse without the `admin` claim.
class AdminFlagScreen extends ConsumerStatefulWidget {
  const AdminFlagScreen({super.key, required this.questionId});

  final String questionId;

  @override
  ConsumerState<AdminFlagScreen> createState() => _AdminFlagScreenState();
}

class _AdminFlagScreenState extends ConsumerState<AdminFlagScreen> {
  /// The option picked as the new answer; null until one is tapped.
  int? _picked;
  bool _busy = false;

  Future<void> _run(
    String done,
    Future<void> Function(AdminFlagRepository repo, String uid) action,
  ) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(adminFlagRepositoryProvider), uid);
      ref.invalidate(adminFlaggedQuestionProvider(widget.questionId));
      ref.invalidate(adminFlagQueueProvider);
      if (!mounted) return;
      setState(() => _picked = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRetire(FlaggedQuestion row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: const Text('Retire this question?'),
        content: const Text(
          'Students will stop seeing it in drill, WAEC exams, topic tests '
          'and exercises. Marking an answer later brings it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retire'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
        'Question retired',
        (repo, uid) => repo.retire(row: row, uid: uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminFlaggedQuestionProvider(widget.questionId));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: const Text('Problem report')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "Couldn't load this question.\n$e",
              style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
            ),
          ),
          data: (row) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                  child: _body(row),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(FlaggedQuestion row) {
    final q = row.question;
    final secondary = AppTheme.bodyMd.copyWith(
      color: context.palette.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportSummary(row: row),
        const SizedBox(height: 24),
        if (q == null) ...[
          Text(
            'This question no longer exists. Its reports can still be '
            'dismissed.',
            style: secondary,
          ),
        ] else ...[
          _QuestionHeader(question: q),
          const SizedBox(height: 16),
          MathText(
            text: q.question.text,
            style: AppTheme.bodyLg.copyWith(color: context.palette.textPrimary),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < q.question.options.length; i++)
            _OptionRow(
              letter: _letter(i),
              text: q.question.options[i],
              isAnswer: i == q.question.correctIndex,
              isPicked: i == _picked,
              onTap: _busy ? null : () => setState(() => _picked = i),
            ),
          if (q.question.explanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'EXPLANATION',
              style: AppTheme.label.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            MathText(text: q.question.explanation, style: secondary),
          ],
          const SizedBox(height: 8),
          Text(
            q.question.correctIndex < 0
                ? 'No answer is marked. Tap an option to set one.'
                : 'Tap an option to mark it as the answer instead.',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _actions(row),
      ],
    );
  }

  Widget _actions(FlaggedQuestion row) {
    final q = row.question;
    final picked = _picked;
    final canChange =
        q != null && picked != null && picked != q.question.correctIndex;
    final previous = q?.previousCorrectIndex;
    final canRevert =
        q != null &&
        previous != null &&
        previous >= 0 &&
        previous < q.question.options.length &&
        previous != q.question.correctIndex;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton(
          onPressed: _busy || !canChange
              ? null
              : () => _run(
                  'Answer changed to ${_letter(picked)}',
                  (repo, uid) =>
                      repo.changeAnswer(row: row, newIndex: picked, uid: uid),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(
            canChange
                ? 'Mark ${_letter(picked)} as the answer'
                : 'Change answer',
          ),
        ),
        OutlinedButton(
          onPressed: _busy || !row.isOpen
              ? null
              : () => _run(
                  'Reports dismissed',
                  (repo, uid) => repo.dismiss(row: row, uid: uid),
                ),
          child: const Text('Answer is right, dismiss'),
        ),
        if (q != null && q.hasAnswer)
          OutlinedButton(
            onPressed: _busy ? null : () => _confirmRetire(row),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.wrong),
            child: const Text('Retire question'),
          ),
        if (canRevert)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                    'Reverted to ${_letter(previous)}',
                    (repo, uid) => repo.changeAnswer(
                      row: row,
                      newIndex: previous,
                      uid: uid,
                    ),
                  ),
            child: Text('Revert to previous answer (${_letter(previous)})'),
          ),
      ],
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.row});

  final FlaggedQuestion row;

  @override
  Widget build(BuildContext context) {
    final open = row.openReports.length;
    final closed = row.reports.length - open;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open == 0
                ? 'No open reports'
                : '$open open report${open == 1 ? '' : 's'}',
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final (reason, count) in row.openReasonCounts)
            Text(
              '$count × ${reason.label}',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          if (closed > 0)
            Text(
              '$closed already resolved',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionHeader extends ConsumerWidget {
  const _QuestionHeader({required this.question});

  final ReviewedQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = question.question;
    final topic = ref.watch(topicByIdProvider(q.topicId)).asData?.value;
    final where = [
      topic?.name ?? q.topicId,
      if (q.year != null) '${q.source.toUpperCase()} ${q.year}',
    ].join(' · ');

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          where,
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        if (question.isGenerated)
          const _Tag(
            'Generated: fix the generator too',
            color: AppColors.warning,
          ),
        if (!question.hasAnswer)
          const _Tag('Not shown to students', color: AppColors.wrong),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: AppTheme.caption.copyWith(color: color)),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.letter,
    required this.text,
    required this.isAnswer,
    required this.isPicked,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool isAnswer;
  final bool isPicked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = isPicked
        ? AppColors.primary
        : isAnswer
        ? AppColors.correct
        : context.palette.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border.all(
              color: border,
              width: isPicked || isAnswer ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                letter,
                style: AppTheme.bodyMd.copyWith(
                  color: border == context.palette.border
                      ? context.palette.textSecondary
                      : border,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MathText(
                  text: text,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              if (isAnswer)
                Text(
                  'Marked answer',
                  style: AppTheme.caption.copyWith(color: AppColors.correct),
                )
              else if (isPicked)
                Text(
                  'New answer',
                  style: AppTheme.caption.copyWith(color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
