import 'package:flutter/material.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/lessons/subject_index.dart';
import '../../../core/study/study_tool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/article_view.dart';
import '../glossary/glossary_tool.dart' show IndexPage;
import '../glossary/glossary_widgets.dart';
import '../../../core/theme/app_palette.dart';

/// The subject's formulas, grouped by topic. Built from the formula boxes
/// in its published lessons, like the glossary. Not allowed in the exam
/// hall — `subject_tools.dart` already keeps it out.
class FormulaSheetTool extends StudyTool {
  const FormulaSheetTool();

  @override
  StudyToolId get id => StudyToolId.formulaSheet;
  @override
  String get label => 'Formula sheet';
  @override
  IconData get icon => Icons.functions;
  @override
  StudyPanelMode get mode => StudyPanelMode.page;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      FormulaSheetScreen(subjectId: scope.subjectId, close: close);
}

const kFormulaSheetEmpty =
    'No formulas for this subject yet. They appear here as lessons are '
    'published.';

class FormulaSheetScreen extends StatelessWidget {
  const FormulaSheetScreen({super.key, required this.subjectId, this.close});

  final String subjectId;
  final VoidCallback? close;

  @override
  Widget build(BuildContext context) {
    return IndexPage(
      subjectId: subjectId,
      hint: 'Search formulas or topics',
      empty: kFormulaSheetEmpty,
      builder: (index, query) {
        final topics = [
          for (final t in index.topics.values)
            if (t.formulas.isNotEmpty) t,
        ];
        if (topics.isEmpty) return null;
        topics.sort(
          (a, b) =>
              a.topicName.toLowerCase().compareTo(b.topicName.toLowerCase()),
        );
        final out = <Widget>[];
        for (final t in topics) {
          final topicMatches =
              query.isNotEmpty && t.topicName.toLowerCase().contains(query);
          final shown = [
            for (final f in t.formulas)
              if (query.isEmpty ||
                  topicMatches ||
                  f.title.toLowerCase().contains(query))
                f,
          ];
          if (shown.isEmpty) continue;
          out.add(
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(
                t.topicName.isEmpty ? t.topicId : t.topicName,
                style: AppTheme.label.copyWith(color: AppColors.primary),
              ),
            ),
          );
          for (final f in shown) {
            out.add(_FormulaEntry(formula: f, close: close));
          }
        }
        return out;
      },
    );
  }
}

class _FormulaEntry extends StatelessWidget {
  const _FormulaEntry({required this.formula, this.close});

  final IndexedFormula formula;
  final VoidCallback? close;

  @override
  Widget build(BuildContext context) {
    final f = formula;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            f.title,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ArticleView(body: f.body),
          if (f.resourceId.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: IndexSourceLine(
                topicName: '',
                onOpen: () => openIndexedLesson(
                  context,
                  topicId: f.topicId,
                  resourceId: f.resourceId,
                  close: close,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
