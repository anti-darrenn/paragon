import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).asData?.value;
});

/// Streams the Firestore user document for the currently signed-in user.
/// Returns null if no user is signed in or the doc doesn't exist yet.
final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.asData?.value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

/// Returns the count of questions attempted this week.
/// Returns 0 until the attempts collection is populated in Session 6.
final weeklyAttemptsCountProvider = FutureProvider<int>((ref) async {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.asData?.value;
  if (user == null) return 0;

  final now = DateTime.now();
  final startOfWeek = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));

  try {
    final snap = await FirebaseFirestore.instance
        .collection('attempts')
        .where('userId', isEqualTo: user.uid)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
        )
        .get();
    return snap.docs.length;
  } catch (_) {
    // attempts collection doesn't exist yet — returns 0 silently
    return 0;
  }
});