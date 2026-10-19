import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/questions/question_draft.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/rooms/teacher_quiz.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/full_latex_view.dart';
import '../../core/widgets/math_field/math_field.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/question_image.dart';
import '../../core/widgets/ui/ui.dart';
import '../admin/studio/image_upload.dart' deferred as image_upload;
import 'room_paths.dart';

/// `/quizzes`: a host's own quizzes (owner's request, 2026-10-17), to run
/// in a live room. Any account.
class MyQuizzesScreen extends ConsumerWidget {
  const MyQuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final quizzes = ref.watch(myQuizzesProvider);
    final isGuest = ref.watch(isGuestProvider);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ParagonAppBar(title: Text('My quizzes')),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(quizEditPath('new')),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New quiz'),
            ),
      body: PageBody(
        children: [
          Text(
            'Write your own questions, in Normal or LaTeX mode, with '
            'diagrams, then host them as a live quiz. Only players in your '
            'rooms see them.',
            style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          if (isGuest)
            const EmptyState(
              icon: Icons.lock_outline,
              title: 'Writing quizzes needs an account',
              message: 'Make a free account, then come back.',
            )
          else
            quizzes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text("Couldn't load your quizzes.\n$e"),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'No quizzes yet',
                      message: 'Tap New quiz to write the first.',
                    )
                  : RowGroup(
                      children: [
                        for (final q in list)
                          ListRow(
                            leading: const Icon(Icons.quiz_outlined),
                            title: q.title,
                            subtitle:
                                '${q.questions.length} questions, '
                                '${q.playable.length} ready',
                            onTap: () => context.push(quizEditPath(q.id)),
                          ),
                      ],
                    ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// One question being edited: its boxes.
class _QBoxes {
  _QBoxes(QuizQuestion q)
    : text = TextEditingController(text: q.text),
      explanation = TextEditingController(text: q.explanation),
      options = [for (final o in q.options) TextEditingController(text: o)],
      correct = q.correctIndex,
      imageId = q.imageId;

  final TextEditingController text;
  final TextEditingController explanation;
  final List<TextEditingController> options;
  int correct;
  String? imageId;

  QuizQuestion get value => QuizQuestion(
    text: text.text,
    options: [for (final o in options) o.text],
    correctIndex: correct,
    explanation: explanation.text,
    imageId: imageId,
  );

  QuestionDraft get draft => QuestionDraft(
    text: text.text,
    options: [for (final o in options) o.text],
    correctIndex: correct,
    explanation: explanation.text,
    hasAnswer: true,
  );

  void dispose() {
    text.dispose();
    explanation.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

/// `/quizzes/:id` (`new` for a new one): the studio's editor, for one quiz.
///
/// Each question has a stem, 2 to 5 options (tap a letter to mark the
/// answer), a worked answer and an optional diagram, typed in Normal or
/// LaTeX mode, checked as you type by the same rules as the studio
/// (`checkDraft`), and previewed as players will see it. "Add from
/// Paragon" copies questions from a topic in. Saved as one document.
class QuizEditorScreen extends ConsumerStatefulWidget {
  const QuizEditorScreen({super.key, required this.quizId});
  final String quizId;

  @override
  ConsumerState<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends ConsumerState<QuizEditorScreen> {
  final _math = MathEditing(prefsKey: 'quizzes');
  final _title = TextEditingController();
  final _qs = <_QBoxes>[];
  String? _subjectId;
  late String _id = widget.quizId == 'new' ? '' : widget.quizId;
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  int? _uploadingFor;

  @override
  void dispose() {
    _title.dispose();
    for (final q in _qs) {
      q.dispose();
    }
    _math.dispose();
    super.dispose();
  }

  void _touch() {
    if (_loaded && !_dirty) setState(() => _dirty = true);
  }

  void _add(QuizQuestion q) {
    final b = _QBoxes(q);
    for (final c in [b.text, b.explanation, ...b.options]) {
      c.addListener(_touch);
    }
    _qs.add(b);
  }

  void _load(TeacherQuiz? quiz) {
    _loaded = true;
    _title.text = quiz?.title ?? '';
    _title.addListener(_touch);
    _subjectId = quiz?.subjectId;
    for (final q in quiz?.questions ?? const <QuizQuestion>[]) {
      _add(q);
    }
    if (_qs.isEmpty) {
      _add(const QuizQuestion(text: '', options: ['', '', '', ''], correctIndex: -1));
    }
  }

  TeacherQuiz get _quiz => TeacherQuiz(
    id: _id,
    title: _title.text,
    subjectId: _subjectId,
    questions: [for (final q in _qs) q.value],
  );

  Future<bool> _save() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return false;
    setState(() => _saving = true);
    try {
      _id = await ref.read(teacherQuizRepositoryProvider).save(uid, _quiz);
      ref.invalidate(myQuizzesProvider);
      ref.invalidate(teacherQuizProvider(_id));
      if (mounted) setState(() => _dirty = false);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_id.isEmpty) return context.popOrGo();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this quiz?'),
        content: const Text('Rooms already running keep their copy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.wrong),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(teacherQuizRepositoryProvider).delete(_id);
    ref.invalidate(myQuizzesProvider);
    _dirty = false;
    if (mounted) context.go(kMyQuizzesPath);
  }

  Future<void> _upload(int i) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _uploadingFor = i);
    try {
      await image_upload.loadLibrary();
      final id = await image_upload.pickAndUploadQuizImage(
        db: FirebaseFirestore.instance,
        uid: uid,
      );
      if (id != null && mounted) {
        setState(() {
          _qs[i].imageId = id;
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't upload: $e")));
      }
    } finally {
      if (mounted) setState(() => _uploadingFor = null);
    }
  }

  Future<void> _fromParagon() async {
    final picked = await showModalBottomSheet<List<Question>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: _BankPickerSheet(),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      // A blank first question is replaced, not kept.
      if (_qs.length == 1 && _qs.first.value.text.trim().isEmpty) {
        _qs.removeAt(0).dispose();
      }
      for (final q in picked.take(TeacherQuiz.maxQuestions - _qs.length)) {
        _add(
          QuizQuestion(
            text: q.text,
            options: q.options.take(QuizQuestion.maxOptions).toList(),
            correctIndex: q.correctIndex < QuizQuestion.maxOptions
                ? q.correctIndex
                : -1,
            explanation: q.explanation,
            imageId: q.imageId,
          ),
        );
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!_loaded) {
      if (_id.isEmpty) {
        _load(null);
      } else {
        final quiz = ref.watch(teacherQuizProvider(_id));
        if (quiz.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        _load(quiz.asData?.value);
      }
    }
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final full = _qs.length >= TeacherQuiz.maxQuestions;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _save() && context.mounted) context.popOrGo();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: ParagonAppBar(
          title: Text(_id.isEmpty ? 'New quiz' : 'Edit quiz'),
          actions: [
            IconButton(
              tooltip: 'Delete the quiz',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            TextButton(
              onPressed: _saving || !_dirty ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PageBody(
          children: [
            TextField(
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Quiz name',
                hintText: 'e.g. SS2 Indices revision',
              ),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _subjectId,
              decoration: const InputDecoration(labelText: 'Subject (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final s in subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() {
                _subjectId = v;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            MathToolbar(editing: _math),
            const SizedBox(height: 12),
            for (var i = 0; i < _qs.length; i++)
              _QuestionCard(
                key: ObjectKey(_qs[i]),
                number: i + 1,
                boxes: _qs[i],
                editing: _math,
                uploading: _uploadingFor == i,
                onUpload: () => _upload(i),
                onChanged: () => setState(() => _dirty = true),
                onRemove: _qs.length <= 1
                    ? null
                    : () => setState(() {
                        _qs.removeAt(i).dispose();
                        _dirty = true;
                      }),
                onMove: (delta) => setState(() {
                  final j = i + delta;
                  if (j < 0 || j >= _qs.length) return;
                  final q = _qs.removeAt(i);
                  _qs.insert(j, q);
                  _dirty = true;
                }),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: full
                      ? null
                      : () => setState(() {
                          _add(
                            const QuizQuestion(
                              text: '',
                              options: ['', '', '', ''],
                              correctIndex: -1,
                            ),
                          );
                          _dirty = true;
                        }),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(full ? 'A quiz holds 50' : 'Add a question'),
                ),
                OutlinedButton.icon(
                  onPressed: full ? null : _fromParagon,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Add from Paragon'),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.number,
    required this.boxes,
    required this.editing,
    required this.uploading,
    required this.onUpload,
    required this.onChanged,
    required this.onMove,
    this.onRemove,
  });

  final int number;
  final _QBoxes boxes;
  final MathEditing editing;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onChanged;
  final ValueChanged<int> onMove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final issues = checkDraft(boxes.draft)
        .where((i) => i.blocks || i.field != 'explanation')
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Question $number',
                  style: AppTheme.label.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: () => onMove(-1),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: () => onMove(1),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Remove question $number',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            MathField(controller: boxes.text, editing: editing, minLines: 2),
            if (boxes.imageId != null) QuestionImage(assetId: boxes.imageId),
            Row(
              children: [
                TextButton.icon(
                  onPressed: uploading ? null : onUpload,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(
                    uploading
                        ? 'Uploading…'
                        : boxes.imageId == null
                        ? 'Add a diagram'
                        : 'Replace the diagram',
                  ),
                ),
                if (boxes.imageId != null)
                  TextButton(
                    onPressed: () {
                      boxes.imageId = null;
                      onChanged();
                    },
                    child: const Text('Remove'),
                  ),
              ],
            ),
            Text(
              'Options: tap a letter to mark the answer',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 6),
            for (var j = 0; j < boxes.options.length; j++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: ChoiceChip(
                        label: Text(optionLetter(j)),
                        selected: boxes.correct == j,
                        onSelected: (_) {
                          boxes.correct = j;
                          onChanged();
                        },
                      ),
                    ),
                    Expanded(
                      child: MathField(
                        controller: boxes.options[j],
                        editing: editing,
                        hint: 'Option ${optionLetter(j)}',
                        showPreview: false,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove option ${optionLetter(j)}',
                      onPressed:
                          boxes.options.length <= QuizQuestion.minOptions
                          ? null
                          : () {
                              boxes.options.removeAt(j).dispose();
                              if (boxes.correct == j) boxes.correct = -1;
                              if (boxes.correct > j) boxes.correct--;
                              onChanged();
                            },
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ],
                ),
              ),
            if (boxes.options.length < QuizQuestion.maxOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    boxes.options.add(
                      TextEditingController()..addListener(onChanged),
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add an option'),
                ),
              ),
            const SizedBox(height: 8),
            MathField(
              controller: boxes.explanation,
              editing: editing,
              hint: 'Worked answer (shown after the reveal; optional)',
              paragraphs: true,
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final i in issues.take(3))
                Text(
                  i.message,
                  style: AppTheme.caption.copyWith(
                    color: i.blocks ? AppColors.wrong : AppColors.warning,
                  ),
                ),
            ],
            if (boxes.text.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Preview as players see it'),
                children: [
                  FullLatexView(
                    latex: boxes.text.text,
                    textStyle: AppTheme.bodyLg.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  for (var j = 0; j < boxes.options.length; j++)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: FullLatexView(
                        latex: '${optionLetter(j)}. ${boxes.options[j].text}',
                        textStyle: AppTheme.bodyMd.copyWith(
                          color: j == boxes.correct
                              ? AppColors.correct
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Add from Paragon": a topic's questions, ticked to copy in.
class _BankPickerSheet extends ConsumerStatefulWidget {
  const _BankPickerSheet();

  @override
  ConsumerState<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends ConsumerState<_BankPickerSheet> {
  String? _subjectId;
  String? _topicId;
  final _picked = <String, Question>{};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final course = _subjectId == null
        ? null
        : ref.watch(courseProvider(_subjectId!)).asData?.value;
    final pool = _topicId == null
        ? null
        : ref.watch(drillQuestionsProvider(_topicId!));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add from Paragon',
                  style: AppTheme.heading3.copyWith(color: palette.textPrimary),
                ),
              ),
              FilledButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_picked.values.toList()),
                child: Text('Add ${_picked.length}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subjects)
                ChoiceChip(
                  label: Text(s.name),
                  selected: s.id == _subjectId,
                  onSelected: (_) => setState(() {
                    _subjectId = s.id;
                    _topicId = null;
                  }),
                ),
            ],
          ),
          if (course != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _topicId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Topic'),
              items: [
                for (final m in course.modules)
                  for (final t in m.topics)
                    if (!t.isPlaceholder && t.counts.servable > 0)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _topicId = v),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: pool == null
                ? const SizedBox.shrink()
                : pool.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const Text("Couldn't load questions."),
                    data: (qs) => ListView(
                      children: [
                        for (final q in qs)
                          CheckboxListTile(
                            value: _picked.containsKey(q.id),
                            onChanged: (on) => setState(() {
                              if (on == true) {
                                _picked[q.id] = q;
                              } else {
                                _picked.remove(q.id);
                              }
                            }),
                            title: FullLatexView(
                              latex: q.text,
                              textStyle: AppTheme.bodyMd.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
