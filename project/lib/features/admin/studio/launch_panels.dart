import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/read_meter.dart';
import '../../../core/models/firestore_parsing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/feedback_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';

/// Studio panels that watch the live app rather than the content: how
/// close today is to the Spark quota, and what students are telling us.
/// Reviewers only; the studio home decides.

// ─── Usage ──────────────────────────────────────────────────────────

/// One Pacific quota day from `_meta/usage` (written by
/// `tools/admin/usage.js` every 15 minutes).
class UsageDay {
  const UsageDay(this.day, this.reads, this.writes, this.deletes);
  final String day;
  final int reads;
  final int writes;
  final int deletes;
}

class UsageSnapshot {
  const UsageSnapshot({
    required this.days,
    required this.readQuota,
    required this.writeQuota,
    required this.updatedAt,
  });

  /// Newest first.
  final List<UsageDay> days;
  final int readQuota;
  final int writeQuota;
  final DateTime? updatedAt;

  static UsageSnapshot? fromDocument(Map<String, dynamic>? d) {
    if (d == null) return null;
    final quota = d['quota'] is Map ? d['quota'] as Map : const {};
    final raw = d['days'] is Map ? d['days'] as Map : const {};
    final days = [
      for (final e in raw.entries)
        if (e.value is Map)
          UsageDay(
            e.key.toString(),
            asInt((e.value as Map)['reads']),
            asInt((e.value as Map)['writes']),
            asInt((e.value as Map)['deletes']),
          ),
    ]..sort((a, b) => b.day.compareTo(a.day));
    final updated = d['updatedAt'];
    return UsageSnapshot(
      days: days,
      readQuota: asInt(quota['reads'], fallback: 50000),
      writeQuota: asInt(quota['writes'], fallback: 20000),
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}

final usageProvider = FutureProvider.autoDispose<UsageSnapshot?>((ref) async {
  final snap = await FirebaseFirestore.instance
      .doc('_meta/usage')
      .get()
      .metered();
  return UsageSnapshot.fromDocument(snap.data());
});

class UsagePanel extends ConsumerWidget {
  const UsagePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final usage = ref.watch(usageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Daily quota',
          style: AppTheme.heading3.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 12),
        usage.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load usage.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (u) {
            if (u == null || u.days.isEmpty) {
              return Text(
                'No usage recorded yet. The usage job needs the service '
                'account to hold Monitoring Viewer; see tools/admin/usage.js.',
                style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
              );
            }
            final today = u.days.first;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuotaBar(
                    label: 'Reads today',
                    used: today.reads,
                    quota: u.readQuota,
                  ),
                  const SizedBox(height: 12),
                  _QuotaBar(
                    label: 'Writes today',
                    used: today.writes,
                    quota: u.writeQuota,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    [
                      for (final d in u.days.skip(1).take(6))
                        '${d.day.substring(5)}: ${d.reads} reads, '
                            '${d.writes} writes',
                    ].join('\n'),
                    style: AppTheme.caption.copyWith(
                      color: palette.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quota days run midnight to midnight Pacific time. '
                    'Figures lag by a few minutes'
                    '${u.updatedAt == null ? '' : '; updated ${_ago(u.updatedAt!)}'}.',
                    style: AppTheme.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  return '${m ~/ 60} h ago';
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.label,
    required this.used,
    required this.quota,
  });

  final String label;
  final int used;
  final int quota;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fraction = quota <= 0 ? 0.0 : (used / quota).clamp(0.0, 1.0);
    final colour = fraction >= 0.9
        ? AppColors.wrong
        : fraction >= 0.7
        ? AppColors.warning
        : AppColors.correct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
              ),
            ),
            Text(
              '$used of $quota (${(fraction * 100).round()}%)',
              style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            color: colour,
            backgroundColor: palette.track,
          ),
        ),
      ],
    );
  }
}

// ─── Feedback ───────────────────────────────────────────────────────

class FeedbackPanel extends ConsumerWidget {
  const FeedbackPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final feedback = ref.watch(recentFeedbackProvider);

    Future<void> resolve(FeedbackItem f, String status) async {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null) return;
      await ref.read(feedbackRepositoryProvider).setStatus(f.id, status, uid);
      ref.invalidate(recentFeedbackProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Feedback',
          style: AppTheme.heading3.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 12),
        feedback.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load feedback.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (all) {
            final open = all.where((f) => f.isOpen).toList();
            if (open.isEmpty) {
              return Text(
                'No open feedback.',
                style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final f in open)
                    ListTile(
                      isThreeLine: true,
                      leading: Icon(
                        _icon(f.kind),
                        color: palette.textSecondary,
                      ),
                      title: SelectableText(
                        f.message,
                        style: AppTheme.bodyMd.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${f.kind.label} · ${f.screen}'
                        '${f.createdAt == null ? '' : ' · ${_ago(f.createdAt!)}'}',
                        style: AppTheme.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      trailing: Wrap(
                        children: [
                          TextButton(
                            onPressed: () => resolve(f, 'done'),
                            child: const Text('Done'),
                          ),
                          TextButton(
                            onPressed: () => resolve(f, 'dismissed'),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static IconData _icon(FeedbackKind kind) => switch (kind) {
    FeedbackKind.idea => Icons.lightbulb_outline_rounded,
    FeedbackKind.problem => Icons.report_problem_outlined,
    FeedbackKind.praise => Icons.favorite_border_rounded,
    FeedbackKind.other => Icons.chat_bubble_outline_rounded,
  };
}
