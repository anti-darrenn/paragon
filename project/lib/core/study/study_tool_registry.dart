import '../../features/study/calculator/calculator_tool.dart';
import '../../features/study/references/references.dart';
import '../../features/study/scratchpad/scratchpad_tool.dart';
import 'study_tool.dart';

/// Every study tool in the app, in the order the dock lists them.
///
/// **One line per tool.** Adding a tool means adding its entry here and
/// nothing else in the host screens. A tool whose id the current subject
/// or context does not allow is filtered out by `StudyScope.allowed`, so
/// entries are unconditional.
const List<StudyTool> studyTools = [
  CalculatorTool(),
  FourFigureTablesTool(),
  PeriodicTableTool(),
  ConstantsTool(),
  ScratchpadTool(),
];
