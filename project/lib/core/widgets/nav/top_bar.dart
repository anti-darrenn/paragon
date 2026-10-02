import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/search/search_field.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../page_layout.dart';
import 'nav_destinations.dart';
import 'profile_menu.dart';

/// Below this width the top bar's search field becomes an icon: the logo,
/// four links and the avatar leave too little room for a usable field.
const double kTopBarSearchFieldMinWidth = 960;

/// The wide-screen navigation: logo, the four sections, search, and the
/// account menu, on one full-bleed bar.
///
/// Its contents sit in the same [kContentMaxWidth] column as the page
/// below, so the logo lines up with each page's heading.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.current, required this.onSelect});

  /// The active tab. [NavTab.me] has no link here, so on the profile and
  /// settings screens no link is lit and the avatar is the way back.
  final NavTab current;
  final ValueChanged<NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final roomyForSearch = width >= kTopBarSearchFieldMinWidth;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.background,
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: ContentColumn(
            child: Row(
              children: [
                _Logo(onTap: () => onSelect(NavTab.home)),
                SizedBox(width: roomyForSearch ? 28 : 14),
                for (final tab in NavTab.topBarTabs) ...[
                  _TabLink(
                    tab: tab,
                    isActive: tab == current,
                    dense: !roomyForSearch,
                    onTap: () => onSelect(tab),
                  ),
                  const SizedBox(width: 4),
                ],
                SizedBox(width: roomyForSearch ? 16 : 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: roomyForSearch
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: const TopBarSearchField(),
                          )
                        : IconButton(
                            key: const ValueKey('topbar.searchIcon'),
                            tooltip: 'Search',
                            icon: Icon(
                              Icons.search_rounded,
                              color: context.palette.textSecondary,
                            ),
                            onPressed: () => context.push('/search'),
                          ),
                  ),
                ),
                SizedBox(width: roomyForSearch ? 16 : 4),
                const ProfileMenuButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabLink extends StatefulWidget {
  const _TabLink({
    required this.tab,
    required this.isActive,
    required this.onTap,
    this.dense = false,
  });

  final NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  /// Tighter padding, for a window just past the breakpoint.
  final bool dense;

  @override
  State<_TabLink> createState() => _TabLinkState();
}

class _TabLinkState extends State<_TabLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final fg = active
        ? AppColors.primary
        : _hovered
        ? context.palette.textPrimary
        : context.palette.textSecondary;
    final bg = active
        ? AppColors.primary.withAlpha(30)
        : _hovered
        ? context.palette.track
        : Colors.transparent;

    return Semantics(
      selected: active,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: ValueKey('topbar.${widget.tab.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? 10 : 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              widget.tab.label,
              style: AppTheme.bodyMd.copyWith(
                color: fg,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.onTap});
  final VoidCallback onTap;

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
            height: 28,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
