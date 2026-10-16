import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/features/waec_exam_setup_screen.dart';

/// Plan v2 6.4: "Sit this paper" on a static year page opens setup on
/// that year (`/waec/mathematics/setup?from=2018&to=2018`).
void main() {
  (int, int)? preset(int? a, int? b) =>
      presetYearRange(a, b, minYear: 1990, maxYear: 2025);

  test('one year', () => expect(preset(2018, 2018), (2018, 2018)));
  test('a range, either order', () {
    expect(preset(2015, 2018), (2015, 2018));
    expect(preset(2018, 2015), (2015, 2018));
  });
  test('only one end given', () => expect(preset(2018, null), (2018, 2018)));
  test(
    'clamped to the subject',
    () => expect(preset(1980, 2030), (1990, 2025)),
  );
  test('years the subject lacks entirely are ignored', () {
    expect(preset(1970, 1980), isNull);
    expect(preset(2030, 2031), isNull);
  });
  test('CONTROL: no years asked for keeps the default', () {
    expect(preset(null, null), isNull);
  });
}
