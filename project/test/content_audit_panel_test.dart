import 'package:flutter_test/flutter_test.dart';
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
}
