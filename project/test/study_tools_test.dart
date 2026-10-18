import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/question.dart';
import 'package:paragon/core/questions/difficulty.dart';
import 'package:paragon/features/study/flashcards/deck.dart';
import 'package:paragon/features/study/quiz/custom_quiz_screen.dart';

Question _q(String id, String topic, {String text = 'Q', int? level}) =>
    Question(
      id: id,
      topicId: topic,
      subjectId: 's1',
      text: '$text $id',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 0,
      explanation: '',
      source: 'drill',
      difficulty: level,
      vetted: true,
    );

/// The Study tab's own tools (owner's request, 2026-10-17): flashcards,
/// a quiz from them, and a custom quiz over any mix of topics.
void main() {
  group('flashcards', () {
    Deck deck(int n, {bool sameBacks = false}) => Deck(
      id: 'd1',
      title: 'Indices',
      cards: [
        for (var i = 0; i < n; i++)
          Flashcard(
            id: 'c$i',
            front: r'\(a^0\) ' '$i',
            back: sameBacks ? '1' : 'answer $i',
          ),
      ],
    );

    test('a quiz from a deck: the front asks, the back is right', () {
      final qs = quizFromDeck(deck(6), random: Random(1));
      expect(qs, hasLength(6));
      for (final q in qs) {
        expect(q.options, hasLength(4));
        expect(q.options.toSet(), hasLength(4), reason: 'no repeated option');
        final card = deck(6).cards.firstWhere((c) => 'card_${c.id}' == q.id);
        expect(q.options[q.correctIndex], card.back);
        expect(q.provenanceLabel, 'Your flashcards');
      }
    });

    test('CONTROL: too few different answers makes no quiz', () {
      expect(quizFromDeck(deck(3)), isEmpty);
      expect(quizFromDeck(deck(8, sameBacks: true)), isEmpty);
    });

    test('blank cards are not saved; the deck caps at 300', () {
      final d = Deck(
        id: 'd',
        title: '  ',
        cards: [
          const Flashcard(id: 'a', front: 'x', back: 'y'),
          const Flashcard(id: 'b', front: ' ', back: ''),
          for (var i = 0; i < 400; i++)
            Flashcard(id: 'n$i', front: 'f', back: 'b'),
        ],
      );
      final m = d.toMap();
      expect((m['cards'] as List), hasLength(Deck.maxCards));
      expect(m['title'], 'Untitled deck');
    });

    test('a schedule id never holds a dot (it is a map key in a merge)', () {
      expect(scheduleId('a.b', 'c.d'), 'deck_a_b_c_d');
    });

    test('a deck reads back as written', () {
      final d = Deck.fromMap('d1', {
        'title': 'Logs',
        'subjectId': 's1',
        'cards': [
          {'id': 'c1', 'front': 'log 1', 'back': '0'},
          'not a card',
          {'front': 'no id'},
        ],
      });
      expect(d.cards.single.front, 'log 1');
      expect(d.subjectId, 's1');
    });
  });

  group('custom quiz', () {
    test('spreads across the chosen topics in turn', () {
      final pools = [
        [for (var i = 0; i < 20; i++) _q('a$i', 'tA', text: 'Alpha $i')],
        [for (var i = 0; i < 20; i++) _q('b$i', 'tB', text: 'Beta $i')],
      ];
      final qs = buildCustomQuiz(pools, length: 10, random: Random(2));
      expect(qs, hasLength(10));
      expect(qs.where((q) => q.topicId == 'tA'), hasLength(5));
    });

    test('a chosen difficulty keeps only that tier', () {
      final pools = [
        [
          _q('e', 't', level: 1),
          _q('s', 't', level: 4),
          _q('s2', 't', level: 4),
        ],
      ];
      final qs = buildCustomQuiz(
        pools,
        length: 10,
        tier: DifficultyTier.spicy,
      );
      expect(qs.map((q) => q.id).toSet(), {'s', 's2'});
    });

    test('mastery only for topics whose drill is open (never past a test)', () {
      final results = [
        (question: _q('1', 'open'), selected: 0, correct: true),
        (question: _q('2', 'open'), selected: 1, correct: false),
        (question: _q('3', 'locked'), selected: 0, correct: true),
      ];
      final sessions = quizMasterySessions(
        results,
        isOpen: (t) => t == 'open',
      );
      expect(sessions, hasLength(1));
      expect(sessions.single.topicId, 'open');
      expect(sessions.single.answered, 2);
      expect(sessions.single.correct, 1);
    });

    test('CONTROL: with every topic open, every topic counts', () {
      final results = [
        (question: _q('1', 'a'), selected: 0, correct: true),
        (question: _q('2', 'b'), selected: 0, correct: true),
      ];
      expect(quizMasterySessions(results, isOpen: (_) => true), hasLength(2));
    });
  });
}
