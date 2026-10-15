import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/theme/app_theme.dart';
import 'package:paragon/core/widgets/question_source_badge.dart';

Question _q({String source = 'waec', int? year, String origin = ''}) =>
    Question(
      id: 'q',
      topicId: 't',
      subjectId: 's',
      text: 'What is 2 + 2?',
      options: const ['3', '4'],
      correctIndex: 1,
      explanation: '',
      source: source,
      year: year,
      origin: origin,
    );

void main() {
  test('control: a scraped past question is labelled with its year', () {
    final q = _q(year: 2018);
    expect(q.isPastQuestion, isTrue);
    expect(q.provenanceLabel, 'WAEC 2018');
  });

  test('a past question with no year still says it is a past question', () {
    expect(_q().provenanceLabel, 'WAEC past question');
  });

  test('generated questions are Paragon practice, never past questions', () {
    final generated = _q(source: 'drill', origin: 'ai_generated');
    expect(generated.provenanceLabel, 'Paragon practice');
    expect(generated.isPastQuestion, isFalse);
    // Even a generated question mislabelled with source "waec" and a year
    // must not claim to be from a paper: origin wins.
    final mislabelled = _q(year: 2019, origin: 'ai_generated');
    expect(mislabelled.isPastQuestion, isFalse);
    expect(mislabelled.provenanceLabel, 'Paragon practice');
  });

  test('an unclassified question gets no badge', () {
    expect(_q(source: 'drill').provenanceLabel, isNull);
  });

  testWidgets('the badge shows the label and draws nothing when unknown', (
    tester,
  ) async {
    Future<void> pump(Question q) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: QuestionSourceBadge(question: q)),
      ),
    );
    await pump(_q(year: 2018));
    expect(find.text('WAEC 2018'), findsOneWidget);
    await pump(_q(source: 'drill', origin: 'ai_generated'));
    expect(find.text('Paragon practice'), findsOneWidget);
    await pump(_q(source: 'drill'));
    expect(find.byType(Text), findsNothing);
  });
}
