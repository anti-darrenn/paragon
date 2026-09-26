import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lessons/lesson_doc.dart';
import '../../../core/models/learn_resource.dart';
import '../../../core/models/question.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'study_models.dart';
import 'study_providers.dart';
import '../../../core/theme/app_palette.dart';

/// The one-line prompt a guest sees wherever their notes are shown.
const kGuestNotesPrompt = 'Sign up to keep your notes on every device';

class GuestNotesPrompt extends ConsumerWidget {
  const GuestNotesPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isGuestProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.phone_android,
            size: 14,
            color: context.palette.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$kGuestNotesPrompt. Right now they are kept on this device only.',
              style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

LessonRef lessonRefOf(LearnResource r) =>
    (topicId: r.topicId, resourceId: r.id, subjectId: r.subjectId);

void _showError(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text("Couldn't save that. Try again.")),
  );
}

// ─── A block in the article ──────────────────────────────────────────

/// A top-level article block with its highlight and note marker.
///
/// **The widget tree has the same shape whatever the block's state.** A
/// block can hold a video iframe, and a browser restarts an iframe that
/// moves to a new parent — so highlighting changes a decoration and a
/// padding value, never which widgets are present.
///
/// Long-press opens the actions (tap is left to the interactive blocks'
/// own buttons); on a pointer device a small handle also appears in the
/// gutter on hover.
class AnnotatedBlock extends ConsumerStatefulWidget {
  const AnnotatedBlock({
    super.key,
    required this.block,
    required this.resource,
    required this.note,
    required this.child,
  });

  final LessonBlock block;
  final LearnResource resource;
  final LessonNote? note;
  final Widget child;

  @override
  ConsumerState<AnnotatedBlock> createState() => _AnnotatedBlockState();
}

class _AnnotatedBlockState extends ConsumerState<AnnotatedBlock> {
  bool _hover = false;

  LessonNotesNotifier get _notes =>
      ref.read(lessonNotesProvider(lessonRefOf(widget.resource)).notifier);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) _showError(context);
    }
  }

  Future<void> _openActions() async {
    final choice = await showModalBottomSheet<_BlockAction>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _BlockActionsSheet(note: widget.note),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _SetColour(:final colour):
        await _run(() => _notes.setColour(widget.block, colour));
      case _EditNote():
        await _editNote();
      case _RemoveAll():
        final id = widget.note?.id;
        if (id != null) await _run(() => _notes.remove(id));
    }
  }

  Future<void> _editNote() async {
    final text = await showNoteEditor(context, initial: widget.note?.text ?? '');
    if (text == null || !mounted) return;
    await _run(() => _notes.setText(widget.block, text));
  }

  Future<void> _showNote() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: Text(
          'Your note',
          style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Text(
            widget.note?.text ?? '',
            style: AppTheme.bodyMd.copyWith(color: context.palette.textPrimary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const Text('Delete', style: TextStyle(color: AppColors.wrong)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('edit'),
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _editNote();
    if (action == 'delete') await _run(() => _notes.setText(widget.block, ''));
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final colour = note?.colour;
    final enabled = ref.watch(studyStoreProvider) != null;

    Widget gutter;
    if (note != null && note.hasText) {
      gutter = IconButton(
        key: ValueKey('note-marker-${widget.block.key}'),
        tooltip: 'Your note',
        onPressed: _showNote,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(
          Icons.sticky_note_2,
          color: colour?.colour ?? AppColors.warning,
        ),
      );
    } else if (_hover && enabled) {
      gutter = IconButton(
        tooltip: 'Highlight or add a note',
        onPressed: _openActions,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(Icons.edit_note, color: context.palette.textSecondary),
      );
    } else {
      gutter = const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onLongPress: enabled ? _openActions : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                key: ValueKey('note-block-${widget.block.key}'),
                decoration: BoxDecoration(
                  color: colour?.fill ?? Colors.transparent,
                  // `BorderSide.none`, not width 0: a zero-width side is
                  // drawn as a hairline.
                  border: Border(
                    left: colour == null
                        ? BorderSide.none
                        : BorderSide(color: colour.colour, width: 3),
                  ),
                ),
                child: Padding(
                  padding: colour == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(10, 4, 6, 4),
                  child: widget.child,
                ),
              ),
            ),
            SizedBox(width: 28, child: gutter),
          ],
        ),
      ),
    );
  }
}

sealed class _BlockAction {
  const _BlockAction();
}

class _SetColour extends _BlockAction {
  const _SetColour(this.colour);
  final HighlightColour? colour;
}

class _EditNote extends _BlockAction {
  const _EditNote();
}

class _RemoveAll extends _BlockAction {
  const _RemoveAll();
}

class _BlockActionsSheet extends StatelessWidget {
  const _BlockActionsSheet({required this.note});

  final LessonNote? note;

  @override
  Widget build(BuildContext context) {
    final current = note?.colour;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Highlight',
              style: AppTheme.label.copyWith(color: context.palette.textPrimary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                for (final c in HighlightColour.values)
                  _Swatch(
                    colour: c,
                    selected: c == current,
                    onTap: () => Navigator.of(context).pop(
                      _SetColour(c == current ? null : c),
                    ),
                  ),
                if (current != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const _SetColour(null)),
                    child: const Text('No highlight'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.sticky_note_2_outlined, color: context.palette.textPrimary),
              title: Text(
                note?.hasText == true ? 'Edit note' : 'Add a note',
                style: TextStyle(color: context.palette.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(const _EditNote()),
            ),
            if (note != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: AppColors.wrong),
                title: const Text(
                  'Remove highlight and note',
                  style: TextStyle(color: AppColors.wrong),
                ),
                onTap: () => Navigator.of(context).pop(const _RemoveAll()),
              ),
            const GuestNotesPrompt(),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour, required this.selected, required this.onTap});

  final HighlightColour colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${colour.label} highlight',
      child: InkWell(
        key: ValueKey('swatch-${colour.name}'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colour.colour,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.palette.textPrimary : context.palette.border,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a note's text. Returns the text on Done, null on Cancel —
/// the only point at which a note is written.
Future<String?> showNoteEditor(BuildContext context, {required String initial}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NoteEditor(initial: initial),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.initial});
  final String initial;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(
        widget.initial.isEmpty ? 'Add a note' : 'Edit note',
        style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('note-editor-field'),
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: kMaxNoteLength,
          style: TextStyle(color: context.palette.textPrimary),
          decoration: const InputDecoration(hintText: 'Your note'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ─── Header actions ──────────────────────────────────────────────────

/// Bookmark for this lesson item, and "Notes (n)".
class LessonHeaderActions extends ConsumerWidget {
  const LessonHeaderActions({super.key, required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(studyStoreProvider) == null) return const SizedBox.shrink();
    final notes =
        ref.watch(lessonNotesProvider(lessonRefOf(resource))).asData?.value ??
        const <LessonNote>[];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BookmarkButton(
          bookmark: Bookmark(
            kind: BookmarkKind.lesson,
            topicId: resource.topicId,
            resourceId: resource.id,
            subjectId: resource.subjectId,
            title: resource.title,
          ),
          savedLabel: 'Remove bookmark',
          unsavedLabel: 'Bookmark this lesson',
        ),
        TextButton(
          key: const ValueKey('notes-button'),
          onPressed: () => showLessonNotesSheet(context, resource),
          child: Text('Notes (${notes.length})'),
        ),
      ],
    );
  }
}

/// A save/unsave icon for one bookmark.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({
    super.key,
    required this.bookmark,
    this.savedLabel = 'Remove from saved',
    this.unsavedLabel = 'Save for later',
    this.size = 20,
  });

  final Bookmark bookmark;
  final String savedLabel;
  final String unsavedLabel;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(studyStoreProvider) == null) return const SizedBox.shrink();
    final saved =
        ref.watch(bookmarksProvider).asData?.value.containsKey(bookmark.key) ??
        false;
    return IconButton(
      key: ValueKey('bookmark-${bookmark.key}'),
      tooltip: saved ? savedLabel : unsavedLabel,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        try {
          await ref.read(bookmarksProvider.notifier).toggle(bookmark);
        } catch (_) {
          if (context.mounted) _showError(context);
        }
      },
      icon: Icon(
        saved ? Icons.bookmark : Icons.bookmark_border,
        color: saved ? AppColors.primary : context.palette.textSecondary,
      ),
    );
  }
}

/// The bookmark toggle placed beside "Report a problem" on a question.
class QuestionBookmarkButton extends StatelessWidget {
  const QuestionBookmarkButton({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) => BookmarkButton(
    size: 16,
    bookmark: Bookmark(
      kind: BookmarkKind.question,
      topicId: question.topicId,
      questionId: question.id,
      subjectId: question.subjectId.isEmpty ? null : question.subjectId,
      title: Bookmark.questionTitle(question.text),
    ),
    unsavedLabel: 'Save this question',
  );
}

// ─── The lesson's notes ──────────────────────────────────────────────

Future<void> showLessonNotesSheet(BuildContext context, LearnResource resource) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => LessonNotesSheet(resource: resource),
  );
}

/// Every highlight and note on this lesson, with those whose paragraph has
/// since been rewritten listed apart — with the text they were written
/// against — so none silently disappears.
class LessonNotesSheet extends ConsumerWidget {
  const LessonNotesSheet({super.key, required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = lessonRefOf(resource);
    final notes = ref.watch(lessonNotesProvider(lesson)).asData?.value ??
        const <LessonNote>[];
    final parts = partitionNotes(notes, parseLessonDoc(resource.body));

    Widget tile(LessonNote n, {required bool detached}) => NoteTile(
      key: ValueKey('${detached ? 'detached' : 'attached'}-${n.id}'),
      note: n,
      showSnapshot: detached,
      onDelete: () async {
        try {
          await ref.read(lessonNotesProvider(lesson).notifier).remove(n.id);
        } catch (_) {
          if (context.mounted) _showError(context);
        }
      },
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Your notes',
            style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Long-press any paragraph to highlight it or add a note.',
            style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
          ),
          const GuestNotesPrompt(),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No notes on this lesson yet.',
                style: AppTheme.bodyMd.copyWith(color: context.palette.textSecondary),
              ),
            ),
          for (final n in parts.attached) tile(n, detached: false),
          if (parts.detached.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'From an earlier version of this lesson',
              key: const ValueKey('detached-heading'),
              style: AppTheme.label.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: 4),
            Text(
              'The paragraph these were written on has since been changed.',
              style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final n in parts.detached) tile(n, detached: true),
          ],
        ],
      ),
    );
  }
}

/// One note in a list: its text (or "Highlight"), optionally the text it
/// was written against.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    this.showSnapshot = true,
    this.onTap,
    this.onDelete,
  });

  final LessonNote note;
  final bool showSnapshot;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bar = note.colour?.colour ?? context.palette.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            color: context.palette.track,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: bar, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.hasText ? note.text : 'Highlight',
                      style: AppTheme.bodyMd.copyWith(
                        color: note.hasText
                            ? context.palette.textPrimary
                            : context.palette.textSecondary,
                      ),
                    ),
                    if (showSnapshot && note.snapshot.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note.snapshot,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption.copyWith(
                          color: context.palette.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: context.palette.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
