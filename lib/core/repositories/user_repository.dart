import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserRepository {
  const UserRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> createUserIfNew(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'currentStreak': 0,
        'lastActiveDate': null,
      });
    }
  }

  Future<void> updateStreak(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastActive = data['lastActiveDate'] as String?;

    if (lastActive == today) return;

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final currentStreak = (data['currentStreak'] as num? ?? 0).toInt();

    await ref.update({
      'lastActiveDate': today,
      'currentStreak': lastActive == yesterdayStr ? currentStreak + 1 : 1,
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});