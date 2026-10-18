import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/read_meter.dart';
import '../../../core/providers/auth_provider.dart';
import '../notes/study_providers.dart' show studyDbProvider;
import 'deck.dart';

/// Where a student's flashcard decks are kept: [FirestoreDeckStore]
/// (`decks/{id}`, owner-only) for an account, [LocalDeckStore] for a guest,
/// whose anonymous account may not write (as with notes and cards).
///
/// **Quota.** Listing is one query; saving a deck is one write, made when
/// the editor is left or saved — never per keystroke.
abstract class DeckStore {
  Future<List<Deck>> list();
  Future<void> save(Deck deck);
  Future<void> delete(String deckId);
}

class FirestoreDeckStore implements DeckStore {
  FirestoreDeckStore(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _decks =>
      _db.collection('decks');

  @override
  Future<List<Deck>> list() async {
    final snap = await _decks
        .where('userId', isEqualTo: uid)
        .limit(100)
        .get()
        .metered();
    final decks = [for (final d in snap.docs) Deck.fromMap(d.id, d.data())];
    decks.sort(
      (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return decks;
  }

  @override
  Future<void> save(Deck deck) => _decks.doc(deck.id).set({
    'userId': uid,
    ...deck.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> delete(String deckId) => _decks.doc(deckId).delete();
}

/// A guest's decks, on this device only, under one preferences key.
class LocalDeckStore implements DeckStore {
  LocalDeckStore(this.uid);

  final String uid;
  String get _key => 'study.v1.$uid.decks';

  Future<Map<String, dynamic>> _all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  @override
  Future<List<Deck>> list() async {
    final all = await _all();
    final decks = [
      for (final e in all.entries)
        if (e.value is Map<String, dynamic>)
          Deck.fromMap(e.key, e.value as Map<String, dynamic>),
    ];
    decks.sort(
      (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return decks;
  }

  @override
  Future<void> save(Deck deck) async {
    final all = await _all();
    all[deck.id] = {
      ...deck.toMap(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _write(all);
  }

  @override
  Future<void> delete(String deckId) async {
    final all = await _all();
    all.remove(deckId);
    await _write(all);
  }
}

/// The current student's deck store; null when signed out.
final deckStoreProvider = Provider<DeckStore?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  if (user.isAnonymous) return LocalDeckStore(user.uid);
  final db = ref.watch(studyDbProvider);
  return db == null ? null : FirestoreDeckStore(db, user.uid);
});

/// The student's decks, newest first. Saves and deletes update it in
/// place, so the list costs one read a visit.
class DecksNotifier extends AsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() async {
    final store = ref.watch(deckStoreProvider);
    if (store == null) return const [];
    return store.list();
  }

  Future<void> save(Deck deck) async {
    final now = Deck(
      id: deck.id,
      title: deck.title,
      subjectId: deck.subjectId,
      cards: deck.usable,
      updatedAt: DateTime.now(),
    );
    final rest = [
      for (final d in state.asData?.value ?? const <Deck>[])
        if (d.id != deck.id) d,
    ];
    state = AsyncData([now, ...rest]);
    await ref.read(deckStoreProvider)?.save(now);
  }

  Future<void> delete(String deckId) async {
    state = AsyncData([
      for (final d in state.asData?.value ?? const <Deck>[])
        if (d.id != deckId) d,
    ]);
    await ref.read(deckStoreProvider)?.delete(deckId);
  }
}

final decksProvider = AsyncNotifierProvider<DecksNotifier, List<Deck>>(
  DecksNotifier.new,
);

/// One deck, from the list.
final deckProvider = Provider.family<Deck?, String>((ref, id) {
  final decks = ref.watch(decksProvider).asData?.value ?? const <Deck>[];
  return decks.where((d) => d.id == id).firstOrNull;
});
