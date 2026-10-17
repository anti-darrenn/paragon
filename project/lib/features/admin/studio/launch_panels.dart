import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../core/repositories/admin_flag_repository.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/widgets/ui/ui.dart';
import 'question_widgets.dart';

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
    this.byRule = const {},
    this.at,
    this.dataAt,
  });
  final int total;

  /// Level S, then A, then B, each with the largest counts first.
  final List<AuditRule> rules;

  /// Questions to check first, in the audit's order (suspects, then A).
  final List<AuditSuspect> suspects;

  /// Every rule's question ids (`byRule`, capped per rule), so a count can
  /// open the questions behind it. Empty for an audit published before
  /// 2026-10-17.
  final Map<String, List<String>> byRule;
  final DateTime? at;

  /// When the audited questions were read. A run from the site cache reads
  /// data hours or days older than [at]; null on audits before 2026-10-17.
  final DateTime? dataAt;

  /// Whether the audit's [rule] finding on [q] is out of date: a person
  /// saved the question after the audit read it, or marked that rule
  /// checked. Until 2026-10-17 a fixed question stayed flagged until
  /// someone re-ran the audit by hand, which looked like the fix had not
  /// taken.
  bool isCleared(ReviewedQuestion q, String rule) {
    if (q.auditDismissed.contains(rule)) return true;
    final read = dataAt ?? at;
    final touched = q.lastTouched;
    return read != null && touched != null && touched.isAfter(read);
  }

  /// What the audit found on one question: the rule, its level, and the
  /// detail when the audit kept one (suspects and level A).
  List<({String rule, String level, String detail})> findingsFor(String id) {
    final level = {for (final r in rules) r.rule: r.level};
    final detail = {
      for (final s in suspects)
        if (s.id == id) s.rule: s.detail,
    };
    return [
      for (final e in byRule.entries)
        if (e.value.contains(id))
          (
            rule: e.key,
            level: level[e.key] ?? 'B',
            detail: detail[e.key] ?? '',
          ),
    ]..sort(
      (a, b) => AuditRule.rank(a.level).compareTo(AuditRule.rank(b.level)),
    );
  }

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
    final rawByRule = d['byRule'] is Map ? d['byRule'] as Map : const {};
    final at = d['at'];
    final dataAt = d['dataAt'];
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
      byRule: {
        for (final e in rawByRule.entries)
          e.key.toString(): [
            for (final id in asStringList(e.value))
              if (id.isNotEmpty) id,
          ],
      },
      at: at is Timestamp ? at.toDate() : null,
      dataAt: dataAt is Timestamp ? dataAt.toDate() : null,
    );
  }
}

final contentAuditProvider = FutureProvider<ContentAudit?>((ref) async {
  final snap = await FirebaseFirestore.instance
      .doc('_meta/contentAudit')
      .get()
      .metered();
  return ContentAudit.fromDocument(snap.data());
});

/// The questions behind one audit rule, a page at a time; keyed by the
/// ids joined with commas.
final _auditQuestionsProvider = FutureProvider.autoDispose
    .family<List<ReviewedQuestion>, String>(
      (ref, joined) =>
          ref.read(adminQuestionRepositoryProvider).byIds(joined.split(',')),
    );

/// What the content rules say about the past-question bank, each rule
/// opening onto its questions so they can be fixed on the spot.
class ContentQualityPanel extends ConsumerWidget {
  const ContentQualityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final audit = ref.watch(contentAuditProvider);
    return audit.when(
      loading: () => const StudioListSkeleton(),
      error: (e, _) => Text(
        "Couldn't load the content audit.\n$e",
        style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
      ),
      data: (a) {
        if (a == null) {
          return const EmptyState(
            icon: Icons.manage_search_rounded,
            title: 'No audit published yet',
            message:
                'Run node tools/admin/content_audit.js --cache --publish after '
                'a static-site refresh.',
          );
        }
        final groups = [
          ('S', 'Answer may be wrong', 'Check against the original paper.'),
          (
            'A',
            'Changes what a question means',
            'A student can be marked wrong for a right answer.',
          ),
          ('B', 'Presentation', 'Readable, but untidy or incomplete.'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${groupThousandsLocal(a.total)} past questions checked'
              '${a.at == null ? '' : ' ${_ago(a.at!)}'}. Open a rule to see its '
              'questions; open a question to fix it.',
              style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
            ),
            if (a.byRule.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'This audit was published before questions could be listed. '
                'Publish it again to open the questions behind each count.',
                style: AppTheme.caption.copyWith(color: AppColors.warning),
              ),
            ],
            for (final (level, title, help) in groups)
              if (a.rules.any((r) => r.level == level && r.count > 0)) ...[
                const SizedBox(height: 20),
                SectionHeader(title, subtitle: help),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final r in a.rules.where(
                        (r) => r.level == level && r.count > 0,
                      ))
                        _RuleTile(rule: r, ids: a.byRule[r.rule] ?? const []),
                    ],
                  ),
                ),
              ],
          ],
        );
      },
    );
  }
}

class _RuleTile extends ConsumerStatefulWidget {
  const _RuleTile({required this.rule, required this.ids});
  final AuditRule rule;
  final List<String> ids;

  @override
  ConsumerState<_RuleTile> createState() => _RuleTileState();
}

class _RuleTileState extends ConsumerState<_RuleTile> {
  static const _page = 8;
  bool _open = false;
  int _shown = _page;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final r = widget.rule;
    final colour = switch (r.level) {
      'S' => AppColors.wrong,
      'A' => AppColors.warning,
      _ => palette.textSecondary,
    };
    final ids = widget.ids;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: ids.isEmpty ? null : () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colour,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.label[0].toUpperCase() + r.label.substring(1),
                    style: AppTheme.bodyMd.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${r.count}',
                  style: AppTheme.bodyMd.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: ids.isEmpty ? palette.border : palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_open) _questions(ids),
        Divider(height: 1, color: palette.border.withAlpha(150)),
      ],
    );
  }

  Widget _questions(List<String> ids) {
    final shown = ids.take(_shown).toList();
    final async = ref.watch(_auditQuestionsProvider(shown.join(',')));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: async.when(
        loading: () => const StudioListSkeleton(count: 2),
        error: (e, _) => Text(
          "Couldn't load these questions.\n$e",
          style: AppTheme.caption.copyWith(color: AppColors.wrong),
        ),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final q in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: QuestionListCard(
                  question: q,
                  findings: [(widget.rule.rule, widget.rule.level)],
                  onTap: () async {
                    await openQuestion(
                      context,
                      ref,
                      q.question.id,
                      list: ids,
                    );
                    // What was fixed there shows as fixed here.
                    ref.invalidate(_auditQuestionsProvider);
                  },
                ),
              ),
            if (ids.length > _shown)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _shown += _page),
                  child: Text('Show more (${ids.length - _shown} left)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String groupThousandsLocal(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

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
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final live = {for (final s in subjects) SubjectCatalog.slugify(s.name)};
    // Live for practice, with no past paper to sit yet (Plan v2 7.7).
    final noPapers = [
      for (final s in subjects)
        if (s.counts.isSplit && s.pastQuestionCount == 0) s.name,
    ];
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
        if (noPapers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Waiting for WAEC past papers',
            style: AppTheme.bodyMd.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final name in noPapers)
                Chip(
                  label: Text(
                    '$name: '
                    '${ref.watch(waitlistCountProvider(waecPapersWaitlistKey(SubjectCatalog.slugify(name)))).asData?.value ?? '…'}',
                  ),
                ),
            ],
          ),
        ],
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
