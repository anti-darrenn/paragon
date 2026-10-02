import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/learning_repository.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// An app bar title for a focus session: what kind of session, small,
/// over which topic it is on — "DRILL / Quadratic equations". The topic
/// name comes from a document the session has already read; until it
/// arrives, only the kind shows.
class SessionTitle extends ConsumerWidget {
  const SessionTitle({super.key, required this.kind, required this.topicId});

  final String kind;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(topicByIdProvider(topicId)).asData?.value?.name;
    if (name == null || name.isEmpty) return Text(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kind.toUpperCase(),
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.bodyLg.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
