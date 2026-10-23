import 'package:flutter/material.dart';

import 'buttons.dart';

/// Asks the student to confirm something, and says whether they did.
/// Dismissing the dialog (Esc, a tap outside) counts as no.
///
/// A [destructive] confirmation is a red button, for deleting or leaving
/// work behind. The labels are the caller's: some are pinned by tests
/// ("Keep going" / "Leave"), and they should name the action ("Delete
/// deck"), never just "OK".
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: content ?? (message == null ? null : Text(message)),
      actions: [
        AppButton(
          label: cancelLabel,
          tone: ButtonTone.ghost,
          onPressed: () => Navigator.of(dialog).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          tone: destructive ? ButtonTone.destructive : ButtonTone.primary,
          onPressed: () => Navigator.of(dialog).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
