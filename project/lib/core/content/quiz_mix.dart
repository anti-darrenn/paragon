import 'dart:math';

import '../models/question.dart';
import '../questions/difficulty.dart';
import 'session_mix.dart';

/// A custom quiz's questions from [pools] (one per chosen topic): the
/// chosen [tier] only, when one is chosen, spread across the topics in
/// turn so no topic crowds the rest out, at most [length]. Pure.
List<Question> buildCustomQuiz(
  List<List<Question>> pools, {
  required int length,
  DifficultyTier? tier,
  Random? random,
}) {
  final r = random ?? Random();
  final filtered = [
    for (final p in pools)
      [
        for (final q in p)
          if (tier == null || q.tier == tier) q,
      ]..shuffle(r),
  ];
  final out = <Question>[];
  final seen = <String>{};
  for (var round = 0; out.length < length; round++) {
    var took = false;
    for (final p in filtered) {
      if (round < p.length && out.length < length && seen.add(p[round].id)) {
        out.add(p[round]);
        took = true;
      }
    }
    if (!took) break;
  }
  return mixSession(out..shuffle(r), (q) => q.text);
}
