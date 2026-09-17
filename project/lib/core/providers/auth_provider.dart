import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/user_repository.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Runs the Google sign-in popup flow and provisions the Firestore user
/// doc on first sign-in. Shared by SignInScreen and WelcomeScreen so this
/// flow lives in exactly one place — callers handle their own
/// loading/error UI around it. Rethrows FirebaseAuthException/other
/// errors for the caller to present.
Future<User?> signInWithGoogle(WidgetRef ref) async {
  final provider = GoogleAuthProvider();
  final userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
  final user = userCredential.user;
  if (user != null) {
    await ref.read(userRepositoryProvider).createUserIfNew(user);
  }
  return user;
}

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
final weeklyAttemptsCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(0);

  final now = DateTime.now();
  final weekStart = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));

  return FirebaseFirestore.instance
      .collection('attempts')
      .where('userId', isEqualTo: user.uid)
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
      .snapshots()
      .map((snap) => snap.docs.length);
});