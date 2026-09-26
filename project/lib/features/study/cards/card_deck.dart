import '../../../core/lessons/subject_index.dart';
import 'leitner.dart';

/// Cards per session. Enough to be worth sitting down for, few enough to
/// finish on a bus.
const int kCardsPerSession = 20;

/// Which cards a session shows, in order. Pure, so the choice is testable.
///
/// Only cards in [cards] (the subject index as published now) are ever
/// considered; states for ids no longer in it are ignored.
class CardDeck {
  const CardDeck({
    required this.cards,
    required this.schedule,
    required this.leitner,
  });

  final List<IndexedCard> cards;
  final Map<String, CardState> schedule;
  final Leitner leitner;

  bool isDue(IndexedCard c) => leitner.isDue(schedule[c.id]);

  List<IndexedCard> get due => [
    for (final c in cards)
      if (isDue(c)) c,
  ];

  int get dueCount => due.length;

  /// "Review all due": cards seen before and now overdue first, most
  /// overdue first, then new cards in lesson order; at most [limit].
  List<IndexedCard> dueSession({int limit = kCardsPerSession}) {
    final seen = <IndexedCard>[];
    final fresh = <IndexedCard>[];
    for (final c in due) {
      (schedule.containsKey(c.id) ? seen : fresh).add(c);
    }
    seen.sort((a, b) => schedule[a.id]!.due.compareTo(schedule[b.id]!.due));
    return [...seen, ...fresh].take(limit).toList();
  }

  /// "Pick a topic": that topic's cards, due ones first, then the rest
  /// soonest-due first, so a student can revise a topic before a test
  /// even when nothing in it is due yet. At most [limit].
  List<IndexedCard> topicSession(
    String topicId, {
    int limit = kCardsPerSession,
  }) {
    final inTopic = [
      for (final c in cards)
        if (c.topicId == topicId) c,
    ];
    final dueFirst = [
      for (final c in inTopic)
        if (isDue(c)) c,
    ];
    final later = [
      for (final c in inTopic)
        if (!isDue(c)) c,
    ]..sort((a, b) => schedule[a.id]!.due.compareTo(schedule[b.id]!.due));
    return [...dueFirst, ...later].take(limit).toList();
  }
}
