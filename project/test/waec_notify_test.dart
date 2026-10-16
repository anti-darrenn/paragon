import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/subject.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/learning_repository.dart';
import 'package:paragon/core/repositories/waitlist_repository.dart';
import 'package:paragon/features/waec_subject_screen.dart';

/// Plan v2 7.7: a WAEC subject with no past papers offers "Notify me" and
/// a way to practise, instead of a dead tile.
void main() {
  const subjects = [
    Subject(
      id: 'c',
      name: 'Chemistry',
      unitCount: 1,
      practiceQuestionCount: 300,
    ),
    Subject(
      id: 'm',
      name: 'Mathematics',
      unitCount: 1,
      pastQuestionCount: 1677,
      practiceQuestionCount: 12900,
    ),
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith((ref) async => subjects),
          isGuestProvider.overrideWithValue(false),
          myWaitlistProvider.overrideWith((ref) => Stream.value(const {})),
        ],
        child: const MaterialApp(home: WaecSubjectScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no past papers: notify me, and practise meanwhile', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No past questions yet'), findsOneWidget);
    expect(
      find.text('Notify me when Chemistry past papers are ready'),
      findsOneWidget,
    );
    expect(find.text('Practise Chemistry meanwhile'), findsOneWidget);
    // CONTROL: a subject with papers gets neither.
    expect(find.textContaining('Notify me when Mathematics'), findsNothing);
    expect(find.text('Practise Mathematics meanwhile'), findsNothing);
  });

  test('the papers waitlist is apart from the subject launch list', () {
    expect(waecPapersWaitlistKey('chemistry'), 'waec-chemistry');
    expect(waecPapersWaitlistKey('chemistry'), isNot('chemistry'));
  });
}
