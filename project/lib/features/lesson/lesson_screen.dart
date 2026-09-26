import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/learn/lesson_progress.dart';
import '../../core/models/learn_resource.dart';
import '../../core/models/topic.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/repositories/learn_progress_repository.dart';
import '../../core/repositories/learn_repository.dart';
import '../../core/repositories/learning_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_top_nav.dart';
import '../../core/study/study_dock.dart';
import '../../core/study/study_tool.dart';
import 'article_pane.dart';
import 'exercise_pane.dart';
import 'lesson_sidebar.dart';
import 'video_pane.dart';
import '../../core/theme/app_palette.dart';

/// Path of one Learn item. The one place this shape is written.
String lessonPath(String topicId, String resourceId) =>
    '/learn/topic/$topicId/$resourceId';

/// A topic's lesson, Khan Academy style — `/learn/topic/:topicId/:resourceId`.
///
/// The sequence stays in view (a sidebar when wide, a sheet when compact)
/// while one item plays in the main pane, and "Up next" walks the
/// sequence, ending at the topic test.
///
/// Reads only `topicResourcesProvider` (the published-only query the topic
/// page has already cached) and the topic document, so moving between
/// items costs nothing.
///
/// **When an item counts as complete** — the rules, in one place:
///   - video: when [LessonVideoPlayer] judges it actually watched
///   - article: when its end has been on screen, or on "Up next"
///   - exercise: when a set is finished, whatever the score
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.topicId,
    required this.resourceId,
  });

  final String topicId;
  final String resourceId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(LessonScreen old) {
    super.didUpdateWidget(old);
    if (old.resourceId != widget.resourceId && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _fitCheck?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // Scroll notifications arrive many times a second; without this an
  // article would fire several writes before the first one lands and the
  // stored progress catches up.
  final _marked = <String>{};

  void _complete(LearnResource r) {
    if (!_marked.add(r.id)) return;
    markLessonComplete(ref, resource: r);
  }

  // A short article fits on screen and never scrolls, so no scroll
  // notification ever reports its end. Check once it has had time to
  // settle: on the first frames the maths fonts are still loading and every
  // article is briefly short enough to "fit", which marked long articles
  // read the moment they opened. Seen in the browser, hence the delay.
  Timer? _fitCheck;

  void _checkArticleEndAfterLayout(LearnResource current) {
    _fitCheck?.cancel();
    if (current.type != LearnResourceType.article) return;
    _fitCheck = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_scroll.hasClients) return;
      if (widget.resourceId != current.id) return;
      final p = _scroll.position;
      if (p.maxScrollExtent < 48) _complete(current);
    });
  }

  void _open(LearnResource r) => context.go(lessonPath(r.topicId, r.id));

  /// Reaching the end by scrolling counts. [ScrollUpdateNotification]
  /// fires only when the offset actually moves — never for content still
  /// laying out — and `pixels > 0` rules out the jump back to the top when
  /// moving to a new item. Deliberately not `dragDetails`, which a mouse
  /// wheel never sets: that version missed every desktop reader.
  bool _onScroll(ScrollUpdateNotification n, LearnResource current) {
    if (current.type == LearnResourceType.article &&
        n.metrics.pixels > 0 &&
        n.metrics.extentAfter < 48) {
      _complete(current);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final resourcesAsync = ref.watch(topicResourcesProvider(widget.topicId));
    final topic = ref.watch(topicByIdProvider(widget.topicId)).asData?.value;

    final scaffold = Scaffold(
      backgroundColor: context.palette.background,
      body: Column(
        children: [
          const AppTopNav(),
          Expanded(
            child: resourcesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _Message(
                "This lesson couldn't be loaded. Try refreshing.",
              ),
              data: (resources) {
                final current = resources
                    .where((r) => r.id == widget.resourceId)
                    .firstOrNull;
                if (current == null || !current.isAvailable) {
                  return const _Message('This lesson is not available.');
                }
                return _layout(context, resources, current, topic);
              },
            ),
          ),
        ],
      ),
    );

    // Study tools (calculator, tables…) beside the lesson.
    return StudyDock(
      subjectId: topic?.subjectId,
      studyContext: StudyContext.lesson,
      child: scaffold,
    );
  }

  Widget _layout(
    BuildContext context,
    List<LearnResource> resources,
    LearnResource current,
    Topic? topic,
  ) {
    final completed = ref
        .watch(lessonProgressProvider)
        .forTopic(widget.topicId)
        .completed;
    final isOffline = ref.watch(isOnlineProvider).asData?.value == false;
    final isCompact = MediaQuery.sizeOf(context).width < kCompactBreakpoint;
    _checkArticleEndAfterLayout(current);

    final list = LessonSequenceList(
      resources: resources,
      currentId: current.id,
      completed: completed,
      onOpen: _open,
    );

    // Keyed by item, so moving to the next one builds a fresh pane (and
    // a fresh player) rather than reusing the last one's state.
    final pane = KeyedSubtree(
      key: ValueKey('pane-${current.id}'),
      child: switch (current.type) {
        LearnResourceType.video => VideoPane(
          resource: current,
          isOffline: isOffline,
          onWatched: () => _complete(current),
        ),
        LearnResourceType.exercise => ExercisePane(
          resource: current,
          onFinished: () => _complete(current),
        ),
        _ => ArticlePane(resource: current),
      },
    );

    final main = Column(
      children: [
        if (isOffline) const _OfflineBanner(),
        if (isCompact)
          _CompactHeader(
            topic: topic,
            position: resources.indexOf(current) + 1,
            count: resources.length,
            onShowList: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: context.palette.surface,
              isScrollControlled: true,
              builder: (_) => SafeArea(
                child: SingleChildScrollView(
                  child: LessonSequenceList(
                    resources: resources,
                    currentId: current.id,
                    completed: completed,
                    onOpen: (r) {
                      Navigator.of(context).pop();
                      _open(r);
                    },
                  ),
                ),
              ),
            ),
          ),
        // Keyed: the banner and compact header above come and go, and the
        // key keeps this element — and a playing video inside it — where
        // it is rather than rebuilding it in a new slot.
        Expanded(
          key: const ValueKey('lesson-main'),
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (n) => _onScroll(n, current),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: contentGutterFor(context),
                vertical: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: pane,
                ),
              ),
            ),
          ),
        ),
        _UpNextBar(
          next: nextAfter(resources, current.id),
          topic: topic,
          onNext: (r) {
            if (current.type == LearnResourceType.article) _complete(current);
            _open(r);
          },
          onTest: (t) {
            if (current.type == LearnResourceType.article) _complete(current);
            context.go(
              '/subject/${t.subjectId}/unit/${t.unitId}/topic/${t.id}/test',
            );
          },
        ),
      ],
    );

    // One structure for both layouts: the sidebar collapses to zero width
    // rather than leaving the tree. Swapping a Row for a Column moved the
    // main pane to a new parent, and a browser reloads an iframe whose DOM
    // node moves — resizing the window restarted the video. Measured, not
    // assumed.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: isCompact ? 0 : 280,
          child: isCompact
              ? const SizedBox.shrink()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: context.palette.border),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _SidebarHeader(
                        topic: topic,
                        done: completedCount(resources, completed),
                        total: availableCount(resources),
                      ),
                      list,
                    ],
                  ),
                ),
        ),
        Expanded(child: main),
      ],
    );
  }
}

String? _topicPagePath(Topic? t) =>
    t == null ? null : '/subject/${t.subjectId}/course/topic/${t.id}';

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.topic,
    required this.done,
    required this.total,
  });

  final Topic? topic;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final path = _topicPagePath(topic);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (path != null)
            InkWell(
              onTap: () => context.go(path),
              child: Text(
                '← Topic overview',
                style: AppTheme.caption.copyWith(color: AppColors.primary),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            topic?.name ?? '',
            style: AppTheme.heading3.copyWith(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$done of $total done',
            style: AppTheme.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 4,
              backgroundColor: context.palette.track,
              color: AppColors.correct,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.topic,
    required this.position,
    required this.count,
    required this.onShowList,
  });

  final Topic? topic;
  final int position;
  final int count;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      child: InkWell(
        onTap: onShowList,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.list_rounded, color: context.palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${topic?.name ?? 'Lesson'} · $position of $count',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMd.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                color: context.palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpNextBar extends StatelessWidget {
  const _UpNextBar({
    required this.next,
    required this.topic,
    required this.onNext,
    required this.onTest,
  });

  final LearnResource? next;
  final Topic? topic;
  final ValueChanged<LearnResource> onNext;
  final ValueChanged<Topic> onTest;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    final topic = this.topic;
    final (String label, VoidCallback? onPressed) = next != null
        ? ('Up next: ${next.title}', () => onNext(next))
        : topic != null
        ? ('Up next: Topic test', () => onTest(topic))
        : ('End of lesson', null);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: contentGutterFor(context),
        vertical: 12,
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.wrong.withAlpha(38),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        "You're offline — showing what was already loaded.",
        textAlign: TextAlign.center,
        style: AppTheme.caption.copyWith(color: AppColors.wrong),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: AppTheme.bodyLg.copyWith(color: context.palette.textSecondary),
      ),
    );
  }
}
