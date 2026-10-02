import 'package:flutter/material.dart';

/// The app's top-level destinations, in tab order.
///
/// The order is also the [StatefulShellRoute]'s branch order in
/// `app_router.dart` — a tab's index *is* its branch index, so the two
/// must change together. `nav_shell_test.dart` checks that every tab's
/// [path] lands in its own branch.
enum NavTab {
  home('Home', 'Home', '/', Icons.home_outlined, Icons.home_rounded),
  courses(
    'Courses',
    'Courses',
    '/courses',
    Icons.auto_stories_outlined,
    Icons.auto_stories_rounded,
  ),
  waec(
    'WAEC Prep',
    'WAEC',
    '/waec',
    Icons.assignment_outlined,
    Icons.assignment_rounded,
  ),
  review('Review', 'Review', '/review', Icons.style_outlined, Icons.style_rounded),

  /// On a phone, a tab showing the student's avatar. On a wide screen it
  /// is not a tab at all: the avatar menu at the end of the top bar is.
  me('Me', 'Me', '/me', Icons.person_outline_rounded, Icons.person_rounded);

  const NavTab(this.label, this.shortLabel, this.path, this.icon, this.activeIcon);

  /// For the top bar, which has room.
  final String label;

  /// For the bottom tabs, which share a phone's width five ways.
  final String shortLabel;

  /// The branch's first screen, where tapping an already-active tab
  /// returns to.
  final String path;
  final IconData icon;
  final IconData activeIcon;

  /// The tabs the wide top bar shows as links.
  static const List<NavTab> topBarTabs = [home, courses, waec, review];
}

/// Viewport width at or above which the app shows the top bar instead of
/// bottom tabs. The same breakpoint as the course pages' compact layout.
const double kNavWideBreakpoint = 760;

enum NavLayout { bottomTabs, topBar }

/// Which navigation the current window gets.
///
/// A side rail for native desktop builds would be a third value; the
/// switch point lives here so adding one touches nothing else.
NavLayout navLayoutFor(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kNavWideBreakpoint
    ? NavLayout.topBar
    : NavLayout.bottomTabs;
