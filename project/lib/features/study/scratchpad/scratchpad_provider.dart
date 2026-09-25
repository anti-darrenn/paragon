import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scratchpad_model.dart';

/// The scratchpad's strokes and history.
///
/// Kept in a provider, not the overlay's state, so closing and reopening
/// the scratchpad brings the working back. In memory only: nothing is
/// written to Firestore or disk, and an app restart starts a clean page.
final scratchpadProvider =
    NotifierProvider<ScratchpadNotifier, ScratchpadModel>(
      ScratchpadNotifier.new,
    );

class ScratchpadNotifier extends Notifier<ScratchpadModel> {
  @override
  ScratchpadModel build() => const ScratchpadModel();

  void addStroke(ScratchStroke stroke) => state = state.addStroke(stroke);
  void eraseAlong(List<Offset> path, double radius) =>
      state = state.eraseAlong(path, radius);
  void undo() => state = state.undo();
  void redo() => state = state.redo();
  void clear() => state = state.clear();
}
