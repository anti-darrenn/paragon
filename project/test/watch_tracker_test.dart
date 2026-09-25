import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/learn/watch_tracker.dart';

/// Plays [from]..[to] in half-second ticks, as the player reports it.
void play(WatchTracker t, double from, double to) {
  for (var s = from; s <= to + 1e-9; s += 0.5) {
    t.onPosition(s);
  }
}

void main() {
  test('watching 90% continuously completes it', () {
    final t = WatchTracker(durationSeconds: 100);
    play(t, 0, 90);
    expect(t.isComplete, isTrue);
  });

  test('control: 80% watched is not complete', () {
    final t = WatchTracker(durationSeconds: 100);
    play(t, 0, 80);
    expect(t.isComplete, isFalse);
  });

  test('seeking to the end earns nothing', () {
    final t = WatchTracker(durationSeconds: 100);
    play(t, 0, 5);
    t.onPosition(99);
    play(t, 99, 100);
    t.onEnded();
    expect(t.watchedSeconds, closeTo(6, 0.01));
    expect(t.isComplete, isFalse);
  });

  test('seeking back does not double-count or subtract', () {
    final t = WatchTracker(durationSeconds: 100);
    play(t, 0, 50);
    t.onPosition(10);
    expect(t.watchedSeconds, closeTo(50, 0.01));
  });

  test('ended after at least half watched completes it', () {
    final t = WatchTracker(durationSeconds: 100);
    t.onPosition(40);
    play(t, 40, 100);
    t.onEnded();
    expect(t.isComplete, isTrue);
  });

  test('control: ended with under half watched does not', () {
    final t = WatchTracker(durationSeconds: 100);
    t.onPosition(60);
    play(t, 60, 100);
    t.onEnded();
    expect(t.isComplete, isFalse);
  });

  test('no known duration never completes', () {
    final t = WatchTracker();
    play(t, 0, 500);
    t.onEnded();
    expect(t.isComplete, isFalse);
  });

  test("the player's duration replaces the authored one", () {
    final t = WatchTracker(durationSeconds: 1000)..durationSeconds = 100;
    play(t, 0, 90);
    expect(t.isComplete, isTrue);
  });

  test('a zero or missing player duration keeps the authored one', () {
    final t = WatchTracker(durationSeconds: 100)
      ..durationSeconds = 0
      ..durationSeconds = null;
    expect(t.durationSeconds, 100);
  });
}
