import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui/ui.dart';

/// A studio panel that failed to load. Staff see the raw error on purpose
/// (it is how a broken index or rule gets reported), but folded under
/// "Details" with a copy button, rather than dumped in red under the
/// heading.
class StudioError extends StatelessWidget {
  const StudioError({
    super.key,
    required this.message,
    required this.error,
    this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return InlineAlert(
      tone: Tone.danger,
      message: message,
      action: Wrap(
        spacing: 4,
        children: [
          if (onRetry != null)
            AppButton(
              label: 'Try again',
              tone: ButtonTone.ghost,
              size: ButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          AppButton(
            label: 'Details',
            tone: ButtonTone.ghost,
            size: ButtonSize.sm,
            icon: Icons.code_rounded,
            onPressed: () => showErrorDetails(context, error),
          ),
        ],
      ),
    );
  }
}

/// The raw error in a dialog, selectable and copyable, for a report.
Future<void> showErrorDetails(BuildContext context, Object error) {
  final text = '$error';
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Error details'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: AppTheme.label.copyWith(
              fontFamily: 'monospace',
              color: dialog.palette.textPrimary,
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'Copy',
          tone: ButtonTone.ghost,
          icon: Icons.copy_rounded,
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
        ),
        AppButton(label: 'Close', onPressed: () => Navigator.of(dialog).pop()),
      ],
    ),
  );
}

/// A failed action, said in a toast, with the raw error a tap away.
void showStudioFailure(BuildContext context, String message, Object error) {
  showToast(
    context,
    message,
    tone: Tone.danger,
    actionLabel: 'Details',
    onAction: () => showErrorDetails(context, error),
  );
}
