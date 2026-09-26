import 'package:shared_preferences/shared_preferences.dart';

/// Studio conveniences kept on this device only: the block clipboard and
/// the autosave backup. Neither touches Firestore — a backup every few
/// seconds would cost a write (and a history version) each time.
///
/// Every call tolerates storage being unavailable (a private window, a
/// test without mocks) by doing nothing, never by throwing.
class StudioStorage {
  const StudioStorage();

  static const _clipboardKey = 'studio.clipboard.v1';
  static String _backupKey(String topicId, String resourceId) =>
      'studio.backup.v1.$topicId.$resourceId';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// The block last copied from any lesson's preview, or null.
  Future<String?> readClipboard() async =>
      (await _prefs())?.getString(_clipboardKey);

  Future<void> writeClipboard(String block) async =>
      (await _prefs())?.setString(_clipboardKey, block);

  /// The body typed but not yet saved for this item, or null.
  Future<String?> readBackup(String topicId, String resourceId) async =>
      (await _prefs())?.getString(_backupKey(topicId, resourceId));

  Future<void> writeBackup(
    String topicId,
    String resourceId,
    String body,
  ) async => (await _prefs())?.setString(_backupKey(topicId, resourceId), body);

  /// Called after a successful save: the backup has nothing to add.
  Future<void> clearBackup(String topicId, String resourceId) async =>
      (await _prefs())?.remove(_backupKey(topicId, resourceId));
}
