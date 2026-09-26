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
