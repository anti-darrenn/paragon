import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/firestore_parsing.dart';
import '../../../core/models/question.dart';

/// A student's own flashcards (owner's decision, 2026-10-17).
///
/// One `decks/{id}` document per deck for an account, holding every card,
/// so opening a deck is one read and saving it one write. A guest's decks
/// stay on the device (`LocalDeckStore`) and are copied up when they make
/// an account. Each card's review schedule lives with the revision cards'
/// in `study/{uid}.cards`, under [scheduleId], so "due today" works the
/// same for both.
///
/// Pure apart from the Firestore timestamp it reads; `flashcards_test.dart`
/// pins it.
class Flashcard {
  const Flashcard({required this.id, required this.front, required this.back});

  final String id;

  /// Each side is the renderers' dialect: text with maths in it.
  final String front;
  final String back;

  bool get isBlank => front.trim().isEmpty && back.trim().isEmpty;

  Map<String, String> toMap() => {'id': id, 'front': front, 'back': back};

  static Flashcard? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = asString(raw['id']);
    if (id.isEmpty) return null;
    return Flashcard(
      id: id,
      front: asString(raw['front']),
      back: asString(raw['back']),
    );
  }

  Flashcard copyWith({String? front, String? back}) =>
      Flashcard(id: id, front: front ?? this.front, back: back ?? this.back);
}

class Deck {
  const Deck({
    required this.id,
    required this.title,
    this.subjectId,
    this.cards = const [],
    this.updatedAt,
  });

  /// The most cards a deck holds; the rules hold the same cap, and it
  /// keeps one deck well inside a Firestore document.
  static const maxCards = 300;
  static const maxTitle = 80;

  /// Each side's longest text.
  static const maxSide = 2000;

  final String id;
  final String title;
  final String? subjectId;
  final List<Flashcard> cards;
  final DateTime? updatedAt;

  /// The cards worth saving or studying: not both sides empty.
  List<Flashcard> get usable => [
    for (final c in cards)
      if (!c.isBlank) c,
  ];

  Deck copyWith({String? title, String? Function()? subjectId, List<Flashcard>? cards}) =>
      Deck(
        id: id,
        title: title ?? this.title,
        subjectId: subjectId == null ? this.subjectId : subjectId(),
        cards: cards ?? this.cards,
        updatedAt: updatedAt,
      );

  /// What is stored, apart from `userId` and `updatedAt`, which the store
  /// adds.
  Map<String, Object> toMap() => {
    'title': title.trim().isEmpty ? 'Untitled deck' : title.trim(),
    'subjectId': ?subjectId,
    'cards': [for (final c in usable.take(maxCards)) c.toMap()],
  };

  static Deck fromMap(String id, Map<String, dynamic> d) {
    final at = d['updatedAt'];
    return Deck(
      id: id,
      title: asString(d['title'], fallback: 'Untitled deck'),
      subjectId: asStringOrNull(d['subjectId']),
      cards: [
        for (final raw in (d['cards'] is List ? d['cards'] as List : const []))
          ?Flashcard.fromMap(raw),
      ],
      updatedAt: at is Timestamp
          ? at.toDate()
          : at is int
          ? DateTime.fromMillisecondsSinceEpoch(at)
          : null,
    );
  }
}

/// The card's key in `study/{uid}.cards`, beside the revision cards'.
/// No `.` in it: those are map keys in a merge.
String scheduleId(String deckId, String cardId) =>
    'deck_${deckId}_$cardId'.replaceAll('.', '_');

/// A new card or deck id: short, random, never containing `.`.
String newFlashId([Random? random]) {
  final r = random ?? Random.secure();
  const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
  return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
}

/// "Quiz from my flashcards": each card's front as a question, its back
/// the right answer, and three other cards' backs as the wrong ones. Needs
/// at least four usable cards with four different backs; returns fewer
/// questions (or none) rather than repeat an option. Nothing is recorded.
List<Question> quizFromDeck(Deck deck, {Random? random, int limit = 20}) {
  final r = random ?? Random();
  final cards = deck.usable
      .where((c) => c.front.trim().isNotEmpty && c.back.trim().isNotEmpty)
      .toList();
  String norm(String s) => s.trim().toLowerCase();
  final backs = {for (final c in cards) norm(c.back)};
  if (backs.length < 4) return const [];
  final order = [...cards]..shuffle(r);
  final out = <Question>[];
  for (final c in order.take(limit)) {
    final wrong = [
      for (final o in cards)
        if (norm(o.back) != norm(c.back)) o.back,
    ];
    final seen = <String>{};
    wrong.retainWhere((w) => seen.add(norm(w)));
    if (wrong.length < 3) continue;
    wrong.shuffle(r);
    final options = [c.back, ...wrong.take(3)]..shuffle(r);
    out.add(
      Question(
        id: 'card_${c.id}',
        topicId: '',
        subjectId: deck.subjectId ?? '',
        text: c.front,
        options: options,
        correctIndex: options.indexOf(c.back),
        explanation: '',
        source: 'flashcards',
        origin: 'flashcards',
        vetted: true,
      ),
    );
  }
  return out;
}
