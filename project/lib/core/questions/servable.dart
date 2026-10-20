import 'package:cloud_firestore/cloud_firestore.dart';

/// What a student may be shown, said once.
///
/// A question reaches students only when it has a verified answer
/// (`hasAnswer`) **and the founder has vetted it** (`vetted`, owner's
/// decision 2026-10-17: everything pending, enforced on deploy). Every
/// student-facing query goes through [servable]; questions loaded by id go
/// through [isServable]. The composite indexes in `firestore.indexes.json`
/// carry `vetted` after `hasAnswer` for each query shape.
extension ServableQuestions<T> on Query<T> {
  Query<T> servable() => where(
    'hasAnswer',
    isEqualTo: true,
  ).where('vetted', isEqualTo: true);
}

/// The same test for a question document's data, for paths that load by
/// id (rooms, challenge links, the mistakes notebook, pinned exercises,
/// bookmarks): an unvetted or retired question is dropped.
bool isServable(Map<String, dynamic>? data) =>
    data != null && data['hasAnswer'] == true && data['vetted'] == true;

/// The `vettedBy` of questions passed by the bulk check
/// (`tools/admin/vet_bank.js`, owner's decision 2026-10-19) rather than by a
/// person. It names no account, so the studio shows it as the automatic
/// check, and `vet_bank.js --revert` finds them all by it.
const String kBulkVetTag = 'claude-check';
