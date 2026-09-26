import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'study_models.dart';

/// Where a student's notes and bookmarks are kept.
///
/// Two implementations with one contract: [FirestoreStudyStore] for a
/// signed-in account, [LocalStudyStore] for a guest. Callers never know
/// which they have, so no screen can accidentally write a guest's notes to
/// the database.
///
/// **Quota.** Every method is one Firestore operation at most. Nothing is
/// written per keystroke: a note is saved when the student presses Done,
/// and a highlight toggle is a single write.
abstract class StudyStore {
  /// This lesson's notes. [resourceId] is a slug, unique only within a
  /// topic, so the topic is checked as well.
  Future<List<LessonNote>> lessonNotes(String topicId, String resourceId);

  /// Every note the student has, for the Saved page.
  Future<List<LessonNote>> allNotes();

  /// Stores a new note and returns it with its id.
  Future<LessonNote> createNote(LessonNote note);

  /// Rewrites a note's colour, text and snapshot.
  Future<void> updateNote(LessonNote note);

  Future<void> deleteNote(String id);

  Future<Map<String, Bookmark>> bookmarks();

  /// Saves [bookmark] under its key. Saving one that is already there
  /// changes nothing the student can see.
  Future<void> addBookmark(Bookmark bookmark);

  /// Removes the bookmark under [key]. A key that is not there is a no-op.
  Future<void> removeBookmark(String key);
}

/// A signed-in student's notes and bookmarks.
///
/// - `notes/{autoId}` — one document per annotated block, with `userId`.
///   Every query is equality-only (`userId`, and `resourceId` for one
///   lesson), so no composite index is needed. The topic check is done
///   client-side for the same reason.
/// - `study/{uid}` — bookmarks, under `bookmarks.<key>`. **Shared with
///   future features** (revision cards will add `cards`), so every write
///   here merges and never replaces the document.
class FirestoreStudyStore implements StudyStore {
  FirestoreStudyStore(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');
  DocumentReference<Map<String, dynamic>> get _study =>
      _db.collection('study').doc(uid);

  @override
  Future<List<LessonNote>> lessonNotes(String topicId, String resourceId) async {
    final snap = await _notes
        .where('userId', isEqualTo: uid)
        .where('resourceId', isEqualTo: resourceId)
        .get();
    return [
      for (final d in snap.docs)
        if (LessonNote.fromFirestore(d) case final n when n.topicId == topicId)
          n,
    ];
  }

  @override
  Future<List<LessonNote>> allNotes() async {
    final snap = await _notes.where('userId', isEqualTo: uid).get();
    return [for (final d in snap.docs) LessonNote.fromFirestore(d)];
  }

  @override
  Future<LessonNote> createNote(LessonNote note) async {
    final ref = await _notes.add({
      'userId': uid,
      'topicId': note.topicId,
      'resourceId': note.resourceId,
      'subjectId': note.subjectId,
      'blockKey': note.blockKey,
      'colour': note.colour?.name,
      'text': note.text,
      'snapshot': note.snapshot,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final now = DateTime.now();
    return LessonNote(
      id: ref.id,
      topicId: note.topicId,
      resourceId: note.resourceId,
      subjectId: note.subjectId,
      blockKey: note.blockKey,
      colour: note.colour,
      text: note.text,
      snapshot: note.snapshot,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> updateNote(LessonNote note) => _notes.doc(note.id).update({
    'colour': note.colour?.name,
    'text': note.text,
    'snapshot': note.snapshot,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> deleteNote(String id) => _notes.doc(id).delete();

  @override
  Future<Map<String, Bookmark>> bookmarks() async {
    final snap = await _study.get();
    return Bookmark.mapFrom(snap.data()?['bookmarks']);
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) => _study.set({
    'userId': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'bookmarks': {
      bookmark.key: {
        ...bookmark.toFields(),
        'savedAt': FieldValue.serverTimestamp(),
      },
    },
  }, SetOptions(merge: true));

  /// A merge with a delete sentinel rather than `update()`: it works
  /// whether or not the document exists yet, so removing twice is as
  /// harmless as adding twice.
  @override
  Future<void> removeBookmark(String key) => _study.set({
    'userId': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'bookmarks': {key: FieldValue.delete()},
  }, SetOptions(merge: true));
}

/// A guest's notes and bookmarks, in this browser's local storage only.
///
/// Keyed by the guest's anonymous uid, so a second guest on a shared
/// computer (a school lab, a family phone) does not open the first one's
/// notes. Nothing here ever reaches the server, and nothing is carried
/// over if the guest later signs up.
///
/// When storage is unavailable (private browsing, blocked site data) the
/// store keeps what it has in memory for the visit and loses it after.
class LocalStudyStore implements StudyStore {
  LocalStudyStore(this.uid, {Future<SharedPreferences?>? prefs})
    : _prefs = prefs ?? _open();

  final String uid;
  final Future<SharedPreferences?> _prefs;

  static Future<SharedPreferences?> _open() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  String get _notesKey => 'study.v1.$uid.notes';
  String get _bookmarksKey => 'study.v1.$uid.bookmarks';

  List<LessonNote>? _notesCache;
  Map<String, Bookmark>? _bookmarksCache;
  int _seq = 0;

  Future<List<LessonNote>> _loadNotes() async {
    if (_notesCache case final cached?) return cached;
    final prefs = await _prefs;
    final out = <LessonNote>[];
    try {
      final raw = jsonDecode(prefs?.getString(_notesKey) ?? '[]');
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final m = e.map((k, v) => MapEntry('$k', v));
            final id = '${m['id'] ?? ''}';
            if (id.isNotEmpty) out.add(LessonNote.fromMap(id, m));
          }
        }
      }
    } catch (_) {
      // Corrupt local data reads as none rather than breaking the lesson.
    }
    return _notesCache = out;
  }

  Future<void> _saveNotes(List<LessonNote> notes) async {
    _notesCache = notes;
    final prefs = await _prefs;
    await prefs?.setString(
      _notesKey,
      jsonEncode([for (final n in notes) n.toJson()]),
    );
  }

  @override
  Future<List<LessonNote>> lessonNotes(String topicId, String resourceId) async =>
      [
        for (final n in await _loadNotes())
          if (n.topicId == topicId && n.resourceId == resourceId) n,
      ];

  @override
  Future<List<LessonNote>> allNotes() async => List.of(await _loadNotes());

  @override
  Future<LessonNote> createNote(LessonNote note) async {
    final notes = await _loadNotes();
    final now = DateTime.now();
    final created = LessonNote(
      id: 'local-${now.microsecondsSinceEpoch}-${_seq++}',
      topicId: note.topicId,
      resourceId: note.resourceId,
      subjectId: note.subjectId,
      blockKey: note.blockKey,
      colour: note.colour,
      text: note.text,
      snapshot: note.snapshot,
      createdAt: now,
      updatedAt: now,
    );
    await _saveNotes([...notes, created]);
    return created;
  }

  @override
  Future<void> updateNote(LessonNote note) async {
    final notes = await _loadNotes();
    final updated = note.copyWith(updatedAt: DateTime.now());
    await _saveNotes([
      for (final n in notes) n.id == note.id ? updated : n,
    ]);
  }

  @override
  Future<void> deleteNote(String id) async {
    final notes = await _loadNotes();
    await _saveNotes([for (final n in notes) if (n.id != id) n]);
  }

  Future<Map<String, Bookmark>> _loadBookmarks() async {
    if (_bookmarksCache case final cached?) return cached;
    final prefs = await _prefs;
    var out = <String, Bookmark>{};
    try {
      out = Bookmark.mapFrom(jsonDecode(prefs?.getString(_bookmarksKey) ?? '{}'));
    } catch (_) {}
    return _bookmarksCache = out;
  }

  Future<void> _saveBookmarks(Map<String, Bookmark> b) async {
    _bookmarksCache = b;
    final prefs = await _prefs;
    await prefs?.setString(
      _bookmarksKey,
      jsonEncode({for (final e in b.entries) e.key: e.value.toJson()}),
    );
  }

  @override
  Future<Map<String, Bookmark>> bookmarks() async =>
      Map.of(await _loadBookmarks());

  @override
  Future<void> addBookmark(Bookmark bookmark) async {
    final b = Map.of(await _loadBookmarks());
    if (b.containsKey(bookmark.key)) return;
    b[bookmark.key] = bookmark.withSavedAt(DateTime.now());
    await _saveBookmarks(b);
  }

  @override
  Future<void> removeBookmark(String key) async {
    final b = Map.of(await _loadBookmarks());
    if (b.remove(key) == null) return;
    await _saveBookmarks(b);
  }
}
