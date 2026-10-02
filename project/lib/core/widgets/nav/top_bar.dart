import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/lesson/continue_learning.dart';
import '../../../features/search/search_palette.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import 'courses_menu.dart';
import 'nav_destinations.dart';
import 'profile_menu.dart';

/// Height of the top bar, not counting any status-bar inset. Pages in the
/// shell scroll underneath it, so `AppShell` adds this to their top
/// padding.
const double kTopBarHeight = 68;

/// Widths at which the bar sheds detail as the window narrows: the
/// "Continue" button goes first, then the search label and long labels.
const double kTopBarRoomy = 1100;
const double kTopBarDense = 900;

/// The wide-screen navigation, in three parts:
///
/// - the logo, pinned to the left edge;
/// - a central island of controls — the four sections (Courses opening a
///   dropdown of every subject) and search;
/// - the student's corner, pinned to the right edge: an offline notice
///   when there is no connection, "Continue" (or "Save progress" for a
///   guest), and the account menu.
///
/// Slightly translucent: pages scroll beneath it and show through, blurred.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.current, required this.onSelect});

  /// The active tab. [NavTab.me] has no link here, so on the profile and
  /// settings screens no link is lit and the avatar is the way back.
  final NavTab current;
  final ValueChanged<NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dense = width < kTopBarDense;
    final roomy = width >= kTopBarRoomy;

    return SearchShortcut(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // ~80% opaque: enough to read the bar over any page, little
              // enough that what scrolls beneath it shows through.
              color: context.palette.background.withAlpha(205),
              border: Border(
                bottom: BorderSide(
                  color: context.palette.border.withAlpha(170),
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kTopBarHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 22),
                  child: Row(
                    children: [
                      // The two sides take equal shares of what the island
                      // leaves, so the island sits dead centre. Each side
                      // scales down rather than overflow on a narrow window.
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _Logo(
                              height: roomy ? 40 : 34,
                              onTap: () => onSelect(NavTab.home),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _Island(
                        current: current,
                        onSelect: onSelect,
                        dense: dense,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _OfflineChip(),
                                if (roomy) const _ActionButton(),
                                const SizedBox(width: 12),
                                const ProfileMenuButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The central group of controls, drawn as one segmented pill.
class _Island extends StatelessWidget {
  const _Island({
    required this.current,
    required this.onSelect,
    required this.dense,
  });

  final NavTab current;
  final ValueChanged<NavTab> onSelect;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    Widget tab(NavTab t) => _IslandCell(
      key: ValueKey('topbar.${t.name}'),
      label: dense ? t.shortLabel : t.label,
      isActive: t == current,
      dense: dense,
      onTap: () => onSelect(t),
    );

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface.withAlpha(185),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab(NavTab.home),
          CoursesMenu(
            builder: (context, isOpen, toggle) => _IslandCell(
              key: const ValueKey('topbar.courses'),
              label: 'Courses',
              isActive: current == NavTab.courses,
              isOpen: isOpen,
              dense: dense,
              trailing: AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ),
              onTap: toggle,
            ),
          ),
          tab(NavTab.waec),
          tab(NavTab.review),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: context.palette.border,
          ),
          _IslandCell(
            key: const ValueKey('topbar.search'),
            label: dense ? null : 'Search',
            leading: const Icon(Icons.search_rounded, size: 18),
            trailing: dense ? null : KeyHint(searchShortcutLabel),
            tooltip: 'Search ($searchShortcutLabel)',
            dense: dense,
            onTap: () => openSearchPalette(context),
          ),
        ],
      ),
    );
  }
}

/// One control in the island. Active: a tinted fill and a small brand-
/// coloured dot in its corner.
class _IslandCell extends StatefulWidget {
  const _IslandCell({
    super.key,
    required this.onTap,
    this.label,
    this.leading,
    this.trailing,
    this.tooltip,
    this.isActive = false,
    this.isOpen = false,
    this.dense = false,
  });

  final VoidCallback onTap;
  final String? label;
  final Widget? leading;
  final Widget? trailing;
  final String? tooltip;
  final bool isActive;

  /// Its dropdown is showing.
  final bool isOpen;
  final bool dense;

  @override
  State<_IslandCell> createState() => _IslandCellState();
}

class _IslandCellState extends State<_IslandCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final lit = _hovered || widget.isOpen;
    final fg = active
        ? AppColors.primary
        : lit
        ? context.palette.textPrimary
        : context.palette.textSecondary;
    final bg = active
        ? AppColors.primary.withAlpha(34)
        : lit
        ? context.palette.track
        : Colors.transparent;

    final cell = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(horizontal: widget.dense ? 10 : 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconTheme.merge(
                data: IconThemeData(color: fg),
                child: DefaultTextStyle.merge(
                  style: AppTheme.bodyMd.copyWith(
                    color: fg,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.leading != null) widget.leading!,
                      if (widget.leading != null && widget.label != null)
                        const SizedBox(width: 6),
                      if (widget.label != null) Text(widget.label!),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 6),
                        widget.trailing!,
                      ],
                    ],
                  ),
                ),
              ),
              if (active)
                Positioned(
                  top: 5,
                  right: -8,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: active,
      label: widget.label ?? widget.tooltip,
      child: widget.tooltip == null
          ? cell
          : Tooltip(message: widget.tooltip!, child: cell),
    );
  }
}

/// The one solid button in the bar: back to the lesson you were last in,
/// or, for a guest, keeping what they have done. Nothing at all for a
/// student who has not opened a lesson yet.
class _ActionButton extends ConsumerWidget {
  const _ActionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final cont = isGuest ? null : ref.watch(continueLearningProvider);

    final (String, String, String)? action = isGuest
        ? (
            'Save progress',
            'Make an account so your progress is kept',
            '/account/upgrade',
          )
        : cont == null
        ? null
        : (
            'Continue',
            cont.lessonFinished
                ? 'Take the ${cont.topic.name} topic test'
                : 'Continue ${cont.topic.name}: ${cont.next!.title}',
            cont.path,
          );
    if (action == null) return const SizedBox.shrink();
    final (label, tooltip, path) = action;

    return Tooltip(
      message: tooltip,
      child: Material(
        key: const ValueKey('topbar.action'),
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(path),
          child: SizedBox(
            height: 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    label,
                    style: AppTheme.btnLabel.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // The arrow sits in its own darker cell, so the button
                // reads as "go" at a glance.
                Container(
                  width: 38,
                  height: 38,
                  color: AppColors.primaryDark,
                  child: Icon(
                    isGuest
                        ? Icons.cloud_upload_outlined
                        : Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Offline" while there is no connection: lessons saved for offline still
/// open, and nothing else is promised.
class _OfflineChip extends ConsumerWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOnlineProvider).asData?.value == false;
    if (!offline) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'No connection. Topics saved for offline still open.',
        child: Container(
          key: const ValueKey('topbar.offline'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warning.withAlpha(120)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 15,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Offline',
                style: AppTheme.label.copyWith(color: AppColors.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.onTap, required this.height});
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          label: 'Project Paragon — home',
          button: true,
          child: Image.asset(
            'assets/images/paragon_logo.png',
            height: height,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
