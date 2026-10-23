import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/subject_catalog.dart';
import '../../../core/data/read_meter.dart';
import '../../../core/models/subject.dart';
import '../../../core/models/topic.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/admin_flag_repository.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/search/search.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/web/browser.dart';
import '../../../core/widgets/ui/ui.dart';
import 'launch_panels.dart' show contentAuditProvider;
import 'question_widgets.dart';
import 'subject_picker.dart';

/// The studio's question selector: find any question by its words, its
/// paper, or its topic, then open it in the workbench.
///
/// - **Search** reads `/past-questions/search.json`, the file the static
///   site build writes, so finding a past question by its text costs no
///   Firestore reads. A pasted question id opens that question.
/// - **Browse** is a Firestore query a page at a time: a past paper by
///   year, or a topic's past or practice questions, live or hidden.
class QuestionBrowser extends ConsumerStatefulWidget {
  const QuestionBrowser({super.key});

  @override
  ConsumerState<QuestionBrowser> createState() => _QuestionBrowserState();
}

/// One row of `search.json`: `[subject slug, year, stem, page dir, id?]`.
/// The full id is the fifth entry since 2026-10-17; older files carry only
/// the page's 10-character prefix.
typedef _SearchRow = ({
  String slug,
  int year,
  String stem,
  String dir,
  String? id,
});

final _searchRowsProvider = FutureProvider<List<_SearchRow>>((ref) async {
  final text = await fetchText('/past-questions/search.json');
  if (text == null) return const [];
  try {
    final d = jsonDecode(text) as Map<String, dynamic>;
    return [
      for (final r in (d['questions'] as List? ?? const []))
        if (r is List && r.length >= 4)
          (
            slug: '${r[0]}',
            year: int.tryParse('${r[1]}') ?? 0,
            stem: '${r[2]}',
            dir: '${r[3]}',
            id: r.length >= 5 ? '${r[4]}' : null,
          ),
    ];
  } on Object {
    return const [];
  }
});

final _idPattern = RegExp(r'^[A-Za-z0-9]{20}$');

class _QuestionBrowserState extends ConsumerState<QuestionBrowser> {
  final _search = TextEditingController();
  String? _subjectId;
  QuestionKind _kind = QuestionKind.past;
  int? _year;
  String? _topicId;
  bool _live = true;

  final List<ReviewedQuestion> _rows = [];

  /// Questions that also count for the chosen topic (main topic elsewhere).
  List<ReviewedQuestion> _also = const [];
  DocumentSnapshot? _last;
  bool _hasMore = false;
  bool _loading = false;
  Object? _error;
  QuestionFilter? _loaded;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  QuestionFilter? get _filter => _subjectId == null
      ? null
      : QuestionFilter(
          subjectId: _subjectId!,
          kind: _kind,
          year: _topicId == null ? _year : null,
          topicId: _topicId,
          live: _live,
        );

  /// Opens a question, then re-reads the rows on screen: a fix made in the
  /// workbench shows at once, without losing the page. Until 2026-10-17 the
  /// list kept the old stem and findings until the filter changed.
  Future<void> _open(String id, List<String> ids) async {
    await openQuestion(context, ref, id, list: ids);
    if (!mounted || (_rows.isEmpty && _also.isEmpty)) return;
    try {
      final fresh = {
        for (final q in await ref.read(adminQuestionRepositoryProvider).byIds([
          for (final q in [..._rows, ..._also]) q.question.id,
        ]))
          q.question.id: q,
      };
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _rows.length; i++) {
          _rows[i] = fresh[_rows[i].question.id] ?? _rows[i];
        }
        _also = [for (final q in _also) fresh[q.question.id] ?? q];
      });
    } catch (_) {
      // The old rows stay; a filter change reloads them.
    }
  }

  Future<void> _fetch({bool more = false}) async {
    final f = _filter;
    if (f == null || !f.isQueryable) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _rows.clear();
        _also = const [];
        _last = null;
      }
    });
    try {
      final page = await ref
          .read(adminQuestionRepositoryProvider)
          .browse(f, after: more ? _last : null);
      if (!mounted || _filter != f) return;
      setState(() {
        _rows.addAll(page.questions);
        if (!more) _also = page.also;
        _last = page.last;
        _hasMore = page.hasMore;
        _loaded = f;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed(VoidCallback update) {
    setState(update);
    _fetch();
  }

  Future<void> _openSearchRow(_SearchRow row) async {
    var id = row.id;
    if (id == null || id.isEmpty) {
      // An older search.json: resolve the page's 10-character prefix.
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .orderBy(FieldPath.documentId)
          .startAt([row.dir])
          .endAt(['${row.dir}'])
          .limit(1)
          .get()
          .metered();
      if (snap.docs.isEmpty) return;
      id = snap.docs.first.id;
    }
    if (mounted) openQuestion(context, ref, id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final access = ref.watch(staffAccessProvider);
    final subjects = [...?ref.watch(subjectsProvider).asData?.value]
      ..sort(
        (a, b) => (access.covers(a.id) ? 0 : 1).compareTo(
          access.covers(b.id) ? 0 : 1,
        ),
      );
    if (_subjectId == null && subjects.isNotEmpty) {
      _subjectId = subjects.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeDefault());
    }
    final subject = subjects.where((s) => s.id == _subjectId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchBox(palette),
        const SizedBox(height: 16),
        if (_search.text.trim().length >= 3)
          _searchResults(subject)
        else ...[
          _filters(subjects, subject),
          const SizedBox(height: 16),
          _results(),
        ],
      ],
    );
  }

  /// Opens on the newest paper of the first subject, so the list is never
  /// blank on arrival.
  Future<void> _maybeDefault() async {
    if (_year != null || _topicId != null || _subjectId == null) return;
    try {
      final (_, max) = await ref.read(
        waecYearRangeProvider(_subjectId!).future,
      );
      if (mounted && _year == null) _changed(() => _year = max);
    } catch (_) {}
  }

  Widget _searchBox(AppPalette palette) => TextField(
    controller: _search,
    onChanged: (v) {
      setState(() {});
      if (_idPattern.hasMatch(v.trim())) openQuestion(context, ref, v.trim());
    },
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded),
      hintText: 'Search past questions by their words, or paste a question id',
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear',
              onPressed: () => setState(_search.clear),
              icon: const Icon(Icons.close_rounded),
            ),
    ),
  );

  Widget _filters(List<Subject> subjects, Subject? subject) {
    final subjectId = _subjectId;
    final years = subjectId == null
        ? null
        : ref.watch(waecYearRangeProvider(subjectId)).asData?.value;
    final topics = subjectId == null
        ? const <Topic>[]
        : ref.watch(subjectTopicsProvider(subjectId)).asData?.value ??
              const <Topic>[];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Its own line: the shared studio picker, chips not a dropdown.
        SizedBox(
          width: double.infinity,
          child: StudioSubjectPicker(
          subjects: subjects,
          selected: subjectId,
          onSelected: (v) => _changed(() {
            _subjectId = v;
            _year = null;
            _topicId = null;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _maybeDefault(),
            );
          }),
          ),
        ),
        SegmentedButton<QuestionKind>(
          segments: [
            for (final k in QuestionKind.values)
              ButtonSegment(value: k, label: Text(k.label)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => _changed(() {
            _kind = s.first;
            // A practice bank is browsed by topic: there are no papers.
            if (_kind == QuestionKind.practice && _topicId == null) {
              _topicId = topics.firstOrNull?.id;
            }
          }),
        ),
        if (_kind == QuestionKind.past && years != null)
          _Picker<int?>(
            label: 'Paper',
            value: _topicId == null ? _year : null,
            items: [for (var y = years.$2; y >= years.$1; y--) (y, 'WAEC $y')],
            onChanged: (v) => _changed(() {
              _year = v;
              _topicId = null;
            }),
          ),
        _Picker<String?>(
          label: 'Topic',
          value: _topicId,
          items: [
            if (_kind == QuestionKind.past) (null, 'Any topic'),
            for (final t in topics) (t.id, t.name),
          ],
          onChanged: (v) => _changed(() => _topicId = v),
        ),
        FilterChip(
          label: const Text('Hidden from students'),
          selected: !_live,
          onSelected: (v) => _changed(() => _live = !v),
        ),
      ],
    );
  }

  Widget _results() {
    final f = _filter;
    if (f == null) return const StudioListSkeleton();
    if (!f.isQueryable) {
      return const EmptyState(
        icon: Icons.filter_list_rounded,
        title: 'Pick a paper or a topic',
        message:
            'A subject holds thousands of questions; choose a WAEC paper or a '
            'topic to list them.',
      );
    }
    if (_error != null) {
      return Text(
        "Couldn't load these questions.\n$_error",
        style: AppTheme.bodyMd.copyWith(color: context.palette.dangerFg),
      );
    }
    if (_loading && _rows.isEmpty) return const StudioListSkeleton();
    if (_rows.isEmpty && _loaded == f) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: f.live ? 'No questions here' : 'Nothing hidden here',
        message: f.live
            ? 'Try another paper or topic.'
            : 'No question in this paper or topic is hidden from students.',
      );
    }

    final audit = ref.watch(contentAuditProvider).asData?.value;
    final byId = <String, List<(String, String)>>{};
    if (audit != null) {
      final level = {for (final r in audit.rules) r.rule: r.level};
      for (final e in audit.byRule.entries) {
        for (final id in e.value) {
          (byId[id] ??= []).add((e.key, level[e.key] ?? 'B'));
        }
      }
    }
    final reports = <String, int>{
      for (final r
          in ref.watch(adminFlagQueueProvider).asData?.value ??
              const <FlaggedQuestion>[])
        r.questionId: r.openReports.length,
    };
    final ids = [
      for (final q in _rows) q.question.id,
      for (final q in _also) q.question.id,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_rows.length}${_hasMore ? '+' : ''} questions',
          style: AppTheme.caption.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final q in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: QuestionListCard(
              question: q,
              findings: (byId[q.question.id] ?? const [])
                  .where((f) => f.$1 != 'missing-explanation')
                  .toList(),
              openReports: reports[q.question.id] ?? 0,
              onTap: () => _open(q.question.id, ids),
            ),
          ),
        if (_also.isNotEmpty) ...[
          const SizedBox(height: 12),
          const GroupLabel('Also count for this topic'),
          for (final q in _also)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuestionListCard(
                question: q,
                findings: (byId[q.question.id] ?? const [])
                    .where((f) => f.$1 != 'missing-explanation')
                    .toList(),
                openReports: reports[q.question.id] ?? 0,
                onTap: () => _open(q.question.id, ids),
              ),
            ),
        ],
        if (_hasMore)
          Center(
            child: OutlinedButton(
              onPressed: _loading ? null : () => _fetch(more: true),
              child: Text(_loading ? 'Loading…' : 'Load more'),
            ),
          ),
      ],
    );
  }

  Widget _searchResults(Subject? subject) {
    final rows = ref.watch(_searchRowsProvider);
    final palette = context.palette;
    return rows.when(
      loading: () => const StudioListSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Search needs the public site',
            message:
                'Searching reads /past-questions/search.json, which exists on '
                'the deployed site. Browse by paper or topic instead.',
          );
        }
        final words = normalizeForSearch(
          _search.text,
        ).split(' ').where((w) => w.isNotEmpty).toList();
        final slug = subject == null
            ? null
            : SubjectCatalog.slugify(subject.name);
        final hits = [
          for (final r in all)
            if ((slug == null || r.slug == slug) &&
                words.every(normalizeForSearch(r.stem).contains))
              r,
        ]..sort((a, b) => b.year.compareTo(a.year));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hits.isEmpty
                  ? 'No ${subject?.name ?? ''} past question has those words.'
                  : '${hits.length} past questions${subject == null ? '' : ' in ${subject.name}'}'
                        '${hits.length > 40 ? ', newest 40 shown' : ''}',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            RowGroup(
              children: [
                for (final r in hits.take(40))
                  ListRow(
                    icon: Icons.quiz_outlined,
                    iconColor: AppColors.primary,
                    title: r.stem,
                    subtitle: 'WAEC ${r.year}',
                    onTap: () => _openSearchRow(r),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A labelled dropdown in the filter bar.
class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final has = items.any((i) => i.$1 == value);
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: DropdownButton<T>(
              value: has ? value : null,
              isDense: true,
              isExpanded: false,
              underline: const SizedBox.shrink(),
              dropdownColor: palette.surface,
              hint: const Text('Choose'),
              items: [
                for (final (v, text) in items)
                  DropdownMenuItem<T>(
                    value: v,
                    child: Text(text, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => onChanged(v as T),
            ),
          ),
        ],
      ),
    );
  }
}
