import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'quota_status.dart';

/// Counts billed Firestore reads per screen, in debug builds only.
///
/// Firestore is on the free Spark plan: 50k reads a day for every student
/// together, and when they run out the app stops working for everyone
/// until the Pacific-time quota day resets. "How many students per day can
/// we serve" is reads-per-session divided into 50k, so the number has to be
/// measured per flow, not guessed. `docs/audit/QUOTA.md` holds the results.
///
/// Every Firestore read in `lib/` ends in `.metered()`. **Keep it that way
/// for new reads**: besides counting (debug builds only), it is how the app
/// notices a spent quota in production and says so (`QuotaStatus`).
///
/// What counts, following Firestore's billing:
/// - a document or query result served by the **server**: one read per
///   document returned, and one for a query that returns nothing;
/// - a listener: the documents in each server snapshot's `docChanges`
///   (the first snapshot is all of them, later ones only what changed);
/// - a `count()`: one read per 1000 index entries, counted here as one,
///   which is exact for every count the app runs today (each is per
///   student or per topic, well under 1000).
///
/// Results served from the local cache are not billed and not counted.
class ReadMeter extends ChangeNotifier {
  ReadMeter._();

  static final ReadMeter instance = ReadMeter._();

  /// Whether to print a line per read. Off by default so tests stay quiet;
  /// `main.dart` turns it on in debug builds.
  bool logging = false;

  String _screen = '(start)';
  final Map<String, int> _byScreen = {};
  int _total = 0;

  String get screen => _screen;
  int get total => _total;
  int get onScreen => _byScreen[_screen] ?? 0;
  Map<String, int> get byScreen => Map.unmodifiable(_byScreen);

  /// Called with the route pattern on every navigation (see
  /// `analytics_binding.dart`), so reads are filed under the screen that
  /// caused them. A read still in flight when the student moves on is
  /// filed under the new screen; at human navigation speeds that is rare.
  void enter(String screen) {
    if (!kDebugMode) return;
    _screen = screen;
    notifyListeners();
  }

  void add(int reads, String what) {
    if (!kDebugMode || reads <= 0) return;
    _total += reads;
    _byScreen[_screen] = (_byScreen[_screen] ?? 0) + reads;
    if (logging) {
      debugPrint('[reads] +$reads $what  ($_screen: $onScreen, total $_total)');
    }
    notifyListeners();
  }

  void reset() {
    _total = 0;
    _byScreen.clear();
    notifyListeners();
  }

  /// A table to paste into `docs/audit/QUOTA.md`.
  String report() {
    final rows = _byScreen.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      '| Screen | Reads |',
      '| --- | ---: |',
      for (final r in rows) '| `${r.key}` | ${r.value} |',
      '| **Total** | **$_total** |',
    ].join('\n');
  }
}

int _queryReads<T>(QuerySnapshot<T> s) => s.docs.isEmpty ? 1 : s.docs.length;

/// Runs in every build, not just debug: a spent quota is a production
/// concern (see [QuotaStatus]). Counting is debug-only, inside
/// [ReadMeter.add].
void _served(SnapshotMetadata metadata, int reads, String what) {
  if (metadata.isFromCache) return;
  QuotaStatus.instance.noteServerSuccess();
  ReadMeter.instance.add(reads, what);
}

Never _failed(Object error, StackTrace stack) {
  QuotaStatus.instance.noteError(error);
  Error.throwWithStackTrace(error, stack);
}

extension MeteredQueryGet<T> on Future<QuerySnapshot<T>> {
  Future<QuerySnapshot<T>> metered() => then((s) {
    _served(s.metadata, _queryReads(s), 'query');
    return s;
  }, onError: _failed);
}

extension MeteredDocGet<T> on Future<DocumentSnapshot<T>> {
  Future<DocumentSnapshot<T>> metered() => then((s) {
    _served(s.metadata, 1, 'doc ${s.reference.parent.id}');
    return s;
  }, onError: _failed);
}

/// Aggregate results carry no metadata; a `count()` is always answered by
/// the server.
extension MeteredCount on Future<AggregateQuerySnapshot> {
  Future<AggregateQuerySnapshot> metered() => then((s) {
    QuotaStatus.instance.noteServerSuccess();
    ReadMeter.instance.add(1, 'count');
    return s;
  }, onError: _failed);
}

extension MeteredQueryStream<T> on Stream<QuerySnapshot<T>> {
  Stream<QuerySnapshot<T>> metered() {
    var first = true;
    return transform(
      StreamTransformer.fromHandlers(
        handleData: (s, sink) {
          final n = s.docChanges.length;
          // An empty result still costs one read, but only the first
          // time: a later snapshot with no changes is a metadata update.
          if (!s.metadata.isFromCache) {
            _served(s.metadata, first && n == 0 ? 1 : n, 'listen');
            first = false;
          }
          sink.add(s);
        },
        handleError: (error, stack, sink) {
          QuotaStatus.instance.noteError(error);
          sink.addError(error, stack);
        },
      ),
    );
  }
}

extension MeteredDocStream<T> on Stream<DocumentSnapshot<T>> {
  Stream<DocumentSnapshot<T>> metered() => transform(
    StreamTransformer.fromHandlers(
      handleData: (s, sink) {
        _served(s.metadata, 1, 'listen ${s.reference.parent.id}');
        sink.add(s);
      },
      handleError: (error, stack, sink) {
        QuotaStatus.instance.noteError(error);
        sink.addError(error, stack);
      },
    ),
  );
}
