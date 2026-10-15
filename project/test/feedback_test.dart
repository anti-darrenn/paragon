import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/data/error_reporter.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/repositories/feedback_repository.dart';
import 'package:paragon/core/theme/app_theme.dart';
import 'package:paragon/features/feedback/feedback_sheet.dart';

// ignore: subtype_of_sealed_class
class FakeUser implements User {
  FakeUser(this.uid);

  @override
  final String uid;
  @override
  bool get isAnonymous => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore db;
  late FeedbackRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FeedbackRepository(db);
    ErrorReporter.screen = '/settings';
  });

  group('FeedbackRepository', () {
    test('writes exactly the fields the rule allows', () async {
      await repo.send(
        userId: 'u1',
        kind: FeedbackKind.idea,
        message: '  Please add Biology  ',
      );
      final doc = (await db.collection('feedback').get()).docs.single.data();
      // The rule's hasOnly list; a field added here without the rule would
      // make every send fail in production.
      expect(doc.keys.toSet(), {
        'userId',
        'kind',
        'message',
        'screen',
        'createdAt',
      });
      expect(doc['userId'], 'u1');
      expect(doc['kind'], 'idea');
      expect(doc['message'], 'Please add Biology');
      // The route pattern, never a URL with ids in it.
      expect(doc['screen'], '/settings');
    });

    test('a message over the cap is cut to it, not refused', () async {
      await repo.send(
        userId: 'u1',
        kind: FeedbackKind.other,
        message: 'x' * (kFeedbackMaxLength + 50),
      );
      final doc = (await db.collection('feedback').get()).docs.single.data();
      expect((doc['message'] as String).length, kFeedbackMaxLength);
    });

    test('recent: missing status reads as open; triaged ones do not', () async {
      final at = Timestamp.fromDate(DateTime.utc(2026, 10, 3));
      await db.collection('feedback').doc('a').set({
        'userId': 'u1',
        'kind': 'problem',
        'message': 'broken',
        'screen': '/',
        'createdAt': at,
      });
      await db.collection('feedback').doc('b').set({
        'userId': 'u2',
        'kind': 'nonsense',
        'message': 'ok',
        'screen': '/',
        'createdAt': at,
        'status': 'done',
      });
      final items = {for (final f in await repo.recent()) f.id: f};
      expect(items['a']!.isOpen, isTrue);
      expect(items['a']!.kind, FeedbackKind.problem);
      // Control: a triaged message is not open.
      expect(items['b']!.isOpen, isFalse);
      // An unknown kind does not throw; it reads as "other".
      expect(items['b']!.kind, FeedbackKind.other);
    });
  });

  group('FeedbackSheet', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(FakeUser('guest1')),
            feedbackRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showFeedbackSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    FilledButton sendButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));

    testWidgets('Send stays off until something is written', (tester) async {
      await pump(tester);
      expect(sendButton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(sendButton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Add Biology');
      await tester.pump();
      expect(sendButton(tester).onPressed, isNotNull);
    });

    testWidgets('a guest can send, with the chosen kind', (tester) async {
      await pump(tester);
      await tester.tap(find.text(FeedbackKind.problem.label));
      await tester.enterText(find.byType(TextField), 'The timer froze');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();

      final docs = (await db.collection('feedback').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['userId'], 'guest1');
      expect(docs.single.data()['kind'], 'problem');
      expect(find.byType(FeedbackSheet), findsNothing);
      expect(find.textContaining('The team reads every one'), findsOneWidget);
    });
  });
}
