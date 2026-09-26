import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';

/// Keeps `users/{uid}.email` in step with Firebase Auth.
///
/// Auth is the truth — it is what the student signs in with. The copy on
/// the user document goes stale when an email is changed through the
/// verify-link flow (the change happens in the student's inbox, not in
/// the app), so this writes the new one the next time the app sees it.
/// One write per real change; nothing at all while they agree.
///
/// Watched once by `app.dart`.
final accountEmailSyncProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final data = ref.watch(userDataProvider).asData?.value;
  if (user == null || user.isAnonymous || data == null) return;
  final authEmail = user.email;
  if (!emailNeedsSync(stored: data['email'], auth: authEmail)) return;
  FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .update({'email': authEmail, 'updatedAt': FieldValue.serverTimestamp()})
      .catchError((_) {});
});

/// Whether the stored copy should be replaced by [auth]. Never with
/// nothing: an Auth user without an email (possible mid-link) is not a
/// reason to erase the one on file.
bool emailNeedsSync({required Object? stored, required String? auth}) {
  if (auth == null || auth.isEmpty) return false;
  return stored != auth;
}
