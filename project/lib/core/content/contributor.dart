import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Who wrote a lesson, shown to students as a byline (PLAN.md P7.5).
///
/// `contributors/{uid}`: `{displayName, role, credential}`. **Written only
/// by an admin** (`tools/admin/set_contributor.js`), after the person has
/// agreed and the owner has checked any credential line ("A1 Mathematics,
/// WASSCE 2025" is self-declared until then). Readable by anyone signed
/// in, because bylines are public. No byline without a document: the
/// studio's private `staffProfiles` are never shown to students.
class Contributor {
  const Contributor({
    required this.displayName,
    required this.role,
    this.credential = '',
  });

  final String displayName;

  /// `student`, `teacher` or `team`.
  final String role;
  final String credential;

  String get byline =>
      credential.isEmpty ? 'By $displayName' : 'By $displayName · $credential';

  factory Contributor.fromFirestore(DocumentSnapshot doc) {
    final d = docData(doc);
    return Contributor(
      displayName: asString(d['displayName']),
      role: asString(d['role'], fallback: 'team'),
      credential: asString(d['credential']),
    );
  }
}

/// The byline for [uid], or null. Kept alive: the same few writers wrote
/// every lesson, so each is read once a session.
final contributorProvider = FutureProvider.family<Contributor?, String>((
  ref,
  uid,
) async {
  ref.keepAlive();
  if (uid.isEmpty) return null;
  try {
    final s = await FirebaseFirestore.instance
        .collection('contributors')
        .doc(uid)
        .get()
        .metered();
    if (!s.exists) return null;
    final c = Contributor.fromFirestore(s);
    return c.displayName.trim().isEmpty ? null : c;
  } on FirebaseException {
    return null;
  }
});

/// "By Ada O. · A1 Mathematics, WASSCE 2025" under a lesson's title, or
/// nothing.
class ContributorByline extends ConsumerWidget {
  const ContributorByline({super.key, required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = uid;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final c = ref.watch(contributorProvider(id)).asData?.value;
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        c.byline,
        style: AppTheme.caption.copyWith(color: context.palette.textSecondary),
      ),
    );
  }
}
