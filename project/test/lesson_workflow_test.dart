import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/auth/staff_role.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/repositories/admin_resource_repository.dart';
import 'package:paragon/core/repositories/lesson_workflow.dart';

const _topic = 't1';

Future<LearnResource> _seed(
  FakeFirebaseFirestore db,
  String id, {
  String status = 'published',
  String body = 'Original body.',
  int order = 20,
  Map<String, Object?> extra = const {},
}) async {
  final ref = db
      .collection('topics')
      .doc(_topic)
      .collection('resources')
      .doc(id);
  await ref.set({
    'type': 'article',
    'title': 'Number bases',
    'order': order,
    'body': body,
    'subjectId': 's1',
    'topicId': _topic,
    'status': status,
    ...extra,
  });
  return LearnResource.fromFirestore(await ref.get());
}

Future<Map<String, dynamic>?> _data(
  FakeFirebaseFirestore db,
  String id,
) async =>
    (await db
            .collection('topics')
            .doc(_topic)
            .collection('resources')
            .doc(id)
            .get())
        .data();

Future<int> _versions(FakeFirebaseFirestore db, String id) async =>
    (await db
            .collection('topics')
            .doc(_topic)
            .collection('resources')
            .doc(id)
            .collection('versions')
            .get())
        .size;

void main() {
  group('StaffRole.fromClaims', () {
    test('highest role wins, and only a literal true counts', () {
      expect(
        StaffRole.fromClaims({'writer': true, 'reviewer': true}),
        StaffRole.reviewer,
      );
      expect(StaffRole.fromClaims({'admin': true}), StaffRole.admin);
      expect(StaffRole.fromClaims(null), StaffRole.none);
      // Control: truthy-looking values are not true, as in the rules.
      expect(
        StaffRole.fromClaims({'writer': 'true', 'reviewer': 1}),
        StaffRole.none,
      );
    });

    test('capabilities nest', () {
      expect(StaffRole.writer.canWrite, isTrue);
      expect(StaffRole.writer.canReview, isFalse);
      expect(StaffRole.reviewer.canReview, isTrue);
      expect(StaffRole.none.canWrite, isFalse);
    });
  });

  group('transitions', () {
    test(
      'submit sets in_review, records the writer and queues an email',
      () async {
        final db = FakeFirebaseFirestore();
        final r = await _seed(db, 'a', status: 'draft');
        await LessonWorkflow(db).submitForReview(r, uid: 'writer1');
        final d = (await _data(db, 'a'))!;
        expect(d['status'], 'in_review');
        expect(d['submittedBy'], 'writer1');
        expect(d['pendingNotice'], 'in_review');
      },
    );

    test(
      'requesting changes writes the reason as a comment in the same step',
      () async {
        final db = FakeFirebaseFirestore();
        final r = await _seed(db, 'a', status: 'in_review');
        await LessonWorkflow(db).requestChanges(
          r,
          uid: 'rev1',
          authorName: 'Reviewer',
          reason: 'Step 2 skips the carry.',
        );
        expect((await _data(db, 'a'))!['status'], 'changes_requested');
        final comments = await db
            .collection('topics/$_topic/resources/a/comments')
            .get();
        expect(comments.docs.single.data()['text'], 'Step 2 skips the carry.');
        expect(comments.docs.single.data()['authorUid'], 'rev1');
      },
    );

    test('approving a new item publishes it', () async {
      final db = FakeFirebaseFirestore();
      final r = await _seed(db, 'a', status: 'in_review');
      final live = await LessonWorkflow(db).approve(r, uid: 'rev1');
      expect(live, 'a');
      expect((await _data(db, 'a'))!['status'], 'published');
      expect((await _data(db, 'a'))!['pendingNotice'], 'published');
    });
  });

  group('revisions', () {
    test(
      'a revision copies the content as a draft and points at the original',
      () async {
        final db = FakeFirebaseFirestore();
        final published = await _seed(db, 'bases');
        final id = await LessonWorkflow(db).startRevision(published, uid: 'w1');
        final rev = (await _data(db, id))!;
        expect(rev['status'], 'draft');
        expect(rev['revisionOf'], 'bases');
        expect(rev['body'], 'Original body.');
        expect(rev['createdBy'], 'w1');
        // The original is untouched until approval.
        expect((await _data(db, 'bases'))!['status'], 'published');
      },
    );

    test('starting a second revision returns the open one', () async {
      final db = FakeFirebaseFirestore();
      final published = await _seed(db, 'bases');
      final wf = LessonWorkflow(db);
      final a = await wf.startRevision(published, uid: 'w1');
      final b = await wf.startRevision(published, uid: 'w2');
      expect(b, a);
    });

    test(
      'approving a revision updates the original in place and removes the copy',
      () async {
        final db = FakeFirebaseFirestore();
        await _seed(db, 'bases', order: 20);
        await _seed(
          db,
          'bases-revision',
          status: 'in_review',
          body: 'Rewritten body.',
          order: 99,
          extra: {'revisionOf': 'bases', 'submittedBy': 'w1'},
        );
        final rev = LearnResource.fromFirestore(
          await db.doc('topics/$_topic/resources/bases-revision').get(),
        );

        final live = await LessonWorkflow(db).approve(rev, uid: 'rev1');

        expect(live, 'bases');
        final orig = (await _data(db, 'bases'))!;
        expect(orig['body'], 'Rewritten body.');
        expect(orig['status'], 'published');
        // It keeps its own place, and its id — completion ticks survive.
        expect(orig['order'], 20);
        expect(orig['submittedBy'], 'w1');
        expect(await _data(db, 'bases-revision'), isNull);
        // The replaced content is kept.
        expect(await _versions(db, 'bases'), 1);
      },
    );

    test(
      'control: if the original is gone, the revision publishes on its own',
      () async {
        final db = FakeFirebaseFirestore();
        await _seed(
          db,
          'orphan',
          status: 'in_review',
          extra: {'revisionOf': 'deleted'},
        );
        final rev = LearnResource.fromFirestore(
          await db.doc('topics/$_topic/resources/orphan').get(),
        );
        final live = await LessonWorkflow(db).approve(rev, uid: 'rev1');
        expect(live, 'orphan');
        final d = (await _data(db, 'orphan'))!;
        expect(d['status'], 'published');
        expect(d.containsKey('revisionOf'), isFalse);
      },
    );
  });

  group('history', () {
    test('every save keeps the previous content as a version', () async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 'a', status: 'draft');
      final repo = AdminResourceRepository(db);
      const draft = ResourceDraft(
        type: LearnResourceType.article,
        title: 'Number bases',
        orderText: '20',
        body: 'Second body.',
      );
      await repo.save(
        topicId: _topic,
        resourceId: 'a',
        draft: draft,
        status: ResourceStatus.draft,
        savedBy: 'w1',
      );
      expect(await _versions(db, 'a'), 1);
      final v =
          (await db.collection('topics/$_topic/resources/a/versions').get())
              .docs
              .single
              .data();
      expect(v['body'], 'Original body.');
      expect(v['savedBy'], 'w1');
      expect((await _data(db, 'a'))!['body'], 'Second body.');
    });

    test(
      'restoring a version brings its content back and keeps the current as a version',
      () async {
        final db = FakeFirebaseFirestore();
        final r = await _seed(db, 'a', status: 'draft', body: 'Current.');
        const old = ResourceVersion(
          id: 'v1',
          content: {'title': 'Old title', 'body': 'Old body.', 'order': 5},
        );
        await LessonWorkflow(db).restoreVersion(r, old, uid: 'w1');
        final d = (await _data(db, 'a'))!;
        expect(d['body'], 'Old body.');
        expect(d['title'], 'Old title');
        expect(d['order'], 20, reason: 'restoring never moves the item');
        expect(await _versions(db, 'a'), 1);
      },
    );
  });
}
