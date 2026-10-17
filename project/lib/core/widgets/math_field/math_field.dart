import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../latex/tex_preprocess.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../full_latex_view.dart';
import 'math_input.dart';

export 'math_input.dart' show MathInputMode;

/// The Normal/LaTeX switch and the box being typed in, shared by every
/// [MathField] of one editor and its [MathToolbar].
///
/// The choice of mode is remembered on the device per [prefsKey], so a
/// teacher who types in Normal mode finds it there next time.
class MathEditing extends ChangeNotifier {
  MathEditing({
    required this.prefsKey,
    MathInputMode initialMode = MathInputMode.normal,
  }) : _mode = initialMode {
    _restore();
  }

  final String prefsKey;
  MathInputMode _mode;
  _MathFieldState? _focused;
  bool _disposed = false;

  MathInputMode get mode => _mode;
  bool get isLatex => _mode == MathInputMode.latex;

  set mode(MathInputMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    _save();
  }

  /// Types [s] into the box last used.
  void insert(MathSnippet s) => _focused?._insert(s);

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('mathInput.$prefsKey');
      if (_disposed || saved == null) return;
      final m = MathInputMode.values.where((v) => v.name == saved);
      if (m.isNotEmpty && m.first != _mode) {
        _mode = m.first;
        notifyListeners();
      }
    } catch (_) {
      // A preference is a convenience; the default mode is fine.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mathInput.$prefsKey', _mode.name);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A text box for question or card text with maths in it.
///
/// [controller] always holds the stored form: Paragon's LaTeX dialect. In
/// LaTeX mode the box edits it directly (and `$…$` becomes `\(…\)` when the
/// box loses focus, as Overleaf authors expect). In Normal mode the box
/// holds calculator-style text and the stored form follows it
/// (`plainToLatex`); a value Normal mode cannot show faithfully stays
/// read-only there, with a note, so switching modes never rewrites it.
class MathField extends StatefulWidget {
  const MathField({
    super.key,
    required this.controller,
    required this.editing,
    this.enabled = true,
    this.minLines = 1,
    this.hint,
    this.error,
    this.showPreview = true,
    this.style,
    this.onFocus,
  });

  final TextEditingController controller;
  final MathEditing editing;
  final bool enabled;
  final int minLines;
  final String? hint;
  final String? error;

  /// The text as students will see it, under the box, when it has maths.
  final bool showPreview;
  final TextStyle? style;
  final VoidCallback? onFocus;

  @override
  State<MathField> createState() => _MathFieldState();
}

class _MathFieldState extends State<MathField> {
  final _plain = TextEditingController();
  final _focus = FocusNode();

  /// The stored text this state last wrote, to tell its own changes from
  /// someone else's (a load, a restore from history).
  String? _wrote;

  /// Whether Normal mode can show the current value.
  bool _fits = true;

  @override
  void initState() {
    super.initState();
    widget.editing.addListener(_modeChanged);
    widget.controller.addListener(_storedChanged);
    _focus.addListener(_focusChanged);
    _syncPlain();
  }

  @override
  void didUpdateWidget(MathField old) {
    super.didUpdateWidget(old);
    if (old.editing != widget.editing) {
      old.editing.removeListener(_modeChanged);
      widget.editing.addListener(_modeChanged);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_storedChanged);
      widget.controller.addListener(_storedChanged);
      _syncPlain();
    }
  }

  @override
  void dispose() {
    widget.editing.removeListener(_modeChanged);
    widget.controller.removeListener(_storedChanged);
    if (widget.editing._focused == this) widget.editing._focused = null;
    _plain.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _modeChanged() {
    if (!mounted) return;
    _syncPlain();
    setState(() {});
  }

  void _storedChanged() {
    // Typing in LaTeX mode only needs the preview redrawn; the Normal box
    // is worked out again when the mode switches.
    if (!widget.editing.isLatex && widget.controller.text != _wrote) {
      _syncPlain();
    }
    if (mounted) setState(() {});
  }

  /// The Normal-mode box from the stored text.
  void _syncPlain() {
    final stored = widget.controller.text;
    _fits = showsInNormalMode(stored);
    final plain = _fits ? latexToPlain(stored) : stored;
    if (_plain.text != plain) _plain.text = plain;
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      widget.editing._focused = this;
      widget.onFocus?.call();
      return;
    }
    // Leaving a LaTeX box: Overleaf's $x$ becomes the dialect's \(x\).
    if (widget.editing.isLatex && widget.controller.text.contains(r'$')) {
      final converted = dollarMathToParens(widget.controller.text);
      if (converted != widget.controller.text) _write(converted);
    }
  }

  void _write(String stored) {
    _wrote = stored;
    widget.controller.value = TextEditingValue(
      text: stored,
      selection: TextSelection.collapsed(offset: stored.length),
    );
  }

  void _plainEdited(String plain) => _write(plainToLatex(plain));

  void _insert(MathSnippet s) {
    final latex = widget.editing.isLatex;
    final snippet = latex ? s.latex : s.plain;
    if (snippet == null || !widget.enabled) return;
    if (!latex && !_fits) return;
    final c = latex ? widget.controller : _plain;
    final sel = c.selection.isValid
        ? c.selection
        : TextSelection.collapsed(offset: c.text.length);
    final r = applySnippet(
      c.text,
      sel.start,
      sel.end,
      snippet,
      latexMode: latex,
    );
    c.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.caret),
    );
    if (!latex) _plainEdited(r.text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final latex = widget.editing.isLatex;
    final locked = !latex && !_fits;
    final style =
        widget.style ??
        AppTheme.bodyMd.copyWith(color: palette.textPrimary, height: 1.5);
    final stored = widget.controller.text;
    final hasMaths = stored.contains(r'\') || stored.contains(r'$$');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: latex ? widget.controller : _plain,
          focusNode: _focus,
          readOnly: !widget.enabled || locked,
          minLines: widget.minLines,
          maxLines: null,
          style: latex || locked
              ? style.copyWith(fontFamily: 'monospace', fontSize: 14)
              : style,
          onChanged: latex
              ? (v) => _wrote = v
              : (v) => _plainEdited(v),
          decoration: InputDecoration(
            hintText:
                widget.hint ??
                (latex
                    ? r'Maths in \( … \) or $ … $, e.g. \(x^{2} + 1\)'
                    : 'Type maths as on a calculator: x^2 + 1, 3/4, sqrt(2)'),
            errorText: widget.error,
          ),
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'This has LaTeX that Normal mode cannot show. Switch to LaTeX '
              'to edit it.',
              style: AppTheme.caption.copyWith(color: AppColors.warning),
            ),
          ),
        if (widget.showPreview && hasMaths && stored.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: FullLatexView(
              latex: stored,
              textStyle: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
            ),
          ),
      ],
    );
  }
}

/// The Normal/LaTeX switch and one-tap maths for the editor's boxes.
class MathToolbar extends StatelessWidget {
  const MathToolbar({super.key, required this.editing, this.enabled = true});
  final MathEditing editing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: editing,
      builder: (context, _) {
        final latex = editing.isLatex;
        final snippets = [
          for (final s in kMathSnippets)
            if (latex || s.plain != null) s,
        ];
        return Row(
          children: [
            SegmentedButton<MathInputMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: MathInputMode.normal,
                  label: Text('Normal'),
                  tooltip: 'Type maths as on a calculator',
                ),
                ButtonSegment(
                  value: MathInputMode.latex,
                  label: Text('LaTeX'),
                  tooltip: 'Type LaTeX, as in Overleaf',
                ),
              ],
              selected: {editing.mode},
              onSelectionChanged: (s) => editing.mode = s.first,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in snippets)
                      Tooltip(
                        message: s.tip,
                        child: InkWell(
                          // Keeps focus (and the cursor) in the box.
                          canRequestFocus: false,
                          onTap: enabled ? () => editing.insert(s) : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: palette.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.label,
                              style: AppTheme.caption.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
