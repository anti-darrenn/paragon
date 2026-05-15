import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/repositories/learning_repository.dart';
import '../core/models/topic.dart';

class TopicListScreen extends ConsumerWidget {
  final String subjectId;
  final String unitId;
  const TopicListScreen(
      {super.key, required this.subjectId, required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(unitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Topics')),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (topics) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: topics.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _TopicTile(
            topic: topics[i],
            subjectId: subjectId,
            unitId: unitId,
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final Topic topic;
  final String subjectId;
  final String unitId;
  const _TopicTile(
      {required this.topic,
      required this.subjectId,
      required this.unitId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push(
          '/subject/$subjectId/unit/$unitId/topic/${topic.id}'),
      title: Text(topic.name),
      subtitle: Text('${topic.questionCount} questions'),
      trailing: const Icon(Icons.chevron_right),
      tileColor: Theme.of(context).colorScheme.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}