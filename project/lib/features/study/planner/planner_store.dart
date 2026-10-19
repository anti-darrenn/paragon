import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/plan/planner.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/reading_settings_provider.dart'
    show readingPrefsProvider;

/// Where the planner is kept: this device's shared_preferences, one entry
/// per account, so two students sharing a phone each see their own week.
/// Signed out (before the auth state is known) there is no planner.
String plannerKey(String uid) => 'planner.v1.$uid';

/// The student's planner, read from and written to the device
/// (`lib/core/plan/planner.dart` has why it is not in Firestore).
class PlannerNotifier extends Notifier<Planner> {
  final _random = Random();

  String? get _uid => ref.read(currentUserProvider)?.uid;

  @override
  Planner build() {
    final prefs = ref.watch(readingPrefsProvider).asData?.value;
    final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
    if (prefs == null || uid == null) return Planner.empty;
    try {
      final raw = prefs.getString(plannerKey(uid));
      return raw == null ? Planner.empty : Planner.fromJson(jsonDecode(raw));
    } catch (_) {
      return Planner.empty;
    }
  }

  /// A fresh task id: the time and a few random letters, unique enough on
  /// one device.
  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(1 << 20).toRadixString(36)}';

  Future<void> add(PlannerTask task) => _save(state.add(task));

  Future<void> addAll(Iterable<PlannerTask> tasks) {
    var next = state;
    for (final t in tasks) {
      next = next.add(t);
    }
    return _save(next);
  }

  Future<void> remove(String id) => _save(state.remove(id));

  Future<void> toggle(String id) => _save(state.toggle(id));

  Future<void> move(String id, String day) => _save(state.move(id, day));

  Future<void> carryOver(String today) => _save(state.carryOver(today));

  Future<void> _save(Planner next) async {
    next = next.pruned(DateTime.now());
    state = next;
    final uid = _uid;
    final SharedPreferences? prefs = ref
        .read(readingPrefsProvider)
        .asData
        ?.value;
    if (prefs == null || uid == null) return;
    try {
      await prefs.setString(plannerKey(uid), jsonEncode(next.toJson()));
    } catch (_) {
      // Storage refused; the plan still holds for this session.
    }
  }
}

final plannerProvider = NotifierProvider<PlannerNotifier, Planner>(
  PlannerNotifier.new,
);
