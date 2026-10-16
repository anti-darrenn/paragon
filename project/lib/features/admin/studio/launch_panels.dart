import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/content/subject_catalog.dart';
import '../../../core/data/read_meter.dart';
import '../../../core/models/firestore_parsing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/feedback_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/repositories/waitlist_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_flag_screen.dart' show adminFlagPath;

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

// ─── Content quality ────────────────────────────────────────────────

/// One rule from `_meta/contentAudit`, written by
/// `tools/admin/content_audit.js --publish` after a static-site refresh.
class AuditRule {
  const AuditRule(this.rule, this.level, this.count);
  final String rule;

  /// "S" is a suspect (the marked answer may be wrong, to check against the
  /// paper), "A" changes what a question means, "B" is presentation.
  final String level;
  final int count;

  String get label => rule.replaceAll('-', ' ');

  /// Suspects first, then meaning, then presentation (Plan v2 2.4.2).
  static int rank(String level) => switch (level) {
    'S' => 0,
    'A' => 1,
    'B' => 2,
    _ => 3,
  };
}

/// One question the audit says to open first, from `suspects`.
class AuditSuspect {
  const AuditSuspect({
    required this.id,
    required this.rule,
    required this.level,
    required this.subject,
    required this.detail,
    this.year,
  });
  final String id;
  final String rule;
  final String level;
  final String subject;
  final int? year;
  final String detail;
}

class ContentAudit {
  const ContentAudit({
    required this.total,
    required this.rules,
    this.suspects = const [],
    this.at,
  });
  final int total;

  /// Level S, then A, then B, each with the largest counts first.
  final List<AuditRule> rules;

  /// Questions to check first, in the audit's order (suspects, then A).
  final List<AuditSuspect> suspects;
  final DateTime? at;

  static ContentAudit? fromDocument(Map<String, dynamic>? d) {
    if (d == null) return null;
    final raw = d['rules'] is Map ? d['rules'] as Map : const {};
    final rules =
        [
          for (final e in raw.entries)
            if (e.value is Map)
              AuditRule(
                e.key.toString(),
                asString((e.value as Map)['level'], fallback: 'B'),
                asInt((e.value as Map)['count']),
              ),
        ]..sort((a, b) {
          final byLevel = AuditRule.rank(
            a.level,
          ).compareTo(AuditRule.rank(b.level));
          return byLevel != 0 ? byLevel : b.count.compareTo(a.count);
        });
    final rawSuspects = d['suspects'] is List
        ? d['suspects'] as List
        : const [];
    final at = d['at'];
    return ContentAudit(
      total: asInt(d['total']),
      rules: rules,
      suspects: [
        for (final e in rawSuspects)
          if (e is Map && asString(e['id']).isNotEmpty)
            AuditSuspect(
              id: asString(e['id']),
              rule: asString(e['rule']),
              level: asString(e['level'], fallback: 'A'),
              subject: asString(e['subject']),
              year: asIntOrNull(e['year']),
              detail: asString(e['detail']),
            ),
      ],
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

final contentAuditProvider = FutureProvider.autoDispose<ContentAudit?>((
  ref,
) async {
  final snap = await FirebaseFirestore.instance
      .doc('_meta/contentAudit')
      .get()
      .metered();
  return ContentAudit.fromDocument(snap.data());
});

/// How the past-question bank stands against the content rules, so the
/// team can see what to fix next and watch it fall (audit, section B).
class ContentQualityPanel extends ConsumerWidget {
  const ContentQualityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final audit = ref.watch(contentAuditProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Content quality',
          style: AppTheme.heading3.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 12),
        audit.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load the content audit.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (a) {
            if (a == null) {
              return Text(
                'No audit published yet. Run tools/admin/content_audit.js '
                '--cache --publish after a static-site refresh.',
                style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
              );
            }
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
                  for (final r in a.rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            r.level,
                            style: AppTheme.caption.copyWith(
                              color: r.level != 'B' && r.count > 0
                                  ? AppColors.wrong
                                  : palette.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.label,
                              style: AppTheme.bodyMd.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${r.count}',
                            style: AppTheme.bodyMd.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (a.suspects.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Check these first',
                      style: AppTheme.bodyMd.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final q in a.suspects.take(20))
                      InkWell(
                        onTap: () => context.push(adminFlagPath(q.id)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${q.level}  ${q.subject} ${q.year ?? ''} · '
                            '${q.rule.replaceAll('-', ' ')}: ${q.detail}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodyMd.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${a.total} past questions. S may have the wrong answer '
                    'marked, to check against the paper; A changes what a '
                    'question means; B is presentation. List any rule with '
                    'content_audit.js --cache --list=<rule>'
                    '${a.at == null ? '' : '; checked ${_ago(a.at!)}'}.',
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

// ─── Waitlist ───────────────────────────────────────────────────────

/// How many students tapped "Notify me" on each coming-soon subject —
/// what students are asking for next. One `count()` per planned subject.
class WaitlistPanel extends ConsumerWidget {
  const WaitlistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final live = {
      for (final s in ref.watch(subjectsProvider).asData?.value ?? const [])
        SubjectCatalog.slugify(s.name),
    };
    final planned = [
      for (final c in SubjectCatalog.all)
        if (!live.contains(c.slug)) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Waiting for a subject',
          style: AppTheme.heading3.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 12),
        if (planned.isEmpty)
          Text(
            'Every catalog subject is live.',
            style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in planned)
                Chip(
                  label: Text(
                    '${c.name}: '
                    '${ref.watch(waitlistCountProvider(c.slug)).asData?.value ?? '…'}',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ─── Traction ───────────────────────────────────────────────────────

/// The last fortnight of `metrics/{day}` (jobs.js --job=metrics): counts
/// only, never a name. Admins only (the rules agree). "Copy" puts a plain
/// table on the clipboard for a pitch deck or a funder's form.
final _tractionProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final snap = await FirebaseFirestore.instance
          .collection('metrics')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(14)
          .get()
          .metered();
      return [for (final d in snap.docs) d.data()];
    });

const _tractionColumns = [
  ('questionsAnswered', 'Answers'),
  ('drillLearners', 'Drillers'),
  ('newAccounts', 'Accounts'),
  ('newGuests', 'Guests'),
  ('examsSat', 'Exams'),
  ('challengesMade', 'Challenges'),
  ('roomsHosted', 'Rooms'),
];

/// The table as tab-separated text, newest day first.
String tractionTable(List<Map<String, dynamic>> days) => [
  ['Day', for (final c in _tractionColumns) c.$2].join('\t'),
  for (final d in days)
    [
      asString(d['day']),
      for (final c in _tractionColumns) '${d[c.$1] ?? ''}',
    ].join('\t'),
].join('\n');

class TractionPanel extends ConsumerWidget {
  const TractionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(_tractionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Traction',
                style: AppTheme.heading3.copyWith(color: palette.textPrimary),
              ),
            ),
            if (async.asData?.value case final days? when days.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tractionTable(days)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied as a table')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy for a pitch deck'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            "Couldn't load metrics.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (days) => days.isEmpty
              ? Text(
                  'No metrics yet. The nightly job writes yesterday\'s.',
                  style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Day')),
                      for (final c in _tractionColumns)
                        DataColumn(label: Text(c.$2), numeric: true),
                    ],
                    rows: [
                      for (final d in days)
                        DataRow(
                          cells: [
                            DataCell(Text(asString(d['day']))),
                            for (final c in _tractionColumns)
                              DataCell(Text('${d[c.$1] ?? '—'}')),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
