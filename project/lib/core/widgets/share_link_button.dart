import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../web/browser.dart';

/// Shares a link to a page of the app: the system share sheet where the
/// browser has one (most phones, so straight into WhatsApp), else the link
/// is copied and the student is told so.
///
/// [path] is an app route (`/subject/abc/course`); the origin is added
/// here. Works only because the app uses real paths, not `#/` URLs.
class ShareLinkButton extends StatelessWidget {
  const ShareLinkButton({super.key, required this.title, required this.path});

  final String title;
  final String path;

  String get url => '$appOrigin$path';

  Future<void> _share(BuildContext context) async {
    if (await shareLink(title: title, url: url)) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share',
      icon: const Icon(Icons.ios_share_rounded),
      onPressed: () => _share(context),
    );
  }
}
