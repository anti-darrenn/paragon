import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/study/study_tool.dart';
import '../../../core/study/study_tool_registry.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/ui/ui.dart';

/// `/review/tools/:toolId`: one study tool on a page of its own, from the
/// Study tab, without a lesson or drill around it.
///
/// The same tools the dock offers (`study_tool_registry.dart`), in the
/// learning context, so the periodic table is here too (it is only kept
/// out of the exam). A tool that depends on a subject — the glossary, the
/// formula sheet — asks which one first. Rough work lives as long as the
/// page, as it does in the dock.
class StandaloneToolScreen extends ConsumerStatefulWidget {
  const StandaloneToolScreen({super.key, required this.toolId});
  final String toolId;

  @override
  ConsumerState<StandaloneToolScreen> createState() =>
      _StandaloneToolScreenState();
}

class _StandaloneToolScreenState extends ConsumerState<StandaloneToolScreen> {
  final _session = StudySession();
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final tool = studyTools
        .where((t) => t.id.name == widget.toolId)
        .firstOrNull;
    if (tool == null) {
      return const Scaffold(
        appBar: ParagonAppBar(title: Text('Study tool')),
        body: EmptyState(
          icon: Icons.handyman_outlined,
          title: 'No such tool',
          message: 'Pick one from the Study tab.',
        ),
      );
    }
    final subjects = [
      for (final s in ref.watch(subjectsProvider).asData?.value ?? const [])
        if (toolsForSubject(s.name).contains(tool.id)) s,
    ];
    final subject =
        subjects.where((s) => s.id == _subjectId).firstOrNull ??
        subjects.firstOrNull;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: Text(tool.label)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subjects.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subjects)
                    ChoiceChip(
                      label: Text(s.name),
                      selected: s.id == subject?.id,
                      onSelected: (_) => setState(() => _subjectId = s.id),
                    ),
                ],
              ),
            ),
          Expanded(
            child: subject == null
                ? const EmptyState(
                    icon: Icons.handyman_outlined,
                    title: 'Not for these subjects yet',
                    message: 'No live subject uses this tool.',
                  )
                : StudySessionScope(
                    session: _session,
                    child: KeyedSubtree(
                      key: ValueKey(subject.id),
                      child: tool.build(
                        context,
                        StudyScope(
                          subjectName: subject.name,
                          subjectId: subject.id,
                          context: StudyContext.lesson,
                        ),
                        () => context.popOrGo(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
