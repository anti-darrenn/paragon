import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/rooms/room.dart';

void main() {
  // `/rooms/:code` comes from the address bar, so the code never passed the
  // join screen's checks; it also names a Firestore document.
  test('anything that cannot be a code goes to /join', () {
    for (final raw in [
      '',
      'ABC',
      'ABCDEFG',
      'ABC0I1',
      '../x',
      'AB/CD2',
      '%2F',
    ]) {
      expect(roomPathRedirect(raw, '/rooms/:code'), '/join', reason: raw);
      expect(roomPathRedirect(raw, '/rooms/:code/host'), '/join', reason: raw);
    }
  });

  test('a code typed loosely is tidied', () {
    expect(roomPathRedirect('abc234', '/rooms/:code'), '/rooms/ABC234');
    expect(
      roomPathRedirect('abc-234', '/rooms/:code/host'),
      '/rooms/ABC234/host',
    );
  });

  test('control: a canonical code stays where it is', () {
    expect(roomPathRedirect('ABC234', '/rooms/:code'), isNull);
    expect(roomPathRedirect('ABC234', '/rooms/:code/host'), isNull);
  });
}
