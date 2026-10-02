import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../repositories/course_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

/// The Courses dropdown, Khan Academy style: every subject on one panel,
/// the student's own first, each one click from its course page.
///
/// Reads only the course catalog, which the app has already loaded for
/// the dashboard and the course pages.
class CoursesMenu extends StatefulWidget {
  const CoursesMenu({super.key, required this.builder});

  /// Builds the trigger; call `toggle` to open or close the panel.
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle)
  builder;

  @override
  State<CoursesMenu> createState() => _CoursesMenuState();
}

class _CoursesMenuState extends State<CoursesMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(-8, 10),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(16),
        shadowColor: WidgetStatePropertyAll(AppColors.overlay.withAlpha(160)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.palette.border),
          ),
        ),
      ),
      menuChildren: [_CoursesPanel(onClose: _controller.close)],
      builder: (context, controller, _) => widget.builder(
        context,
        controller.isOpen,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _CoursesPanel extends ConsumerWidget {
  const _CoursesPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(courseCatalogProvider).asData?.value;
    final mine = ref.watch(selectedSubjectSlugsProvider);

    void open(String path) {
      onClose();
      context.go(path);
    }

    if (catalog == null) {
      return const SizedBox(
        width: 560,
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final yours = [for (final c in catalog) if (mine.contains(c.slug)) c];
    final others = [for (final c in catalog) if (!mine.contains(c.slug)) c]
      ..sort((a, b) {
        // Live courses first: something you can open beats a promise.
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    Widget section(String title, List<CourseSummary> courses) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Wrap(
            children: [
              for (final c in courses)
                _CourseTile(
                  course: c,
                  onTap: () => open('/subject/${c.key}/course'),
                ),
            ],
          ),
        ),
      ],
    );

    return SizedBox(
      key: const ValueKey('nav.coursesPanel'),
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (yours.isNotEmpty) section('Your subjects', yours),
          section(yours.isEmpty ? 'All subjects' : 'More subjects', others),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.palette.background,
              border: Border(top: BorderSide(color: context.palette.border)),
            ),
            child: Row(
              children: [
                _FooterLink(
                  label: 'Browse all courses',
                  onTap: () => open('/courses'),
                ),
                const Spacer(),
                _FooterLink(
                  label: 'WAEC past papers',
                  onTap: () => open('/waec'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatefulWidget {
  const _CourseTile({required this.course, required this.onTap});

  final CourseSummary course;
  final VoidCallback onTap;

  @override
  State<_CourseTile> createState() => _CourseTileState();
}

class _CourseTileState extends State<_CourseTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final accent = AppColors.forSubject(c.name);
    final meta = !c.isLive
        ? 'Coming soon'
        : c.topicCount > 0
        ? '${c.topicCount} topics'
        : '${c.moduleCount} units';
    final initials = c.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: ValueKey('nav.course.${c.slug}'),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 290,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hovered ? context.palette.track : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Opacity(
            opacity: c.isLive ? 1 : 0.6,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(40),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: accent.withAlpha(90)),
                  ),
                  child: Text(
                    initials,
                    style: AppTheme.label.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyMd.copyWith(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        meta,
                        style: AppTheme.caption.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hovered)
                  Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      label: Text(label, style: AppTheme.label),
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    );
  }
}
