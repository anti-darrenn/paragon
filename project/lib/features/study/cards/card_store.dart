import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/firestore_parsing.dart';
import 'leitner.dart';

/// Where a student's revision-card schedule is kept.
///
/// Two implementations with one contract, as with notes:
/// [FirestoreCardStore] for an account, [LocalCardStore] for a guest.
///
/// **Quota.** [save] is called once per review session, with every card
/// that session touched — never once per card. A twenty-card session is
/// one write.
///
/// Cards whose id is no longer in the subject index are left alone: they
/// are simply never shown. Deleting them would cost a write for nothing,
/// and a lesson unpublished by mistake and published again gets its
/// schedule back.
abstract class CardStore {
  /// Every card's state, keyed by card id.
  Future<Map<String, CardState>> load();

  /// Records [changed], leaving every other card as it was.
  Future<void> save(Map<String, CardState> changed);
}

/// Parses one stored entry. Anything malformed reads as "no state", which
/// makes the card new again — the harmless direction.
CardState? _parseEntry(Object? raw) {
  if (raw is! Map) return null;
  final box = asIntOrNull(raw['box']);
  final due = raw['due'];
  DateTime? when;
  if (due is Timestamp) {
    when = due.toDate();
  } else if (due is DateTime) {
    when = due;
  } else if (due is int) {
    when = DateTime.fromMillisecondsSinceEpoch(due);
  }
  if (box == null || when == null) return null;
  return CardState(box: box.clamp(1, Leitner.boxes), due: when);
}

Map<String, CardState> _parseAll(Object? raw) {
  final out = <String, CardState>{};
  if (raw is Map) {
    raw.forEach((k, v) {
      final s = _parseEntry(v);
      if (s != null) out['$k'] = s;
    });
  }
  return out;
}

/// A signed-in student's schedule: `study/{uid}.cards`, a map of
/// `{cardId: {box, due}}`.
///
/// `study/{uid}` also holds bookmarks, so every write **merges** — a set
/// without merge would wipe them. Card ids never contain `.` (the index
/// replaces it), and a nested map in a merge is written key by key, so
/// saving a session touches only that session's cards.
class FirestoreCardStore implements CardStore {
  FirestoreCardStore(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  DocumentReference<Map<String, dynamic>> get _study =>
      _db.collection('study').doc(uid);

  @override
  Future<Map<String, CardState>> load() async {
    final snap = await _study.get();
    return _parseAll(snap.data()?['cards']);
  }

  @override
  Future<void> save(Map<String, CardState> changed) async {
    if (changed.isEmpty) return;
    await _study.set({
      'userId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'cards': {
        for (final e in changed.entries)
          e.key: {'box': e.value.box, 'due': Timestamp.fromDate(e.value.due)},
      },
    }, SetOptions(merge: true));
  }
}

/// A guest's schedule, in this browser's storage only, keyed by the
/// anonymous uid so two guests on one device keep separate decks. Never
/// reaches the server.
class LocalCardStore implements CardStore {
  LocalCardStore(this.uid, {Future<SharedPreferences?>? prefs})
    : _prefs = prefs ?? _open();

  final String uid;
  final Future<SharedPreferences?> _prefs;

  static Future<SharedPreferences?> _open() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  String get key => 'study.v1.$uid.cards';

  Map<String, CardState>? _cache;

  @override
  Future<Map<String, CardState>> load() async {
    if (_cache case final cached?) return Map.of(cached);
    final prefs = await _prefs;
    var out = <String, CardState>{};
    try {
      out = _parseAll(jsonDecode(prefs?.getString(key) ?? '{}'));
    } catch (_) {
      // Corrupt local data reads as a fresh deck.
    }
    _cache = out;
    return Map.of(out);
  }

  @override
  Future<void> save(Map<String, CardState> changed) async {
    if (changed.isEmpty) return;
    final all = {...await load(), ...changed};
    _cache = all;
    final prefs = await _prefs;
    await prefs?.setString(
      key,
      jsonEncode({
        for (final e in all.entries)
          e.key: {
            'box': e.value.box,
            'due': e.value.due.millisecondsSinceEpoch,
          },
      }),
    );
  }
}
