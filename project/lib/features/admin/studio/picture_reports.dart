import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/read_meter.dart';
import '../../../core/models/firestore_parsing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/avatar_photo_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui/ui.dart';

/// Reported profile photos, one row per account with an open report
/// (2026-10-17). "Remove" deletes the photo and blocks new ones
/// (`avatarBlocks/{uid}`), closing the reports as fixed, in one batch;
/// "Keep" dismisses them. Reviewers only, as the rules require.
///
/// Reads the 100 most recent photo reports: `orderBy('avatarUid')` returns
/// only reports that have the field, so question and lesson reports never
/// load here.
class PictureReport {
  const PictureReport({required this.avatarUid, required this.reportIds});
  final String avatarUid;
  final List<String> reportIds;
}

final pictureReportsProvider = FutureProvider.autoDispose<List<PictureReport>>((
  ref,
) async {
  final snap = await FirebaseFirestore.instance
      .collection('flags')
      .orderBy('avatarUid')
      .limit(100)
      .get()
      .metered();
  final open = <String, List<String>>{};
  for (final d in snap.docs) {
    final data = d.data();
    final status = asString(data['status'], fallback: 'open');
    if (status != 'open') continue;
    final uid = asString(data['avatarUid']);
    if (uid.isEmpty) continue;
    (open[uid] ??= []).add(d.id);
  }
  return [
    for (final e in open.entries)
      PictureReport(avatarUid: e.key, reportIds: e.value),
  ]..sort((a, b) => b.reportIds.length.compareTo(a.reportIds.length));
});

class PictureReportsPanel extends ConsumerStatefulWidget {
  const PictureReportsPanel({super.key});

  @override
  ConsumerState<PictureReportsPanel> createState() =>
      _PictureReportsPanelState();
}

class _PictureReportsPanelState extends ConsumerState<PictureReportsPanel> {
  String? _busy;

  Future<void> _resolve(PictureReport r, {required bool remove}) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _busy = r.avatarUid);
    final db = FirebaseFirestore.instance;
    try {
      final batch = db.batch();
      if (remove) {
        batch.delete(db.doc('avatarImages/${r.avatarUid}'));
        batch.set(db.doc('avatarBlocks/${r.avatarUid}'), {
          'by': uid,
          'at': FieldValue.serverTimestamp(),
          'reason': 'Removed after a report',
        });
      }
      for (final id in r.reportIds) {
        batch.update(db.doc('flags/$id'), {
          'status': remove ? 'fixed' : 'dismissed',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': uid,
        });
      }
      await batch.commit();
      ref.invalidate(pictureReportsProvider);
      ref.invalidate(avatarPhotoProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reports = ref.watch(pictureReportsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          'Reported photos',
          subtitle:
              'Profile photos students reported in quiz rooms. Removing one '
              'also stops that account adding another.',
        ),
        reports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            "Couldn't load reported photos.\n$e",
            style: AppTheme.bodyMd.copyWith(color: AppColors.wrong),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No photo reports waiting.',
                style: AppTheme.bodyMd.copyWith(color: palette.textSecondary),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      child: Row(
                        children: [
                          _Photo(uid: r.avatarUid),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '${r.reportIds.length} report'
                              '${r.reportIds.length == 1 ? '' : 's'}',
                              style: AppTheme.bodyMd.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          if (_busy == r.avatarUid)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            TextButton(
                              onPressed: () => _resolve(r, remove: false),
                              child: const Text('Keep'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.wrong,
                              ),
                              onPressed: () => _resolve(r, remove: true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(avatarPhotoProvider('$uid@review')).asData?.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        height: 96,
        child: bytes == null
            ? ColoredBox(
                color: context.palette.track,
                child: const Center(child: Text('Already removed')),
              )
            : Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}
