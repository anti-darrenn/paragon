import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/questions/question_draft.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import '../../../core/widgets/math_field/math_field.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/ui/ui.dart';
import '../admin_paths.dart';
import 'founder_question_tools.dart';

/// `/admin/new-question`: the founder writes a question, typically from a
/// textbook, into the bank (2026-10-17).
///
/// The same checks as the workbench (`checkDraft`), Normal or LaTeX typing,
/// and the placement card for subject, topic, source and pictures. Saving
/// creates it **pending** (`foundersCreate` in the rules) and opens it in
/// the workbench, where it is approved like any other.
class NewQuestionScreen extends ConsumerStatefulWidget {
  const NewQuestionScreen({super.key, required this.subjectId, this.topicId});

  final String subjectId;
  final String? topicId;

  @override
  ConsumerState<NewQuestionScreen> createState() => _NewQuestionScreenState();
}

class _NewQuestionScreenState extends ConsumerState<NewQuestionScreen> {
  final _math = MathEditing(prefsKey: 'studio', initialMode: MathInputMode.latex);
  final _stem = TextEditingController();
  final _explanation = TextEditingController();
  final _options = [for (var i = 0; i < 4; i++) TextEditingController()];
  int _correct = -1;
  bool _busy = false;
  late QuestionPlacement _placement = QuestionPlacement(
    subjectId: widget.subjectId,
    topicId: widget.topicId ?? '',
    source: 'drill',
  );

  @override
  void initState() {
    super.initState();
    for (final c in [_stem, _explanation, ..._options]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_stem, _explanation, ..._options]) {
      c.dispose();
    }
    _math.dispose();
    super.dispose();
  }

  QuestionDraft get _draft => QuestionDraft(
    text: _stem.text,
    options: [for (final c in _options) c.text],
    correctIndex: _correct,
    explanation: _explanation.text,
    hasAnswer: true,
  );

  Future<void> _create() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(adminQuestionRepositoryProvider)
          .create(draft: _draft, placement: _placement, uid: uid);
      if (!mounted) return;
      ref.read(studioWorkListProvider.notifier).set([id]);
      context.pushReplacement(adminQuestionPath(id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!ref.watch(staffAccessProvider).isFounder) {
      return Scaffold(
        appBar: const ParagonAppBar(title: Text('Write a question')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'The question bank is the founder\'s',
          message: 'Questions are added to the bank by the founder.',
        ),
      );
    }
    final issues = checkDraft(_draft);
    final blocked = issues.any((i) => i.blocks);
    final placed =
        _placement.topicId.isNotEmpty &&
        (_placement.source != 'waec' || _placement.year != null);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ParagonAppBar(title: Text('Write a question')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  !placed
                      ? 'Choose a topic (and a year for a past paper).'
                      : blocked
                      ? issues.firstWhere((i) => i.blocks).message
                      : 'Saved as pending; you approve it next.',
                  style: AppTheme.caption.copyWith(
                    color: blocked || !placed
                        ? AppColors.warning
                        : palette.textSecondary,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _busy || blocked || !placed ? null : _create,
                child: const Text('Save to the bank'),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlacementCard(
                  value: _placement,
                  onChanged: (p) => setState(() => _placement = p),
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MathToolbar(editing: _math),
                      const SizedBox(height: 12),
                      _label('Question'),
                      MathField(
                        controller: _stem,
                        editing: _math,
                        minLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _label('Options: tap a letter to mark the answer'),
                      for (var i = 0; i < _options.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 8),
                                child: ChoiceChip(
                                  label: Text(optionLetter(i)),
                                  selected: _correct == i,
                                  onSelected: (_) =>
                                      setState(() => _correct = i),
                                ),
                              ),
                              Expanded(
                                child: MathField(
                                  controller: _options[i],
                                  editing: _math,
                                  hint: 'Option ${optionLetter(i)}',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove option ${optionLetter(i)}',
                                onPressed:
                                    _options.length <= QuestionDraft.minOptions
                                    ? null
                                    : () => setState(() {
                                        _options.removeAt(i).dispose();
                                        if (_correct == i) _correct = -1;
                                        if (_correct > i) _correct--;
                                      }),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                      if (_options.length < QuestionDraft.maxOptions)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              final c = TextEditingController();
                              c.addListener(() => setState(() {}));
                              _options.add(c);
                            }),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add an option'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _label('Worked answer'),
                      MathField(
                        controller: _explanation,
                        editing: _math,
                        minLines: 4,
                        hint: 'How to get the answer, step by step',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (issues.isNotEmpty)
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final i in issues)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              i.message,
                              style: AppTheme.bodyMd.copyWith(
                                color: i.blocks
                                    ? AppColors.wrong
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_stem.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionHeader('As students will see it'),
                  SurfaceCard(
                    child: FullLatexView(
                      latex: _stem.text,
                      textStyle: AppTheme.bodyLg.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppTheme.label.copyWith(
        color: context.palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
