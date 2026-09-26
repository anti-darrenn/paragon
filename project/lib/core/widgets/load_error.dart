import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_palette.dart';

/// What a student sees when a screen's data fails to load: a plain
/// message and a way to try again.
///
/// Never the exception itself. Firestore errors read like
/// `[cloud_firestore/unavailable] The service is currently unavailable`,
/// which tells a student nothing they can act on. The error goes to the
/// debug console instead. Admin screens show raw errors on purpose, and
/// don't use this.
class LoadError extends StatelessWidget {
  const LoadError({
    super.key,
    required this.error,
    required this.onRetry,
    this.message = "Couldn't load this. Check your connection and try again.",
  });

  final Object error;
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    debugPrint('LoadError: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: context.palette.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
