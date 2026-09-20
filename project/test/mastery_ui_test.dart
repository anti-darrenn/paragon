import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/progress/mastery.dart';
import 'package:paragon/core/repositories/course_repository.dart';
import 'package:paragon/core/repositories/progress_repository.dart';
import 'package:paragon/core/theme/app_colors.dart';
import 'package:paragon/core/widgets/course_module_card.dart';
import 'package:paragon/core/widgets/mastery_indicator.dart';

/// Checks that the rings are actually wired to the student's counters, not
/// merely that the maths in `mastery.dart` is right. The failure this
/// guards against is a card that draws a perfectly correct circle for the
/// wrong topic, or draws every circle empty because the progress never
/// reached it.
void main() {
  CourseTopic topic(String id, {bool placeholder = false}) => CourseTopic(
    id: id,
    name: 'Topic $id',
    questionCount: 300,
    hasNotes: false,
    isPlaceholder: placeholder,
  );

  CourseModule moduleOf(List<CourseTopic> topics, {bool placeholder = false}) =>
      CourseModule(
        id: 'm1',
        name: 'Algebra',
        topics: topics,
        isPlaceholder: placeholder,
      );

  Future<void> pumpCard(
    WidgetTester tester,
    CourseModule module,
    UserProgress progress,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CourseModuleCard(
              module: module,
              accent: AppColors.subjectPhysics,
              index: 0,
              gridColumns: 1,
              progress: progress,
              onTopicTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every practisable topic gets a circle', (tester) async {
    await pumpCard(
      tester,
      moduleOf([topic('a'), topic('b'), topic('c')]),
      UserProgress.empty,
    );

    expect(find.byType(MasteryCircle), findsNWidgets(3));
  });

  testWidgets('a placeholder topic gets no circle', (tester) async {
    // A planned topic has nothing to have practised; an empty ring beside
    // it would report on the student rather than on the missing content.
    await pumpCard(
      tester,
      moduleOf([topic('a'), topic('b', placeholder: true)]),
      UserProgress.empty,
    );

    expect(find.byType(MasteryCircle), findsNWidgets(1));
  });

  testWidgets('each circle reads the level of its own topic', (tester) async {
    final progress = UserProgress.fromDocument({
      'topics': {
        'a': {'answered': 40, 'correct': 40},
        'b': {'answered': 10, 'correct': 5},
      },
    });

    await pumpCard(
      tester,
      moduleOf([topic('a'), topic('b'), topic('c')]),
      progress,
    );

    final circles = tester
        .widgetList<MasteryCircle>(find.byType(MasteryCircle))
        .toList();
    expect(circles[0].level, MasteryLevel.mastered);
    expect(circles[1].level, MasteryLevel.familiar);
    // The control: a topic with no stored progress must not inherit a
    // neighbour's level.
    expect(circles[2].level, MasteryLevel.notStarted);
  });

  testWidgets('a started topic shows its level instead of a question count', (
    tester,
  ) async {
    final progress = UserProgress.fromDocument({
      'topics': {
        'a': {'answered': 20, 'correct': 18},
      },
    });

    await pumpCard(tester, moduleOf([topic('a'), topic('b')]), progress);

    expect(find.text('Proficient'), findsOneWidget);
    // The untouched topic still advertises how much material is in it.
    expect(find.text('300 questions'), findsOneWidget);
  });

  testWidgets('the module ring reflects its topics, and hides when planned', (
    tester,
  ) async {
    final progress = UserProgress.fromDocument({
      'topics': {
        'a': {'answered': 40, 'correct': 40},
        'b': {'answered': 40, 'correct': 40},
      },
    });

    await pumpCard(tester, moduleOf([topic('a'), topic('b')]), progress);
    final ring = tester.widget<MasteryRing>(find.byType(MasteryRing));
    expect(ring.fraction, 1.0);
    expect(find.text('2 of 2 started'), findsOneWidget);

    await pumpCard(
      tester,
      moduleOf([topic('x', placeholder: true)], placeholder: true),
      UserProgress.empty,
    );
    expect(find.byType(MasteryRing), findsNothing);
  });

  testWidgets('an untouched module says nothing rather than a row of zeroes', (
    tester,
  ) async {
    await pumpCard(
      tester,
      moduleOf([topic('a'), topic('b')]),
      UserProgress.empty,
    );

    expect(find.textContaining('started'), findsNothing);
    final ring = tester.widget<MasteryRing>(find.byType(MasteryRing));
    expect(ring.fraction, 0.0);
  });
}
