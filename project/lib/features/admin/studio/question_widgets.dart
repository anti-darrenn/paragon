import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/questions/question_draft.dart';
import '../../../core/repositories/admin_flag_repository.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/models/topic.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import '../../../core/widgets/question_source_badge.dart' show DifficultyBadge;
import '../admin_paths.dart';
import 'launch_panels.dart' show contentAuditProvider;

/// Pieces every question list in the studio shares: the browser, the
/// report queue and the content-quality findings.

/// Every topic of a subject, in course order, for the topic picker.
final subjectTopicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  subjectId,
) async {
  final units = await ref.watch(unitsProvider(subjectId).future);
  return [
    for (final u in units) ...await ref.watch(topicsProvider(u.id).future),
  ];
});

/// Opens the workbench on [id], remembering [list] so it can step through
/// the rest with Previous and Next.
/// Completes when the workbench is closed, so a list can refresh what was
/// edited there.
Future<void> openQuestion(
  BuildContext context,
  WidgetRef ref,
  String id, {
  List<String> list = const [],
}) async {
  ref.read(studioWorkListProvider.notifier).set(list.isEmpty ? [id] : list);
  await context.push(adminQuestionPath(id));
}

/// A small outlined label: "WAEC 2018", "Retired", "3 reports".
class StudioTag extends StatelessWidget {
  const StudioTag(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(22),
        border: Border.all(color: c.withAlpha(110)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a question comes from, as a tag.
String questionOriginLabel(ReviewedQuestion q) {
  final question = q.question;
  if (q.isGenerated) return 'Paragon practice';
  if (question.source == 'waec') {
    return question.year == null ? 'WAEC' : 'WAEC ${question.year}';
  }
  return 'Authored';
}

/// One question in a list: where it is from, its stem (maths drawn, a few
/// lines at most), its options and marked answer, and anything wrong.
class QuestionListCard extends ConsumerWidget {
  const QuestionListCard({
    super.key,
    required this.question,
    required this.onTap,
    this.findings = const [],
    this.openReports = 0,
  });

  final ReviewedQuestion question;
  final VoidCallback onTap;

  /// Content-audit rules this question breaks (`rule`, level).
  final List<(String, String)> findings;
  final int openReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = question.question;
    final palette = context.palette;
    final topic = ref.watch(topicByIdProvider(q.topicId)).asData?.value;
    // A finding the question was saved or marked checked after is shown as
    // fixed, not as still wrong.
    final audit = ref.watch(contentAuditProvider).asData?.value;
    final live = [
      for (final f in findings)
        if (audit == null || !audit.isCleared(question, f.$1)) f,
    ];
    final fixed = findings.length - live.length;
    final answer = q.correctIndex >= 0 && q.correctIndex < q.options.length
        ? optionLetter(q.correctIndex)
        : null;

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: live.any((f) => f.$2 != 'B') || openReports > 0
              ? AppColors.warning.withAlpha(150)
              : palette.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StudioTag(
                          questionOriginLabel(question),
                          color: question.isGenerated
                              ? AppColors.accentBlue
                              : AppColors.primary,
                        ),
                        if (topic != null) StudioTag(topic.name),
                        DifficultyBadge(tier: q.tier, estimated: !q.tierIsSet),
                        if (!question.hasAnswer)
                          const StudioTag(
                            'Hidden from students',
                            color: AppColors.wrong,
                            icon: Icons.visibility_off_outlined,
                          ),
                        if (openReports > 0)
                          StudioTag(
                            '$openReports report${openReports == 1 ? '' : 's'}',
                            color: AppColors.warning,
                            icon: Icons.flag_outlined,
                          ),
                        if (fixed > 0 && live.isEmpty)
                          const StudioTag(
                            'Fixed since the audit',
                            color: AppColors.correct,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        for (final (rule, level) in live.take(3))
                          StudioTag(
                            rule.replaceAll('-', ' '),
                            color: level == 'B'
                                ? palette.textSecondary
                                : AppColors.wrong,
                            icon: Icons.error_outline_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // A few lines of the real thing, maths drawn, faded
                    // rather than cut mid-line.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 76),
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, 0.7, 1],
                        ).createShader(r),
                        blendMode: BlendMode.dstIn,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: FullLatexView(
                            latex: q.text,
                            textStyle: AppTheme.bodyMd.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${q.options.length} options',
                        answer == null ? 'no answer marked' : 'answer $answer',
                        if (q.explanation.trim().isEmpty) 'no explanation',
                      ].join(' · '),
                      style: AppTheme.caption.copyWith(
                        color: answer == null
                            ? AppColors.wrong
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list's loading and empty states, the same everywhere in the studio.
class StudioListSkeleton extends StatelessWidget {
  const StudioListSkeleton({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.border),
            ),
          ),
        ),
    ],
  );
}

/// The question's content as stored, for a write that changes nothing in
/// it (marking a finding checked writes the content back unchanged, as
/// the edit rule requires).
QuestionDraft storedDraftOf(ReviewedQuestion q) => QuestionDraft(
  text: q.question.text,
  options: q.question.options,
  correctIndex: q.question.correctIndex,
  explanation: q.question.explanation,
  hasAnswer: q.hasAnswer,
  difficulty: q.question.difficulty,
  alsoTopicIds: q.question.alsoTopicIds,
);

/// Asks why a content-audit finding is not a problem. The answer goes on
/// the question's history. [initialNote] fills the box, selected, so a
/// quick dismissal from a list is one Enter.
class MarkCheckedDialog extends StatefulWidget {
  const MarkCheckedDialog({super.key, required this.rule, this.initialNote});
  final String rule;
  final String? initialNote;

  @override
  State<MarkCheckedDialog> createState() => _MarkCheckedDialogState();
}

class _MarkCheckedDialogState extends State<MarkCheckedDialog> {
  late final _note = TextEditingController(text: widget.initialNote)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialNote?.length ?? 0,
    );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done() {
    if (_note.text.trim().length >= 3) {
      Navigator.of(context).pop(_note.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark "${widget.rule.replaceAll('-', ' ')}" checked'),
      content: TextField(
        controller: _note,
        autofocus: true,
        maxLength: 300,
        decoration: const InputDecoration(
          labelText: 'Why it is not a problem',
          hintText: 'e.g. Checked against the 2018 paper: 0.612 is as printed',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _note.text.trim().length < 3 ? null : _done,
          child: const Text('Mark checked'),
        ),
      ],
    );
  }
}

/// "Nothing wrong" on a question in a findings list: marks the audit's
/// [rule] checked on [q] without opening the workbench. The same write as
/// the workbench's "Mark checked", history and all, so the audit skips it
/// from then on. True when it was saved.
Future<bool> dismissFinding(
  BuildContext context,
  WidgetRef ref,
  ReviewedQuestion q,
  String rule,
) async {
  final uid = ref.read(currentUserProvider)?.uid;
  if (uid == null) return false;
  final note = await showDialog<String>(
    context: context,
    builder: (_) => MarkCheckedDialog(
      rule: rule,
      initialNote: 'Looked at it in the studio: nothing wrong.',
    ),
  );
  if (note == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(adminQuestionRepositoryProvider)
        .markChecked(
          questionId: q.question.id,
          current: storedDraftOf(q),
          rule: rule,
          note: note,
          uid: uid,
        );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Dismissed. The audit will skip it from now on.'),
      ),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text("Couldn't dismiss: $e")));
    return false;
  }
}
