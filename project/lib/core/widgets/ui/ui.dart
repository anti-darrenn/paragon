/// The building blocks screens are laid out from, so pages share one
/// width, one rhythm and one card style instead of each inventing its own.
///
/// - [PageBody]: the scrolling, centred column a page's content sits in.
/// - [SectionHeader]: a heading over a group, with an optional action.
/// - [SurfaceCard]: the bordered card everything groups into.
/// - [ListRow]: an icon tile, a title and a subtitle, usually a link.
/// - [IconTile]: the tinted square an icon sits in.
/// - [EmptyState]: what a list says when it has nothing in it.
library;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../nav/nav_destinations.dart';
import '../../theme/app_theme.dart';

/// Reading width for text-and-list pages.
const double kPageMaxWidth = 720;

/// Space between groups on a page.
const double kSectionGap = 28;

/// A page's scrolling content: centred at [maxWidth], with the same
/// gutters and end padding on every page. Takes a list of children, like
/// a [ListView], and builds them lazily.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = kPageMaxWidth,
    this.padding,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          controller: controller,
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                compact ? 16 : 24,
                compact ? 16 : 24,
                48,
              ),
          children: children,
        ),
      ),
    );
  }
}

/// A heading over a group of rows or cards. [action] sits at the end of
/// the line ("Edit", "See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLg.copyWith(
                    color: context.palette.textStrong,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTheme.label.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A small upper-case label over a group, for denser pages like settings.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.caption.copyWith(
          color: color ?? context.palette.textSecondary,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The bordered card things group into. Tappable when [onTap] is given,
/// with the ripple clipped to its corners.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusMd + 2);
    return Material(
      color: color ?? context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? context.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// The tinted, rounded square an icon sits in.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(34),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// One row: an optional icon tile, a title, an optional subtitle and a
/// trailing widget (a chevron when it is a link). Used inside cards and
/// as cards of its own.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  /// Instead of an icon tile — an avatar, a ring.
  final Widget? leading;

  /// Defaults to a chevron when [onTap] is set.
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final lead =
        leading ??
        (icon == null
            ? null
            : IconTile(
                icon: icon!,
                color: iconColor ?? context.palette.textSecondary,
                size: subtitle == null ? 34 : 40,
              ));
    final trail =
        trailing ??
        (onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: context.palette.textSecondary,
              ));

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (lead != null) ...[lead, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMd.copyWith(
                    color: titleColor ?? context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTheme.label.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trail != null) ...[const SizedBox(width: 10), trail],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Rows stacked in one card with hairlines between them, as in a
/// settings list.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.palette.border.withAlpha(150),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A list with nothing in it: an icon, what is missing, and how to get
/// some — never just a blank page.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.palette.border),
            ),
            child: Icon(icon, size: 28, color: context.palette.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMd.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// A page's own heading, under the app bar: a big title, an optional
/// line beneath it, and room for an action.
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.wideOnly = false,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  /// Only on a wide screen — for a tab's first page, whose app bar names
  /// it on a phone and steps aside on a wide screen.
  final bool wideOnly;

  @override
  Widget build(BuildContext context) {
    if (wideOnly && navLayoutFor(context) != NavLayout.topBar) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.heading1.copyWith(
                    color: context.palette.textStrong,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: AppTheme.bodyMd.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 16), action!],
        ],
      ),
    );
  }
}
