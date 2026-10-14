import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/rooms/room.dart';

void main() {
  test('codes use only unmistakable characters', () {
    final r = math.Random(1);
    for (var i = 0; i < 200; i++) {
      final c = newRoomCode(r);
      expect(c, hasLength(6));
      expect(c, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
    }
    // The rules' pattern and the alphabet agree, character for character.
    for (final ch in kRoomCodeAlphabet.split('')) {
      expect(RegExp(r'^[A-HJKMNP-Z2-9]$').hasMatch(ch), isTrue, reason: ch);
    }
    for (final ch in ['O', '0', 'I', '1', 'L']) {
      expect(kRoomCodeAlphabet.contains(ch), isFalse, reason: ch);
    }
  });

  test('typed codes are tidied, and nonsense is refused', () {
    expect(normaliseRoomCode(' abc-234 '), 'ABC234');
    expect(normaliseRoomCode('abc 234'), 'ABC234');
    expect(normaliseRoomCode('ABC23'), isNull);
    expect(normaliseRoomCode('ABC0I1'), isNull); // not in the alphabet
  });

  test('one point per right answer; no answer scores zero', () {
    final scores = roomScores(
      players: ['ann', 'bob', 'cy'],
      answers: [
        (uid: 'ann', index: 0, selected: 1),
        (uid: 'ann', index: 1, selected: 2),
        (uid: 'bob', index: 0, selected: 0),
        (uid: 'bob', index: 1, selected: 2),
        // Control: an answer from someone not in the room counts for no one.
        (uid: 'ghost', index: 0, selected: 1),
        // And an index past the end is ignored.
        (uid: 'ann', index: 9, selected: 0),
      ],
      correctIndexes: [1, 2],
    );
    expect(scores, {'ann': 2, 'bob': 1, 'cy': 0});
  });

  test('standings share places on a tie', () {
    final s = standings({'a': 3, 'b': 5, 'c': 3, 'd': 1});
    expect(s.map((r) => (r.uid, r.place)), [
      ('b', 1),
      ('a', 2),
      ('c', 2),
      ('d', 4),
    ]);
  });

  test('how the room split on a question', () {
    expect(
      optionCounts(
        [
          (uid: 'a', index: 0, selected: 1),
          (uid: 'b', index: 0, selected: 1),
          (uid: 'c', index: 0, selected: 3),
          (uid: 'a', index: 1, selected: 0), // another question
        ],
        0,
        4,
      ),
      [0, 2, 0, 1],
    );
    expect(answerId('u1', 3), 'u1_3');
  });
}
