import 'package:flutter/material.dart';
import 'core/providers/analytics_binding.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParagonApp extends ConsumerWidget {
  const ParagonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched for its side effects only: it subscribes analytics to route
    // changes and to auth state. Nothing reads its value — see
    // analytics_binding.dart.
    ref.watch(analyticsBindingProvider);

    return MaterialApp.router(
      title: 'Paragon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
