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
}
