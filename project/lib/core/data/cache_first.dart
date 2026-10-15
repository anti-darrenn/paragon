import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'read_meter.dart';

/// Reads rarely-changing content (subjects, units, topics) from the local
/// Firestore cache when the server was asked recently, instead of on every
/// app load.
///
/// Why: Spark gives every student together 50k reads a day. A course
/// outline is one units query plus one topics query per unit, 50 to 75
/// documents, and before this a returning student paid it again on every
/// visit even though the documents were already on the device
/// (persistence is on; see main.dart). Content changes when a reviewer
/// publishes, a few times a week; staleness of up to [kContentMaxAge] in a
/// topic's lesson count is a fair price for serving several times as many
/// students.
///
/// The cache is trusted only when **both** hold:
/// - this query was answered by the server less than [maxAge] ago, by this
///   browser (the time and the document count are kept in
///   SharedPreferences under [key]);
/// - the cache still returns the same number of documents. Firestore
///   evicts least-recently-used documents past the cache size, so a query
///   can come back from the cache with some documents missing; a short
///   result goes to the server rather than showing a course with holes.
///
/// Anything else, including any cache error, goes to the server exactly as
/// before. Never use this for questions, attempts, progress or anything a
/// student writes: those must be current.
const Duration kContentMaxAge = Duration(hours: 12);

/// Where the last server fetch of each query is remembered. An interface
/// so tests can run without SharedPreferences.
abstract class FetchLog {
  Future<({DateTime at, int count})?> read(String key);
  Future<void> write(String key, DateTime at, int count);
}

class PrefsFetchLog implements FetchLog {
  const PrefsFetchLog();

  static const _prefix = 'cache_first:';

  @override
  Future<({DateTime at, int count})?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final parts = raw.split('|');
      if (parts.length != 2) return null;
      final ms = int.tryParse(parts[0]);
      final count = int.tryParse(parts[1]);
      if (ms == null || count == null) return null;
      return (at: DateTime.fromMillisecondsSinceEpoch(ms), count: count);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, DateTime at, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix$key',
        '${at.millisecondsSinceEpoch}|$count',
      );
    } catch (_) {
      // Remembering is an optimisation; failing to only costs reads.
    }
  }
}

/// Whether a remembered server fetch is recent enough to trust the cache.
bool isFresh(
  ({DateTime at, int count})? last,
  DateTime now, {
  Duration maxAge = kContentMaxAge,
}) {
  if (last == null) return false;
  final age = now.difference(last.at);
  // A clock moved backwards makes the age negative; don't trust that.
  return !age.isNegative && age < maxAge;
}

Future<QuerySnapshot<T>> getCacheFirst<T>(
  Query<T> query, {
  required String key,
  FetchLog log = const PrefsFetchLog(),
  Duration maxAge = kContentMaxAge,
  DateTime Function() now = DateTime.now,
}) async {
  final last = await log.read(key);
  if (isFresh(last, now(), maxAge: maxAge)) {
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.length == last!.count) return cached;
    } catch (_) {
      // Not in the cache after all; fall through to the server.
    }
  }
  final fresh = await query.get().metered();
  if (!fresh.metadata.isFromCache) {
    await log.write(key, now(), fresh.docs.length);
  }
  return fresh;
}
