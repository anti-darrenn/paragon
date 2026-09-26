import 'package:flutter/material.dart';

import '../../../core/content/subject_tools.dart';
import '../../../core/study/study_tool.dart';
import 'calculator_panel.dart';

/// The WAEC-style scientific calculator, as a study-dock panel. Which
/// subjects and contexts offer it is decided in `subject_tools.dart`.
class CalculatorTool extends StudyTool {
  const CalculatorTool();

  @override
  StudyToolId get id => StudyToolId.calculator;
  @override
  String get label => 'Calculator';
  @override
  IconData get icon => Icons.calculate_outlined;
  @override
  StudyPanelMode get mode => StudyPanelMode.panel;

  @override
  Widget build(BuildContext context, StudyScope scope, VoidCallback close) =>
      const CalculatorPanel();
}
