import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/widgets/difficulty_rating.dart';

/// "How hard was this?" after a practice answer (owner's decision,
/// 2026-10-17): out of the way until tapped, and never in a test or exam.
void main() {
  testWidgets('collapsed until asked; a tap records the tier', (tester) async {
    int? rated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DifficultyRating(
              selected: rated,
              onRate: (l) => setState(() => rated = l),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Spicy'), findsNothing);
    await tester.tap(find.text('How hard was this?'));
    await tester.pump();
    await tester.tap(find.text('Spicy'));
    await tester.pump();
    expect(rated, 4);
    expect(find.text('You said: Spicy'), findsOneWidget);
  });

  test('practice screens ask; the topic test and WAEC exam never do', () {
    bool asks(String path) =>
        File(path).readAsStringSync().contains('DifficultyRating(');
    expect(asks('lib/features/drill_screen.dart'), isTrue);
    expect(asks('lib/features/lesson/exercise_pane.dart'), isTrue);
    expect(asks('lib/features/mistakes/mistakes_practice_screen.dart'), isTrue);
    // Control: the timed and graded sessions.
    expect(asks('lib/features/topic_test_screen.dart'), isFalse);
    expect(asks('lib/features/waec_exam_screen.dart'), isFalse);
  });
}
