import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/legal/legal_documents.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_palette.dart';

/// Renders a [LegalDocument] at `/privacy` or `/terms`.
///
/// Deliberately a plain scaffold rather than `ParagonPage`: these pages
/// have to be readable while signed out (the welcome screen links to
/// them), and the app nav points at routes a signed-out visitor cannot
/// reach. The router exempts both paths from the auth redirect for the
/// same reason.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  /// Asks whether any placeholder is still unfilled, rather than
  /// searching the rendered text for particular values.
  ///
  /// The old version scanned for `publisherPlaceholder` and
  /// `contactPlaceholder` by value, which worked only while those values
  /// were literal placeholder strings. Filling them in turned the check
  /// inside out: every paragraph mentioning the publisher's real name
  /// matched, and the warning would have shown permanently on a document
  /// with nothing left to fill.
  bool get _hasPlaceholders => legalPlaceholdersRemain;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(document.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: AppTheme.displayLg.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last updated $legalLastUpdated',
                        style: AppTheme.caption.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Unmissable while the document is still a draft —
                      // this is the guard against shipping a policy with
                      // "[CONTACT EMAIL — to be confirmed]" in it.
                      if (_hasPlaceholders) const _DraftBanner(),

                      Text(
                        document.intro,
                        style: AppTheme.bodyLg.copyWith(
                          color: context.palette.textSecondary,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 8),

                      for (final section in document.sections) ...[
                        const SizedBox(height: 28),
                        Text(
                          section.heading,
                          style: AppTheme.heading2.copyWith(
                            color: context.palette.textPrimary,
                          ),
                        ),
                        for (final paragraph in section.paragraphs) ...[
                          const SizedBox(height: 12),
                          Text(
                            paragraph,
                            style: AppTheme.bodyLg.copyWith(
                              color: context.palette.textSecondary,
                              height: 1.65,
                            ),
                          ),
                        ],
                        for (final bullet in section.bullets) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 9),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  bullet,
                                  style: AppTheme.bodyLg.copyWith(
                                    color: context.palette.textSecondary,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha((0.10 * 255).round()),
        border: Border.all(
          color: AppColors.warning.withAlpha((0.4 * 255).round()),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Draft — not yet in force. The operator name and contact '
              'address are still placeholders, and this text has not been '
              'reviewed by a lawyer.',
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
