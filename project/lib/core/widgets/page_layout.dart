import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'nav/nav_destinations.dart';

/// Page layout for the screens inside the app shell: a max-width content
/// column, and, on a phone, a compact header with a back button and
/// search. The navigation itself (top bar or bottom tabs) belongs to
/// `AppShell`, not to any page.

/// Content column width. Wide enough for a 3-column topic grid to breathe
/// without the eye having to track across a full 1440px browser window.
const double kContentMaxWidth = 1120;

/// Gutter between the content column and the viewport edge.
const double kContentGutter = 32;
const double kContentGutterCompact = 20;

/// Viewport width below which the layout switches to its compact form
/// (tighter gutters, bottom tabs, stacked module cards). The same point as
/// [kNavWideBreakpoint], so the navigation and the pages change together.
const double kCompactBreakpoint = kNavWideBreakpoint;

double contentGutterFor(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactBreakpoint
    ? kContentGutterCompact
    : kContentGutter;

/// Centres its child in the [kContentMaxWidth] column with page gutters.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: contentGutterFor(context)),
          child: child,
        ),
      ),
    );
  }
}

/// Opens `/search`. Only on a phone: on a wide screen the top bar has the
/// search field, and a second way in beside it would be clutter.
class SearchAction extends StatelessWidget {
  const SearchAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (navLayoutFor(context) == NavLayout.topBar) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey('page.search'),
      tooltip: 'Search',
      icon: const Icon(Icons.search_rounded),
      onPressed: () => context.push('/search'),
    );
  }
}

/// The phone header for a page that has no app bar of its own: back (or
/// the logo, on a section's first page), a title, and search. Nothing at
/// on a wide screen but a spacer the height of the floating top bar.
///
/// Always present in the tree, sized to zero when wide, so a page built
/// on it keeps one tree shape across the breakpoint — the lesson page's
/// video restarts if its player changes parent.
class CompactPageBar extends StatelessWidget {
  const CompactPageBar({
    super.key,
    this.title,
    this.fallbackPath,
    this.reserveTopInset = true,
  });

  /// On a wide screen, take up the top bar's height so the page starts
  /// below it. [ParagonPage] turns this off and pads its scroll view
  /// instead, so its content scrolls under the translucent bar.
  final bool reserveTopInset;

  /// Null shows the logo instead.
  final String? title;

  /// Where back goes when there is nothing to pop — a page opened with
  /// `go`, or straight from a link.
  final String? fallbackPath;

  @override
  Widget build(BuildContext context) {
    if (navLayoutFor(context) == NavLayout.topBar) {
      return SizedBox(
        height: reserveTopInset ? MediaQuery.paddingOf(context).top : 0,
      );
    }
    final canPop = Navigator.of(context).canPop();
    final showBack = canPop || fallbackPath != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.background,
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.palette.background,
        leading: showBack
            ? BackButton(
                onPressed: () =>
                    canPop ? context.pop() : context.go(fallbackPath!),
              )
            : null,
        titleSpacing: showBack ? 0 : 20,
        title: title == null
            ? Image.asset(
                'assets/images/paragon_logo.png',
                height: 24,
                fit: BoxFit.contain,
                semanticLabel: 'Project Paragon',
              )
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.heading3.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
        actions: const [SearchAction(), SizedBox(width: 4)],
      ),
    );
  }
}

/// Standard page: a compact header on a phone, then a scrollable, centred
/// content column. Every course surface is built on this so their header,
/// gutters and scroll behaviour can't drift apart.
class ParagonPage extends StatelessWidget {
  const ParagonPage({
    super.key,
    required this.child,
    this.scrollController,
    this.title,
    this.fallbackPath,
  });

  final Widget child;
  final ScrollController? scrollController;

  /// The phone header's title; see [CompactPageBar].
  final String? title;
  final String? fallbackPath;

  @override
  Widget build(BuildContext context) {
    // On a wide screen the top bar floats over the page; the content
    // starts below it and scrolls beneath it. On a phone the compact bar
    // above has already taken the status-bar inset.
    final wide = navLayoutFor(context) == NavLayout.topBar;
    final topInset = wide ? MediaQuery.paddingOf(context).top : 0.0;
    return Scaffold(
      backgroundColor: context.palette.background,
      body: Column(
        children: [
          CompactPageBar(
            title: title,
            fallbackPath: fallbackPath,
            reserveTopInset: false,
          ),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.only(top: topInset),
                child: ContentColumn(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
