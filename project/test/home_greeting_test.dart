import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/features/dashboard_screen.dart';

void main() {
  test('every greeting names the student and carries no emoji', () {
    // The emoji blocks: pictographs, and the older symbols and dingbats.
    final emoji = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]',
      unicode: true,
    );
    for (var i = 0; i < kHomeGreetings.length; i++) {
      final (title, subtitle) = homeGreeting('Ada', i);
      expect(title, contains('Ada'), reason: 'greeting $i');
      expect(title, isNot(contains('{name}')));
      expect(emoji.hasMatch('$title $subtitle'), isFalse, reason: title);
    }
  });

  test('CONTROL: the emoji check does catch an emoji', () {
    final emoji = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]',
      unicode: true,
    );
    expect(emoji.hasMatch('Hey, Ada 👋'), isTrue);
  });

  test('an index past the end wraps instead of throwing', () {
    expect(homeGreeting('Ada', kHomeGreetings.length), homeGreeting('Ada', 0));
  });

  test('every part of the day has its own greetings', () {
    expect(dayPartAt(7), DayPart.morning);
    expect(dayPartAt(13), DayPart.afternoon);
    expect(dayPartAt(19), DayPart.evening);
    expect(dayPartAt(23), DayPart.late);
    expect(dayPartAt(3), DayPart.late);
    for (final part in DayPart.values) {
      final (title, _) = homeGreeting('Ada', 0, part: part);
      expect(
        kHomeGreetingsByPart[part]!.first.$1.replaceAll('{name}', 'Ada'),
        title,
      );
    }
  });

  test('the tip of the day is the same all day and changes the next', () {
    expect(
      tipFor(DateTime(2026, 10, 19, 6)),
      tipFor(DateTime(2026, 10, 19, 23)),
    );
    expect(
      tipFor(DateTime(2026, 10, 19)),
      isNot(tipFor(DateTime(2026, 10, 20))),
    );
    final emoji = RegExp(
      r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]',
      unicode: true,
    );
    for (final t in kStudyTips) {
      expect(emoji.hasMatch(t), isFalse, reason: t);
    }
  });
}
