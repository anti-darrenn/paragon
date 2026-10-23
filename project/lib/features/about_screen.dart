import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/legal/about_content.dart';
import '../core/legal/legal_documents.dart';
import '../core/providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/nav/back_navigation.dart';
import '../core/widgets/ui/ui.dart';
import '../core/widgets/paragon_logo.dart';
import 'feedback/feedback_sheet.dart';

/// What Paragon is, where its questions come from, and how to reach us.
///
/// Readable signed out, like `/terms` and `/privacy`. Every claim here must
/// stay true of the app as it ships: in particular, nothing may call the
/// answers official or verified — see the Terms' "not official" section.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: ParagonAppBar(title: const Text('About Paragon')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kPageMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Center(
                child: ParagonLogo(height: 64, semanticLabel: 'Paragon'),
              ),
              const SizedBox(height: 24),
              // The same text as the static /about/ page
              // (`about_content.dart`).
              for (final s in kAboutSections) _Section(section: s),
              if (aboutThanks case final thanks?) _Section(section: thanks),
              const _ContactSection(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  _Link(
                    label: 'Support Paragon',
                    onTap: () => context.push('/support'),
                  ),
                  _Link(label: 'Terms', onTap: () => context.push('/terms')),
                  _Link(
                    label: 'Privacy Policy',
                    onTap: () => context.push('/privacy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          for (final p in section.paragraphs) ...[
            const SizedBox(height: 8),
            Text(
              p,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The address is shown as text as well as linked: a school or family
/// device often has no mail app, and then `mailto:` does nothing.
class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kAboutContactText,
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            contactEmail,
            style: AppTheme.bodyLg.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            children: [
              // Signed-out visitors have no account to send it from.
              Consumer(
                builder: (context, ref, _) =>
                    ref.watch(currentUserProvider) == null
                    ? const SizedBox.shrink()
                    : _Link(
                        label: 'Send feedback',
                        onTap: () => showFeedbackSheet(context),
                      ),
              ),
              _Link(
                label: 'Write an email',
                onTap: () => launchUrl(aboutMailto),
              ),
              _Link(
                label: 'Copy address',
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: contactEmail),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `mailto:` for general contact, from About and the welcome screen.
final Uri aboutMailto = Uri(
  scheme: 'mailto',
  path: contactEmail,
  query: 'subject=${Uri.encodeComponent('Paragon')}',
);

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Text(
        label,
        style: AppTheme.bodyMd.copyWith(
          color: context.palette.primaryFg,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
      ),
    );
  }
}
