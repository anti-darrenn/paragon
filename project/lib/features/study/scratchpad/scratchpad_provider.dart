import 'package:flutter/widgets.dart';

import '../../../core/study/study_tool.dart';
import 'scratchpad_model.dart';

/// The scratchpad's strokes and history for one screen visit.
///
/// Held in the screen's [StudySession], not a global provider: closing and
/// reopening the scratchpad brings the working back, but rough work on one
/// question never appears over the next screen or an exam. In memory
/// only — nothing is written to Firestore or disk.
class ScratchpadController extends ValueNotifier<ScratchpadModel> {
  ScratchpadController() : super(const ScratchpadModel());

  /// This screen's controller, created on first use.
  static ScratchpadController of(BuildContext context) => StudySession.of(
    context,
  ).putIfAbsent(ScratchpadController, ScratchpadController.new);

  void addStroke(ScratchStroke stroke) => value = value.addStroke(stroke);
  void eraseAlong(List<Offset> path, double radius) =>
      value = value.eraseAlong(path, radius);
  void undo() => value = value.undo();
  void redo() => value = value.redo();
  void clear() => value = value.clear();
}
