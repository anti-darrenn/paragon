import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/lessons/subject_index.dart';
import '../../../core/repositories/subject_index_repository.dart';
import '../../../core/study/study_tool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/article_view.dart';
import 'glossary_widgets.dart';

/// The subject's glossary, A–Z. Built from the definitions in its
/// published lessons (`subjectIndex/{subjectId}`), so it grows as lessons
/// are written and never says anything a lesson does not.
class GlossaryTool extends StudyTool {
  const GlossaryTool();

  @override
  StudyToolId get id => StudyToolId.glossary;
  @override
  String get label => 'Glossary';
  @override
  IconData get icon => Icons.menu_book_outlined;
  @override
  StudyPanelMode get mode => StudyPanelMode.page;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      GlossaryScreen(subjectId: scope.subjectId, close: close);
}

const kGlossaryEmpty =
    'No terms are defined for this subject yet. They appear here as '
    'lessons are published.';

/// Page body shared by the glossary and formula sheet: a search box over a
/// list, with loading, error and empty states.
class IndexPage extends ConsumerStatefulWidget {
  const IndexPage({
    super.key,
    required this.subjectId,
    required this.hint,
    required this.empty,
    required this.builder,
  });

  final String subjectId;
  final String hint;
  final String empty;

  /// The list for [query] (lower-cased, trimmed), or null when [index]
  /// holds nothing of this kind at all.
  final List<Widget>? Function(SubjectIndex index, String query) builder;

  @override
  ConsumerState<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends ConsumerState<IndexPage> {
  String _query = '';

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTheme.bodyMd.copyWith(color: AppColors.textSecondaryDark),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.subjectId.isEmpty) return _message(widget.empty);
    final async = ref.watch(subjectIndexProvider(widget.subjectId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          _message("Couldn't load this. Check your connection and try again."),
      data: (index) {
        final items = widget.builder(index, _query.trim().toLowerCase());
        if (items == null) return _message(widget.empty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: const ValueKey('index.search'),
                onChanged: (v) => setState(() => _query = v),
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? _message('Nothing matches “${_query.trim()}”.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: items,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key, required this.subjectId, this.close});

  final String subjectId;

  /// Closes the page before a lesson is opened from it.
  final VoidCallback? close;

  static String _letter(String term) {
    final t = term.trim();
    if (t.isEmpty) return '#';
    final c = t[0].toUpperCase();
    return RegExp('[A-Z]').hasMatch(c) ? c : '#';
  }

  @override
  Widget build(BuildContext context) {
    return IndexPage(
      subjectId: subjectId,
      hint: 'Search terms',
      empty: kGlossaryEmpty,
      builder: (index, query) {
        final all = index.definitions;
        if (all.isEmpty) return null;
        final shown = [
          for (final d in all)
            if (query.isEmpty || d.term.toLowerCase().contains(query)) d,
        ];
        final out = <Widget>[];
        String? letter;
        for (final d in shown) {
          final l = _letter(d.term);
          if (l != letter) {
            letter = l;
            out.add(
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(
                  l,
                  style: AppTheme.label.copyWith(color: AppColors.primary),
                ),
              ),
            );
          }
          out.add(_DefinitionEntry(definition: d, close: close));
        }
        return out;
      },
    );
  }
}

class _DefinitionEntry extends StatelessWidget {
  const _DefinitionEntry({required this.definition, this.close});

  final IndexedDefinition definition;
  final VoidCallback? close;

  @override
  Widget build(BuildContext context) {
    final d = definition;
    return Padding(
      key: ValueKey('glossary.entry.${d.topicId}.${d.term}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            d.term,
            style: AppTheme.heading3.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 4),
          ArticleView(body: d.body),
          IndexSourceLine(
            topicName: d.topicName,
            onOpen: d.resourceId.isEmpty
                ? null
                : () => openIndexedLesson(
                    context,
                    topicId: d.topicId,
                    resourceId: d.resourceId,
                    close: close,
                  ),
          ),
          const Divider(color: AppColors.borderDark),
        ],
      ),
    );
  }
}
