import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lessons/lesson_doc.dart';
import '../../../core/models/question.dart';
import '../../../core/providers/auth_provider.dart';
import 'study_models.dart';
import 'study_store.dart';

/// Failures here are shown as "nothing saved yet", never retried on a
/// timer: a note that failed to load is not worth hammering the quota for.
Duration? _noRetry(int _, Object _) => null;

/// The database for signed-in notes. Null when Firebase is not set up —
/// in a widget test that never initialised it, `FirebaseFirestore.instance`
/// throws, and a lesson must still render.
final studyDbProvider = Provider<FirebaseFirestore?>((ref) {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
});

/// The current student's store: local for a guest, Firestore for an
/// account, none when signed out.
final studyStoreProvider = Provider<StudyStore?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  if (user.isAnonymous) return LocalStudyStore(user.uid);
  final db = ref.watch(studyDbProvider);
  return db == null ? null : FirestoreStudyStore(db, user.uid);
});

typedef LessonRef = ({String topicId, String resourceId, String subjectId});

/// One lesson's highlights and notes, and the ways to change them.
///
/// Read once when the lesson opens (one query) and then kept in step
/// locally after each write, so annotating costs writes, not re-reads.
class LessonNotesNotifier extends AsyncNotifier<List<LessonNote>> {
  LessonNotesNotifier(this.lesson);

  final LessonRef lesson;

  StudyStore? get _store => ref.read(studyStoreProvider);

  @override
  Future<List<LessonNote>> build() async {
    final store = ref.watch(studyStoreProvider);
    if (store == null) return const [];
    return store.lessonNotes(lesson.topicId, lesson.resourceId);
  }

  List<LessonNote> get _current => state.asData?.value ?? const [];

  LessonNote? noteFor(String blockKey) {
    for (final n in _current) {
      if (n.blockKey == blockKey) return n;
    }
    return null;
  }

  /// Sets or clears a block's highlight. One write.
  Future<void> setColour(LessonBlock block, HighlightColour? colour) async {
    final existing = noteFor(block.key);
    if (existing == null) {
      if (colour == null) return;
      await _create(block, colour: colour, text: '');
    } else {
      await _write(
        existing.copyWith(
          colour: colour,
          clearColour: colour == null,
          snapshot: blockSnapshot(block),
        ),
      );
    }
  }

  /// Saves a block's note text — called on Done, never per keystroke.
  Future<void> setText(LessonBlock block, String text) async {
    final t = text.trim();
    final clipped = t.length <= kMaxNoteLength ? t : t.substring(0, kMaxNoteLength);
    final existing = noteFor(block.key);
    if (existing == null) {
      if (clipped.isEmpty) return;
      await _create(block, colour: null, text: clipped);
    } else if (existing.text != clipped) {
      await _write(existing.copyWith(text: clipped, snapshot: blockSnapshot(block)));
    }
  }

  /// Deletes a note outright — attached or from an earlier version.
  Future<void> remove(String noteId) async {
    final store = _store;
    if (store == null) return;
    await store.deleteNote(noteId);
    state = AsyncData([for (final n in _current) if (n.id != noteId) n]);
  }

  Future<void> _create(
    LessonBlock block, {
    required HighlightColour? colour,
    required String text,
  }) async {
    final store = _store;
    if (store == null) return;
    final created = await store.createNote(
      LessonNote(
        id: '',
        topicId: lesson.topicId,
        resourceId: lesson.resourceId,
        subjectId: lesson.subjectId,
        blockKey: block.key,
        colour: colour,
        text: text,
        snapshot: blockSnapshot(block),
      ),
    );
    state = AsyncData([..._current, created]);
  }

  /// Updates, or deletes a record left with neither colour nor text.
  Future<void> _write(LessonNote note) async {
    if (note.isEmpty) return remove(note.id);
    final store = _store;
    if (store == null) return;
    await store.updateNote(note);
    state = AsyncData([
      for (final n in _current) n.id == note.id ? note : n,
    ]);
  }
}

final lessonNotesProvider =
    AsyncNotifierProvider.family<LessonNotesNotifier, List<LessonNote>, LessonRef>(
      LessonNotesNotifier.new,
      retry: _noRetry,
    );

/// Every note the student has, for the Saved page. Fetched when the page
/// opens and dropped when it closes, so it is always current.
final allNotesProvider = FutureProvider.autoDispose<List<LessonNote>>(
  (ref) async {
    final store = ref.watch(studyStoreProvider);
    if (store == null) return const [];
    final notes = await store.allNotes();
    notes.sort(
      (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return notes;
  },
  retry: _noRetry,
);

/// The student's bookmarks, keyed by [Bookmark.key]. One read per session.
class BookmarksNotifier extends AsyncNotifier<Map<String, Bookmark>> {
  @override
  Future<Map<String, Bookmark>> build() async {
    final store = ref.watch(studyStoreProvider);
    if (store == null) return const {};
    return store.bookmarks();
  }

  Map<String, Bookmark> get _current => state.asData?.value ?? const {};

  bool isSaved(String key) => _current.containsKey(key);

  /// Adds [bookmark] if it is not saved, removes it if it is. Returns
  /// whether it is saved afterwards.
  Future<bool> toggle(Bookmark bookmark) async {
    final store = ref.read(studyStoreProvider);
    if (store == null) return false;
    final key = bookmark.key;
    if (_current.containsKey(key)) {
      await store.removeBookmark(key);
      state = AsyncData({..._current}..remove(key));
      return false;
    }
    await store.addBookmark(bookmark);
    state = AsyncData({..._current, key: bookmark.withSavedAt(DateTime.now())});
    return true;
  }

  Future<void> remove(String key) async {
    final store = ref.read(studyStoreProvider);
    if (store == null || !_current.containsKey(key)) return;
    await store.removeBookmark(key);
    state = AsyncData({..._current}..remove(key));
  }
}

final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, Map<String, Bookmark>>(
      BookmarksNotifier.new,
      retry: _noRetry,
    );

/// One bookmarked question, for the Saved page's read-only view. Fetched
/// by id rather than through `pinnedQuestionsProvider`, which drops
/// questions with no verified answer — a scraped question the student
/// saved must still open.
final savedQuestionProvider = FutureProvider.autoDispose.family<Question?, String>(
  (ref, id) async {
    final db = ref.watch(studyDbProvider);
    if (db == null) return null;
    final snap = await db.collection('questions').doc(id).get();
    return snap.exists ? Question.fromFirestore(snap) : null;
  },
  retry: _noRetry,
);
