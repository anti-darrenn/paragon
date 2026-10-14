import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/feature_access.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/course_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/rooms/room_repository.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nav/back_navigation.dart';
import '../../core/widgets/ui/ui.dart';

/// `/rooms/new`: pick a topic and a length, get a code. Accounts only.
class NewRoomScreen extends ConsumerStatefulWidget {
  const NewRoomScreen({super.key});

  @override
  ConsumerState<NewRoomScreen> createState() => _NewRoomScreenState();
}

class _NewRoomScreenState extends ConsumerState<NewRoomScreen> {
  String? _subjectId;
  int _count = 10;
  bool _busy = false;
  String? _error;

  Future<void> _create(CourseTopic topic) async {
    final user = ref.read(currentUserProvider);
    final subjectId = _subjectId;
    if (user == null || subjectId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pool = await ref.read(drillQuestionsProvider(topic.id).future);
      final ids = [
        for (final q in ([...pool]..shuffle()).take(_count)) q.id,
      ];
      if (ids.isEmpty) throw StateError('no questions');
      final code = await ref
          .read(roomRepositoryProvider)
          .create(
            hostUid: user.uid,
            subjectId: subjectId,
            topicId: topic.id,
            topicName: topic.name,
            questionIds: ids,
          );
      ref.read(analyticsProvider).roomHosted(questions: ids.length);
      if (mounted) context.go('/rooms/$code/host');
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't make the room. Try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canUse(Feature.hostRoom, isGuest: ref.watch(isGuestProvider))) {
      return Scaffold(
        appBar: const ParagonAppBar(title: Text('Host a quiz')),
        body: EmptyState(
          icon: Icons.groups_outlined,
          title: 'Hosting needs an account',
          message:
              'Anyone can join a quiz as a guest; making one needs a '
              'free account.',
          action: ElevatedButton(
            onPressed: () => context.push('/account/upgrade'),
            child: const Text('Make an account'),
          ),
        ),
      );
    }
    final subjects = ref.watch(subjectsProvider).asData?.value ?? const [];
    final subjectId = _subjectId;
    return Scaffold(
      appBar: const ParagonAppBar(title: Text('Host a quiz')),
      body: PageBody(
        children: [
          const PageIntro(
            title: 'Host a live quiz',
            subtitle:
                'Everyone answers the same question at once on their own '
                'phone. One point a right answer. Rooms close after a day.',
          ),
          const SectionHeader('Length'),
          Wrap(
            spacing: 8,
            children: [
              for (final n in const [5, 10, 20])
                ChoiceChip(
                  label: Text('$n questions'),
                  selected: _count == n,
                  onSelected: (_) => setState(() => _count = n),
                ),
            ],
          ),
          const SizedBox(height: kSectionGap),
          const SectionHeader('Subject'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subjects)
                ChoiceChip(
                  label: Text(s.name),
                  selected: subjectId == s.id,
                  onSelected: (_) => setState(() => _subjectId = s.id),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppTheme.bodyMd),
          ],
          if (subjectId != null) ...[
            const SizedBox(height: kSectionGap),
            const SectionHeader('Topic'),
            ref
                .watch(courseProvider(subjectId))
                .when(
                  loading: () => const SkeletonPage(
                    title: false,
                    count: 4,
                    cardHeight: 48,
                  ),
                  error: (_, _) => const Text("Couldn't load the topics."),
                  data: (course) => RowGroup(
                    children: [
                      for (final m in course.modules)
                        for (final t in m.topics)
                          if (!t.isPlaceholder && t.counts.servable >= 5)
                            ListRow(
                              title: t.name,
                              subtitle: m.name,
                              onTap: _busy ? null : () => _create(t),
                            ),
                    ],
                  ),
                ),
          ],
          const SizedBox(height: 12),
          Text(
            'Nothing from a quiz goes into anyone\'s practice record.',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
