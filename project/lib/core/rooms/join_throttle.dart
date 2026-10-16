/// Slows down guessing at live-quiz room codes (audit G5, 2026-10-15).
///
/// Rules cannot count attempts and Spark has no server functions, so this
/// lives in the client. It is enough for what it guards: a code is six
/// characters from a 32-letter alphabet (about a billion), rooms last a
/// day, and every guess is a billed read. After [freeMisses] wrong codes,
/// each further miss doubles the wait, from 10 seconds up to 5 minutes. A
/// successful join resets it. Pure; the join screen holds one in a
/// provider for the session.
library;

class JoinThrottle {
  JoinThrottle({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  static const int freeMisses = 5;
  static const Duration firstWait = Duration(seconds: 10);
  static const Duration maxWait = Duration(minutes: 5);

  int _misses = 0;
  DateTime? _until;

  /// How long until another attempt is allowed; zero when it is now.
  Duration get wait {
    final until = _until;
    if (until == null) return Duration.zero;
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  void miss() {
    _misses++;
    if (_misses <= freeMisses) return;
    final doubled = firstWait * (1 << (_misses - freeMisses - 1).clamp(0, 10));
    _until = _now().add(doubled > maxWait ? maxWait : doubled);
  }

  void success() {
    _misses = 0;
    _until = null;
  }
}
