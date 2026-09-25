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

/// State that lives exactly as long as one visit to a screen.
///
/// Created by the screen's `StudyDock` and dropped when the student leaves
/// it. For tool state that must survive closing and reopening a panel but
/// must **not** follow the student to the next screen — rough work on one
/// question has no business appearing over the next exam. State that
/// should persist across screens (a calculator's memory, like a real
/// calculator's) belongs in a Riverpod provider instead.
class StudySession {
  final Map<Object, Object?> _values = {};

  /// The value stored under [key], creating it on first use.
  T putIfAbsent<T>(Object key, T Function() create) =>
      _values.putIfAbsent(key, create) as T;

  void set(Object key, Object? value) => _values[key] = value;

  /// The session of the nearest `StudyDock`. Throws if there is none —
  /// a tool is only ever built by a dock.
  static StudySession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<StudySessionScope>();
    assert(scope != null, 'StudySession.of called outside a StudyDock');
    return scope!.session;
  }
}

/// Provides a [StudySession] to the tools a `StudyDock` builds.
class StudySessionScope extends InheritedWidget {
  const StudySessionScope({
    super.key,
    required this.session,
    required super.child,
  });

  final StudySession session;

  @override
  bool updateShouldNotify(StudySessionScope oldWidget) =>
      session != oldWidget.session;
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
