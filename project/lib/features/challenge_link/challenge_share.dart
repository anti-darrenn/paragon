import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/web/browser.dart';

/// The link to a challenge.
String challengeUrl(String id) => '$appOrigin/c/$id';

/// The message that travels with it.
String challengeMessage({
  required int score,
  required int total,
  required String topicName,
  required String id,
}) =>
    'I got $score/$total on $topicName in Paragon. Can you beat me? '
    '${challengeUrl(id)}';

/// WhatsApp first (it is how most students will send it), then the
/// system share sheet where there is one, then copy.
Future<void> showChallengeShareSheet(
  BuildContext context, {
  required String id,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send your challenge',
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Your friend answers the same questions, and you both see '
              'the scores. They see your first name and nothing else.',
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Send on WhatsApp'),
              onPressed: () {
                Navigator.of(sheet).pop();
                launchUrl(
                  Uri.parse(
                    'https://wa.me/?text=${Uri.encodeComponent(message)}',
                  ),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share another way'),
              onPressed: () async {
                Navigator.of(sheet).pop();
                if (!await shareLink(title: message, url: challengeUrl(id))) {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Challenge copied')),
                    );
                  }
                }
              },
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(sheet).pop();
                await Clipboard.setData(ClipboardData(text: challengeUrl(id)));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied')));
                }
              },
              child: const Text('Copy link'),
            ),
          ],
        ),
      ),
    ),
  );
}
