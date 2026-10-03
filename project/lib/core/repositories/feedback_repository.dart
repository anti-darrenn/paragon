import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/error_reporter.dart';
import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';

/// What a "Send feedback" message is about. The values are fixed by
/// `firestore.rules`; change both together.
enum FeedbackKind {
  idea('idea', 'An idea', 'Something you wish Paragon did'),
  problem('problem', 'A problem', "Something that broke or didn't make sense"),
  praise('praise', 'Something you like', 'What is working for you'),
  other('other', 'Something else', '');

  const FeedbackKind(this.value, this.label, this.hint);

  final String value;
  final String label;
  final String hint;

  static FeedbackKind parse(String? value) => FeedbackKind.values.firstWhere(
    (k) => k.value == value,
    orElse: () => FeedbackKind.other,
  );
}

/// The rule's cap; the sheet's counter uses it too.
const int kFeedbackMaxLength = 2000;

/// One message, as the studio sees it. A missing `status` means open, as
/// for `flags`.
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.userId,
    required this.kind,
    required this.message,
    required this.screen,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String userId;
  final FeedbackKind kind;
  final String message;
  final String screen;
  final DateTime? createdAt;
  final String status;

  bool get isOpen => status == 'open';

  factory FeedbackItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = docData(doc);
    final created = d['createdAt'];
    return FeedbackItem(
      id: doc.id,
      userId: asString(d['userId']),
      kind: FeedbackKind.parse(asString(d['kind'])),
      message: asString(d['message']),
      screen: asString(d['screen']),
      createdAt: created is Timestamp ? created.toDate() : null,
      status: asString(d['status']).isEmpty ? 'open' : asString(d['status']),
    );
  }
}

class FeedbackRepository {
  const FeedbackRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _db.collection('feedback');

  /// Sends one message. [screen] defaults to the route pattern the student
  /// was on, which tells us what "this" in "this is confusing" means
  /// without sending a URL or any document id.
  Future<void> send({
    required String userId,
    required FeedbackKind kind,
    required String message,
    String? screen,
  }) {
    final text = message.trim();
    return _feedback.add({
      'userId': userId,
      'kind': kind.value,
      'message': text.length > kFeedbackMaxLength
          ? text.substring(0, kFeedbackMaxLength)
          : text,
      'screen': screen ?? ErrorReporter.screen,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// The most recent messages, for reviewers. Open ones are sorted first
  /// by the screen, which also counts them.
  Future<List<FeedbackItem>> recent({int limit = 100}) async {
    final snap = await _feedback
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .metered();
    return snap.docs.map(FeedbackItem.fromFirestore).toList();
  }

  Future<void> setStatus(String id, String status, String reviewerUid) {
    return _feedback.doc(id).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': reviewerUid,
    });
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(FirebaseFirestore.instance);
});

/// Reviewers' view; invalidated after a status change.
final recentFeedbackProvider = FutureProvider.autoDispose<List<FeedbackItem>>((
  ref,
) {
  return ref.watch(feedbackRepositoryProvider).recent();
});
