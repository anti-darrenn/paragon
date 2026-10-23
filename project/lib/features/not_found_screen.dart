import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/web/browser.dart';
import '../core/widgets/ui/ui.dart';

/// Any path the router has no route for (`GoRouter.errorBuilder`). It
/// used to be go_router's debug page: red "GoException: no routes for
/// location" text (audit A6, 2026-10-15).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: EmptyState(
              illustration: IllustrationAsset.notFound,
              title: "We couldn't find that page",
              message:
                  'The link may be old or mistyped. Everything in Paragon '
                  'is still a tap away.',
              action: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  AppButton(label: 'Go home', onPressed: () => context.go('/')),
                  // The static past-question pages live outside the app,
                  // so this is a page load, not a route.
                  AppButton(
                    label: 'Past questions',
                    tone: ButtonTone.secondary,
                    onPressed: () => launchUrl(
                      Uri.parse('$appOrigin/past-questions/'),
                      webOnlyWindowName: '_self',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
