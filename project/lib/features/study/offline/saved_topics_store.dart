import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/reading_settings_provider.dart'
    show readingPrefsProvider;

/// A topic the student saved for offline reading.
///
/// **A record of a request, not of the cache.** Firestore decides what
/// stays in its cache; this list only remembers what the student asked
/// for and when, so it can be shown and managed.
@immutable
class SavedTopic {
  const SavedTopic({
    required this.topicId,
    required this.name,
    required this.subjectId,
    required this.courseKey,
    required this.savedAt,
    required this.itemCount,
    this.videoCount = 0,
  });

  final String topicId;
  final String name;
  final String subjectId;

  /// The course route key, for the "open" link
  /// (`/subject/<courseKey>/course/topic/<topicId>`).
  final String courseKey;
  final DateTime savedAt;

  /// Approximately how many documents were downloaded.
  final int itemCount;

  /// Videos in the topic, which still need a connection.
  final int videoCount;

  String get path => '/subject/$courseKey/course/topic/$topicId';

  Map<String, Object?> toJson() => {
    'topicId': topicId,
    'name': name,
    'subjectId': subjectId,
    'courseKey': courseKey,
    'savedAt': savedAt.toIso8601String(),
    'itemCount': itemCount,
    'videoCount': videoCount,
  };

  /// Null for an entry that is unusable (no topic id); every other field
  /// falls back rather than throwing, like the Firestore parsers.
  static SavedTopic? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['topicId'];
    if (id is! String || id.isEmpty) return null;
    String str(String k) => json[k] is String ? json[k] as String : '';
    int number(String k) => json[k] is int ? json[k] as int : 0;
    return SavedTopic(
      topicId: id,
      name: str('name'),
      subjectId: str('subjectId'),
      courseKey: str('courseKey'),
      savedAt:
          DateTime.tryParse(str('savedAt')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemCount: number('itemCount'),
      videoCount: number('videoCount'),
    );
  }
}

const kSavedTopicsKey = 'offline.savedTopics';

/// The saved-topics list, newest first, stored per device in
/// SharedPreferences (like the reading settings: it describes this
/// device's cache, which another device does not share).
class SavedTopicsNotifier extends Notifier<List<SavedTopic>> {
  @override
  List<SavedTopic> build() {
    final prefs = ref.watch(readingPrefsProvider).asData?.value;
    if (prefs == null) return const [];
    try {
      final raw = prefs.getString(kSavedTopicsKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final e in decoded) ?SavedTopic.fromJson(e)];
    } catch (_) {
      return const [];
    }
  }

  SavedTopic? find(String topicId) {
    for (final t in state) {
      if (t.topicId == topicId) return t;
    }
    return null;
  }

  /// Adds [topic], replacing an earlier save of the same topic.
  Future<void> add(SavedTopic topic) => _save([
    topic,
    for (final t in state)
      if (t.topicId != topic.topicId) t,
  ]);

  /// Drops [topicId] from the list. The cached documents are not touched
  /// — Firestore has no per-document eviction — and stay until the cache
  /// evicts them to make room.
  Future<void> remove(String topicId) => _save([
    for (final t in state)
      if (t.topicId != topicId) t,
  ]);

  Future<void> _save(List<SavedTopic> next) async {
    state = next;
    final SharedPreferences? prefs = ref
        .read(readingPrefsProvider)
        .asData
        ?.value;
    if (prefs == null) return;
    try {
      await prefs.setString(
        kSavedTopicsKey,
        jsonEncode([for (final t in next) t.toJson()]),
      );
    } catch (_) {
      // Storage refused; the list still holds for this session.
    }
  }
}

final savedTopicsProvider =
    NotifierProvider<SavedTopicsNotifier, List<SavedTopic>>(
      SavedTopicsNotifier.new,
    );

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "26 Sep 2026" — the app has no `intl` dependency, and a date is all
/// this needs.
String formatSavedDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';
