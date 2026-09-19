import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Page chrome for the course surfaces: a full-bleed top nav, and a
/// max-width content column beneath it.
///
/// The nav bar is the only full-bleed element on these pages — its
/// background and bottom border run edge to edge, but its own contents are
/// constrained to the same [kContentMaxWidth] column the page body uses, so
/// the leftmost nav link lines up with the page heading below it.

/// Content column width. Wide enough for a 3-column topic grid to breathe
/// without the eye having to track across a full 1440px browser window.
const double kContentMaxWidth = 1120;

/// Gutter between the content column and the viewport edge.
const double kContentGutter = 32;
const double kContentGutterCompact = 20;

/// Viewport width below which the layout switches to its compact form
/// (tighter gutters, smaller nav, stacked module cards).
const double kCompactBreakpoint = 760;

double contentGutterFor(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactBreakpoint
    ? kContentGutterCompact
    : kContentGutter;

/// The three top-level destinations. Kept here (not per-screen) so every
/// page that uses [AppTopNav] shows the same set in the same order.
class _NavDestination {
  const _NavDestination(this.label, this.path);
  final String label;
  final String path;
}

const _destinations = [
  // Home is the dashboard — see app_router.dart, where '/' builds
  // DashboardScreen and '/dashboard' redirects here.
  _NavDestination('Home', '/'),
  _NavDestination('Courses', '/courses'),
  _NavDestination('WAEC Prep', '/waec'),
];

/// Full-bleed top navigation bar: text links left, logo lockup right,
/// single row, vertically centred.
class AppTopNav extends StatelessWidget {
  const AppTopNav({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;
    final currentPath = GoRouterState.of(context).uri.path;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: isCompact ? 56 : 64,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: contentGutterFor(context),
                ),
                child: Row(
                  children: [
                    // ── Left: text nav links ─────────────────────────────
                    // Expanded, not Flexible: the link row has to actually
                    // fill the space left of the logo, or the logo ends up
                    // butted against the last link instead of flush right.
                    // (A loose Flexible shrink-wraps to its content and the
                    // leftover width is neither given back to the Row nor
                    // distributed by mainAxisAlignment — so neither Spacer
                    // nor spaceBetween fixes it.) The horizontal scroll view
                    // means a narrow phone scrolls the links rather than
                    // overflowing them into the logo.
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final destination in _destinations)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: isCompact ? 16 : 28,
                                ),
                                child: _NavLink(
                                  label: destination.label,
                                  path: destination.path,
                                  isActive: _isActive(
                                    currentPath,
                                    destination.path,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Right: logo + wordmark ───────────────────────────
                    // One PNG lockup (globe mark + "Project Paragon"), the
                    // same asset the welcome screen uses. Tapping it goes
                    // home, as a site logo is expected to.
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: _LogoLink(height: isCompact ? 24 : 30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `/courses` stays lit while you're inside a course page, so the nav
  /// still tells you which section you're in two levels deep.
  static bool _isActive(String currentPath, String destinationPath) {
    if (currentPath == destinationPath) return true;
    // '/' is a prefix of every path, so it only ever matches exactly.
    if (destinationPath == '/') return false;
    if (destinationPath == '/courses') {
      return currentPath.startsWith('/courses') ||
          currentPath.startsWith('/subject/');
    }
    return currentPath.startsWith('$destinationPath/');
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({
    required this.label,
    required this.path,
    required this.isActive,
  });

  final String label;
  final String path;
  final bool isActive;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? AppColors.primary
        : _isHovered
        ? AppColors.textPrimaryDark
        : AppColors.textSecondaryDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.path),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: AppTheme.bodyMd.copyWith(
                color: color,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            // Underline is always laid out (transparent when inactive) so
            // hovering doesn't shift the label up by 2px.
            Container(
              height: 2,
              width: 20,
              decoration: BoxDecoration(
                color: widget.isActive ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoLink extends StatelessWidget {
  const _LogoLink({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/'),
        child: Semantics(
          label: 'Project Paragon — home',
          button: true,
          child: Image.asset(
            'assets/images/paragon_logo.png',
            height: height,
            fit: BoxFit.contain,
            // Decorative-but-meaningful: the Semantics above carries the
            // label, so the raw image doesn't need its own.
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

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

/// Standard page: full-bleed nav, then a scrollable, centred content
/// column. Every course surface is built on this so their nav, gutters and
/// scroll behaviour can't drift apart.
class ParagonPage extends StatelessWidget {
  const ParagonPage({super.key, required this.child, this.scrollController});

  final Widget child;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          const AppTopNav(),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              child: SingleChildScrollView(
                controller: scrollController,
                child: ContentColumn(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
