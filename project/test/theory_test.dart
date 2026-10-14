import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/theory/theory_question.dart';

void main() {
  const q = TheoryQuestion(
    id: 't1',
    subjectId: 's1',
    examYear: 2019,
    number: 3,
    parts: [
      TheoryPart(
        label: 'a',
        prompt: 'Factorise',
        marks: 3,
        scheme: [
          SchemeStep(description: 'Common factor', marks: 1),
          SchemeStep(description: 'Grouping', marks: 1),
          SchemeStep(description: 'Answer', marks: 1),
        ],
      ),
      TheoryPart(
        label: 'b',
        prompt: 'Solve',
        marks: 2,
        // A scheme that allows more than the part is worth.
        scheme: [
          SchemeStep(description: 'Method', marks: 2),
          SchemeStep(description: 'Answer', marks: 1),
        ],
      ),
    ],
  );

  test('self-marking adds the ticked steps', () {
    expect(q.totalMarks, 5);
    expect(selfMarked(q, {}), 0);
    expect(selfMarked(q, {(0, 0), (0, 2)}), 2);
  });

  test('a part never scores above what it is worth', () {
    expect(selfMarked(q, {(1, 0), (1, 1)}), 2);
    expect(selfMarked(q, {(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)}), 5);
  });

  test('the section stays hidden below the threshold', () {
    expect(kTheoryMinQuestions, 20);
  });
}
