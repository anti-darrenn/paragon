import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/admin_flag_repository.dart';
import 'package:paragon/core/repositories/flag_repository.dart';

void main() {
  test('a lesson report is filed against the item, not a question', () async {
    final db = FakeFirebaseFirestore();
    await FlagRepository(db).createLessonReport(
      userId: 'u1',
      topicId: 't1',
      resourceId: 'bases-intro',
      reason: LessonReportReason.mistake,
    );
    final d = (await db.collection('flags').get()).docs.single.data();
    expect(d['resourceId'], 'bases-intro');
    expect(d['topicId'], 't1');
    expect(d['reason'], 'lesson_mistake');
    expect(d.containsKey('questionId'), isFalse);
  });

  test('lesson and question reports each reach their own queue', () async {
    final db = FakeFirebaseFirestore();
    final flags = FlagRepository(db);
    await flags.createLessonReport(
      userId: 'u1',
      topicId: 't1',
      resourceId: 'r1',
      reason: LessonReportReason.unclear,
    );
    await flags.create(
      userId: 'u1',
      questionId: 'q1',
      reason: FlagReason.wrongAnswer,
    );

    final admin = AdminFlagRepository(db);
    final lesson = await admin.lessonReports();
    expect(lesson.map((r) => r.resourceId), ['r1']);
    // Control: the question queue is untouched by the lesson report.
    final questions = await admin.queue();
    expect(questions.map((q) => q.questionId), ['q1']);
  });

  test('a resolved lesson report leaves the list', () async {
    final db = FakeFirebaseFirestore();
    await FlagRepository(db).createLessonReport(
      userId: 'u1',
      topicId: 't1',
      resourceId: 'r1',
      reason: LessonReportReason.video,
    );
    final admin = AdminFlagRepository(db);
    final report = (await admin.lessonReports()).single;
    await admin.resolveLessonReport(
      report,
      status: FlagStatus.fixed,
      uid: 'rev',
    );
    expect(await admin.lessonReports(), isEmpty);
    final d = (await db.collection('flags').doc(report.id).get()).data()!;
    expect(d['status'], 'fixed');
    expect(d['resolvedBy'], 'rev');
  });
}
