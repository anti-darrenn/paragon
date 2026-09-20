import 'package:cloud_firestore/cloud_firestore.dart';

/// Forgiving coercion for Firestore documents.
///
/// CLAUDE.md requires every `fromFirestore` to be fully null-safe. The reason
/// is the failure mode, not tidiness: a direct cast like `d['name'] as String`
/// throws on a missing or mistyped field, and because these run inside
/// `FutureProvider`/`StreamProvider` mapping, one bad document takes down the
/// whole screen rather than leaving a single gap.
///
/// Documents are not guaranteed well-formed. They are written by several
/// seeders, edited by hand in the Firebase Console, and a seeding run can be
/// interrupted part-way (the free-tier quota does exactly this). So these
/// helpers never throw: they coerce what they can and fall back otherwise.
///
/// Numbers get special treatment. Firestore returns `int` or `double`
/// depending on how a value was written, and a hand-edited field is easily
/// saved as the string "5", so both are accepted.

/// Document payload, or an empty map when the document is missing or the
/// payload is not a map. `doc.data()` returns null for a document that does
/// not exist, which a bare `as Map<String, dynamic>` would throw on.
Map<String, dynamic> docData(DocumentSnapshot doc) {
  final data = doc.data();
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return const <String, dynamic>{};
}

String asString(dynamic value, {String fallback = ''}) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

/// Null when absent or uncoercible, so callers can distinguish "no value"
/// from a real zero.
int? asIntOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? double.tryParse(value.trim())?.toInt();
  return null;
}

int asInt(dynamic value, {int fallback = 0}) => asIntOrNull(value) ?? fallback;

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return fallback;
}

/// Always a list of strings. Non-string entries are stringified rather than
/// dropped, so option positions survive — `correctIndex` is an index into
/// this list, and silently removing an entry would shift the right answer
/// onto the wrong option.
List<String> asStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((e) => e is String ? e : (e?.toString() ?? '')).toList();
}
