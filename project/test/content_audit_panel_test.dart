import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/repositories/admin_flag_repository.dart';
import 'package:paragon/features/admin/studio/launch_panels.dart';

void main() {
  group('ContentAudit.fromDocument', () {
    test('suspects rank first, then A, then B (Plan v2 2.4.2)', () {
      final a = ContentAudit.fromDocument({
        'total': 10,
        'rules': {
          'missing-explanation': {'level': 'B', 'count': 900},
          'duplicate-options': {'level': 'A', 'count': 20},
          'recurring-decimal-suspect': {'level': 'S', 'count': 1},
          'equivalent-options': {'level': 'A', 'count': 30},
        },
      })!;
      expect(a.rules.map((r) => r.rule), [
        'recurring-decimal-suspect',
        'equivalent-options',
        'duplicate-options',
        'missing-explanation',
      ]);
    });

    test('reads the suspects list, skipping rows without an id', () {
      final a = ContentAudit.fromDocument({
        'total': 1,
        'rules': <String, dynamic>{},
        'suspects': [
          {
            'id': 'J0lgjrRavaLb7ygmnU09',
            'rule': 'recurring-decimal-suspect',
            'level': 'S',
            'subject': 'Mathematics',
            'year': 2018,
            'detail': '0.612: B is 0.(612) recurring; marked A',
          },
          {'rule': 'no id'},
          'not a map',
        ],
      })!;
      expect(a.suspects, hasLength(1));
      expect(a.suspects.single.id, 'J0lgjrRavaLb7ygmnU09');
      expect(a.suspects.single.year, 2018);
    });

    test('an audit published before suspects existed still reads', () {
      final a = ContentAudit.fromDocument({
        'total': 3,
        'rules': {
          'typo': {'level': 'B', 'count': 2},
        },
      })!;
      expect(a.suspects, isEmpty);
      expect(a.rules.single.rule, 'typo');
    });
  });

  // The owner's report (2026-10-17): a question fixed in the studio stayed
  // flagged, because the flags were a snapshot taken before the fix.
  group('a fix clears its finding at once', () {
    final read = DateTime.utc(2026, 10, 16, 8, 47);
    final audit = ContentAudit.fromDocument({
      'total': 1,
      'rules': {
        'recurring-decimal-suspect': {'level': 'S', 'count': 1},
      },
      'byRule': {
        'recurring-decimal-suspect': ['q1'],
      },
      'at': Timestamp.fromDate(read.add(const Duration(hours: 20))),
      'dataAt': Timestamp.fromDate(read),
    })!;
    ReviewedQuestion q({
      DateTime? editedAt,
      List<String> dismissed = const [],
    }) => ReviewedQuestion(
      question: const Question(
        id: 'q1',
        topicId: 't',
        subjectId: 's',
        text: 'Q',
        options: ['a', 'b'],
        correctIndex: 0,
        explanation: '',
        source: 'waec',
      ),
      hasAnswer: true,
      origin: '',
      editedAt: editedAt,
      auditDismissed: dismissed,
    );
    const rule = 'recurring-decimal-suspect';

    test('CONTROL: a question nobody touched is still flagged', () {
      expect(audit.isCleared(q(), rule), isFalse);
    });
    test('saved after the audit read it: cleared', () {
      expect(
        audit.isCleared(q(editedAt: read.add(const Duration(hours: 1))), rule),
        isTrue,
      );
    });
    test('saved after the data was read, before the audit ran: cleared', () {
      // An audit from the site cache reads old data; the read time counts.
      expect(
        audit.isCleared(q(editedAt: read.add(const Duration(hours: 5))), rule),
        isTrue,
      );
    });
    test('saved before the audit read it: still flagged', () {
      expect(
        audit.isCleared(
          q(editedAt: read.subtract(const Duration(days: 1))),
          rule,
        ),
        isFalse,
      );
    });
    test('marked checked: cleared, whenever it was', () {
      expect(audit.isCleared(q(dismissed: [rule]), rule), isTrue);
      expect(audit.isCleared(q(dismissed: ['typo']), rule), isFalse);
    });
  });
}
