import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learn_resource.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ai_tutor.dart';

/// "Ask about this". Greyed out with a *Coming soon* tooltip while
/// [AiTutor.isAvailable] is false, which is always, for now; see
/// [AiTutor].
class AskTutorButton extends ConsumerWidget {
  const AskTutorButton({super.key, required this.resource});

  final LearnResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(aiTutorProvider).isAvailable;
    return Tooltip(
      message: available
          ? 'Ask about this lesson'
          : 'Ask about this: coming soon',
      child: TextButton.icon(
        // Disabled until a tutor backend exists; nothing is sent anywhere.
        onPressed: available ? () {} : null,
        icon: const Icon(Icons.auto_awesome_outlined, size: 16),
        label: Text(
          available ? 'Ask' : 'Ask (soon)',
          style: AppTheme.caption.copyWith(
            color: available ? AppColors.primary : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}
