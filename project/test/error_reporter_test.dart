import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/data/error_reporter.dart';
import 'package:paragon/core/data/quota_status.dart';

void main() {
  late List<String> sent;
  late ErrorReporter reporter;

  setUp(() {
    sent = [];
    reporter = ErrorReporter(
      ({required kind, required screen}) => sent.add('$kind@$screen'),
    );
    ErrorReporter.screen = '/waec/:subjectId/exam';
  });

  tearDown(() => QuotaStatus.instance.noteServerSuccess());

  test('sends the type and route pattern, never the message', () {
    reporter.report(StateError('student typed: my secret answer'));
    expect(sent, ['StateError@/waec/:subjectId/exam']);
    expect(sent.single, isNot(contains('secret')));
  });

  test('a Firebase error is reported by plugin and code', () {
    reporter.report(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'uid abc123 may not read users/xyz',
      ),
    );
    expect(sent, ['cloud_firestore/permission-denied@/waec/:subjectId/exam']);
  });

  test('the same error on the same screen is sent once', () {
    for (var i = 0; i < 50; i++) {
      reporter.report(StateError('again'));
    }
    expect(sent, hasLength(1));
    // Control: a different screen is a different report.
    ErrorReporter.screen = '/';
    reporter.report(StateError('again'));
    expect(sent, hasLength(2));
  });

  test('at most ten different errors per session', () {
    for (var i = 0; i < 30; i++) {
      ErrorReporter.screen = '/screen$i';
      reporter.report(StateError('x'));
    }
    expect(sent, hasLength(10));
  });

  test('a spent quota raises the banner as well as being reported', () {
    reporter.report(
      FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted'),
    );
    expect(QuotaStatus.instance.value, isTrue);
    expect(sent.single, startsWith('cloud_firestore/resource-exhausted'));
  });
}
