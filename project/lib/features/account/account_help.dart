import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_palette.dart';

/// "Help with your account": who to write to, and a way to write.
///
/// Several screens already say "contact us" — a deletion that only partly
/// finished, a request the app cannot do itself — and until this there was
/// nothing in the app telling a student how. The address is shown as well
/// as linked, because a school or family device often has no mail app set
/// up and `mailto:` then does nothing.
Future<void> showAccountHelp(BuildContext context, {String? uid}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.palette.surface,
      title: Text(
        'Help with your account',
        style: AppTheme.heading3.copyWith(color: context.palette.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email us about anything to do with your account or your data: '
            'getting back in, a deletion that did not finish, or a copy of '
            'what we hold. A parent or guardian can write too.',
            style: AppTheme.bodyMd.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            contactEmail,
            style: AppTheme.bodyLg.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (uid != null) ...[
            const SizedBox(height: 10),
            Text(
              'Include your account ID so we can find you: $uid',
              style: AppTheme.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(const ClipboardData(text: contactEmail));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(
            'Copy address',
            style: AppTheme.btnLabel.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            launchUrl(accountHelpMailto(uid: uid));
            Navigator.of(context).pop();
          },
          child: Text(
            'Write an email',
            style: AppTheme.btnLabel.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}

/// The `mailto:` link, with a subject and — when known — the account id in
/// the body. Never the student's name or email: those are theirs to add.
Uri accountHelpMailto({String? uid}) => Uri(
  scheme: 'mailto',
  path: contactEmail,
  query: [
    'subject=${Uri.encodeComponent('Paragon account help')}',
    if (uid != null) 'body=${Uri.encodeComponent('Account ID: $uid\n\n')}',
  ].join('&'),
);
