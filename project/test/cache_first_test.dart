// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/data/cache_first.dart';

class _Meta implements SnapshotMetadata {
  _Meta(this.isFromCache);
  @override
  final bool isFromCache;
  @override
  bool get hasPendingWrites => false;
}

class _Snap implements QuerySnapshot<Map<String, dynamic>> {
  _Snap(int n, bool fromCache)
    : docs = List.generate(n, (_) => _Doc()),
      metadata = _Meta(fromCache);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Doc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Answers from "the cache" with [cacheCount] documents (or throws, when
/// null) and from "the server" with [serverCount], recording which.
class _SpyQuery implements Query<Map<String, dynamic>> {
  _SpyQuery({required this.cacheCount, required this.serverCount});
  final int? cacheCount;
  final int serverCount;
  final List<String> asked = [];

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (options?.source == Source.cache) {
      asked.add('cache');
      if (cacheCount == null) throw StateError('not cached');
      return _Snap(cacheCount!, true);
    }
    asked.add('server');
    return _Snap(serverCount, false);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _MemoryLog implements FetchLog {
  final Map<String, ({DateTime at, int count})> entries = {};
  @override
  Future<({DateTime at, int count})?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, DateTime at, int count) async =>
      entries[key] = (at: at, count: count);
}

void main() {
  final now = DateTime(2026, 10, 3, 12);
  late _MemoryLog log;

  setUp(() => log = _MemoryLog());

  Future<_SpyQuery> run({int? cache = 40, int server = 40}) async {
    final q = _SpyQuery(cacheCount: cache, serverCount: server);
    await getCacheFirst(q, key: 'topics:u1', log: log, now: () => now);
    return q;
  }

  test('first visit asks the server and remembers it', () async {
    final q = await run();
    expect(q.asked, ['server']);
    expect(log.entries['topics:u1'], (at: now, count: 40));
  });

  test('a recent server fetch is answered from the cache', () async {
    log.entries['topics:u1'] = (
      at: now.subtract(const Duration(hours: 2)),
      count: 40,
    );
    final q = await run();
    expect(q.asked, ['cache']);
  });

  test('control: an old fetch goes back to the server', () async {
    log.entries['topics:u1'] = (
      at: now.subtract(kContentMaxAge + const Duration(minutes: 1)),
      count: 40,
    );
    final q = await run();
    expect(q.asked, ['server']);
    expect(log.entries['topics:u1']!.at, now);
  });

  test('a cache missing documents (evicted) goes to the server', () async {
    log.entries['topics:u1'] = (
      at: now.subtract(const Duration(hours: 1)),
      count: 40,
    );
    final q = await run(cache: 37);
    expect(q.asked, ['cache', 'server']);
  });

  test('a cache error goes to the server', () async {
    log.entries['topics:u1'] = (
      at: now.subtract(const Duration(hours: 1)),
      count: 40,
    );
    final q = await run(cache: null);
    expect(q.asked, ['cache', 'server']);
  });

  test('a clock that moved backwards is not trusted', () {
    expect(
      isFresh((at: now.add(const Duration(hours: 1)), count: 1), now),
      isFalse,
    );
  });
}
