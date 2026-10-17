import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/questions/question_draft.dart';
import '../../../core/repositories/admin_flag_repository.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import '../../../core/widgets/question_source_badge.dart' show DifficultyBadge;
import '../admin_paths.dart';

/// Pieces every question list in the studio shares: the browser, the
/// report queue and the content-quality findings.

/// Opens the workbench on [id], remembering [list] so it can step through
/// the rest with Previous and Next.
void openQuestion(
  BuildContext context,
  WidgetRef ref,
  String id, {
  List<String> list = const [],
}) {
  ref.read(studioWorkListProvider.notifier).set(list.isEmpty ? [id] : list);
  context.push(adminQuestionPath(id));
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
    final answer = q.correctIndex >= 0 && q.correctIndex < q.options.length
        ? optionLetter(q.correctIndex)
        : null;

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: findings.any((f) => f.$2 != 'B') || openReports > 0
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
                        for (final (rule, level) in findings.take(3))
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
