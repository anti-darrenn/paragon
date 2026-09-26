import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/staff_role.dart';
import '../../core/lessons/lesson_doc.dart';
import '../../core/models/learn_resource.dart';
import '../../core/models/question.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/admin_resource_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/repositories/lesson_workflow.dart';
import '../../core/repositories/subject_index_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/article_view.dart';
import '../../core/widgets/full_latex_view.dart';
import '../lesson/exercise_pane.dart';
import '../lesson/video_pane.dart';
import '../onboarding/onboarding_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'studio/block_toolbar.dart';
// Deferred: the image codecs and file picker load only when an author
// uploads an image, never as part of a student's download.
import 'studio/image_upload.dart' deferred as image_upload;
import 'studio/problems_panel.dart';
import 'studio/review_panels.dart';
import 'studio/studio_storage.dart';
import '../../core/theme/app_palette.dart';

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

  /// The resource as last loaded or saved; null for a new one. The
  /// workflow actions (submit, approve…) act on it.
  LearnResource? _loaded;

  /// Autosave: the body is backed up to this device a few seconds after
  /// typing stops — never to Firestore, where every save writes a history
  /// version. See [StudioStorage].
  final _storage = const StudioStorage();
  Timer? _backupTimer;

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
    _body.addListener(_scheduleBackup);
  }

  void _scheduleBackup() {
    final id = widget.resourceId;
    if (!_hydrated || !_dirty || id == null) return;
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(seconds: 5), () {
      _storage.writeBackup(widget.topicId, id, _body.text);
    });
  }

  /// Offers the text this device backed up but never saved — the tab was
  /// closed, the browser crashed — when it differs from what is stored.
  Future<void> _offerBackup() async {
    final id = widget.resourceId;
    if (id == null) return;
    final backup = await _storage.readBackup(widget.topicId, id);
    if (!mounted || backup == null || backup == _body.text) return;
    final restore = await _confirm(
      title: 'Restore unsaved writing?',
      message:
          'This device has text for this item that was never saved. '
          'Restore it? (You can still discard it before saving.)',
      action: 'Restore',
    );
    if (!mounted) return;
    if (restore) {
      _body.text = backup;
      setState(() => _dirty = true);
    } else {
      await _storage.clearBackup(widget.topicId, id);
    }
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
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
      _loaded = resource;
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerBackup());
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
        backgroundColor: context.palette.background,
        appBar: AppBar(
          title: Text(
            _isNew ? 'New $noun' : 'Edit $noun',
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_loaded != null)
              IconButton(
                tooltip: 'History',
                icon: const Icon(Icons.history_rounded),
                onPressed: () => showHistorySheet(
                  context,
                  resource: _loaded!,
                  onRestored: () {
                    _hydrated = false;
                    _snack(
                      'Restored. The version you replaced is in the history too.',
                    );
                    setState(() {});
                  },
                ),
              ),
          ],
          bottom: topic == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      topic.name,
                      style: AppTheme.caption.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ),
        ),
        body: SafeArea(
          child: StudioShortcuts(
            body: _body,
            onSave: () {
              if (!_isSaving) _save(_status ?? ResourceStatus.draft);
            },
            onSubmit: _primaryAction(),
            child: missing
                ? Center(
                    child: Text(
                      'This resource no longer exists.',
                      style: AppTheme.bodyMd.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  )
                : !_hydrated
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 900
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _editorPane()),
                              VerticalDivider(
                                width: 1,
                                color: context.palette.border,
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
            statusLine(_status!, isRevision: _loaded?.isRevision ?? false),
            style: AppTheme.label.copyWith(color: statusColour(_status!)),
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
          Text(
            _error!,
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
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
    BlockToolbar(
      controller: _body,
      onInsertQuestion: _insertPastQuestion,
      onInsertImage: _insertImage,
      onPasteBlock: _pasteBlock,
    ),
    const SizedBox(height: 8),
    _multiline(_body, minLines: 18, monospace: true),
    const SizedBox(height: 12),
    ProblemsPanel(body: _body),
  ];

  Future<void> _insertPastQuestion() async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          _QuestionPicker(topicId: widget.topicId, initial: const []),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final questions = await ref.read(
      pinnedQuestionsProvider(picked.join(',')).future,
    );
    final byId = {for (final q in questions) q.id: q};
    for (final id in picked) {
      // A real past paper question is labelled "Seen in WAEC"; anything
      // else from the bank is a plain quick check.
      final waec = byId[id]?.source == 'waec' && byId[id]?.year != null;
      insertAtCursor(_body, '::: ${waec ? 'waec' : 'check'} q:$id\n:::');
    }
  }

  Future<void> _insertImage() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    try {
      await image_upload.loadLibrary();
      final id = await image_upload.pickAndUploadLessonImage(
        db: FirebaseFirestore.instance,
        uid: uid,
      );
      if (id == null || !mounted) return;
      insertAtCursor(_body, '![Describe the image here](asset:$id)');
      _snack(
        'Image uploaded. Replace "Describe the image here" with a caption.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't upload the image: $e");
    }
  }

  Future<void> _pasteBlock() async {
    final block = await _storage.readClipboard();
    if (!mounted) return;
    if (block == null || block.trim().isEmpty) {
      _snack(
        'Nothing copied yet. Use the copy icon on a block in any preview.',
      );
      return;
    }
    insertAtCursor(_body, block);
  }

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
      builder: (_) =>
          _QuestionPicker(topicId: widget.topicId, initial: _questionIds),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _questionIds = picked;
      _dirty = true;
    });
  }

  Widget _label(String text) => Text(
    text,
    style: AppTheme.label.copyWith(color: context.palette.textSecondary),
  );

  Widget _hint(String text, {Color? color}) => Text(
    text,
    style: AppTheme.caption.copyWith(
      color: color ?? context.palette.textSecondary,
    ),
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
        color: context.palette.textPrimary,
        fontFamily: monospace ? 'monospace' : null,
        height: 1.5,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: context.palette.surface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  // ─── Preview ───────────────────────────────────────────────────────

  /// Puts a copy icon on each block in the preview. The block's source
  /// goes to the studio clipboard, pastable into any lesson with
  /// "Paste block".
  Widget _copyableBlock(LessonBlock block, Widget child) => Stack(
    children: [
      Padding(padding: const EdgeInsets.only(right: 32), child: child),
      Positioned(
        top: 0,
        right: 0,
        child: IconButton(
          tooltip: 'Copy this block',
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: Icon(
            Icons.copy_all_rounded,
            color: context.palette.textSecondary,
          ),
          onPressed: () async {
            await _storage.writeClipboard(block.source);
            if (mounted) {
              _snack('Block copied. Use "Paste block" in any lesson.');
            }
          },
        ),
      ),
    ],
  );

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
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ArticleView(
                    body: r.body,
                    authorPreview: true,
                    decorate: _copyableBlock,
                  ),
                ],
              ),
            },
          ],
        );
      },
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────

  /// The buttons, by role and status (docs/CONTENT_ROLES.md). The rules
  /// enforce the same table; this only avoids offering what would fail.
  Widget _actions() {
    final role = _roleHere();
    final status = _status;
    final loaded = _loaded;
    final busy = _isSaving;
    final buttons = <Widget>[];

    // Outside this account's subjects: look, but change nothing — the
    // rules would refuse every write.
    if (!role.canWrite) {
      return Text(
        'This subject is outside the ones you work on, so you can read this '
        'but not change it.',
        style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
      );
    }

    Widget outline(String label, Color colour, VoidCallback onTap) =>
        _OutlineAction(
          label: label,
          color: colour,
          onPressed: busy ? null : onTap,
        );

    final primary = _primaryLabel(role);
    final primaryAction = _primaryAction();

    if (status == null) {
      // New item: the first save creates the draft.
      buttons.add(
        outline(
          'Save draft',
          context.palette.textPrimary,
          () => _save(ResourceStatus.draft),
        ),
      );
    } else if (status.isLive) {
      if (role.canReview) {
        buttons.add(outline('Delete', AppColors.wrong, _delete));
        buttons.add(outline('Unpublish', AppColors.warning, _unpublish));
        buttons.add(
          outline(
            'Save changes',
            context.palette.textPrimary,
            () => _save(status),
          ),
        );
      }
      buttons.add(
        outline('Start a revision', AppColors.accentBlue, _startRevision),
      );
    } else {
      final ownDraft = loaded?.createdBy == ref.watch(currentUserProvider)?.uid;
      if (role.canReview || (status == ResourceStatus.draft && ownDraft)) {
        buttons.add(outline('Delete', AppColors.wrong, _delete));
      }
      if (role.canReview && status == ResourceStatus.inReview) {
        buttons.add(
          outline('Request changes', AppColors.wrong, _requestChanges),
        );
      }
      buttons.add(
        outline('Save', context.palette.textPrimary, () => _save(status)),
      );
    }

    if (primary != null && primaryAction != null) {
      buttons.add(
        ElevatedButton(
          onPressed: busy ? null : primaryAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: buttons,
        ),
        if (loaded != null) ...[
          const SizedBox(height: 20),
          CommentsPanel(resource: loaded),
        ],
      ],
    );
  }

  /// This account's role for this item's subject — its role inside the
  /// subjects it covers, none outside them (`StaffAccess.roleIn`).
  StaffRole _roleHere() {
    final subjectId =
        _loaded?.subjectId ??
        ref.watch(topicByIdProvider(widget.topicId)).asData?.value?.subjectId ??
        '';
    return ref.watch(staffAccessProvider).roleIn(subjectId);
  }

  /// The one thing this person most likely wants to do next.
  String? _primaryLabel(StaffRole role) => switch (_status) {
    _ when !role.canWrite => null,
    null || ResourceStatus.published => null,
    ResourceStatus.draft || ResourceStatus.changesRequested =>
      role.canReview ? 'Publish' : 'Submit for review',
    ResourceStatus.inReview =>
      role.canReview
          ? ((_loaded?.isRevision ?? false)
                ? 'Approve revision'
                : 'Approve and publish')
          : null,
  };

  /// Also Ctrl+Enter. Null when there is nothing to submit or approve.
  VoidCallback? _primaryAction() {
    final role = _roleHere();
    return switch (_status) {
      _ when !role.canWrite => null,
      null || ResourceStatus.published => null,
      ResourceStatus.draft ||
      ResourceStatus.changesRequested => role.canReview ? _approve : _submit,
      ResourceStatus.inReview => role.canReview ? _approve : null,
    };
  }

  /// Saves unsaved edits first, so a transition never applies to stale
  /// text. Returns the fresh resource, or null if saving failed.
  Future<LearnResource?> _saveThenLoad() async {
    if (_dirty && !await _save(_status ?? ResourceStatus.draft, quiet: true)) {
      return null;
    }
    final key = (topicId: widget.topicId, resourceId: widget.resourceId!);
    ref.invalidate(adminResourceProvider(key));
    return ref.read(adminResourceProvider(key).future);
  }

  Future<void> _transition(
    String done,
    Future<void> Function(LearnResource r, String uid) action, {
    bool changesLiveContent = false,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null || widget.resourceId == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final r = await _saveThenLoad();
      if (r == null) return;
      await action(r, user.uid);
      if (changesLiveContent) await _refreshLiveIndexes();
      _hydrated = false;
      _invalidate(widget.resourceId!);
      if (mounted) _snack(done);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't update: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submit() => _transition(
    'Submitted. The reviewers are emailed on the next check.',
    (r, uid) => ref.read(lessonWorkflowProvider).submitForReview(r, uid: uid),
  );

  Future<void> _approve() async {
    final isRevision = _loaded?.isRevision ?? false;
    final ok = await _confirm(
      title: isRevision
          ? 'Approve this revision?'
          : 'Publish this ${_type.label.toLowerCase()}?',
      message: isRevision
          ? 'It replaces the published version for every student straight '
                'away. The old version stays in the history.'
          : 'Every student who opens this topic will see it immediately. '
                'Check the preview first.',
      action: isRevision ? 'Approve' : 'Publish',
    );
    if (!ok || !mounted) return;
    String? liveId;
    await _transition(
      isRevision ? 'Revision approved and live.' : 'Published.',
      (r, uid) async =>
          liveId = await ref.read(lessonWorkflowProvider).approve(r, uid: uid),
      changesLiveContent: true,
    );
    // An approved revision is deleted; carry on in the live original.
    final id = liveId;
    if (mounted && id != null && id != widget.resourceId) {
      setState(() => _dirty = false);
      context.pushReplacement(adminResourcePath(widget.topicId, id));
    }
  }

  Future<void> _requestChanges() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: const Text('Request changes'),
        content: TextField(
          controller: reason,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'What needs to change? The writer is emailed this.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Send back'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true || !mounted) return;
    final user = ref.read(currentUserProvider);
    await _transition(
      'Sent back to the writer.',
      (r, uid) => ref
          .read(lessonWorkflowProvider)
          .requestChanges(
            r,
            uid: uid,
            authorName: authorNameFor(user?.displayName, user?.email),
            reason: text,
          ),
    );
  }

  Future<void> _unpublish() async {
    final ok = await _confirm(
      title: 'Unpublish?',
      message:
          'Students will no longer see this. It goes back to being a draft.',
      action: 'Unpublish',
      destructive: true,
    );
    if (!ok) return;
    await _transition(
      'Unpublished. Students can no longer see it.',
      (r, uid) => ref.read(lessonWorkflowProvider).unpublish(r, uid: uid),
      changesLiveContent: true,
    );
  }

  Future<void> _startRevision() async {
    final user = ref.read(currentUserProvider);
    final r = _loaded;
    if (user == null || r == null) return;
    setState(() => _isSaving = true);
    try {
      final id = await ref
          .read(lessonWorkflowProvider)
          .startRevision(r, uid: user.uid);
      ref.invalidate(adminTopicResourcesProvider(widget.topicId));
      if (!mounted) return;
      context.push(adminResourcePath(widget.topicId, id));
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't start a revision: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// After anything that changes what students see: the subject's
  /// glossary/formula/card index. Best effort — "Rebuild index" in the
  /// studio heals a miss. (The lesson count is refreshed by [_invalidate].)
  Future<void> _refreshLiveIndexes() async {
    final topic = await ref.read(topicByIdProvider(widget.topicId).future);
    if (topic == null) return;
    try {
      await ref
          .read(subjectIndexRepositoryProvider)
          .rebuildTopic(
            subjectId: topic.subjectId,
            topicId: topic.id,
            topicName: topic.name,
          );
    } catch (_) {}
    ref.invalidate(subjectIndexProvider(topic.subjectId));
  }

  /// Saves the form without changing the item's status. Returns whether it
  /// saved. [quiet] skips the snackbar and busy state, for saving just
  /// before a workflow transition.
  Future<bool> _save(ResourceStatus status, {bool quiet = false}) async {
    final draft = _draft;
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return false;
    }
    final user = ref.read(currentUserProvider);
    final topic = await ref.read(topicByIdProvider(widget.topicId).future);
    if (user == null || topic == null) {
      setState(() => _error = "Couldn't find this topic.");
      return false;
    }

    if (!quiet) {
      setState(() {
        _isSaving = true;
        _error = null;
      });
    }

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
        if (!mounted) return true;
        setState(() => _dirty = false);
        _snack('Draft saved. Submit it for review when it is ready.');
        context.pushReplacement(adminResourcePath(widget.topicId, id));
        return true;
      }

      await repo.save(
        topicId: widget.topicId,
        resourceId: widget.resourceId!,
        draft: draft,
        status: status,
        savedBy: user.uid,
      );
      await _storage.clearBackup(widget.topicId, widget.resourceId!);
      if (status.isLive) await _refreshLiveIndexes();
      _invalidate(widget.resourceId!);
      if (!mounted) return true;
      setState(() {
        _status = status;
        _dirty = false;
      });
      if (!quiet) {
        _snack(
          status.isLive
              ? 'Saved. Students see the change now.'
              : 'Saved. The previous version is in the history.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't save: $e");
      return false;
    } finally {
      if (mounted && !quiet) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      title: 'Delete this ${_type.label.toLowerCase()}?',
      message: (_status?.isLive ?? false)
          ? 'Students lose it immediately. This cannot be undone. To take '
                'it down but keep it, use Unpublish instead.'
          : 'This cannot be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(adminResourceRepositoryProvider)
          .delete(topicId: widget.topicId, resourceId: widget.resourceId!);
      if (_status?.isLive ?? false) await _refreshLiveIndexes();
      _invalidate(widget.resourceId!);
      if (!mounted) return;
      setState(() => _dirty = false);
      _snack('Deleted.');
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
    ref.invalidate(adminStatusQueueProvider);
    ref.invalidate(adminSubjectResourcesProvider);
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
        backgroundColor: context.palette.surface,
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
                color: context.palette.textSecondary,
              ),
            ),
            title: byId[ids[i]] != null
                ? FullLatexView(
                    latex: byId[ids[i]]!.text,
                    textStyle: AppTheme.bodyMd.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  )
                : Text(
                    loaded.isLoading
                        ? 'Loading…'
                        : '${ids[i]} — no longer available, will be skipped',
                    style: AppTheme.caption.copyWith(
                      color: context.palette.textSecondary,
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
      backgroundColor: context.palette.surface,
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
                          color: context.palette.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Answer: ${q.correctIndex >= 0 && q.correctIndex < q.options.length ? q.options[q.correctIndex] : '—'}'
                        '${q.year != null ? ' · ${q.year}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption.copyWith(
                          color: context.palette.textSecondary,
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
