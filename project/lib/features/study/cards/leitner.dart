/// Leitner scheduling for revision cards. Pure Dart, with an injectable
/// clock, so every rule here is testable without a widget or a database.
///
/// Five boxes. A card in box n comes back after [Leitner.intervalDays]
/// `[n-1]` days. "Knew it" moves a card up one box (capped at the last);
/// "Didn't know" sends it back to box 1, due tomorrow. A card the student
/// has never reviewed has no state at all, counts as box 1, and is due now.
///
/// **Revision only.** Nothing here feeds mastery, progress or attempts:
/// a card a student marks "knew it" proves nothing to anyone but them.
library;

/// One card's place in the schedule.
class CardState {
  const CardState({required this.box, required this.due});

  /// 1 to [Leitner.boxes].
  final int box;

  /// The start of the day the card is next due.
  final DateTime due;

  @override
  bool operator ==(Object other) =>
      other is CardState && other.box == box && other.due == due;

  @override
  int get hashCode => Object.hash(box, due);

  @override
  String toString() => 'CardState(box: $box, due: $due)';
}

class Leitner {
  Leitner({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const int boxes = 5;

  /// Days until a card in box 1…5 is due again.
  static const List<int> intervalDays = [1, 2, 4, 8, 16];

  DateTime now() => _clock();

  /// Midnight at the start of today, local time.
  DateTime get today {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  /// Whether a card should be reviewed now. A card with no state is new,
  /// and new cards are due.
  bool isDue(CardState? state) => state == null || !state.due.isAfter(_clock());

  /// The card's state after one review.
  CardState review(CardState? state, {required bool knew}) {
    if (!knew) return CardState(box: 1, due: _daysFromToday(1));
    // A new card starts in box 1, as every card does in a Leitner deck,
    // so knowing it first time moves it to box 2.
    final from = (state?.box ?? 1).clamp(1, boxes);
    final box = (from + 1).clamp(1, boxes);
    return CardState(box: box, due: _daysFromToday(intervalDays[box - 1]));
  }

  /// Calendar arithmetic rather than adding hours, so a daylight-saving
  /// change can never make a card due at 23:00 the day before.
  DateTime _daysFromToday(int days) {
    final t = today;
    return DateTime(t.year, t.month, t.day + days);
  }
}
