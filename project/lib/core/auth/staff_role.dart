/// Content-team roles, from custom claims on the Auth token.
///
/// Set only with the Admin SDK (`tools/admin/set_role.js`), never from a
/// field on `users/{uid}` — anything a client can write there, a client can
/// grant itself. This reading gates the studio **UI** only; the matching
/// `isWriter()` / `isReviewer()` in `firestore.rules` are the protection.
/// See `docs/CONTENT_ROLES.md`.
enum StaffRole {
  none,
  writer,
  reviewer,
  admin;

  /// Can open the studio, write drafts, submit for review, comment.
  bool get canWrite => index >= StaffRole.writer.index;

  /// Can publish, request changes, unpublish, delete, handle reports.
  bool get canReview => index >= StaffRole.reviewer.index;

  /// The highest role the claims grant. Only a literal `true` counts, the
  /// same test the rules make.
  static StaffRole fromClaims(Map<String, dynamic>? claims) {
    if (claims == null) return StaffRole.none;
    if (claims['admin'] == true) return StaffRole.admin;
    if (claims['reviewer'] == true) return StaffRole.reviewer;
    if (claims['writer'] == true) return StaffRole.writer;
    return StaffRole.none;
  }
}

/// A content-team role together with the subjects it covers.
///
/// A role may be limited to some subjects by the `subjects` claim (a list
/// of subject ids); no such claim means every subject, and an admin is
/// never limited — exactly as `inScope()` in `firestore.rules` reads it.
/// Outside its subjects an account can look but not change anything.
class StaffAccess {
  const StaffAccess(this.role, [this.subjects]);

  final StaffRole role;

  /// Null means every subject.
  final Set<String>? subjects;

  static const none = StaffAccess(StaffRole.none);

  bool covers(String subjectId) =>
      role == StaffRole.admin ||
      subjects == null ||
      subjects!.contains(subjectId);

  /// The role this account holds for [subjectId]: its role inside its
  /// subjects, none outside them.
  StaffRole roleIn(String subjectId) =>
      covers(subjectId) ? role : StaffRole.none;

  static StaffAccess fromClaims(Map<String, dynamic>? claims) {
    final role = StaffRole.fromClaims(claims);
    final raw = claims?['subjects'];
    if (role == StaffRole.admin || raw is! List) return StaffAccess(role);
    return StaffAccess(role, {for (final s in raw) '$s'});
  }
}
