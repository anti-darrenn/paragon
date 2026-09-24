import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/learn_resource.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/admin_resource_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/article_view.dart';
import '../onboarding/onboarding_scaffold.dart';

/// Write or edit one Learn article.
///
/// `/admin/topic/:topicId/article/new` starts a draft;
/// `/admin/topic/:topicId/article/:resourceId` edits an existing one, and
/// is the link the draft-notification email points at.
///
/// The preview is the real [ArticleView] fed the text being typed, not a
/// second renderer, so what you see here is what a student gets.
class AdminArticleEditorScreen extends ConsumerStatefulWidget {
  const AdminArticleEditorScreen({
    super.key,
    required this.topicId,
    this.resourceId,
  });

  final String topicId;

  /// Null for a new article.
  final String? resourceId;

  @override
  ConsumerState<AdminArticleEditorScreen> createState() =>
      _AdminArticleEditorScreenState();
}

class _AdminArticleEditorScreenState
    extends ConsumerState<AdminArticleEditorScreen> {
  final _title = TextEditingController();
  final _order = TextEditingController();
  final _body = TextEditingController();

  bool _hydrated = false;
  bool _dirty = false;
  bool _isSaving = false;
  String? _error;

  /// Null until the article exists in Firestore.
  ResourceStatus? _status;

  bool get _isNew => widget.resourceId == null;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _order, _body]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _order.dispose();
    _body.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_hydrated && !_dirty) setState(() => _dirty = true);
  }

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
      final async = ref.watch(
        adminResourceProvider((
          topicId: widget.topicId,
          resourceId: widget.resourceId!,
        )),
      );
      final resource = async.asData?.value;
      if (resource == null) return;
      _title.text = resource.title;
      _order.text = '${resource.order}';
      _body.text = resource.body;
      _status = resource.status;
    }
    _hydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    final topic = ref.watch(adminTopicProvider(widget.topicId)).asData?.value;
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
            _isNew ? 'New article' : 'Edit article',
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
                    'This article no longer exists.',
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
          hintText: 'e.g. Completing the square',
        ),
        const SizedBox(height: 16),
        OnboardingTextField(
          controller: _order,
          label: 'POSITION IN TOPIC',
          hintText: '1',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Text(
          'BODY',
          style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 4),
        Text(
          r'Inline maths \( ... \). Display maths \[ ... \] on its own line. '
          r'\textbf{...} and \textit{...} for emphasis. Headings #, ##, ###; '
          r'lists - or 1.; quotes >; rule ---. A lone $ is a dollar sign. '
          r'**bold**, $...$ and \emph are not supported.',
          style: AppTheme.caption.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          minLines: 18,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: AppTheme.bodyMd.copyWith(
            color: AppColors.textPrimaryDark,
            fontFamily: 'monospace',
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
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: AppTheme.bodyMd.copyWith(color: AppColors.wrong)),
        ],
        const SizedBox(height: 20),
        _actions(),
      ],
    );
  }

  Widget _previewPane() {
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _body]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'PREVIEW',
            style: AppTheme.label.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 16),
          Text(
            _title.text.trim().isEmpty ? '(untitled)' : _title.text.trim(),
            style: AppTheme.heading2.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 16),
          ArticleView(body: _body.text),
        ],
      ),
    );
  }

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

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Give the article a title.';
    if (int.tryParse(_order.text.trim()) == null) {
      return 'Position must be a whole number.';
    }
    if (_body.text.trim().isEmpty) return 'The article has no body.';
    return null;
  }

  Future<void> _save(ResourceStatus status) async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final user = ref.read(currentUserProvider);
    final topic = await ref.read(adminTopicProvider(widget.topicId).future);
    if (user == null || topic == null) {
      setState(() => _error = "Couldn't find this topic.");
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final repo = ref.read(adminResourceRepositoryProvider);
    final order = int.parse(_order.text.trim());

    try {
      if (_isNew) {
        final id = await repo.createDraft(
          topicId: widget.topicId,
          subjectId: topic.subjectId,
          uid: user.uid,
          title: _title.text,
          order: order,
          body: _body.text,
        );
        _invalidate(id);
        if (!mounted) return;
        setState(() => _dirty = false);
        _snack('Draft saved. The review email goes out on the next check.');
        context.pushReplacement('/admin/topic/${widget.topicId}/article/$id');
        return;
      }

      await repo.save(
        topicId: widget.topicId,
        resourceId: widget.resourceId!,
        title: _title.text,
        order: order,
        body: _body.text,
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
      title: 'Publish this article?',
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
