import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/subject_index_repository.dart';
import '../notes/study_providers.dart' show studyDbProvider;
import 'card_deck.dart';
import 'card_store.dart';
import 'leitner.dart';

/// Failures show as "nothing reviewed yet" rather than retrying on a timer.
Duration? _noRetry(int _, Object _) => null;

/// The scheduling rules, with the real clock. Overridden in tests.
final leitnerProvider = Provider<Leitner>((ref) => Leitner());

/// The current student's card store: local for a guest, Firestore for an
/// account, none when signed out (the schedule then lives in memory).
final cardStoreProvider = Provider<CardStore?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  if (user.isAnonymous) return LocalCardStore(user.uid);
  final db = ref.watch(studyDbProvider);
  return db == null ? null : FirestoreCardStore(db, user.uid);
});

/// Every card's state for the current student, keyed by card id. Read
/// once — one document read — and then kept in step locally, so the due
/// counts on course pages cost nothing more.
class CardScheduleNotifier extends AsyncNotifier<Map<String, CardState>> {
  @override
  Future<Map<String, CardState>> build() async {
    final store = ref.watch(cardStoreProvider);
    if (store == null) return const {};
    return store.load();
  }

  /// Applies one finished session's results: the local schedule first, so
  /// the screen is right even offline, then **one** write.
  Future<void> commit(Map<String, CardState> changed) async {
    if (changed.isEmpty) return;
    state = AsyncData({...state.asData?.value ?? const {}, ...changed});
    await ref.read(cardStoreProvider)?.save(changed);
  }
}

final cardScheduleProvider =
    AsyncNotifierProvider<CardScheduleNotifier, Map<String, CardState>>(
      CardScheduleNotifier.new,
      retry: _noRetry,
    );

/// A subject's deck against the student's schedule. Null while either is
/// still loading or failed to load.
final cardDeckProvider = Provider.family<CardDeck?, String>((ref, subjectId) {
  if (subjectId.isEmpty) return null;
  final index = ref.watch(subjectIndexProvider(subjectId)).asData?.value;
  // A schedule that failed to load reads as a fresh deck: the cards are
  // still worth reviewing, and the session's write merges, so nothing
  // already stored is lost.
  final scheduleAsync = ref.watch(cardScheduleProvider);
  final schedule = scheduleAsync.hasError
      ? const <String, CardState>{}
      : scheduleAsync.asData?.value;
  if (index == null || schedule == null) return null;
  return CardDeck(
    cards: index.cards,
    schedule: schedule,
    leitner: ref.watch(leitnerProvider),
  );
});
