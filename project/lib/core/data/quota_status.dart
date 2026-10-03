import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Whether Firestore has refused us for running out of daily quota.
///
/// The project is on the free Spark plan (50k reads, 20k writes a day for
/// all students together). When either runs out, every request fails with
/// `resource-exhausted` until the quota day resets at midnight Pacific
/// time. Without this, students would see "check your connection" on a
/// connection that is fine, and try again, and again.
///
/// Set by `metered()` (every read in `lib/` goes through it) and by the
/// app-wide error handler (writes that fail unhandled). Cleared by the next
/// read the server answers, so the banner goes away by itself.
class QuotaStatus extends ValueNotifier<bool> {
  QuotaStatus._() : super(false);

  static final QuotaStatus instance = QuotaStatus._();

  /// Marks the quota as spent if [error] says so. Returns whether it did.
  bool noteError(Object error) {
    if (!isQuotaError(error)) return false;
    value = true;
    return true;
  }

  void noteServerSuccess() {
    if (value) value = false;
  }
}

bool isQuotaError(Object error) =>
    error is FirebaseException && error.code == 'resource-exhausted';

/// When Firestore's quota day next starts: midnight in
/// America/Los_Angeles, returned in UTC.
///
/// Computed by hand rather than with a time-zone database, which would be
/// a large download for one date. US daylight saving runs from 2am on the
/// second Sunday of March to 2am on the first Sunday of November; inside
/// it Pacific time is UTC-7, outside UTC-8. Midnight is never inside a
/// switch-over hour, so the rule only has to be right per calendar day.
DateTime quotaResetUtc(DateTime now) {
  final utc = now.toUtc();
  final pacificNow = utc.add(Duration(hours: _pacificOffsetHours(utc)));
  final tomorrow = DateTime.utc(
    pacificNow.year,
    pacificNow.month,
    pacificNow.day + 1,
  );
  return tomorrow.add(Duration(hours: _isPacificDst(tomorrow) ? 7 : 8));
}

/// Pacific time's offset from UTC at an instant. Daylight time starts at
/// 2am PST (10:00 UTC) and ends at 2am PDT (09:00 UTC).
int _pacificOffsetHours(DateTime utc) {
  final start = _nthSunday(
    utc.year,
    DateTime.march,
    2,
  ).add(const Duration(hours: 10));
  final end = _nthSunday(
    utc.year,
    DateTime.november,
    1,
  ).add(const Duration(hours: 9));
  return !utc.isBefore(start) && utc.isBefore(end) ? -7 : -8;
}

/// Whether a Pacific calendar day (given as a UTC-midnight date) is a
/// daylight-saving day at midnight.
bool _isPacificDst(DateTime day) {
  final start = _nthSunday(day.year, DateTime.march, 2);
  final end = _nthSunday(day.year, DateTime.november, 1);
  // Midnight of the start day is still standard time; midnight of the end
  // day is still daylight time.
  return day.isAfter(start) && !day.isAfter(end);
}

DateTime _nthSunday(int year, int month, int n) {
  final first = DateTime.utc(year, month, 1);
  final toSunday = (DateTime.sunday - first.weekday) % 7;
  return DateTime.utc(year, month, 1 + toSunday + 7 * (n - 1));
}
