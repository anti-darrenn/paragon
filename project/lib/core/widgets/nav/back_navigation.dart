import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'nav_destinations.dart';

/// Where "back" goes from [uri] when there is no history to go back
/// through: a page opened from a link, a reload, a search result, or with
/// `go`. Null on a tab's first page, which has nowhere further back to go.
///
/// Every route the app declares has an answer here, so no screen is a
/// dead end. `back_navigation_test.dart` walks the router's routes to
/// keep it that way.
String? parentPathFor(Uri uri) {
  final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  return switch (s) {
    // Tab roots.
    [] || ['courses'] || ['waec'] || ['review'] || ['me'] => null,

    // Courses.
    ['subject', _, 'course'] => '/courses',
    ['subject', final id, 'course', 'topic', _] => '/subject/$id/course',
    ['subject', final id, 'course', 'challenge'] => '/subject/$id/course',
    ['subject', final id, 'course', 'unit', _, 'test'] => '/subject/$id/course',
    // Drill and the topic test go back to their topic's page.
    ['subject', final id, 'unit', _, 'topic', final t] ||
    [
      'subject',
      final id,
      'unit',
      _,
      'topic',
      final t,
      'test',
    ] => '/subject/$id/course/topic/$t',
    ['subject', final id, ...] => '/subject/$id/course',
    ['learn', ...] => '/courses',

    // WAEC.
    ['waec', ...] => '/waec',

    // Review.
    ['mistakes', 'practice'] => '/mistakes',
    ['mistakes'] ||
    ['saved'] ||
    ['cards', _] ||
    ['settings', 'offline'] => '/review',

    // Me.
    ['settings'] => '/me',
    ['settings', _] => '/settings',

    // The studio.
    ['admin'] => '/',
    ['admin', ...] => '/admin',

    _ => '/',
  };
}

/// The page's location, or null outside a routed page (a dialog's own
/// context, or a widget test with no router).
Uri? _uriOf(BuildContext context) {
  try {
    return GoRouterState.of(context).uri;
  } catch (_) {
    return null;
  }
}

extension BackNavigation on BuildContext {
  /// Back one page if there is one, else to the page's parent (see
  /// [parentPathFor]). For "Done" and "Back" buttons, which used to call
  /// `pop()` and threw when the page had been opened directly.
  void popOrGo() {
    final nav = Navigator.of(this);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final uri = _uriOf(this);
    go(uri == null ? '/' : parentPathFor(uri) ?? '/');
  }
}

/// The back arrow every page uses. Pops when there is history; otherwise
/// goes to the page's parent. Null — no arrow at all — on a tab's first
/// page.
///
/// Tries `maybePop` first even then, so a page guarding its exit with a
/// `PopScope` (a test in progress) still gets to ask before it is left.
class ParagonBackButton extends StatelessWidget {
  const ParagonBackButton({super.key});

  /// The button, or null where there is nowhere to go back to.
  static Widget? maybe(BuildContext context) {
    if (Navigator.of(context).canPop()) return const ParagonBackButton();
    final uri = _uriOf(context);
    if (uri == null || parentPathFor(uri) == null) return null;
    return const ParagonBackButton();
  }

  @override
  Widget build(BuildContext context) {
    return BackButton(
      key: const ValueKey('nav.back'),
      onPressed: () async {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          await nav.maybePop();
          return;
        }
        final router = GoRouter.of(context);
        final uri = _uriOf(context);
        final parent = uri == null ? '/' : parentPathFor(uri) ?? '/';
        if (await nav.maybePop()) return;
        router.go(parent);
      },
    );
  }
}

/// The app bar every page uses: [AppBar] with [ParagonBackButton] in
/// place of Flutter's own, which only appears when there is history to
/// pop and so left pages opened from a link with no way back.
class ParagonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ParagonAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.backgroundColor,
    this.centerTitle,
    this.titleSpacing,
    this.collapseWhenWide = false,
  });

  /// For a tab's first page: on a wide screen the top bar already names
  /// the section, so the app bar steps aside and the page's own heading
  /// ([PageIntro]) leads instead.
  final bool collapseWhenWide;

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool? centerTitle;
  final double? titleSpacing;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    if (collapseWhenWide && navLayoutFor(context) == NavLayout.topBar) {
      // The Scaffold lays the app bar out at its own height, so this
      // leaves only the inset the floating top bar needs.
      return SizedBox(height: MediaQuery.paddingOf(context).top);
    }
    final back =
        leading ??
        (automaticallyImplyLeading ? ParagonBackButton.maybe(context) : null);
    return AppBar(
      leading: back,
      automaticallyImplyLeading: false,
      title: title,
      actions: [...?actions, const SizedBox(width: 4)],
      bottom: bottom,
      backgroundColor: backgroundColor,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing ?? (back == null ? 20 : 4),
    );
  }
}
