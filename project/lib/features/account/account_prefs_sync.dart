import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/account_prefs.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/appearance_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/reading_settings_provider.dart';
import '../../core/repositories/user_repository.dart';

/// Keeps a signed-in student's settings the same on every device. The
/// rules for who wins are in `core/prefs/account_prefs.dart`.
///
/// Both directions live here, so the settings notifiers stay free of
/// Firebase and of accounts:
///
/// - **Account → device**, whenever the user document changes: the
///   account's reading settings are applied locally, and an account
///   opt-out switches analytics off.
/// - **Device → account**, whenever a setting changes on this device for
///   any reason other than the step above.
///
/// Guests are skipped entirely. Watched once by `app.dart`.
final accountPrefsSyncProvider = Provider<void>((ref) {
  // A fresh sync for each account signed in on this device, so nothing
  // one account saw carries over to the next.
  ref.watch(currentUserProvider.select((u) => u?.uid));
  final sync = _PrefsSync(ref);

  ref.listen<Map<String, dynamic>?>(
    userDataProvider.select((a) => a.asData?.value),
    (_, data) => sync.fromAccount(data),
    fireImmediately: true,
  );
  ref.listen<ReadingSettings>(
    readingSettingsProvider,
    (_, next) => sync.readingChanged(next),
  );
  ref.listen<Appearance>(
    appearanceProvider,
    (_, next) => sync.appearanceChanged(next),
  );
  ref.listen<bool>(
    analyticsEnabledProvider,
    (_, next) => sync.analyticsChanged(next),
  );
});

class _PrefsSync {
  _PrefsSync(this.ref);

  final Ref ref;

  /// The last reading settings that came *from* the account. A change to
  /// exactly this value is the echo of applying it, not a student's
  /// choice, and must not be written back.
  ReadingSettings? _fromAccount;

  /// The same, for the theme.
  Appearance? _appearanceFromAccount;

  /// Whether the account's document has been seen at all. Until it has,
  /// a device change is the device loading its own storage at start-up,
  /// which must not overwrite what the account holds.
  bool _accountSeen = false;

  String? get _uid {
    final user = ref.read(currentUserProvider);
    return user == null || user.isAnonymous ? null : user.uid;
  }

  void fromAccount(Map<String, dynamic>? data) {
    if (_uid == null || data == null) return;
    _accountSeen = true;
    final prefs = data['prefs'];

    final reading = readingFromPrefs(prefs);
    final device = ref.read(readingSettingsProvider);
    if (reading == null) {
      // An account that has never synced takes this device's settings,
      // unless they are just the defaults.
      if (!device.isDefault) _push(readingToPrefs(device));
    } else if (reading != device) {
      _fromAccount = reading;
      // Deferred: a listener must not change another provider mid-build.
      Future.microtask(
        () => ref
            .read(readingSettingsProvider.notifier)
            .applyFromAccount(reading),
      );
    }

    final theme = appearanceFromPrefs(prefs);
    final deviceTheme = ref.read(appearanceProvider);
    if (theme == null) {
      if (deviceTheme != Appearance.dark) _push({'theme': deviceTheme.name});
    } else if (theme != deviceTheme) {
      _appearanceFromAccount = theme;
      Future.microtask(() => ref.read(appearanceProvider.notifier).set(theme));
    }

    if (accountTurnsAnalyticsOff(
      deviceEnabled: ref.read(analyticsEnabledProvider),
      account: analyticsFromPrefs(prefs),
    )) {
      Future.microtask(
        () => ref.read(analyticsEnabledProvider.notifier).applyAccountOptOut(),
      );
    }
  }

  void readingChanged(ReadingSettings next) {
    if (!_accountSeen || next == _fromAccount) return;
    _fromAccount = null;
    _push(readingToPrefs(next));
  }

  void appearanceChanged(Appearance next) {
    if (!_accountSeen || next == _appearanceFromAccount) return;
    _appearanceFromAccount = null;
    _push({'theme': next.name});
  }

  void analyticsChanged(bool enabled) {
    if (!_accountSeen) return;
    _push({'analytics': enabled});
  }

  void _push(Map<String, Object> prefs) {
    final uid = _uid;
    if (uid == null) return;
    ref
        .read(userRepositoryProvider)
        .setPrefs(uid: uid, prefs: prefs)
        .catchError((_) {});
  }
}
