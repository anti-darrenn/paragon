import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/admin_flag_repository.dart';
import '../../../core/repositories/admin_question_repository.dart';
import '../../../core/repositories/learning_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/question_image.dart';
import '../../../core/widgets/ui/ui.dart';
import 'image_upload.dart' deferred as image_upload;
import 'question_widgets.dart' show subjectTopicsProvider;
import 'staff_profile.dart';

/// The founder's parts of the question workbench (2026-10-17): whether a
/// question is vetted, and where it sits and comes from. Reviewers never
/// see these; the rules (`foundersEdit`, `foundersCreate`) are the
/// protection.

/// Where a stored question sits, for the placement card.
QuestionPlacement placementOf(ReviewedQuestion q) => QuestionPlacement(
  subjectId: q.question.subjectId,
  topicId: q.question.topicId,
  source: q.question.source == 'waec' ? 'waec' : 'drill',
  year: q.question.year,
  sourceRef: q.sourceRef,
  imageId: q.question.imageId,
  explanationImageId: q.question.explanationImageId,
);

bool samePlacement(QuestionPlacement a, QuestionPlacement b) =>
    a.subjectId == b.subjectId &&
    a.topicId == b.topicId &&
    a.source == b.source &&
    (a.source == 'waec' ? a.year == b.year : true) &&
    a.sourceRef.trim() == b.sourceRef.trim() &&
    a.imageId == b.imageId &&
    a.explanationImageId == b.explanationImageId;

/// Pending or vetted, with the founder's two actions.
class VetBar extends ConsumerWidget {
  const VetBar({
    super.key,
    required this.question,
    required this.busy,
    required this.canApprove,
    required this.onApprove,
    required this.onUnvet,
    this.hasNext = false,
  });

  final ReviewedQuestion question;
  final bool busy;

  /// False while the draft has a blocking problem or no marked answer.
  final bool canApprove;
  final VoidCallback onApprove;
  final VoidCallback onUnvet;
  final bool hasNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vetted = question.vetted;
    final by = question.vettedBy;
    final name = by == null
        ? null
        : ref.watch(staffProfileProvider(by)).asData?.value?.displayName;
    final when = question.vettedAt;
    final colour = vetted ? AppColors.correct : AppColors.warning;
    return SurfaceCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            vetted ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            color: colour,
          ),
          Text(
            vetted
                ? 'Vetted${name == null ? '' : ' by $name'}'
                      '${when == null ? '' : ' on ${_day(when)}'}'
                : 'Pending: students do not see this question',
            style: AppTheme.bodyMd.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!vetted)
            FilledButton.icon(
              onPressed: busy || !canApprove ? null : onApprove,
              icon: const Icon(Icons.check_rounded),
              label: Text(hasNext ? 'Approve & next' : 'Approve'),
            ),
          if (vetted)
            OutlinedButton.icon(
              onPressed: busy ? null : onUnvet,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Send back to pending'),
            ),
          if (!vetted)
            Text(
              'Ctrl+Enter approves, saving any edits with it.',
              style: AppTheme.caption.copyWith(color: palette.textSecondary),
            ),
        ],
      ),
    );
  }

  static String _day(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
}

/// Subject, topic, past paper or practice, year, book reference, and the
/// two pictures: everything about a question that is not its text.
class PlacementCard extends ConsumerStatefulWidget {
  const PlacementCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final QuestionPlacement value;
  final ValueChanged<QuestionPlacement> onChanged;
  final bool enabled;

  @override
  ConsumerState<PlacementCard> createState() => _PlacementCardState();
}

class _PlacementCardState extends ConsumerState<PlacementCard> {
  late final _year = TextEditingController(
    text: widget.value.year?.toString() ?? '',
  );
  late final _ref = TextEditingController(text: widget.value.sourceRef);
  bool _uploading = false;

  @override
  void didUpdateWidget(PlacementCard old) {
    super.didUpdateWidget(old);
    final y = widget.value.year?.toString() ?? '';
    if (_year.text != y && int.tryParse(_year.text) != widget.value.year) {
      _year.text = y;
    }
    if (_ref.text.trim() != widget.value.sourceRef.trim()) {
      _ref.text = widget.value.sourceRef;
    }
  }

  @override
  void dispose() {
    _year.dispose();
    _ref.dispose();
    super.dispose();
  }

  QuestionPlacement _with({
    String? subjectId,
    String? topicId,
    String? source,
    int? Function()? year,
    String? sourceRef,
    String? Function()? imageId,
    String? Function()? explanationImageId,
  }) {
    final v = widget.value;
    return QuestionPlacement(
      subjectId: subjectId ?? v.subjectId,
      topicId: topicId ?? v.topicId,
      source: source ?? v.source,
      year: year == null ? v.year : year(),
      sourceRef: sourceRef ?? v.sourceRef,
      imageId: imageId == null ? v.imageId : imageId(),
      explanationImageId: explanationImageId == null
          ? v.explanationImageId
          : explanationImageId(),
      previousTopicId: v.previousTopicId,
    );
  }

  Future<void> _upload(bool worked) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _uploading = true);
    try {
      await image_upload.loadLibrary();
      final id = await image_upload.pickAndUploadLessonImage(
        db: FirebaseFirestore.instance,
        uid: uid,
      );
      if (id != null) {
        widget.onChanged(
          worked
              ? _with(explanationImageId: () => id)
              : _with(imageId: () => id),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't upload: $e")));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final v = widget.value;
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final topics =
        ref.watch(subjectTopicsProvider(v.subjectId)).asData?.value ?? const [];
    final enabled = widget.enabled && !_uploading;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where it sits',
            style: AppTheme.label.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: subjects.any((s) => s.id == v.subjectId)
                ? v.subjectId
                : null,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: [
              for (final s in subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: !enabled
                ? null
                : (id) {
                    if (id == null || id == v.subjectId) return;
                    // A new subject needs a topic of its own.
                    widget.onChanged(_with(subjectId: id, topicId: ''));
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('topics-${v.subjectId}'),
            initialValue: topics.any((t) => t.id == v.topicId)
                ? v.topicId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Topic'),
            items: [
              for (final t in topics)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(t.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: !enabled
                ? null
                : (id) {
                    if (id != null) widget.onChanged(_with(topicId: id));
                  },
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'waec', label: Text('WAEC past paper')),
              ButtonSegment(value: 'drill', label: Text('Practice')),
            ],
            selected: {v.source},
            onSelectionChanged: !enabled
                ? null
                : (s) => widget.onChanged(_with(source: s.first)),
          ),
          if (v.source == 'waec') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year of the paper'),
              onChanged: (t) =>
                  widget.onChanged(_with(year: () => int.tryParse(t.trim()))),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _ref,
            enabled: enabled,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Source (optional)',
              hintText: 'e.g. New General Mathematics SS2, p. 114',
            ),
            onChanged: (t) => widget.onChanged(_with(sourceRef: t)),
          ),
          const SizedBox(height: 8),
          _ImageRow(
            label: 'Diagram',
            assetId: v.imageId,
            enabled: enabled,
            uploading: _uploading,
            onUpload: () => _upload(false),
            onRemove: () => widget.onChanged(_with(imageId: () => null)),
          ),
          _ImageRow(
            label: 'Worked-answer picture',
            assetId: v.explanationImageId,
            worked: true,
            enabled: enabled,
            uploading: _uploading,
            onUpload: () => _upload(true),
            onRemove: () =>
                widget.onChanged(_with(explanationImageId: () => null)),
          ),
        ],
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.label,
    required this.assetId,
    required this.enabled,
    required this.uploading,
    required this.onUpload,
    required this.onRemove,
    this.worked = false,
  });

  final String label;
  final String? assetId;
  final bool enabled;
  final bool uploading;
  final bool worked;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMd.copyWith(color: palette.textPrimary),
              ),
            ),
            if (uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              TextButton.icon(
                onPressed: enabled ? onUpload : null,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(assetId == null ? 'Upload' : 'Replace'),
              ),
              if (assetId != null)
                TextButton(
                  onPressed: enabled ? onRemove : null,
                  child: const Text('Remove'),
                ),
            ],
          ],
        ),
        if (assetId != null)
          worked
              ? QuestionImage.workedAnswer(assetId: assetId)
              : QuestionImage(assetId: assetId),
      ],
    );
  }
}
