import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/ai/ai_tutor.dart';
import 'package:paragon/core/ai/ask_tutor_button.dart';
import 'package:paragon/core/lessons/lesson_doc.dart';
import 'package:paragon/core/models/learn_resource.dart';

const _resource = LearnResource(
  id: 'r1',
  type: LearnResourceType.article,
  order: 1,
  title: 'Bases',
  subjectId: 's',
  topicId: 't',
  body: 'First paragraph.\n\nSecond paragraph.',
);

void main() {
  testWidgets('the button is disabled and says it is coming', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AskTutorButton(resource: _resource)),
        ),
      ),
    );
    expect(find.text('Ask (soon)'), findsOneWidget);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });

  test('the default tutor is unavailable and refuses to answer', () {
    const tutor = UnavailableAiTutor();
    expect(tutor.isAvailable, isFalse);
    expect(
      () => tutor.ask(lessonContextFor(_resource), 'why?'),
      throwsUnsupportedError,
    );
  });

  test('context narrows to the block asked about', () {
    final second = parseLessonDoc(_resource.body).blocks[1].key;
    final narrowed = lessonContextFor(_resource, blockKey: second);
    expect(narrowed.text, 'Second paragraph.');
    // Control: an unknown key falls back to the whole article.
    final whole = lessonContextFor(_resource, blockKey: 'gone');
    expect(whole.text, _resource.body);
  });
}
