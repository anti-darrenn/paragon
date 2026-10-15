import 'package:flutter/material.dart';
import 'core/providers/analytics_binding.dart';
import 'core/providers/appearance_provider.dart';
import 'core/providers/reading_settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/account/account_prefs_sync.dart';
import 'features/account/account_sync.dart';
import 'features/account/guest_upgrade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_palette.dart';
import 'core/data/error_reporter.dart';
import 'core/data/read_meter_overlay.dart';
import 'core/widgets/quota_banner.dart';

class ParagonApp extends ConsumerWidget {
  const ParagonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched for its side effects only: it subscribes analytics to route
    // changes and to auth state. Nothing reads its value — see
    // analytics_binding.dart.
    ref.watch(analyticsBindingProvider);
    // Uncaught errors become an `app_error` event; see error_reporter.dart.
    ref.watch(errorReporterProvider);
    // Finishes carrying a former guest's device-only notes and cards into
    // their account, if an upgrade was interrupted. Usually a no-op.
    ref.watch(guestDataCopyProvider);
    ref.watch(accountEmailSyncProvider);
    ref.watch(accountPrefsSyncProvider);
    final readingSettingsLoading = ref.watch(readingPrefsProvider).isLoading;

    return MaterialApp.router(
      title: 'Paragon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Dark unless the student chose otherwise (Settings → Reading), and
      // always dark until the light theme has been reviewed.
      themeMode: kAppearanceChoiceEnabled
          ? ref.watch(appearanceProvider).mode
          : ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
      // Reading settings (text size) apply above the Navigator, so every
      // route and dialog gets them. The first frame waits for the stored
      // settings — a local read, resolved within a frame — so a student
      // who chose large text never sees the app at the default size first.
      builder: (context, child) {
        if (readingSettingsLoading) {
          return ColoredBox(color: context.palette.background);
        }
        // The read meter draws only in debug builds; the quota banner shows
        // only while Firestore's daily quota is spent.
        return ReadMeterOverlay(
          child: QuotaBanner(
            child: ReadingSettingsScope(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
