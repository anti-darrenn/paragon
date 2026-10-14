import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/read_meter.dart';
import '../models/firestore_parsing.dart';
import '../plan/weekly_goal.dart';
import '../providers/auth_provider.dart';

/// A student's plan settings: `plan/{uid}`, `{userId, weeklyGoal, examDate,
/// updatedAt}`. Only the inputs are stored; the plan itself is computed
/// on the device (`study_plan.dart`). The subjects are the ones chosen in
/// onboarding (`selectedSubjects`), not a second copy.
///
/// Accounts only — a guest is asked to make one (`canUse(Feature.studyPlan)`).
/// Owned by uid, so it is in `deleteOwnedDocuments`, the export, `OWNED` in
/// `tools/admin/jobs.js` and the privacy policy.
class PlanSettings {
  const PlanSettings({this.weeklyGoal = kDefaultWeeklyGoal, this.examDate});

  final int weeklyGoal;

  /// The student's first WASSCE paper, if they have said.
  final DateTime? examDate;

  static const PlanSettings none = PlanSettings();

  factory PlanSettings.fromMap(Map<String, dynamic> d) {
    final goal = asInt(d['weeklyGoal'], fallback: kDefaultWeeklyGoal);
    final date = d['examDate'];
    return PlanSettings(
      weeklyGoal: kWeeklyGoals.contains(goal) ? goal : kDefaultWeeklyGoal,
      examDate: date is Timestamp ? date.toDate() : null,
    );
  }
}

class PlanRepository {
  PlanRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('plan').doc(uid);

  Stream<PlanSettings> watch(String uid) => _doc(uid).snapshots().metered().map(
    (s) => s.exists ? PlanSettings.fromMap(docData(s)) : PlanSettings.none,
  );

  /// The whole document every time: the rules pin its field set.
  Future<void> save(String uid, PlanSettings plan) => _doc(uid).set({
    'userId': uid,
    'weeklyGoal': plan.weeklyGoal,
    'examDate': plan.examDate == null
        ? null
        : Timestamp.fromDate(plan.examDate!),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepository(FirebaseFirestore.instance),
);

/// The signed-in student's plan settings; [PlanSettings.none] for guests,
/// while loading, and before they have set anything.
final planSettingsProvider = StreamProvider<PlanSettings>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || user.isAnonymous) {
    return Stream.value(PlanSettings.none);
  }
  return ref.read(planRepositoryProvider).watch(user.uid);
});
