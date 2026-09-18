import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/repositories/attempt_repository.dart';

// Counts real batch() calls so chunking can be asserted, not just doc counts.
class _CountingFirestore extends FakeFirebaseFirestore {
  int batchCalls = 0;

  @override
  WriteBatch batch() {
    batchCalls++;
    return super.batch();
  }
}

List<AttemptDraft> _drafts(int count) => List.generate(
  count,
  (i) => AttemptDraft(
    questionId: 'q$i',
    topicId: 't1',
    subjectId: 's1',
    selectedIndex: 0,
    isCorrect: true,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttemptRepository.recordBatch', () {
    test('0 attempts writes nothing and opens no batch', () async {
      final db = _CountingFirestore();
      final repo = AttemptRepository(db);

      await repo.recordBatch(userId: 'u1', source: 'waec', attempts: []);

      expect(db.batchCalls, 0);
      final snap = await db.collection('attempts').get();
      expect(snap.docs, isEmpty);
    });

    test('450 attempts commit in exactly one batch', () async {
      final db = _CountingFirestore();
      final repo = AttemptRepository(db);

      await repo.recordBatch(
        userId: 'u1',
        source: 'waec',
        attempts: _drafts(450),
      );

      expect(db.batchCalls, 1);
      final snap = await db.collection('attempts').get();
      expect(snap.docs.length, 450);
    });

    test('451 attempts commit across exactly two batches', () async {
      final db = _CountingFirestore();
      final repo = AttemptRepository(db);

      await repo.recordBatch(
        userId: 'u1',
        source: 'waec',
        attempts: _drafts(451),
      );

      expect(db.batchCalls, 2);
      final snap = await db.collection('attempts').get();
      expect(snap.docs.length, 451);
    });
  });

  group('AttemptRepository.record', () {
    test('delegates to recordBatch with a single-element list', () async {
      final db = _CountingFirestore();
      final repo = AttemptRepository(db);

      await repo.record(
        userId: 'u1',
        questionId: 'q1',
        topicId: 't1',
        subjectId: 's1',
        selectedIndex: 2,
        isCorrect: false,
        source: 'drill',
      );

      expect(db.batchCalls, 1);
      final snap = await db.collection('attempts').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.single.data();
      expect(data['userId'], 'u1');
      expect(data['questionId'], 'q1');
      expect(data['selectedIndex'], 2);
      expect(data['isCorrect'], false);
      expect(data['source'], 'drill');
    });
  });
}
