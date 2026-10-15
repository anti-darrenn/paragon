import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import 'quota_status.dart';

/// Reports uncaught errors from production as an `app_error` analytics
/// event, so a crash on a phone nobody on the team owns is not invisible.
///
/// Flutter web has no Crashlytics, and before this the only sign of a
/// broken screen in production was students quietly leaving.
///
/// **What is sent is deliberately thin**, because error messages can carry
/// things a student typed: the error's type (`TypeError`,
/// `FirebaseException`), a Firebase error code when there is one, and the
/// screen's route pattern. Never the message, never the stack. That is
/// enough to see "TypeError on /waec/:subjectId/exam, 40 times since
/// Tuesday" and go and look; it is not enough to debug from, and is not
/// meant to be.
///
/// The same key is reported at most once per session, and at most
/// [_maxPerSession] keys in all, so a broken build rendering an error per
/// frame cannot flood analytics.
///
/// The opt-out is honoured, as for every event (see [Analytics]).
class ErrorReporter {
  ErrorReporter(this._report);

  final void Function({required String kind, required String screen}) _report;

  static const _maxPerSession = 10;
  final Set<String> _sent = {};

  /// The route pattern of the current screen, set by the analytics binding.
  /// A route pattern, never a URL: no document ids leave the device.
  static String screen = '(start)';

  void report(Object error) {
    QuotaStatus.instance.noteError(error);
    final kind = errorKind(error);
    final key = '$kind@$screen';
    if (_sent.contains(key) || _sent.length >= _maxPerSession) return;
    _sent.add(key);
    _report(kind: kind, screen: screen);
  }

  /// Chains onto Flutter's own handlers, so errors still reach the console
  /// and the red error screen in debug.
  void install() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      report(details.exception);
      previousFlutter?.call(details);
    };
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final previousPlatform = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      report(error);
      return previousPlatform?.call(error, stack) ?? false;
    };
  }
}

/// The type of [error], plus its code for a Firebase error. Nothing taken
/// from the message.
@visibleForTesting
String errorKind(Object error) {
  if (error is FirebaseException) return '${error.plugin}/${error.code}';
  final type = error.runtimeType.toString();
  // Minified release builds name types `minified:aB`; keep it anyway, it
  // still groups identical errors together.
  return type.length > 60 ? type.substring(0, 60) : type;
}

/// Built once, for its side effect; watched by `app.dart`.
final errorReporterProvider = Provider<ErrorReporter>((ref) {
  final analytics = ref.watch(analyticsProvider);
  return ErrorReporter(analytics.appError)..install();
});
