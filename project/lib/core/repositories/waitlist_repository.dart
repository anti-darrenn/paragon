import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../providers/auth_provider.dart';

/// "Notify me" on a coming-soon subject: `waitlist/{uid}`, one document per
/// student listing the catalog slugs they want. Accounts only (the rules
/// refuse anonymous writes) — a guest is asked to make one first.
///
/// Keyed by the catalog **slug**, not a Firestore id: a planned subject
/// has no document yet, and its slug survives it going live.
///
/// Owned by uid, so it is in `AccountRepository.deleteOwnedDocuments`, the
/// export, `OWNED` in `tools/admin/jobs.js` and the privacy policy.
class WaitlistRepository {
  WaitlistRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('waitlist').doc(uid);

  Stream<Set<String>> watch(String uid) => _doc(uid).snapshots().metered().map(
    (s) => asStringList(docData(s)['subjects']).toSet(),
  );

  /// Adds or removes [slug]. Always the whole document — the rules pin its
  /// field set and the server timestamp.
  Future<void> set(
    String uid,
    Set<String> current,
    String slug, {
    required bool wanted,
  }) {
    final next = {...current};
    wanted ? next.add(slug) : next.remove(slug);
    return _doc(uid).set({
      'userId': uid,
      'subjects': next.toList()..sort(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// How many students want [slug] — for the studio, reviewers only.
  /// One `count()` aggregate.
  Future<int> countFor(String slug) async {
    final agg = await _db
        .collection('waitlist')
        .where('subjects', arrayContains: slug)
        .count()
        .get()
        .metered();
    return agg.count ?? 0;
  }
}

final waitlistRepositoryProvider = Provider<WaitlistRepository>(
  (ref) => WaitlistRepository(FirebaseFirestore.instance),
);

/// The signed-in student's waitlist. Empty for guests and while loading.
final myWaitlistProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || user.isAnonymous) return Stream.value(const {});
  return ref.read(waitlistRepositoryProvider).watch(user.uid);
});

/// Sign-ups per planned subject slug, for the studio.
/// The waitlist key for "tell me when this subject has WAEC past papers"
/// (Plan v2 7.7), apart from the subject's own launch ([slug] alone): a
/// subject can be live for practice with no past paper to sit.
String waecPapersWaitlistKey(String slug) => 'waec-$slug';

final waitlistCountProvider = FutureProvider.family<int, String>(
  (ref, slug) => ref.read(waitlistRepositoryProvider).countFor(slug),
);
