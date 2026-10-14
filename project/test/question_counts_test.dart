import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/content/question_counts.dart';

void main() {
  test('control: unsplit documents show the old single total', () {
    expect(const QuestionCounts(total: 14616).label, '14,616 questions');
    expect(const QuestionCounts(total: 14616).servable, 14616);
  });

  test('past and practice are shown apart, never summed', () {
    const c = QuestionCounts(past: 51, practice: 300, total: 351);
    expect(c.label, '51 past · 300 practice');
    expect(c.label, isNot(contains('351')));
  });

  test('a side with none is left out', () {
    expect(
      const QuestionCounts(practice: 12900).label,
      '12,900 practice questions',
    );
    expect(const QuestionCounts(past: 48).label, '48 past questions');
    expect(const QuestionCounts().label, isEmpty);
  });

  test('sums add each side, so a course is the sum of its topics', () {
    const a = QuestionCounts(past: 1, practice: 300, total: 301);
    const b = QuestionCounts(past: 2, practice: 300, total: 302);
    final s = a + b;
    expect((s.past, s.practice, s.total), (3, 600, 603));
    expect(s.servable, 603);
  });

  test('groupThousands', () {
    expect(groupThousands(14602), '14,602');
    expect(groupThousands(999), '999');
    expect(groupThousands(1000000), '1,000,000');
  });
}
