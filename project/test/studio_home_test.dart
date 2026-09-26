import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/features/admin/admin_home_screen.dart';

LearnResource _item(ResourceStatus s) => LearnResource(
  id: 'x',
  type: LearnResourceType.article,
  order: 1,
  title: 'x',
  subjectId: 's',
  topicId: 't',
  status: s,
);

void main() {
  test('a topic with nothing is empty', () {
    expect(TopicState.of(const []), TopicState.empty);
  });

  test('anything needing action outranks published', () {
    expect(
      TopicState.of([
        _item(ResourceStatus.published),
        _item(ResourceStatus.changesRequested),
      ]),
      TopicState.changesRequested,
    );
    expect(
      TopicState.of([
        _item(ResourceStatus.published),
        _item(ResourceStatus.inReview),
      ]),
      TopicState.inReview,
    );
  });

  test(
    'a live lesson with a new draft beside it still counts as published',
    () {
      expect(
        TopicState.of([
          _item(ResourceStatus.published),
          _item(ResourceStatus.draft),
        ]),
        TopicState.published,
      );
    },
  );

  test('control: drafts alone are a draft, not published', () {
    expect(TopicState.of([_item(ResourceStatus.draft)]), TopicState.draft);
  });
}
