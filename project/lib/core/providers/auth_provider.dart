import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/user_repository.dart';
import '../auth/staff_role.dart';

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

/// Starts a guest session via Firebase Anonymous Auth. An anonymous user
/// is a real UID — the same users/{uid} doc shape, the same Firestore
/// rules, the same attempts-write path as a fully signed-in user. This
/// does not link to a real account later; tapping a sign-in entry point
/// while anonymous starts a fresh real-account session instead (no
/// migration in this pass — see docs/audit/NEXT.md).
Future<User?> signInAnonymously(WidgetRef ref) async {
  final userCredential = await FirebaseAuth.instance.signInAnonymously();
  final user = userCredential.user;
  if (user != null) {
    await ref.read(userRepositoryProvider).createUserIfNew(user);
  }
  return user;
}

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).asData?.value;
});

/// The current ID token's decoded result, re-emitted on every token
/// refresh. Custom claims live here and nowhere else in the client.
///
/// A claim granted to an account that is already signed in does not
/// appear until its token refreshes (about an hour) or it signs in again.
final idTokenResultProvider = StreamProvider<IdTokenResult?>((ref) {
  return FirebaseAuth.instance.idTokenChanges().asyncMap(
    (user) => user?.getIdTokenResult(),
  );
});

/// The signed-in account's content-team role (writer, reviewer, admin), or
/// [StaffRole.none]. UI gating only — the rules re-check the same claims.
/// [StaffRole.none] while the token is still loading.
final staffRoleProvider = Provider<StaffRole>((ref) {
  final result = ref.watch(idTokenResultProvider).asData?.value;
  return StaffRole.fromClaims(result?.claims);
});

/// True while the current user is a guest (anonymous auth), false once
/// signed in with a real account, false while signed out entirely.
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAnonymous ?? false;
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

/// Number of questions attempted this week.
///
/// A `count()` aggregate, not a snapshot listener. The previous version
/// streamed every matching attempt document and returned `docs.length` —
/// so a daily user, generating roughly 140 documents a week, re-downloaded
/// all of them on every visit to the dashboard, live, to display a single
/// integer. The read cost scaled with exactly the engagement we want, and
/// the dashboard is now the landing page.
///
/// `waecAvailableCountProvider` already used this aggregate; this brings
/// the dashboard in line. A count() transfers a number, never the
/// documents.
///
/// The trade is that it no longer updates live. That is fine here: the
/// figure is a weekly total on a dashboard, and it refreshes whenever the
/// provider is invalidated or the screen is revisited.
final weeklyAttemptsCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return 0;

  final now = DateTime.now();
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  final aggregate = await FirebaseFirestore.instance
      .collection('attempts')
      .where('userId', isEqualTo: user.uid)
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
      .count()
      .get();

  return aggregate.count ?? 0;
});


/// The catalog slugs the user picked during onboarding.
///
/// Empty for a guest, for a signed-out visitor, or for anyone who has not
/// reached the subject step yet — callers must treat empty as "no
/// preference expressed" and show everything, never as "wants nothing".
final selectedSubjectSlugsProvider = Provider<Set<String>>((ref) {
  final data = ref.watch(userDataProvider).asData?.value;
  final raw = data?['selectedSubjects'];
  if (raw is! List) return const <String>{};
  return raw.whereType<String>().toSet();
});
