import 'package:flutter/widgets.dart';

import '../content/subject_tools.dart';

/// Where a study tool is being opened from.
enum StudyContext {
  lesson,
  drill,
  topicTest,
  waecExam;

  bool get isExam => this == StudyContext.waecExam;
}

/// The screen a tool is opened on: which subject, and in what context.
class StudyScope {
  const StudyScope({required this.subjectName, required this.context});

  /// Empty while the subject is still loading; tools that depend on the
  /// subject then stay hidden.
  final String subjectName;
  final StudyContext context;

  /// The tools this scope may offer: the subject's tools, narrowed to what
  /// the exam hall allows when [context] is an exam.
  Set<StudyToolId> get allowed {
    if (subjectName.isEmpty) return {};
    final tools = toolsForSubject(subjectName);
    return context.isExam ? tools.intersection(examAllowedTools) : tools;
  }
}

/// How a tool's panel is shown.
enum StudyPanelMode {
  /// A small panel that stays open while the student keeps working: a
  /// floating window on wide screens, a bottom sheet (non-modal) on phones.
  /// The calculator, tables.
  panel,

  /// Covers the whole screen, drawn over it. The scratchpad.
  overlay,

  /// A full page: long references like the periodic table or a formula
  /// sheet.
  page,
}

/// One tool in the study dock.
///
/// **The contract for adding a tool:** implement this, then add one entry
/// to `study_tool_registry.dart`. Nothing else — the host screens (lesson,
/// drill, topic test, WAEC exam) already carry a `StudyDock` and never need
/// editing for a new tool. Which subjects and contexts see the tool is
/// decided by [id] through `subject_tools.dart`, not by the tool itself.
abstract class StudyTool {
  const StudyTool();

  StudyToolId get id;
  String get label;
  IconData get icon;
  StudyPanelMode get mode;

  /// The tool's UI. [close] dismisses it. Keep state inside the widget —
  /// a panel is rebuilt when reopened, so a calculator that should keep
  /// its value across openings stores it in a provider.
  Widget build(BuildContext context, StudyScope scope, VoidCallback close);
}
