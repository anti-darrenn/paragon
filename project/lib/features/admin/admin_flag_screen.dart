import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content/subject_catalog.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/questions/question_draft.dart';
import '../../core/repositories/admin_flag_repository.dart';
import '../../core/repositories/admin_question_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/web/browser.dart';
import '../../core/widgets/answer_option.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_image.dart';
import '../../core/widgets/ui/ui.dart';
import 'admin_paths.dart';
import 'studio/launch_panels.dart' show contentAuditProvider;
import 'studio/question_widgets.dart';
import 'studio/staff_profile.dart';

/// Deep link to one flagged question. The report digest email links here;
/// keep `tools/admin/notify_drafts.js` in step if it changes. It opens the
/// same workbench as [adminQuestionPath].
String adminFlagPath(String questionId) => '/admin/flag/$questionId';

/// `/admin/question/:id` and `/admin/flag/:id`: the question workbench.
///
/// Left, the editor: stem, options (tap the circle to mark the answer),
/// explanation, whether students see it, and what is wrong with it as you
/// type. Right, the question exactly as a student meets it, then its
/// reports, the content audit's findings and its history. A save writes
/// the question and its history record in one batch, which the rules
/// insist on (`editsQuestion`), and can close the open reports with it.
///
/// Reviewers of the question's subject edit; everyone else on the team
/// sees it read-only.
class AdminFlagScreen extends ConsumerStatefulWidget {
  const AdminFlagScreen({super.key, required this.questionId});

  final String questionId;

  @override
  ConsumerState<AdminFlagScreen> createState() => _AdminFlagScreenState();
}

class _AdminFlagScreenState extends ConsumerState<AdminFlagScreen> {
  QuestionDraft? _original;
  final _stem = TextEditingController();
  final _explanation = TextEditingController();
  final _reason = TextEditingController();
  final List<TextEditingController> _options = [];
  int _correct = -1;
  bool _live = true;
  bool _closeReports = true;
  bool _busy = false;

  /// The text box the maths toolbar types into.
  TextEditingController? _active;

  @override
  void dispose() {
    for (final c in [_stem, _explanation, _reason, ..._options]) {
      c.dispose();
    }
    super.dispose();
  }

  QuestionDraft get _draft => QuestionDraft(
    text: _stem.text,
    options: [for (final c in _options) c.text],
    correctIndex: _correct,
    explanation: _explanation.text,
    hasAnswer: _live,
  );

  bool get _dirty =>
      _original != null && _draft.changedFrom(_original!).isNotEmpty;

  /// Loads [d] into the boxes. Used on first load, after a save, and to
  /// restore an earlier version from the history.
  void _load(QuestionDraft d, {bool asOriginal = false}) {
    // Setting the boxes fires their listeners; this runs during build on
    // first load, where a setState would throw.
    _loading = true;
    if (asOriginal) _original = d;
    _stem.text = d.text;
    _explanation.text = d.explanation;
    for (final c in _options) {
      c.dispose();
    }
    _options
      ..clear()
      ..addAll([for (final o in d.options) _watched(o)]);
    _correct = d.correctIndex;
    _live = d.hasAnswer;
    _loading = false;
  }

  bool _loading = false;

  TextEditingController _watched(String text) =>
      TextEditingController(text: text)..addListener(_changed);

  void _changed() {
    if (mounted && !_loading) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _stem.addListener(_changed);
    _explanation.addListener(_changed);
    _reason.addListener(_changed);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard your changes?'),
        content: const Text('This question has edits that are not saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _go(String id) async {
    if (!await _confirmDiscard() || !mounted) return;
    context.pushReplacement(adminQuestionPath(id));
  }

  Future<void> _save(FlaggedQuestion row) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final before = _original;
    if (uid == null || before == null) return;
    setState(() => _busy = true);
    try {
      final after = _draft;
      await ref
          .read(adminQuestionRepositoryProvider)
          .save(
            questionId: widget.questionId,
            before: before,
            after: after,
            reason: _reason.text,
            uid: uid,
            closeReports: _closeReports ? row.openReports : const [],
          );
      ref.invalidate(adminFlaggedQuestionProvider(widget.questionId));
      ref.invalidate(questionHistoryProvider(widget.questionId));
      ref.invalidate(adminFlagQueueProvider);
      if (!mounted) return;
      setState(() {
        _original = QuestionDraft.fromMap(after.toMap());
        _reason.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _closeReports && row.openReports.isNotEmpty
                ? 'Saved, and ${row.openReports.length} report'
                      '${row.openReports.length == 1 ? '' : 's'} closed'
                : 'Saved',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissReports(FlaggedQuestion row) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminFlagRepositoryProvider).dismiss(row: row, uid: uid);
      ref.invalidate(adminFlaggedQuestionProvider(widget.questionId));
      ref.invalidate(adminFlagQueueProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reports dismissed: the answer stands')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't dismiss: $e")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Types [snippet] at the cursor of the last box used. `|` marks where
  /// the cursor lands, inside the braces.
  void _insert(String snippet) {
    final c = _active ?? _stem;
    final sel = c.selection.isValid
        ? c.selection
        : TextSelection.collapsed(offset: c.text.length);
    final caret = snippet.indexOf('|');
    final clean = snippet.replaceFirst('|', '');
    final picked = sel.textInside(c.text);
    // Wrapping a selection: `\(` + selection + `\)`.
    final text = caret >= 0 && picked.isNotEmpty
        ? clean.substring(0, caret) + picked + clean.substring(caret)
        : clean;
    c.value = TextEditingValue(
      text: c.text.replaceRange(sel.start, sel.end, text),
      selection: TextSelection.collapsed(
        offset: sel.start + (caret >= 0 ? caret + picked.length : text.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminFlaggedQuestionProvider(widget.questionId));
    final row = async.asData?.value;
    final q = row?.question;
    if (q != null && _original == null) {
      _load(
        QuestionDraft(
          text: q.question.text,
          options: q.question.options,
          correctIndex: q.question.correctIndex,
          explanation: q.question.explanation,
          hasAnswer: q.hasAnswer,
        ),
        asOriginal: true,
      );
    }
    final canEdit =
        q != null &&
        ref.watch(staffAccessProvider).roleIn(q.question.subjectId).canReview;
    final list = ref.watch(studioWorkListProvider);
    final at = list.indexOf(widget.questionId);
    final prev = at > 0 ? list[at - 1] : null;
    final next = at >= 0 && at < list.length - 1 ? list[at + 1] : null;
    final issues = checkDraft(_draft);
    final blocked = issues.any((i) => i.blocks);
    final canSave =
        canEdit &&
        _dirty &&
        !blocked &&
        !_busy &&
        _reason.text.trim().length >= 3;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (canSave && row != null) _save(row);
        },
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (canSave && row != null) _save(row);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (prev != null) _go(prev);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          if (next != null) _go(next);
        },
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _confirmDiscard() && context.mounted) {
            // Clean again, so the next frame's PopScope lets the pop through.
            setState(() => _original = _draft);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.popOrGo();
            });
          }
        },
        child: Scaffold(
          backgroundColor: context.palette.background,
          appBar: ParagonAppBar(
            title: Text(
              list.length > 1 && at >= 0
                  ? 'Question ${at + 1} of ${list.length}'
                  : 'Question',
            ),
            actions: [
              if (list.length > 1) ...[
                IconButton(
                  tooltip: 'Previous (Alt+←)',
                  onPressed: prev == null ? null : () => _go(prev),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Next (Alt+→)',
                  onPressed: next == null ? null : () => _go(next),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
              IconButton(
                tooltip: 'Examiner insight',
                onPressed: () =>
                    context.push('/admin/insight/${widget.questionId}'),
                icon: const Icon(Icons.fact_check_outlined),
              ),
              if (q != null && q.question.isPastQuestion)
                IconButton(
                  tooltip: 'Open the public page',
                  onPressed: () => _openPublicPage(q),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: row == null || q == null || !canEdit
              ? null
              : _SaveBar(
                  dirty: _dirty,
                  blocked: blocked,
                  busy: _busy,
                  canSave: canSave,
                  reason: _reason,
                  openReports: row.openReports.length,
                  closeReports: _closeReports,
                  onCloseReports: (v) => setState(() => _closeReports = v),
                  onDiscard: () => setState(() => _load(_original!)),
                  onSave: () => _save(row),
                ),
          body: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Couldn't load this question.\n$e",
                style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
              ),
            ),
            data: (row) => LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 1040;
                final editor = _editorColumn(row, canEdit, issues);
                final side = _sideColumn(row, canEdit);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1320 : 760),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 11, child: editor),
                                const SizedBox(width: 24),
                                Expanded(flex: 9, child: side),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                editor,
                                const SizedBox(height: 24),
                                side,
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPublicPage(ReviewedQuestion q) async {
    final subjects = await ref.read(subjectsProvider.future);
    final s = subjects.where((s) => s.id == q.question.subjectId).firstOrNull;
    if (s == null) return;
    final slug = SubjectCatalog.slugify(s.name);
    final id = widget.questionId;
    await launchUrl(
      Uri.parse(
        '$appOrigin/past-questions/waec/$slug/${q.question.year}/'
        '${id.length > 10 ? id.substring(0, 10) : id}/',
      ),
    );
  }

  // ── The editor ─────────────────────────────────────────────────────

  Widget _editorColumn(
    FlaggedQuestion row,
    bool canEdit,
    List<DraftIssue> issues,
  ) {
    final q = row.question;
    final palette = context.palette;
    if (q == null) {
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This question no longer exists',
              style: AppTheme.heading3.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Its reports can still be dismissed.',
              style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy || !row.isOpen
                  ? null
                  : () => _dismissReports(row),
              child: const Text('Dismiss the reports'),
            ),
          ],
        ),
      );
    }
    String? fieldError(String field, [int? index]) {
      final hit = issues.where(
        (i) => i.field == field && i.index == index && i.blocks,
      );
      return hit.isEmpty ? null : hit.first.message;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(question: q),
        const SizedBox(height: 16),
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Banner(
              icon: Icons.lock_outline_rounded,
              color: palette.textSecondary,
              text: 'Read-only. Reviewers of this subject can edit questions.',
            ),
          ),
        if (q.isGenerated)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _Banner(
              icon: Icons.auto_fix_high_rounded,
              color: AppColors.accentBlue,
              text:
                  'Paragon practice, made by a template in tools/scraper/gen. '
                  'This fixes one question; if the template is wrong, fix it '
                  'too, or the next seeding brings the mistake back.',
            ),
          ),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(
                'Question',
                trailing: canEdit ? _MathToolbar(onInsert: _insert) : null,
              ),
              _Box(
                controller: _stem,
                enabled: canEdit,
                minLines: 3,
                hint: r'Maths goes in \( … \), e.g. \(x^{2} + 1\)',
                error: fieldError('text'),
                onFocus: () => _active = _stem,
              ),
              QuestionImage(assetId: q.question.imageId),
              const SizedBox(height: 18),
              _FieldLabel(
                'Options',
                helper: canEdit ? 'Tap a letter to mark the answer' : null,
              ),
              for (var i = 0; i < _options.length; i++)
                _OptionEditor(
                  index: i,
                  controller: _options[i],
                  isAnswer: i == _correct,
                  enabled: canEdit,
                  error: fieldError('options', i),
                  onMark: () => setState(() => _correct = i),
                  onRemove: _options.length > QuestionDraft.minOptions
                      ? () => setState(() {
                          final d = _draft.withoutOption(i);
                          _options.removeAt(i).dispose();
                          _correct = d.correctIndex;
                        })
                      : null,
                  onFocus: () => _active = _options[i],
                ),
              if (canEdit && _options.length < QuestionDraft.maxOptions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _options.add(_watched(''))),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add an option'),
                  ),
                ),
              if (fieldError('options') case final e?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    e,
                    style: AppTheme.caption.copyWith(color: AppColors.wrong),
                  ),
                ),
              const SizedBox(height: 18),
              _FieldLabel('Worked answer'),
              _Box(
                controller: _explanation,
                enabled: canEdit,
                minLines: 4,
                hint: 'How to get the answer, step by step, in your own words',
                error: fieldError('explanation'),
                onFocus: () => _active = _explanation,
              ),
              QuestionImage.workedAnswer(
                assetId: q.question.explanationImageId,
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _live,
                onChanged: canEdit ? (v) => setState(() => _live = v) : null,
                title: Text(
                  'Students see this question',
                  style: AppTheme.bodyMd.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _live
                      ? 'In drill, WAEC papers, topic tests and exercises.'
                      : 'Hidden everywhere. Answers already given keep their marks.',
                  style: AppTheme.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ChecksCard(issues: issues, questionId: widget.questionId),
      ],
    );
  }

  // ── Preview, reports, history ───────────────────────────────────────

  Widget _sideColumn(FlaggedQuestion row, bool canEdit) {
    final q = row.question;
    final palette = context.palette;
    final d = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q != null) ...[
          const GroupLabel('What students see'),
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            color: palette.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!d.hasAnswer)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: StudioTag(
                      'Hidden from students',
                      color: AppColors.wrong,
                      icon: Icons.visibility_off_outlined,
                    ),
                  ),
                FullLatexView(
                  latex: d.text.isEmpty ? ' ' : d.text,
                  textStyle: AppTheme.bodyLg.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                QuestionImage(assetId: q.question.imageId),
                const SizedBox(height: 12),
                for (var i = 0; i < d.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AnswerOption(
                      index: i,
                      text: d.options[i].isEmpty ? '…' : d.options[i],
                      state: i == d.correctIndex
                          ? AnswerOptionState.correct
                          : AnswerOptionState.idle,
                    ),
                  ),
                if (d.explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Worked answer',
                    style: AppTheme.label.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FullLatexView(
                    latex: d.explanation,
                    textStyle: AppTheme.bodyMd.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _ReportsCard(
          row: row,
          canAct: canEdit && !_busy,
          onDismiss: () => _dismissReports(row),
        ),
        const SizedBox(height: 20),
        _HistoryCard(
          questionId: widget.questionId,
          canRestore: canEdit,
          onRestore: (e) => setState(() {
            _load(e.before);
            _reason.text = 'Restore the version before "${e.reason}"';
          }),
        ),
      ],
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.question});
  final ReviewedQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = question.question;
    final topic = ref.watch(topicByIdProvider(q.topicId)).asData?.value;
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final subject = subjects.where((s) => s.id == q.subjectId).firstOrNull;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StudioTag(
          questionOriginLabel(question),
          color: question.isGenerated
              ? AppColors.accentBlue
              : AppColors.primary,
        ),
        if (subject != null) StudioTag(subject.name),
        if (topic != null) StudioTag(topic.name),
        if (!question.hasAnswer)
          const StudioTag('Hidden from students', color: AppColors.wrong),
        SelectableText(
          q.id,
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withAlpha(24),
      border: Border.all(color: color.withAlpha(90)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.helper, this.trailing});
  final String text;
  final String? helper;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          text,
          style: AppTheme.label.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              helper!,
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ] else
          const Spacer(),
        ?trailing,
      ],
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({
    required this.controller,
    required this.enabled,
    required this.onFocus,
    this.minLines = 1,
    this.hint,
    this.error,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onFocus;
  final int minLines;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (has) {
      if (has) onFocus();
    },
    child: TextField(
      controller: controller,
      readOnly: !enabled,
      minLines: minLines,
      maxLines: null,
      style: AppTheme.bodyMd.copyWith(
        color: context.palette.textPrimary,
        height: 1.5,
      ),
      decoration: InputDecoration(hintText: hint, errorText: error),
    ),
  );
}

class _OptionEditor extends StatelessWidget {
  const _OptionEditor({
    required this.index,
    required this.controller,
    required this.isAnswer,
    required this.enabled,
    required this.onMark,
    required this.onFocus,
    this.onRemove,
    this.error,
  });

  final int index;
  final TextEditingController controller;
  final bool isAnswer;
  final bool enabled;
  final VoidCallback onMark;
  final VoidCallback onFocus;
  final VoidCallback? onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = isAnswer ? AppColors.correct : palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            selected: isAnswer,
            label:
                'Option ${optionLetter(index)}'
                '${isAnswer ? ', the marked answer' : ', mark as the answer'}',
            onTap: enabled ? onMark : null,
            excludeSemantics: true,
            child: Tooltip(
              message: isAnswer ? 'The marked answer' : 'Mark as the answer',
              child: InkWell(
                onTap: enabled ? onMark : null,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 4, right: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAnswer ? AppColors.correct.withAlpha(40) : null,
                    border: Border.all(color: colour, width: isAnswer ? 2 : 1),
                  ),
                  child: isAnswer
                      ? const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: AppColors.correct,
                        )
                      : Text(
                          optionLetter(index),
                          style: AppTheme.bodyMd.copyWith(
                            color: colour,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _Box(
              controller: controller,
              enabled: enabled,
              onFocus: onFocus,
              hint: 'Option ${optionLetter(index)}',
              error: error,
            ),
          ),
          if (enabled && onRemove != null)
            IconButton(
              tooltip: 'Remove option ${optionLetter(index)}',
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// One tap for the maths students' questions use most. Types at the
/// cursor of the last box used; wraps a selection where that makes sense.
class _MathToolbar extends StatelessWidget {
  const _MathToolbar({required this.onInsert});
  final void Function(String) onInsert;

  static const _snippets = <(String, String, String)>[
    (r'\( \)', r'\(|\)', 'Maths'),
    ('a/b', r'\frac{|}{}', 'Fraction'),
    ('xⁿ', '^{|}', 'Power'),
    ('x₁', '_{|}', 'Subscript'),
    ('√', r'\sqrt{|}', 'Square root'),
    ('×', r'\times ', 'Times'),
    ('÷', r'\div ', 'Divide'),
    ('°', r'^\circ', 'Degrees'),
    ('π', r'\pi ', 'Pi'),
    ('θ', r'\theta ', 'Theta'),
    ('≤', r'\leq ', 'Less than or equal'),
    ('≥', r'\geq ', 'Greater than or equal'),
  ];

  @override
  Widget build(BuildContext context) => Flexible(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (final (label, snippet, tip) in _snippets)
            Tooltip(
              message: tip,
              child: InkWell(
                // Keeps focus (and the cursor) in the box being edited.
                canRequestFocus: false,
                onTap: () => onInsert(snippet),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.palette.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: AppTheme.caption.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// What is wrong, live as you type, then what the last content audit
/// found on the stored question.
class _ChecksCard extends ConsumerWidget {
  const _ChecksCard({required this.issues, required this.questionId});
  final List<DraftIssue> issues;
  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final audit = ref.watch(contentAuditProvider).asData?.value;
    final found = audit?.findingsFor(questionId) ?? const [];
    if (issues.isEmpty && found.isEmpty) {
      return const _Banner(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.correct,
        text: 'No problems found.',
      );
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in issues)
            _CheckLine(
              icon: i.blocks
                  ? Icons.block_rounded
                  : Icons.warning_amber_rounded,
              color: i.blocks ? AppColors.wrong : AppColors.warning,
              text: i.message,
            ),
          if (found.isNotEmpty) ...[
            if (issues.isNotEmpty) const Divider(height: 20),
            Text(
              'The last content audit (on the stored question)',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 6),
            for (final f in found)
              _CheckLine(
                icon: Icons.manage_search_rounded,
                color: f.level == 'B' ? palette.textSecondary : AppColors.wrong,
                text:
                    '${f.rule.replaceAll('-', ' ')}'
                    '${f.detail.isEmpty ? '' : ': ${f.detail}'}',
              ),
          ],
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class _ReportsCard extends StatelessWidget {
  const _ReportsCard({
    required this.row,
    required this.canAct,
    required this.onDismiss,
  });
  final FlaggedQuestion row;
  final bool canAct;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final open = row.openReports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(
          open.isEmpty
              ? 'Student reports'
              : 'Student reports · ${open.length} open',
          color: open.isEmpty ? null : AppColors.warning,
        ),
        if (row.reports.isEmpty)
          Text(
            'No student has reported this question.',
            style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
          )
        else
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in row.reports.take(12))
                  ListRow(
                    icon: r.isOpen
                        ? Icons.flag_rounded
                        : Icons.check_circle_outline_rounded,
                    iconColor: r.isOpen ? AppColors.warning : AppColors.correct,
                    title: r.reason.label,
                    subtitle: [
                      if (r.createdAt != null) _date(r.createdAt!),
                      r.status.value,
                    ].join(' · '),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                if (open.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                    child: Text(
                      'Saving a fix closes these as fixed. If the question '
                      'is right as it is:',
                      style: AppTheme.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                if (open.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: OutlinedButton(
                      onPressed: canAct ? onDismiss : null,
                      child: Text(
                        'Nothing to fix: dismiss ${open.length} '
                        'report${open.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({
    required this.questionId,
    required this.canRestore,
    required this.onRestore,
  });
  final String questionId;
  final bool canRestore;
  final void Function(QuestionEdit) onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final history = ref.watch(questionHistoryProvider(questionId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('History'),
        history.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load the history.\n$e",
            style: AppTheme.caption.copyWith(color: AppColors.wrong),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  'Not edited in the studio yet. Every save is kept here and '
                  'can be restored.',
                  style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
                )
              : SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final e in list)
                        ListRow(
                          leading: StaffAvatar(uid: e.by),
                          title: e.reason.isEmpty
                              ? '(no reason given)'
                              : e.reason,
                          subtitle: [
                            if (e.at != null) _date(e.at!),
                            'changed ${e.after.changedFrom(e.before).join(', ')}',
                          ].join(' · '),
                          trailing: canRestore
                              ? TextButton(
                                  onPressed: () => onRestore(e),
                                  child: const Text('Restore before'),
                                )
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.blocked,
    required this.busy,
    required this.canSave,
    required this.reason,
    required this.openReports,
    required this.closeReports,
    required this.onCloseReports,
    required this.onDiscard,
    required this.onSave,
  });

  final bool dirty;
  final bool blocked;
  final bool busy;
  final bool canSave;
  final TextEditingController reason;
  final int openReports;
  final bool closeReports;
  final ValueChanged<bool> onCloseReports;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          // heightFactor 1: a bottom bar is offered the whole screen's
          // height, and a plain Center would take it, covering the page.
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: !dirty
                  ? Text(
                      'No changes. Edit the question and a save button '
                      'appears here (Ctrl+S).',
                      style: AppTheme.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 360,
                          child: TextField(
                            controller: reason,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText:
                                  'What did you fix? (kept in the history)',
                            ),
                            onSubmitted: (_) {
                              if (canSave) onSave();
                            },
                          ),
                        ),
                        if (openReports > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: closeReports,
                                onChanged: (v) => onCloseReports(v ?? false),
                              ),
                              Text(
                                'Close $openReports report'
                                '${openReports == 1 ? '' : 's'} as fixed',
                                style: AppTheme.bodyMd.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        TextButton(
                          onPressed: busy ? null : onDiscard,
                          child: const Text('Discard'),
                        ),
                        ElevatedButton.icon(
                          onPressed: canSave ? onSave : null,
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(
                            blocked
                                ? 'Fix the problems to save'
                                : reason.text.trim().length < 3
                                ? 'Say what you fixed'
                                : 'Save',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _date(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
