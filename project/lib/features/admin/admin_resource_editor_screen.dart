import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/learn_resource.dart';
import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/admin_resource_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/article_view.dart';
import '../../core/widgets/full_latex_view.dart';
import '../lesson/exercise_pane.dart';
import '../lesson/video_pane.dart';
import '../onboarding/onboarding_scaffold.dart';

/// Path of the editor for an existing resource — also the link in the
/// draft-notification email (`tools/admin/notify_drafts.js`).
String adminResourcePath(String topicId, String resourceId) =>
    '/admin/topic/$topicId/resource/$resourceId';

String adminNewResourcePath(String topicId, LearnResourceType type) =>
    '/admin/topic/$topicId/new/${type.name}';

/// Write or edit one Learn resource: an article, a video or an exercise.
///
/// The preview is the real student-facing pane — [ArticleView],
/// [VideoPane], [ExercisePane] with recording off — fed the form as it is
/// typed, so what you see is what a student gets.
class AdminResourceEditorScreen extends ConsumerStatefulWidget {
  const AdminResourceEditorScreen({
    super.key,
    required this.topicId,
    this.resourceId,
    this.newType = LearnResourceType.article,
  });

  final String topicId;

  /// Null for a new resource.
  final String? resourceId;

  /// The type of a new resource; ignored when editing.
  final LearnResourceType newType;

  @override
  ConsumerState<AdminResourceEditorScreen> createState() =>
      _AdminResourceEditorScreenState();
}

class _AdminResourceEditorScreenState
    extends ConsumerState<AdminResourceEditorScreen> {
  final _title = TextEditingController();
  final _order = TextEditingController();
  final _body = TextEditingController();
  final _youtube = TextEditingController();
  final _duration = TextEditingController();
  final _description = TextEditingController();
  final _transcript = TextEditingController();
  final _questionCount = TextEditingController(
    text: '$kDefaultExerciseQuestions',
  );
  List<String> _questionIds = [];

  late LearnResourceType _type = widget.newType;
  bool _hydrated = false;
  bool _dirty = false;
  bool _isSaving = false;
  String? _error;

  /// Null until the resource exists in Firestore.
  ResourceStatus? _status;

  bool get _isNew => widget.resourceId == null;

  List<TextEditingController> get _controllers => [
    _title,
    _order,
    _body,
    _youtube,
    _duration,
    _description,
    _transcript,
    _questionCount,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_hydrated && !_dirty) setState(() => _dirty = true);
  }

  ResourceDraft get _draft => ResourceDraft(
    type: _type,
    title: _title.text,
    orderText: _order.text,
    body: _body.text,
    youtubeText: _youtube.text,
    durationText: _duration.text,
    description: _description.text,
    transcript: _transcript.text,
    questionCountText: _questionCount.text,
    questionIds: _questionIds,
  );

  void _hydrate() {
    if (_hydrated) return;
    if (_isNew) {
      final existing = ref
          .watch(adminTopicResourcesProvider(widget.topicId))
          .asData
          ?.value;
      if (existing == null) return;
      final next = existing.isEmpty
          ? 1
          : existing.map((r) => r.order).reduce((a, b) => a > b ? a : b) + 1;
      _order.text = '$next';
    } else {
      final resource = ref
          .watch(
            adminResourceProvider((
              topicId: widget.topicId,
              resourceId: widget.resourceId!,
            )),
          )
          .asData
          ?.value;
      if (resource == null) return;
      _type = resource.type;
      _title.text = resource.title;
      _order.text = '${resource.order}';
      _body.text = resource.body;
      _youtube.text = resource.youtubeId ?? '';
      _duration.text = resource.durationSeconds == null
          ? ''
          : formatDuration(resource.durationSeconds!);
      _description.text = resource.description ?? '';
      _transcript.text = resource.transcript ?? '';
      if (resource.questionCount > 0) {
        _questionCount.text = '${resource.questionCount}';
      }
      _questionIds = [...resource.questionIds];
      _status = resource.status;
    }
    _hydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    final topic = ref.watch(topicByIdProvider(widget.topicId)).asData?.value;
    _hydrate();

    final existing = _isNew
        ? null
        : ref.watch(
            adminResourceProvider((
              topicId: widget.topicId,
              resourceId: widget.resourceId!,
            )),
          );
    // Loaded, and not there: deleted, or a stale link from an old email.
    final missing =
        existing != null && existing.hasValue && existing.value == null;
    final noun = _type.label.toLowerCase();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: Text(
            _isNew ? 'New $noun' : 'Edit $noun',
            overflow: TextOverflow.ellipsis,
          ),
          bottom: topic == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      topic.name,
                      style: AppTheme.caption.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                ),
        ),
        body: SafeArea(
          child: missing
              ? Center(
                  child: Text(
                    'This resource no longer exists.',
                    style: AppTheme.bodyMd.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                )
              : !_hydrated
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _editorPane()),
                            const VerticalDivider(
                              width: 1,
                              color: AppColors.borderDark,
                            ),
                            Expanded(child: _previewPane()),
                          ],
                        )
                      : DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: 'Edit'),
                                  Tab(text: 'Preview'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [_editorPane(), _previewPane()],
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

  // ─── Form ──────────────────────────────────────────────────────────

  Widget _editorPane() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_status != null) ...[
          Text(
            _status == ResourceStatus.draft
                ? 'DRAFT — students cannot see this yet.'
                : 'PUBLISHED — students can see this now. Saving updates it live.',
            style: AppTheme.label.copyWith(
              color: _status == ResourceStatus.draft
                  ? AppColors.warning
                  : AppColors.correct,
            ),
          ),
          const SizedBox(height: 16),
        ],
        OnboardingTextField(
          controller: _title,
          label: 'TITLE',
          hintText: switch (_type) {
            LearnResourceType.video => 'e.g. Converting between bases',
            LearnResourceType.exercise => 'e.g. Practise converting bases',
            _ => 'e.g. Completing the square',
          },
        ),
        const SizedBox(height: 16),
        OnboardingTextField(
          controller: _order,
          label: 'POSITION IN TOPIC',
          hintText: '1',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ...switch (_type) {
          LearnResourceType.video => _videoFields(),
          LearnResourceType.exercise => _exerciseFields(),
          _ => _articleFields(),
        },
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: AppTheme.bodyMd.copyWith(color: AppColors.wrong)),
        ],
        const SizedBox(height: 20),
        _actions(),
      ],
    );
  }

  List<Widget> _articleFields() => [
    _label('BODY'),
    const SizedBox(height: 4),
    _hint(
      r'Inline maths \( ... \). Display maths \[ ... \] on its own line. '
      r'\textbf{...} and \textit{...} for emphasis. Headings #, ##, ###; '
      r'lists - or 1.; quotes >; rule ---. A lone $ is a dollar sign. '
      r'**bold**, $...$ and \emph are not supported.',
    ),
    const SizedBox(height: 8),
    _multiline(_body, minLines: 18, monospace: true),
  ];

  List<Widget> _videoFields() => [
    OnboardingTextField(
      controller: _youtube,
      label: 'YOUTUBE LINK',
      hintText: 'https://www.youtube.com/watch?v=…',
    ),
    const SizedBox(height: 4),
    ListenableBuilder(
      listenable: _youtube,
      builder: (context, _) {
        final text = _youtube.text.trim();
        final id = _draft.youtubeId;
        return _hint(
          text.isEmpty
              ? 'Paste a watch, share, embed or Shorts link, or the 11-character id.'
              : id == null
              ? "Not a YouTube video link yet."
              : 'Video id: $id',
          color: text.isNotEmpty && id == null ? AppColors.wrong : null,
        );
      },
    ),
    const SizedBox(height: 16),
    OnboardingTextField(
      controller: _duration,
      label: 'DURATION (OPTIONAL)',
      hintText: '9:30',
    ),
    const SizedBox(height: 4),
    _hint(
      'Shown in the lesson list. Watch tracking uses the real length from '
      'YouTube, so this only needs to be roughly right.',
    ),
    const SizedBox(height: 16),
    _label('DESCRIPTION (OPTIONAL)'),
    const SizedBox(height: 8),
    _multiline(_description, minLines: 3),
    const SizedBox(height: 16),
    _label('TRANSCRIPT (OPTIONAL)'),
    const SizedBox(height: 8),
    _multiline(_transcript, minLines: 5),
  ];

  List<Widget> _exerciseFields() => [
    if (_questionIds.isEmpty) ...[
      OnboardingTextField(
        controller: _questionCount,
        label: 'NUMBER OF QUESTIONS',
        hintText: '$kDefaultExerciseQuestions',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 4),
      _hint(
        "Drawn at random from this topic's questions each time, so a retry "
        'gets a fresh set. Or pin specific questions below.',
      ),
    ] else
      _hint(
        'Serving the ${_questionIds.length} pinned question'
        '${_questionIds.length == 1 ? '' : 's'} below, in this order. Remove '
        'them all to go back to a random set.',
      ),
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(child: _label('PINNED QUESTIONS')),
        TextButton.icon(
          onPressed: _questionIds.length >= kMaxPinnedQuestions ? null : _pick,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Choose questions'),
        ),
      ],
    ),
    if (_questionIds.isNotEmpty)
      _PinnedList(
        ids: _questionIds,
        onRemove: (id) => setState(() {
          _questionIds = [..._questionIds]..remove(id);
          _dirty = true;
        }),
      ),
  ];

  Future<void> _pick() async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) => _QuestionPicker(
        topicId: widget.topicId,
        initial: _questionIds,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _questionIds = picked;
      _dirty = true;
    });
  }

  Widget _label(String text) => Text(
    text,
    style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
  );

  Widget _hint(String text, {Color? color}) => Text(
    text,
    style: AppTheme.caption.copyWith(color: color ?? AppColors.textSecondaryDark),
  );

  Widget _multiline(
    TextEditingController c, {
    required int minLines,
    bool monospace = false,
  }) {
    return TextField(
      controller: c,
      minLines: minLines,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: AppTheme.bodyMd.copyWith(
        color: AppColors.textPrimaryDark,
        fontFamily: monospace ? 'monospace' : null,
        height: 1.5,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  // ─── Preview ───────────────────────────────────────────────────────

  /// The form as a resource, for the real student panes to render.
  LearnResource _asResource() {
    final d = _draft;
    return LearnResource(
      id: widget.resourceId ?? 'preview',
      type: _type,
      order: int.tryParse(_order.text.trim()) ?? 0,
      title: _title.text.trim().isEmpty ? '(untitled)' : _title.text.trim(),
      subjectId: '',
      topicId: widget.topicId,
      body: _body.text,
      youtubeId: d.youtubeId,
      durationSeconds: parseDuration(_duration.text),
      description: _description.text.trim().isEmpty ? null : _description.text,
      transcript: _transcript.text.trim().isEmpty ? null : _transcript.text,
      questionCount: int.tryParse(_questionCount.text.trim()) ?? 0,
      questionIds: _questionIds,
    );
  }

  Widget _previewPane() {
    return ListenableBuilder(
      listenable: Listenable.merge(_controllers),
      builder: (context, _) {
        final r = _asResource();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('PREVIEW'),
            const SizedBox(height: 16),
            switch (_type) {
              LearnResourceType.video => VideoPane(
                resource: r,
                isOffline: false,
              ),
              LearnResourceType.exercise => ExercisePane(
                // A new key per configuration, so changing the count or the
                // pins starts a fresh preview set.
                key: ValueKey('${r.questionCount}|${r.questionIds.join(',')}'),
                resource: r,
                recordAttempts: false,
              ),
              _ => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: AppTheme.heading2.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ArticleView(body: r.body),
                ],
              ),
            },
          ],
        );
      },
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────

  Widget _actions() {
    final buttons = <Widget>[];

    if (_status == ResourceStatus.draft) {
      buttons.add(
        _OutlineAction(
          label: 'Delete',
          color: AppColors.wrong,
          onPressed: _isSaving ? null : _delete,
        ),
      );
    }
    if (_status == ResourceStatus.published) {
      buttons.add(
        _OutlineAction(
          label: 'Unpublish',
          color: AppColors.warning,
          onPressed: _isSaving ? null : () => _save(ResourceStatus.draft),
        ),
      );
    }

    final keepStatus = _status ?? ResourceStatus.draft;
    buttons.add(
      _OutlineAction(
        label: keepStatus == ResourceStatus.published
            ? 'Save changes'
            : 'Save draft',
        color: AppColors.textPrimaryDark,
        onPressed: _isSaving ? null : () => _save(keepStatus),
      ),
    );

    if (_status == ResourceStatus.draft) {
      buttons.add(
        ElevatedButton(
          onPressed: _isSaving ? null : _publish,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Publish'),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: buttons,
    );
  }

  Future<void> _save(ResourceStatus status) async {
    final draft = _draft;
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final user = ref.read(currentUserProvider);
    final topic = await ref.read(topicByIdProvider(widget.topicId).future);
    if (user == null || topic == null) {
      setState(() => _error = "Couldn't find this topic.");
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final repo = ref.read(adminResourceRepositoryProvider);

    try {
      if (_isNew) {
        final id = await repo.createDraft(
          topicId: widget.topicId,
          subjectId: topic.subjectId,
          uid: user.uid,
          draft: draft,
        );
        _invalidate(id);
        if (!mounted) return;
        setState(() => _dirty = false);
        _snack('Draft saved. The review email goes out on the next check.');
        context.pushReplacement(adminResourcePath(widget.topicId, id));
        return;
      }

      await repo.save(
        topicId: widget.topicId,
        resourceId: widget.resourceId!,
        draft: draft,
        status: status,
      );
      _invalidate(widget.resourceId!);
      if (!mounted) return;
      final was = _status;
      setState(() {
        _status = status;
        _dirty = false;
      });
      _snack(switch ((was, status)) {
        (ResourceStatus.draft, ResourceStatus.published) => 'Published.',
        (ResourceStatus.published, ResourceStatus.draft) =>
          'Unpublished. Students can no longer see it.',
        _ => 'Saved.',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't save: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publish() async {
    final ok = await _confirm(
      title: 'Publish this ${_type.label.toLowerCase()}?',
      message:
          'Every student who opens this topic will see it immediately. '
          'Check the preview first.',
      action: 'Publish',
    );
    if (ok) await _save(ResourceStatus.published);
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      title: 'Delete this draft?',
      message: 'This cannot be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(adminResourceRepositoryProvider)
          .delete(topicId: widget.topicId, resourceId: widget.resourceId!);
      _invalidate(widget.resourceId!);
      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('Draft deleted.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't delete: $e";
        _isSaving = false;
      });
    }
  }

  void _invalidate(String resourceId) {
    // Best effort: the nightly `jobs.js --job=counts` heals a miss.
    ref
        .read(adminResourceRepositoryProvider)
        .refreshLessonCount(widget.topicId)
        .then((_) {
          if (mounted) ref.invalidate(topicByIdProvider(widget.topicId));
        })
        .catchError((_) {});
    ref.invalidate(adminTopicResourcesProvider(widget.topicId));
    ref.invalidate(adminDraftsProvider);
    ref.invalidate(
      adminResourceProvider((topicId: widget.topicId, resourceId: resourceId)),
    );
    ref.invalidate(topicResourcesProvider(widget.topicId));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() => _confirm(
    title: 'Discard unsaved changes?',
    message: 'Your edits since the last save will be lost.',
    action: 'Discard',
    destructive: true,
  );

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive
                  ? AppColors.wrong
                  : AppColors.primary,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// The pinned questions, with their text, each removable.
class _PinnedList extends ConsumerWidget {
  const _PinnedList({required this.ids, required this.onRemove});

  final List<String> ids;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(pinnedQuestionsProvider(ids.join(',')));
    final byId = {
      for (final q in loaded.asData?.value ?? const <Question>[]) q.id: q,
    };
    return Column(
      children: [
        for (var i = 0; i < ids.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '${i + 1}',
              style: AppTheme.bodyMd.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            title: byId[ids[i]] != null
                ? FullLatexView(
                    latex: byId[ids[i]]!.text,
                    textStyle: AppTheme.bodyMd.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  )
                : Text(
                    loaded.isLoading
                        ? 'Loading…'
                        : '${ids[i]} — no longer available, will be skipped',
                    style: AppTheme.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onRemove(ids[i]),
            ),
          ),
      ],
    );
  }
}

/// Browse a topic's answerable questions a page at a time and tick the
/// ones to pin. Returns the chosen ids in tick order, or null on cancel.
class _QuestionPicker extends ConsumerStatefulWidget {
  const _QuestionPicker({required this.topicId, required this.initial});

  final String topicId;
  final List<String> initial;

  @override
  ConsumerState<_QuestionPicker> createState() => _QuestionPickerState();
}

class _QuestionPickerState extends ConsumerState<_QuestionPicker> {
  final _questions = <Question>[];
  late final List<String> _chosen = [...widget.initial];
  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(adminResourceRepositoryProvider)
          .questionPage(
            topicId: widget.topicId,
            startAfterId: _questions.isEmpty ? null : _questions.last.id,
          );
      if (!mounted) return;
      setState(() {
        _questions.addAll(page);
        _exhausted = page.length < 20;
      });
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't load questions: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_chosen.contains(id)) {
        _chosen.remove(id);
      } else if (_chosen.length < kMaxPinnedQuestions) {
        _chosen.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text('Choose questions (${_chosen.length} chosen)'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: AppColors.wrong))
            : ListView(
                children: [
                  for (final q in _questions)
                    CheckboxListTile(
                      value: _chosen.contains(q.id),
                      onChanged: (_) => _toggle(q.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: FullLatexView(
                        latex: q.text,
                        textStyle: AppTheme.bodyMd.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      subtitle: Text(
                        'Answer: ${q.correctIndex >= 0 && q.correctIndex < q.options.length ? q.options[q.correctIndex] : '—'}'
                        '${q.year != null ? ' · ${q.year}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_exhausted)
                    TextButton(
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    )
                  else if (_questions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('This topic has no answerable questions.'),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_chosen),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: color.withAlpha(140)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}
