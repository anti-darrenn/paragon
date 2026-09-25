import 'package:flutter/material.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/study/study_tool.dart';
import 'scratchpad_overlay.dart';

/// Rough-work paper over the current screen. Allowed for every subject and
/// in the exam hall (`subject_tools.dart`).
class ScratchpadTool extends StudyTool {
  const ScratchpadTool();

  @override
  StudyToolId get id => StudyToolId.scratchpad;

  @override
  String get label => 'Scratchpad';

  @override
  IconData get icon => Icons.edit_outlined;

  @override
  StudyPanelMode get mode => StudyPanelMode.overlay;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      ScratchpadOverlay(close: close);
}
