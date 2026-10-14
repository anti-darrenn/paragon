import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/router/return_to.dart';

void main() {
  test('control: an app path is kept, query and all', () {
    expect(safeNextPath('/waec/abc/setup'), '/waec/abc/setup');
    expect(
      safeNextPath('/subject/s1/course/topic/t1?x=1'),
      '/subject/s1/course/topic/t1?x=1',
    );
  });

  test('nothing to return to: empty, root, or the sign-in pages', () {
    for (final p in [
      null,
      '',
      '/',
      '/welcome',
      '/signin',
      '/account/upgrade',
    ]) {
      expect(safeNextPath(p), isNull, reason: '$p');
    }
  });

  test('never another site (no open redirect)', () {
    for (final p in [
      'https://evil.example',
      '//evil.example/x',
      r'/\evil.example',
      'evil.example',
      '/x?u=https://evil.example',
    ]) {
      expect(safeNextPath(p), isNull, reason: p);
    }
  });

  test('welcomeWith carries the page, or nothing', () {
    expect(
      welcomeWith(Uri.parse('/waec/abc/setup')),
      '/welcome?next=%2Fwaec%2Fabc%2Fsetup',
    );
    expect(welcomeWith(Uri.parse('/')), '/welcome');
  });
}
