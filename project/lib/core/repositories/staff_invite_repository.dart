import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/firestore_parsing.dart';

/// Requests to give someone a content-team role, and their outcome.
///
/// Roles are custom claims, and claims can only be set with the Admin SDK,
/// which never ships in the app. So the studio's Team page records the
/// request in `staffInvites/{email}` (admin-only in the rules), and
/// `tools/admin/apply_roles.js` — run every 15 minutes by the
/// notify-drafts workflow — applies it and writes back what happened.
/// One document per email: a newer request for the same person replaces
/// the older one.
enum InviteState {
  /// Waiting for the next run of the job.
  pending('pending', 'Waiting to be applied'),

  /// Applied. The person sees it after signing out and in again.
  applied('applied', 'Applied'),

  /// No account uses that email yet. The job keeps checking, so it applies
  /// as soon as they sign up.
  noAccount('no_account', 'Waiting for them to create an account'),

  /// Something went wrong; see the message.
  error('error', 'Failed');

  const InviteState(this.value, this.label);
  final String value;
  final String label;

  static InviteState parse(String? v) => InviteState.values.firstWhere(
    (s) => s.value == v,
    orElse: () => InviteState.pending,
  );
}

class StaffInvite {
  const StaffInvite({
    required this.email,
    required this.role,
    required this.subjects,
    required this.state,
    this.message = '',
    this.requestedAt,
    this.appliedAt,
  });

  final String email;

  /// `writer`, `reviewer`, or `none` (remove from the team).
  final String role;

  /// Subject ids the role is limited to. Empty means every subject.
  final List<String> subjects;
  final InviteState state;
  final String message;
  final DateTime? requestedAt;
  final DateTime? appliedAt;

  factory StaffInvite.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    DateTime? at(Object? v) => v is Timestamp ? v.toDate() : null;
    return StaffInvite(
      email: asString(d['email'], fallback: doc.id),
      role: asString(d['role'], fallback: 'none'),
      subjects: asStringList(d['subjects']),
      state: InviteState.parse(asStringOrNull(d['status'])),
      message: asString(d['message']),
      requestedAt: at(d['requestedAt']),
      appliedAt: at(d['appliedAt']),
    );
  }
}

/// The document id for an email: trimmed and lower-cased, so the same
/// person is always one request.
String inviteKey(String email) => email.trim().toLowerCase();

bool looksLikeEmail(String email) =>
    RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$').hasMatch(email.trim());

class StaffInviteRepository {
  const StaffInviteRepository(this._db);
  final FirebaseFirestore _db;

  /// Records a request; the job applies it. [subjects] empty means every
  /// subject. [role] `none` removes the person from the team.
  Future<void> request({
    required String email,
    required String role,
    required List<String> subjects,
    required String requestedBy,
  }) {
    assert(role == 'writer' || role == 'reviewer' || role == 'none');
    return _db.collection('staffInvites').doc(inviteKey(email)).set({
      'email': inviteKey(email),
      'role': role,
      'subjects': subjects,
      'status': InviteState.pending.value,
      'message': '',
      'requestedBy': requestedBy,
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> forget(String email) =>
      _db.collection('staffInvites').doc(inviteKey(email)).delete();
}

final staffInviteRepositoryProvider = Provider<StaffInviteRepository>((ref) {
  return StaffInviteRepository(FirebaseFirestore.instance);
});

/// Every request, newest first, live — so the page shows "Applied" the
/// moment the job finishes.
final staffInvitesProvider = StreamProvider<List<StaffInvite>>((ref) {
  return FirebaseFirestore.instance
      .collection('staffInvites')
      .orderBy('requestedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(StaffInvite.fromFirestore).toList());
});
