import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_palette.dart';

/// One insertable block: what the toolbar button says and the text it
/// writes. Templates are filled in, so an author edits rather than types
/// syntax from memory. The format is `docs/LESSON_FORMAT.md`.
class BlockTemplate {
  const BlockTemplate(this.label, this.icon, this.text, {this.shortcut});
  final String label;
  final IconData icon;
  final String text;

  /// Alt+digit, shown in the tooltip.
  final int? shortcut;
}

const blockTemplates = [
  BlockTemplate(
    'Definition',
    Icons.menu_book_outlined,
    '::: definition Term\nWhat the term means.\n:::',
    shortcut: 1,
  ),
  BlockTemplate(
    'Formula',
    Icons.functions_rounded,
    '::: formula Name\n\\[ a^2 + b^2 = c^2 \\]\n:::',
    shortcut: 2,
  ),
  BlockTemplate(
    'Worked example',
    Icons.edit_note_rounded,
    '::: example Title\nThe problem.\n--- step\nFirst step.\n--- step\nSecond step.\n--- answer\nThe answer.\n:::',
    shortcut: 3,
  ),
  BlockTemplate(
    'Try it',
    Icons.psychology_alt_outlined,
    '::: tryit\nA problem for the student.\n--- hint\nA nudge.\n--- answer\nThe answer.\n:::',
    shortcut: 4,
  ),
  BlockTemplate(
    'Quick check',
    Icons.task_alt_rounded,
    '::: check\nThe question?\n- [ ] A wrong option\n- [x] The right option\n- [ ] Another wrong option\n--- why\nWhy it is right.\n:::',
    shortcut: 5,
  ),
  BlockTemplate(
    'Remember',
    Icons.bookmark_border_rounded,
    '::: remember\nThe thing to remember.\n:::',
    shortcut: 6,
  ),
  BlockTemplate(
    'Common mistake',
    Icons.error_outline_rounded,
    '::: mistake\nWhat students get wrong, and why.\n:::',
    shortcut: 7,
  ),
  BlockTemplate(
    'Exam tip',
    Icons.school_outlined,
    '::: exam\nHow WAEC asks about this.\n:::',
    shortcut: 8,
  ),
  BlockTemplate(
    'Table',
    Icons.table_chart_outlined,
    '| Heading | Heading |\n|---|---|\n| Cell | Cell |',
    shortcut: 9,
  ),
  BlockTemplate(
    'Objectives',
    Icons.flag_outlined,
    '::: objectives\n- First objective\n- Second objective\n:::',
  ),
  BlockTemplate(
    'Summary',
    Icons.checklist_rounded,
    '::: summary\n- First key point\n- Second key point\n:::',
  ),
  BlockTemplate(
    'Note',
    Icons.info_outline_rounded,
    '::: note\nA side remark.\n:::',
  ),
  BlockTemplate(
    'Tip',
    Icons.lightbulb_outline_rounded,
    '::: tip\nA helpful shortcut.\n:::',
  ),
  BlockTemplate(
    'Theorem',
    Icons.verified_outlined,
    '::: theorem Name\nThe statement.\n:::',
  ),
  BlockTemplate(
    'Revision card',
    Icons.style_outlined,
    '::: card\nThe question side.\n---\nThe answer side.\n:::',
  ),
  BlockTemplate(
    'Go deeper',
    Icons.expand_more_rounded,
    '::: more Why this works\nOptional extra depth.\n:::',
  ),
  BlockTemplate(
    'Video',
    Icons.play_circle_outline_rounded,
    '::: video https://www.youtube.com/watch?v=\n:::',
  ),
  BlockTemplate(
    'To do',
    Icons.construction_rounded,
    '::: todo What still needs doing\n:::',
  ),
];

/// Inserts [text] at the cursor (replacing any selection). A multi-line
/// block is given blank lines around it, so it never runs into the
/// paragraph beside it; inline text is inserted as is. Leaves the cursor
/// after the insertion.
void insertAtCursor(TextEditingController c, String text) {
  final value = c.value;
  final sel = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final before = value.text.substring(0, sel.start);
  final after = value.text.substring(sel.end);

  var insert = text;
  if (text.contains('\n')) {
    final needBefore = before.isEmpty
        ? ''
        : before.endsWith('\n\n')
        ? ''
        : before.endsWith('\n')
        ? '\n'
        : '\n\n';
    final needAfter = after.isEmpty || after.startsWith('\n\n')
        ? ''
        : after.startsWith('\n')
        ? '\n'
        : '\n\n';
    insert = '$needBefore$text$needAfter';
  }
  c.value = TextEditingValue(
    text: '$before$insert$after',
    selection: TextSelection.collapsed(offset: before.length + insert.length),
  );
}

/// Wraps the selection in [open] and [close] (for `\textbf{…}` and maths),
/// or inserts both with the cursor between them.
void wrapSelection(TextEditingController c, String open, String close) {
  final value = c.value;
  final sel = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  final picked = sel.textInside(value.text);
  final text = value.text.replaceRange(
    sel.start,
    sel.end,
    '$open$picked$close',
  );
  final cursor = picked.isEmpty
      ? sel.start + open.length
      : sel.start + open.length + picked.length + close.length;
  c.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor),
  );
}

/// The row of insert buttons above the lesson body.
class BlockToolbar extends StatelessWidget {
  const BlockToolbar({
    super.key,
    required this.controller,
    required this.onInsertQuestion,
    required this.onInsertImage,
    required this.onPasteBlock,
  });

  final TextEditingController controller;

  /// Opens the bank picker; inserts `::: waec q:…` or `::: check q:…`.
  final VoidCallback onInsertQuestion;

  /// Uploads an image and inserts it.
  final VoidCallback? onInsertImage;

  /// Pastes the block last copied from any lesson's preview. Null when the
  /// studio clipboard is empty.
  final VoidCallback? onPasteBlock;

  @override
  Widget build(BuildContext context) {
    Widget button(
      String label,
      IconData icon,
      VoidCallback? onTap, {
      String? tip,
    }) => Tooltip(
      message: tip ?? label,
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: context.palette.textSecondary),
        label: Text(
          label,
          style: AppTheme.caption.copyWith(color: context.palette.textPrimary),
        ),
        backgroundColor: context.palette.surface,
        side: BorderSide(color: context.palette.border),
        onPressed: onTap,
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        button(
          'Maths',
          Icons.calculate_outlined,
          () => wrapSelection(controller, r'\(', r'\)'),
          tip: r'Inline maths \( \)  (Ctrl+M)',
        ),
        button(
          'Display maths',
          Icons.functions_rounded,
          () => insertAtCursor(controller, r'\[ \]'),
          tip: r'Maths on its own line \[ \]  (Ctrl+Shift+M)',
        ),
        button(
          'Bold',
          Icons.format_bold_rounded,
          () => wrapSelection(controller, r'\textbf{', '}'),
          tip: 'Bold  (Ctrl+B)',
        ),
        button(
          'Italic',
          Icons.format_italic_rounded,
          () => wrapSelection(controller, r'\textit{', '}'),
          tip: 'Italic  (Ctrl+I)',
        ),
        for (final t in blockTemplates)
          button(
            t.label,
            t.icon,
            () => insertAtCursor(controller, t.text),
            tip: t.shortcut == null
                ? t.label
                : '${t.label}  (Alt+${t.shortcut})',
          ),
        button('Past question', Icons.history_edu_rounded, onInsertQuestion),
        if (onInsertImage != null)
          button('Image', Icons.image_outlined, onInsertImage),
        button(
          'Paste block',
          Icons.content_paste_rounded,
          onPasteBlock,
          tip: 'Paste the block last copied from a preview',
        ),
      ],
    );
  }
}

/// Studio keyboard shortcuts around the editor.
///
/// Ctrl+S save, Ctrl+Enter submit/publish, Ctrl+B / Ctrl+I bold/italic,
/// Ctrl+M inline maths, Ctrl+Shift+M display maths, Alt+1…9 the first nine
/// block templates. Cmd works in place of Ctrl on a Mac.
class StudioShortcuts extends StatelessWidget {
  const StudioShortcuts({
    super.key,
    required this.body,
    required this.onSave,
    required this.onSubmit,
    required this.child,
  });

  final TextEditingController body;
  final VoidCallback onSave;
  final VoidCallback? onSubmit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final meta in [false, true]) {
      SingleActivator key(LogicalKeyboardKey k, {bool shift = false}) =>
          SingleActivator(k, control: !meta, meta: meta, shift: shift);
      bindings[key(LogicalKeyboardKey.keyS)] = onSave;
      if (onSubmit != null) bindings[key(LogicalKeyboardKey.enter)] = onSubmit!;
      bindings[key(LogicalKeyboardKey.keyB)] = () =>
          wrapSelection(body, r'\textbf{', '}');
      bindings[key(LogicalKeyboardKey.keyI)] = () =>
          wrapSelection(body, r'\textit{', '}');
      bindings[key(LogicalKeyboardKey.keyM)] = () =>
          wrapSelection(body, r'\(', r'\)');
      bindings[key(LogicalKeyboardKey.keyM, shift: true)] = () =>
          insertAtCursor(body, r'\[ \]');
    }
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    for (final t in blockTemplates) {
      final n = t.shortcut;
      if (n != null) {
        bindings[SingleActivator(digits[n - 1], alt: true)] = () =>
            insertAtCursor(body, t.text);
      }
    }
    return CallbackShortcuts(bindings: bindings, child: child);
  }
}
