import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/read_meter.dart';
import '../../../core/insights/examiner_insight.dart';
import '../../../core/models/firestore_parsing.dart';
import '../../../core/models/question.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/full_latex_view.dart';
import '../../../core/widgets/nav/back_navigation.dart';
import '../../../core/widgets/ui/ui.dart';

/// `/admin/insight/:id`: write "What examiners saw" for a question (its
/// id) or "Where students lose marks" for a topic (`topic_<topicId>`).
///
/// Paste the report's text into the checking box (it is never saved) and
/// the editor measures how much of your summary is copied from it; over
/// [kMaxSharedRun] words in a row, it will not publish. Writers save
/// drafts; reviewers publish. A published insight reaches students after
/// the next `jobs.js --job=insights` run stamps its question or topic.
class InsightEditorScreen extends ConsumerStatefulWidget {
  const InsightEditorScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<InsightEditorScreen> createState() =>
      _InsightEditorScreenState();
}

class _InsightEditorScreenState extends ConsumerState<InsightEditorScreen> {
  final _summary = TextEditingController();
  final _tip = TextEditingController();
  final _year = TextEditingController();
  final _ref = TextEditingController();
  final _years = TextEditingController();
  final _source = TextEditingController();
  int? _wrong;
  String _status = 'draft';

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _subjectId = '';
  Question? _question;
  String _topicName = '';

  bool get _isTopic => widget.id.startsWith('topic_');
  String get _topicId => widget.id.substring('topic_'.length);

  @override
  void initState() {
    super.initState();
    _load();
    for (final c in [_summary, _source]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_summary, _tip, _year, _ref, _years, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    try {
      if (_isTopic) {
        final t = await db.collection('topics').doc(_topicId).get().metered();
        _subjectId = asString(t.data()?['subjectId']);
        _topicName = asString(t.data()?['name']);
      } else {
        final q = await db
            .collection('questions')
            .doc(widget.id)
            .get()
            .metered();
        if (q.exists) {
          _question = Question.fromFirestore(q);
          _subjectId = _question!.subjectId;
        }
      }
      final existing = await ref.read(insightRepositoryProvider).any(widget.id);
      if (existing != null) {
        _summary.text = existing.summary;
        _tip.text = existing.tip;
        _year.text = existing.reportYear == 0 ? '' : '${existing.reportYear}';
        _ref.text = existing.reportRef;
        _years.text = existing.years.join(', ');
        _wrong = existing.commonWrongOption;
        _status = existing.status;
      }
    } catch (e) {
      _error = "Couldn't load: $e";
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _sharedRun => longestSharedRun(_summary.text, _source.text);

  Future<void> _save(String status) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final year = int.tryParse(_year.text.trim()) ?? 0;
    if (_summary.text.trim().isEmpty || _ref.text.trim().isEmpty) {
      setState(
        () => _error = 'A summary and the report reference are both needed.',
      );
      return;
    }
    if (status == 'published' && _sharedRun >= kMaxSharedRun) {
      setState(
        () => _error =
            '$_sharedRun words in a row match the report. Put it in your own '
            'words before publishing.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(insightRepositoryProvider)
          .save(
            widget.id,
            ExaminerInsight(
              id: widget.id,
              kind: _isTopic ? 'topic' : 'question',
              subjectId: _subjectId,
              questionId: _isTopic ? '' : widget.id,
              topicId: _isTopic ? _topicId : (_question?.topicId ?? ''),
              summary: _summary.text.trim(),
              commonWrongOption: _isTopic ? null : _wrong,
              tip: _tip.text.trim(),
              reportYear: year,
              reportRef: _ref.text.trim(),
              years: [
                for (final y in _years.text.split(RegExp(r'[,\s]+')))
                  ?int.tryParse(y),
              ],
              status: status,
            ),
            uid: uid,
          );
      if (mounted) {
        setState(() => _status = status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'published'
                  ? 'Published. Students see it after the next nightly run.'
                  : 'Draft saved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't save: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final role = ref.watch(staffAccessProvider).roleIn(_subjectId);
    final run = _sharedRun;
    return Scaffold(
      appBar: ParagonAppBar(
        title: Text(
          _isTopic ? 'Where students lose marks' : 'What examiners saw',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              children: [
                if (_isTopic)
                  PageIntro(title: _topicName.isEmpty ? _topicId : _topicName)
                else if (_question != null) ...[
                  FullLatexView(latex: _question!.text),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _question!.options.length; i++)
                    Text(
                      '${String.fromCharCode(65 + i)}. ${_question!.options[i]}'
                      '${i == _question!.correctIndex ? '  ✓' : ''}',
                      style: AppTheme.bodyMd,
                    ),
                  const SizedBox(height: 16),
                ] else
                  const Text('No question has that id.'),
                Text(
                  'Status: $_status',
                  style: AppTheme.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _summary,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'What candidates did, in your own words',
                  ),
                ),
                if (!_isTopic)
                  DropdownButtonFormField<int?>(
                    initialValue: _wrong,
                    decoration: const InputDecoration(
                      labelText: 'The wrong option most candidates chose',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Not stated'),
                      ),
                      for (var i = 0; i < (_question?.options.length ?? 4); i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(String.fromCharCode(65 + i)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _wrong = v),
                  ),
                TextField(
                  controller: _tip,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Tip (optional)',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Report year',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ref,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText:
                              'Reference, e.g. WASSCE May/June 2018, Q12',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isTopic)
                  TextField(
                    controller: _years,
                    decoration: const InputDecoration(
                      labelText:
                          'Years it was reported (e.g. 2016, 2018, 2021)',
                    ),
                  ),
                const SizedBox(height: kSectionGap),
                const SectionHeader(
                  'Originality check',
                  subtitle:
                      'Paste the report\'s text here to compare. It is not saved.',
                ),
                TextField(
                  controller: _source,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Report text, for checking only',
                  ),
                ),
                const SizedBox(height: 6),
                if (_source.text.trim().isNotEmpty)
                  Text(
                    run >= kMaxSharedRun
                        ? '$run words in a row match the report: too close to publish.'
                        : 'Longest shared run: $run words. Fine.',
                    style: AppTheme.bodyMd.copyWith(
                      color: run >= kMaxSharedRun
                          ? AppColors.wrong
                          : AppColors.correct,
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: AppTheme.bodyMd.copyWith(color: context.palette.dangerFg),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving || !role.canWrite
                          ? null
                          : () => _save('draft'),
                      child: const Text('Save draft'),
                    ),
                    if (role.canReview)
                      ElevatedButton(
                        onPressed: _saving ? null : () => _save('published'),
                        child: const Text('Publish'),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
