import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/rooms/join_throttle.dart';

void main() {
  late DateTime now;
  JoinThrottle make() => JoinThrottle(clock: () => now);
  setUp(() => now = DateTime(2026, 10, 15, 12));

  test('the first wrong codes are free', () {
    final t = make();
    for (var i = 0; i < JoinThrottle.freeMisses; i++) {
      t.miss();
    }
    expect(t.wait, Duration.zero);
  });

  test('each miss after that doubles the wait, up to five minutes', () {
    final t = make();
    for (var i = 0; i < JoinThrottle.freeMisses + 1; i++) {
      t.miss();
    }
    expect(t.wait, const Duration(seconds: 10));
    t.miss();
    expect(t.wait, const Duration(seconds: 20));
    for (var i = 0; i < 10; i++) {
      t.miss();
    }
    expect(t.wait, JoinThrottle.maxWait);
  });

  test('the wait runs out with time, and a join resets it', () {
    final t = make();
    for (var i = 0; i < JoinThrottle.freeMisses + 1; i++) {
      t.miss();
    }
    now = now.add(const Duration(seconds: 11));
    expect(t.wait, Duration.zero);
    t.success();
    t.miss();
    expect(t.wait, Duration.zero, reason: 'control: back to free misses');
  });
}
