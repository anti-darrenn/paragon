import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/lessons/subject_index.dart';
import 'package:paragon/features/study/cards/card_deck.dart';
import 'package:paragon/features/study/cards/leitner.dart';

/// Leitner scheduling and session choice, against a fake clock.
void main() {
  // 14:30 on a Wednesday, so "today" and "now" differ.
  var now = DateTime(2026, 9, 23, 14, 30);
  final leitner = Leitner(clock: () => now);
  DateTime day(int d) => DateTime(2026, 9, 23 + d);

  setUp(() => now = DateTime(2026, 9, 23, 14, 30));

  group('Leitner', () {
    test('a new card is due', () {
      expect(leitner.isDue(null), isTrue);
    });

    test('a card due tomorrow is not due today (control)', () {
      final s = CardState(box: 1, due: day(1));
      expect(leitner.isDue(s), isFalse);
      now = DateTime(2026, 9, 23, 23, 59);
      expect(leitner.isDue(s), isFalse);
      now = DateTime(2026, 9, 24, 0, 1);
      expect(leitner.isDue(s), isTrue);
    });

    test('a card due earlier today, or on a past day, is due', () {
      expect(leitner.isDue(CardState(box: 3, due: day(0))), isTrue);
      expect(leitner.isDue(CardState(box: 3, due: day(-5))), isTrue);
    });

    test('knowing a new card moves it to box 2, due in 2 days', () {
      expect(leitner.review(null, knew: true), CardState(box: 2, due: day(2)));
    });

    test('each "knew it" moves up one box with the interval for that box', () {
      final expected = {1: 2, 2: 4, 3: 8, 4: 16};
      expected.forEach((from, days) {
        final next = leitner.review(
          CardState(box: from, due: day(0)),
          knew: true,
        );
        expect(next.box, from + 1);
        expect(next.due, day(days), reason: 'from box $from');
      });
    });

    test('box 5 is the cap: knowing it again stays in 5, due in 16 days', () {
      final next = leitner.review(CardState(box: 5, due: day(0)), knew: true);
      expect(next, CardState(box: 5, due: day(16)));
      // A corrupt stored box above the cap is clamped, not trusted.
      expect(leitner.review(CardState(box: 9, due: day(0)), knew: true).box, 5);
    });

    test('a miss sends any card back to box 1, due tomorrow', () {
      for (final box in [1, 2, 3, 4, 5]) {
        expect(
          leitner.review(CardState(box: box, due: day(0)), knew: false),
          CardState(box: 1, due: day(1)),
        );
      }
      expect(leitner.review(null, knew: false), CardState(box: 1, due: day(1)));
    });

    test('due dates are calendar days, whatever the time of the review', () {
      now = DateTime(2026, 9, 23, 23, 59);
      expect(leitner.review(null, knew: false).due, DateTime(2026, 9, 24));
    });
  });

  group('CardDeck', () {
    IndexedCard card(String id, {String topic = 't1'}) => IndexedCard(
      id: id,
      front: 'F $id',
      back: 'B $id',
      kind: 'card',
      topicId: topic,
      resourceId: 'r',
    );

    final cards = [
      card('t1:r:a'),
      card('t1:r:b'),
      card('t2:r:c', topic: 't2'),
      card('t2:r:d', topic: 't2'),
    ];

    test('due counts new cards and overdue ones, not future ones', () {
      final deck = CardDeck(
        cards: cards,
        schedule: {
          't1:r:a': CardState(box: 2, due: day(3)), // not due
          't1:r:b': CardState(box: 1, due: day(-1)), // overdue
        },
        leitner: leitner,
      );
      expect(deck.dueCount, 3);
      // Overdue first, then new cards in lesson order.
      expect(deck.dueSession().map((c) => c.id), [
        't1:r:b',
        't2:r:c',
        't2:r:d',
      ]);
    });

    test('a review session holds at most 20 cards', () {
      final many = [for (var i = 0; i < 30; i++) card('t1:r:$i')];
      final deck = CardDeck(cards: many, schedule: const {}, leitner: leitner);
      expect(deck.dueCount, 30);
      expect(deck.dueSession(), hasLength(kCardsPerSession));
    });

    test('state for a card no longer in the index is ignored', () {
      final deck = CardDeck(
        cards: cards,
        schedule: {'gone:r:x': CardState(box: 1, due: day(-3))},
        leitner: leitner,
      );
      expect(deck.dueCount, 4);
      expect(deck.dueSession().map((c) => c.id), isNot(contains('gone:r:x')));
    });

    test('a topic session is that topic only, due cards first', () {
      final deck = CardDeck(
        cards: cards,
        schedule: {'t2:r:c': CardState(box: 3, due: day(4))},
        leitner: leitner,
      );
      expect(deck.topicSession('t2').map((c) => c.id), ['t2:r:d', 't2:r:c']);
    });
  });
}
