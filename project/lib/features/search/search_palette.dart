import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/search/search.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'search_providers.dart';
import 'search_results_view.dart';

/// Rows per group in the palette. Enter with nothing highlighted opens
/// the full list at `/search`.
const int kSearchPalettePerGroup = 6;

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// "⌘ K" on Apple keyboards, "Ctrl K" everywhere else.
String get searchShortcutLabel => isApplePlatform ? '⌘ K' : 'Ctrl K';

bool _paletteOpen = false;

/// Opens the search palette over the page and, if the student picks
/// something, goes there. Does nothing if one is already open.
Future<void> openSearchPalette(BuildContext context) async {
  if (_paletteOpen) return;
  _paletteOpen = true;
  try {
    final path = await showDialog<String>(
      context: context,
      barrierColor: AppColors.overlay.withAlpha(140),
      builder: (_) => const SearchPalette(),
    );
    if (path != null && context.mounted) context.push(path);
  } finally {
    _paletteOpen = false;
  }
}

/// Ctrl+K (⌘K) from anywhere opens the palette. Wrap something that is
/// always on screen while the shortcut should work — the top bar.
class SearchShortcut extends StatefulWidget {
  const SearchShortcut({super.key, required this.child});
  final Widget child;

  @override
  State<SearchShortcut> createState() => _SearchShortcutState();
}

class _SearchShortcutState extends State<SearchShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final kb = HardwareKeyboard.instance;
    if (!(kb.isControlPressed || kb.isMetaPressed)) return false;
    openSearchPalette(context);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The search box itself: a field, and the results grouped beneath it.
/// ↑ and ↓ move, Enter opens (or the full results page when nothing is
/// highlighted), Esc closes. Pops with the chosen route.
class SearchPalette extends ConsumerStatefulWidget {
  const SearchPalette({super.key});

  @override
  ConsumerState<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends ConsumerState<SearchPalette> {
  final _controller = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  /// Index into [_visible]; -1 is none.
  int _highlight = -1;

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<SearchItem> _visible(SearchResults r) => [
    ...r.courses.take(kSearchPalettePerGroup),
    ...r.topics.take(kSearchPalettePerGroup),
    ...r.lessons.take(kSearchPalettePerGroup),
  ];

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!down && e.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final n = _visible(
      ref.read(searchResultsProvider(_controller.text)),
    ).length;
    if (n > 0) {
      setState(() {
        _highlight += down ? 1 : -1;
        if (_highlight >= n) _highlight = -1;
        if (_highlight < -1) _highlight = n - 1;
      });
    }
    return KeyEventResult.handled;
  }

  void _submit() {
    final visible = _visible(ref.read(searchResultsProvider(_controller.text)));
    if (_highlight >= 0 && _highlight < visible.length) {
      Navigator.of(context).pop(visible[_highlight].path);
    } else if (_controller.text.trim().isNotEmpty) {
      final q = Uri.encodeQueryComponent(_controller.text.trim());
      Navigator.of(context).pop('/search?q=$q');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final results = ref.watch(searchResultsProvider(query));
    final loading = ref.watch(searchCorpusProvider).isLoading;
    final visible = _visible(results);
    final highlighted = _highlight >= 0 && _highlight < visible.length
        ? visible[_highlight]
        : null;
    final screen = MediaQuery.sizeOf(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: screen.height < 600 ? 24 : 96,
          left: 16,
          right: 16,
        ),
        child: Material(
          key: const ValueKey('search.palette'),
          color: context.palette.surface,
          elevation: 24,
          shadowColor: AppColors.overlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: screen.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: context.palette.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('search.paletteField'),
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          cursorColor: AppColors.primary,
                          onChanged: (_) => setState(() => _highlight = -1),
                          onSubmitted: (_) => _submit(),
                          style: AppTheme.bodyLg.copyWith(
                            color: context.palette.textPrimary,
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search courses, topics and lessons',
                            hintStyle: AppTheme.bodyLg.copyWith(
                              color: context.palette.textSecondary,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      const KeyHint('Esc'),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.palette.border),
                Flexible(
                  child: query.trim().isEmpty
                      ? const _Suggestions()
                      : loading
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : results.isEmpty
                      ? SearchEmptyMessage(query: query)
                      : SearchResultsView(
                          query: query,
                          results: results,
                          perGroup: kSearchPalettePerGroup,
                          highlighted: highlighted,
                          shrinkWrap: true,
                          onOpen: (item) =>
                              Navigator.of(context).pop(item.path),
                        ),
                ),
                Divider(height: 1, color: context.palette.border),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const KeyHint('↑↓'),
                      const SizedBox(width: 6),
                      _hint(context, 'to move'),
                      const SizedBox(width: 14),
                      const KeyHint('Enter'),
                      const SizedBox(width: 6),
                      _hint(context, 'to open'),
                      const Spacer(),
                      if (results.total > visible.length)
                        _hint(context, 'Enter for all ${results.total}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Text(
    text,
    style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
  );
}

/// What the palette shows before anything is typed: where to go, rather
/// than an empty box.
class _Suggestions extends StatelessWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String path) => InkWell(
      onTap: () => Navigator.of(context).pop(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.palette.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
          child: Text(
            'JUMP TO',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        row(Icons.auto_stories_outlined, 'All courses', '/courses'),
        row(Icons.assignment_outlined, 'WAEC past papers', '/waec'),
        row(Icons.replay_rounded, 'Mistakes notebook', '/mistakes'),
        row(Icons.style_outlined, 'Review', '/review'),
      ],
    );
  }
}

/// A keyboard key, drawn as a small outlined cap.
class KeyHint extends StatelessWidget {
  const KeyHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: context.palette.border),
        color: context.palette.background,
      ),
      child: Text(
        text,
        style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
      ),
    );
  }
}
