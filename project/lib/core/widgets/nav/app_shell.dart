import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import 'bottom_tabs.dart';
import 'nav_destinations.dart';
import 'top_bar.dart';

/// The chrome around every screen inside the shell route: a top bar on a
/// wide window, bottom tabs on a phone. Each tab is a branch with its own
/// navigator, so switching tabs keeps each one's scroll position and
/// history.
///
/// **One tree shape at every width.** The branch navigators sit at the
/// same place in the tree whichever navigation is showing: the top bar's
/// slot is a zero-size box on a phone, and the theme and padding wrappers
/// are always present. Re-parenting the navigators would rebuild every
/// open screen — and restart a playing lesson video — whenever a window
/// is resized across the breakpoint.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Tapping the tab you are already on goes back to its first screen, as
  /// tab bars conventionally do.
  void _select(NavTab tab) => navigationShell.goBranch(
    tab.index,
    initialLocation: tab.index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final wide = navLayoutFor(context) == NavLayout.topBar;
    final current = NavTab.values[navigationShell.currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: Column(
        children: [
          if (wide)
            TopBar(current: current, onSelect: _select)
          else
            const SizedBox.shrink(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              // The top bar has already taken the status-bar inset.
              removeTop: wide,
              child: Theme(
                // Under the top bar a page's own app bar is a page
                // header, not the main navigation: shorter, and no
                // heavier than the bar above it.
                data: wide
                    ? theme.copyWith(
                        appBarTheme: theme.appBarTheme.copyWith(
                          toolbarHeight: 52,
                          centerTitle: false,
                          titleTextStyle: AppTheme.heading3.copyWith(
                            color: context.palette.textPrimary,
                          ),
                        ),
                      )
                    : theme,
                child: navigationShell,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : BottomTabs(current: current, onSelect: _select),
    );
  }
}
