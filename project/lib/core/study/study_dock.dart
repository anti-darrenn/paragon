import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/learning_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'study_tool.dart';
import 'study_tool_registry.dart';

/// Hosts the study tools (calculator, scratchpad, tables…) on a screen.
///
/// Wraps the screen's body. Adds a small "Tools" tab on the right edge —
/// on the edge, not a floating button at the bottom, because the bottom is
/// where drill and exam screens keep their answer and submit controls.
/// Invisible when the subject and context allow no registered tool, so a
/// screen can always carry one.
///
/// A [StudyPanelMode.panel] tool stays open while the student keeps
/// working — that is the point of a calculator beside a question — so it
/// is drawn in this stack, not pushed as a route.
class StudyDock extends ConsumerStatefulWidget {
  const StudyDock({
    super.key,
    required this.subjectId,
    required this.studyContext,
    required this.child,
    this.tools,
  });

  /// Firestore subject id; resolved to a name through `subjectsProvider`.
  /// Null or unknown hides every subject-specific tool.
  final String? subjectId;
  final StudyContext studyContext;
  final Widget child;

  /// Overrides the registry. For tests.
  final List<StudyTool>? tools;

  @override
  ConsumerState<StudyDock> createState() => _StudyDockState();
}

class _StudyDockState extends ConsumerState<StudyDock> {
  StudyTool? _open;

  /// Per-visit tool state; see [StudySession]. Lives and dies with this
  /// dock, which lives and dies with the screen.
  final _session = StudySession();

  void _close() => setState(() => _open = null);

  Future<void> _pick(List<StudyTool> available, StudyScope scope) async {
    final tool = await showModalBottomSheet<StudyTool>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                scope.context.isExam ? 'Allowed in the exam' : 'Study tools',
                style: AppTheme.heading3.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            for (final t in available)
              ListTile(
                leading: Icon(t.icon, color: AppColors.textSecondaryDark),
                title: Text(
                  t.label,
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                onTap: () => Navigator.of(sheet).pop(t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (tool == null || !mounted) return;

    if (tool.mode == StudyPanelMode.page) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (page) => Scaffold(
            backgroundColor: AppColors.backgroundDark,
            appBar: AppBar(title: Text(tool.label)),
            body: StudySessionScope(
              session: _session,
              child: Builder(
                builder: (inner) =>
                    tool.build(inner, scope, () => Navigator.of(page).pop()),
              ),
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _open = tool);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    String name = '';
    for (final s in subjects) {
      if (s.id == widget.subjectId) name = s.name;
    }
    final scope = StudyScope(
      subjectName: name,
      context: widget.studyContext,
      subjectId: name.isEmpty ? '' : widget.subjectId ?? '',
    );
    final allowed = scope.allowed;
    final available = [
      for (final t in widget.tools ?? studyTools)
        if (allowed.contains(t.id)) t,
    ];
    if (available.isEmpty) return widget.child;

    final open = _open;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 720;
        return StudySessionScope(
          session: _session,
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (open == null || open.mode != StudyPanelMode.overlay)
                Positioned(
                  right: 0,
                  top: box.maxHeight * 0.38,
                  child: _ToolsTab(onTap: () => _pick(available, scope)),
                ),
              if (open != null && open.mode == StudyPanelMode.overlay)
                Positioned.fill(child: open.build(context, scope, _close)),
              if (open != null && open.mode == StudyPanelMode.panel)
                wide
                    ? Positioned(
                        right: 44,
                        bottom: 24,
                        width: 360,
                        child: _Panel(tool: open, scope: scope, close: _close),
                      )
                    : Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: box.maxHeight * 0.6,
                          ),
                          child: _Panel(
                            tool: open,
                            scope: scope,
                            close: _close,
                          ),
                        ),
                      ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.borderDark),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
        child: const Tooltip(
          message: 'Study tools',
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Icon(
              Icons.handyman_outlined,
              size: 20,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.tool, required this.scope, required this.close});
  final StudyTool tool;
  final StudyScope scope;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.borderDark),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
            child: Row(
              children: [
                Icon(tool.icon, size: 18, color: AppColors.textSecondaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tool.label,
                    style: AppTheme.label.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: close,
                ),
              ],
            ),
          ),
          Flexible(child: tool.build(context, scope, close)),
        ],
      ),
    );
  }
}
