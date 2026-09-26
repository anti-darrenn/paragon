import 'package:flutter/material.dart';
import 'core/providers/analytics_binding.dart';
import 'core/providers/reading_settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/account/account_prefs_sync.dart';
import 'features/account/account_sync.dart';
import 'features/account/guest_upgrade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_palette.dart';

class ParagonApp extends ConsumerWidget {
  const ParagonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched for its side effects only: it subscribes analytics to route
    // changes and to auth state. Nothing reads its value — see
    // analytics_binding.dart.
    ref.watch(analyticsBindingProvider);
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
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
      // Reading settings (text size) apply above the Navigator, so every
      // route and dialog gets them. The first frame waits for the stored
      // settings — a local read, resolved within a frame — so a student
      // who chose large text never sees the app at the default size first.
      builder: (context, child) {
        if (readingSettingsLoading) {
          return ColoredBox(color: context.palette.background);
        }
        return ReadingSettingsScope(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
