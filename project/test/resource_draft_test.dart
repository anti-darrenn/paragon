import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/repositories/admin_resource_repository.dart';

void main() {
  ResourceDraft video({String link = 'https://youtu.be/M7lc1UVf-VE', String duration = '9:30'}) =>
      ResourceDraft(
        type: LearnResourceType.video,
        title: 'Converting bases',
        orderText: '2',
        youtubeText: link,
        durationText: duration,
        description: '  worked examples ',
        body: 'stale body that must not be saved on a video',
      );

  group('parseDuration', () {
    test('reads m:ss, h:mm:ss and bare seconds', () {
      expect(parseDuration('9:30'), 570);
      expect(parseDuration('1:05:00'), 3900);
      expect(parseDuration('45'), 45);
      expect(parseDuration(' 0:07 '), 7);
    });

    test('control: rejects what is not a duration', () {
      for (final bad in ['', ':30', '9:75', 'nine', '1:2:3:4', '-1:00', '9:3x']) {
        expect(parseDuration(bad), isNull, reason: bad);
      }
    });
  });

  group('validate', () {
    test('a complete video passes', () => expect(video().validate(), isNull));

    test('a video with a non-YouTube link is refused', () {
      expect(video(link: 'https://vimeo.com/123').validate(), contains('YouTube'));
    });

    test('a video with a bad duration is refused, a blank one allowed', () {
      expect(video(duration: '9:75').validate(), contains('Duration'));
      expect(video(duration: '').validate(), isNull);
    });

    test('an article needs a body', () {
      const draft = ResourceDraft(
        type: LearnResourceType.article,
        title: 'T',
        orderText: '1',
      );
      expect(draft.validate(), contains('body'));
    });

    test('an exercise needs 1 to 20 questions unless some are pinned', () {
      ResourceDraft ex(String count, [List<String> pinned = const []]) =>
          ResourceDraft(
            type: LearnResourceType.exercise,
            title: 'Practise',
            orderText: '3',
            questionCountText: count,
            questionIds: pinned,
          );
      expect(ex('5').validate(), isNull);
      expect(ex('0').validate(), isNotNull);
      expect(ex('21').validate(), isNotNull);
      expect(ex('', ['q1', 'q2']).validate(), isNull);
    });

    test('every type needs a title and a whole-number position', () {
      expect(video().validate(), isNull);
      expect(
        const ResourceDraft(type: LearnResourceType.video, title: ' ', orderText: '1')
            .validate(),
        contains('title'),
      );
      expect(
        ResourceDraft(
          type: LearnResourceType.video,
          title: 'x',
          orderText: 'first',
          youtubeText: 'M7lc1UVf-VE',
        ).validate(),
        contains('Position'),
      );
    });
  });

  group('toFields', () {
    test('a video stores the parsed id and clears other types\' fields', () {
      final f = video().toFields();
      expect(f['type'], 'video');
      expect(f['youtubeId'], 'M7lc1UVf-VE');
      expect(f['durationSeconds'], 570);
      expect(f['description'], 'worked examples');
      expect(f['body'], '', reason: 'a stale body must not ride along');
      expect(f['questionIds'], isEmpty);
    });

    test('pinned questions set the count to match', () {
      final f = const ResourceDraft(
        type: LearnResourceType.exercise,
        title: 'Practise',
        orderText: '3',
        questionCountText: '5',
        questionIds: ['a', 'b'],
      ).toFields();
      expect(f['questionCount'], 2);
      expect(f['questionIds'], ['a', 'b']);
      expect(f['youtubeId'], isNull);
    });

    test('control: an article clears video and exercise fields', () {
      final f = const ResourceDraft(
        type: LearnResourceType.article,
        title: 'Read me',
        orderText: '1',
        body: 'Prose.',
        youtubeText: 'M7lc1UVf-VE',
        questionCountText: '5',
      ).toFields();
      expect(f['body'], 'Prose.');
      expect(f['youtubeId'], isNull);
      expect(f['questionCount'], 0);
    });
  });
}
