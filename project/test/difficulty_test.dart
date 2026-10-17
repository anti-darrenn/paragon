import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/questions/difficulty.dart';

/// Difficulty tiers, from "Easy peasy" to "Unnecessarily hard". The tier
/// is an estimate from the question itself, so the tests pin the ends on
/// real questions and check the whole bank still spreads across all five.
void main() {
  DifficultyTier tier(
    String text, [
    List<String> options = const ['1', '2', '3', '4'],
  ]) => estimateDifficulty(text, options);

  test('a one-step recall question is easy peasy', () {
    expect(
      tier('A hypsometer is used for determining', [
        'heat',
        'boiling point',
        'density',
        'pressure',
      ]),
      DifficultyTier.easyPeasy,
    );
  });

  test('stacked fractional and negative powers are unnecessarily hard', () {
    expect(
      tier(
        r'Simplify \(\frac{25 ^\frac{2}{3} \div 25 ^\frac{1}{6}}{( \frac{1}{5})^{-\frac{7}{6}} \times ( \frac{1}{5})^{\frac{1}{6}}}\)',
      ),
      DifficultyTier.unnecessarilyHard,
    );
  });

  test('harder questions never score below easier ones on the same topic', () {
    final easy = difficultyScore(r'Evaluate \(12 \times 6^{0}\).', const [
      '12',
      '72',
      '0',
      '6',
    ]);
    final hard = difficultyScore(
      r'If \(16 \times 2^{x+1} = 4^{x} \times 8^{1-x}\), find \(x\).',
      const ['-4', '4', '-1', '1'],
    );
    expect(hard, greaterThan(easy));
    expect(
      tier(r'Evaluate \(12 \times 6^{0}\).', const [
        '12',
        '72',
        '0',
        '6',
      ]).level,
      lessThan(
        tier(
          r'If \(16 \times 2^{x+1} = 4^{x} \times 8^{1-x}\), find \(x\).',
        ).level,
      ),
    );
  });

  test('"I and II only" is a choice of statements, not algebra', () {
    final statements = difficultyScore(
      'Which of the following are correct? I. A II. B III. C',
      const [
        'I and II only',
        'I and III only',
        'II and III only',
        'I, II and III',
      ],
    );
    final algebra = difficultyScore(
      'Which of the following are correct? I. A II. B III. C',
      const ['x + y', '2x', 'x - y', 'xy'],
    );
    expect(algebra, greaterThan(statements));
  });

  test('a diagram adds to the work', () {
    const t = 'In the diagram, find the angle marked x.';
    expect(
      difficultyScore(t, const ['30', '40', '50', '60'], hasDiagram: true),
      greaterThan(difficultyScore(t, const ['30', '40', '50', '60'])),
    );
  });

  test('a reviewer-set level wins; nonsense levels are ignored', () {
    expect(DifficultyTier.fromLevel(5), DifficultyTier.unnecessarilyHard);
    expect(DifficultyTier.fromLevel(1)!.label, 'Easy peasy');
    expect(DifficultyTier.fromLevel(9), isNull);
    expect(DifficultyTier.fromLevel(null), isNull);
  });

  test('every tier is named and described', () {
    expect(DifficultyTier.values.map((t) => t.level), [1, 2, 3, 4, 5]);
    for (final t in DifficultyTier.values) {
      expect(t.label, isNotEmpty);
      expect(t.blurb, isNotEmpty);
    }
  });

  // CONTROL against a scorer that puts everything in one tier: the whole
  // generated bank must reach all five, none holding 80% or more.
  test('the generated bank spreads across all five tiers', () {
    final counts = <DifficultyTier, int>{};
    var n = 0;
    for (final f in Directory(
      'tools/scraper/data',
    ).listSync().whereType<File>()) {
      if (!f.path.contains('generated_')) continue;
      final d = jsonDecode(f.readAsStringSync());
      for (final q in (d is List ? d : d['questions'] as List)) {
        final t = estimateDifficulty('${q['text']}', [
          for (final o in q['options']) '$o',
        ]);
        counts[t] = (counts[t] ?? 0) + 1;
        n++;
      }
    }
    expect(n, greaterThan(60000), reason: 'control: the corpus was read');
    for (final t in DifficultyTier.values) {
      expect(
        counts[t] ?? 0,
        greaterThan(n ~/ 100),
        reason: '${t.label} is (nearly) empty',
      );
      expect(
        counts[t] ?? 0,
        lessThan(n * 4 ~/ 5),
        reason: '${t.label} holds almost everything',
      );
    }
  });
}
