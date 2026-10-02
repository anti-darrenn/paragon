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

/// Rows per group in the dropdown. Enter with nothing highlighted opens
/// the full list at `/search`.
const int kSearchDropdownPerGroup = 5;

/// The top bar's search field: results drop down as you type.
///
/// Ctrl+K (⌘K on a Mac) focuses it from anywhere; ↑ and ↓ move through
/// the results, Enter opens one (or the full results page when none is
/// highlighted), Esc closes. The corpus is only loaded the first time the
/// field is focused, so a student who never searches never pays the
/// subject-index reads for it.
class TopBarSearchField extends ConsumerStatefulWidget {
  const TopBarSearchField({super.key});

  @override
  ConsumerState<TopBarSearchField> createState() => _TopBarSearchFieldState();
}

class _TopBarSearchFieldState extends ConsumerState<TopBarSearchField> {
  final _controller = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  /// Index into the visible results; -1 is none.
  int _highlight = -1;
  bool _corpusRequested = false;

  bool get _isMac =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _onGlobalKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final kb = HardwareKeyboard.instance;
    if (!(kb.isControlPressed || kb.isMetaPressed)) return false;
    _focus.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    return true;
  }

  void _onFocusChange() {
    if (_focus.hasFocus && !_corpusRequested) {
      _corpusRequested = true;
      ref.read(searchCorpusProvider);
    }
    _syncPortal();
  }

  void _syncPortal() {
    final show = _focus.hasFocus && _controller.text.trim().isNotEmpty;
    if (show && !_portal.isShowing) _portal.show();
    if (!show && _portal.isShowing) _portal.hide();
    setState(() {});
  }

  List<SearchItem> _visible() {
    final r = ref.read(searchResultsProvider(_controller.text));
    return [
      ...r.courses.take(kSearchDropdownPerGroup),
      ...r.topics.take(kSearchDropdownPerGroup),
      ...r.lessons.take(kSearchDropdownPerGroup),
    ];
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final n = _visible().length;
      if (n == 0) return KeyEventResult.handled;
      setState(() {
        final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _highlight = (_highlight + step) % (n + 1);
        if (_highlight == n) _highlight = -1;
        if (_highlight < -1) _highlight = n - 1;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit(String query) {
    final visible = _visible();
    if (_highlight >= 0 && _highlight < visible.length) {
      _open(visible[_highlight]);
    } else if (query.trim().isNotEmpty) {
      final q = Uri.encodeQueryComponent(query.trim());
      _close();
      context.push('/search?q=$q');
    }
  }

  void _open(SearchItem item) {
    _close();
    context.push(item.path);
  }

  void _close() {
    _controller.clear();
    _highlight = -1;
    _focus.unfocus();
    _syncPortal();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _dropdown,
        child: TextFieldTapRegion(
          child: SizedBox(
            height: 38,
            child: TextField(
              key: const ValueKey('topbar.search'),
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                _highlight = -1;
                _syncPortal();
              },
              onSubmitted: _submit,
              // The dropdown is inside the same tap region, so only a
              // click elsewhere on the page closes it. Mouse clicks do
              // not unfocus a field by default on the web.
              onTapOutside: (_) => _focus.unfocus(),
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textPrimary,
              ),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: focused
                    ? context.palette.background
                    : context.palette.surface,
                hintText: 'Search courses, topics, lessons',
                hintStyle: AppTheme.bodyMd.copyWith(
                  color: context.palette.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: context.palette.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 38),
                suffixIcon: focused
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _KeyHint(_isMac ? '⌘ K' : 'Ctrl K'),
                      ),
                suffixIconConstraints: const BoxConstraints(minHeight: 22),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final query = _controller.text;
        final results = ref.watch(searchResultsProvider(query));
        final loading = ref.watch(searchCorpusProvider).isLoading;
        final visible = [
          ...results.courses.take(kSearchDropdownPerGroup),
          ...results.topics.take(kSearchDropdownPerGroup),
          ...results.lessons.take(kSearchDropdownPerGroup),
        ];
        final highlighted = _highlight >= 0 && _highlight < visible.length
            ? visible[_highlight]
            : null;
        final more = results.total - visible.length;

        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: TextFieldTapRegion(
              child: Material(
                color: context.palette.surface,
                elevation: 12,
                shadowColor: AppColors.overlay.withAlpha(140),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.palette.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 420,
                    maxWidth: 420,
                    maxHeight: 460,
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : results.isEmpty
                      ? SearchEmptyMessage(query: query)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: SearchResultsView(
                                query: query,
                                results: results,
                                perGroup: kSearchDropdownPerGroup,
                                highlighted: highlighted,
                                shrinkWrap: true,
                                onOpen: _open,
                              ),
                            ),
                            Divider(height: 1, color: context.palette.border),
                            InkWell(
                              onTap: () => _submit(query),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        more > 0
                                            ? 'See all ${results.total} results'
                                            : 'Open results page',
                                        style: AppTheme.label.copyWith(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '↑↓ to move · Enter to open',
                                      style: AppTheme.caption.copyWith(
                                        color: context.palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.text);
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
