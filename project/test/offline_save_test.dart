import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paragon/core/models/learn_resource.dart';
import 'package:paragon/core/providers/reading_settings_provider.dart';
import 'package:paragon/features/study/offline/offline_fetcher.dart';
import 'package:paragon/features/study/offline/offline_plan.dart';
import 'package:paragon/features/study/offline/save_offline_button.dart';
import 'package:paragon/features/study/offline/saved_topics_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearnResource _res(
  String id,
  LearnResourceType type, {
  String body = '',
  List<String> questionIds = const [],
}) => LearnResource(
  id: id,
  type: type,
  order: 0,
  title: id,
  subjectId: 's',
  topicId: 't1',
  body: body,
  youtubeId: type == LearnResourceType.video ? 'dQw4w9WgXcQ' : null,
  questionIds: questionIds,
);

const _articleWithEverything = '''
# Bases

![A place-value chart](asset:chart1)

::: note
A nested figure:

![Nested](asset:nested2)
:::

::: check q:bankQ1
:::

::: more Deeper
::: waec q:waecQ2
:::
:::

![From the web](https://example.com/x.png)

::: video dQw4w9WgXcQ
:::

![Again](asset:chart1)
''';

/// A fetcher whose calls can be held open, so the saving state can be
/// seen, and made to fail.
class FakeFetcher implements OfflineFetcher {
  FakeFetcher({this.fail = false});

  final bool fail;
  final List<LearnResource> served = [
    _res('a', LearnResourceType.article, body: _articleWithEverything),
    _res('v', LearnResourceType.video),
  ];
  Completer<void>? gate;
  final calls = <String>[];

  @override
  Future<List<LearnResource>> resources(String topicId) async {
    calls.add('resources:$topicId');
    if (gate != null) await gate!.future;
    if (fail) throw Exception('offline');
    return served;
  }

  @override
  Future<int> assets(List<String> ids) async {
    calls.add('assets:${ids.join(',')}');
    return ids.length;
  }

  @override
  Future<int> questions(List<String> ids) async {
    calls.add('questions:${ids.join(',')}');
    return ids.length;
  }

  @override
  Future<int> topicQuestions(String topicId, int limit) async {
    calls.add('topicQuestions:$topicId:$limit');
    return limit;
  }
}

void main() {
  group('planOfflinePrefetch', () {
    test('finds figures and bank questions, nested ones included', () {
      final plan = planOfflinePrefetch([
        _res('a', LearnResourceType.article, body: _articleWithEverything),
        _res('e', LearnResourceType.exercise, questionIds: ['pinned1']),
        _res('v', LearnResourceType.video),
      ]);
      expect(plan.assetIds, ['chart1', 'nested2']);
      expect(plan.questionIds, ['bankQ1', 'waecQ2', 'pinned1']);
      expect(plan.videoCount, 2); // the video resource and the in-text one
      expect(plan.externalImageCount, 1);
      expect(plan.resourceCount, 3);
      expect(plan.approximateItems, 3 + 2 + 3 + kOfflineTopicQuestions);
    });

    test('CONTROL: a body with no figures yields no assets', () {
      final plan = planOfflinePrefetch([
        _res(
          'a',
          LearnResourceType.article,
          body: '# Plain\n\nJust text, and \\(x^2\\).\n\n- a list',
        ),
      ]);
      expect(plan.assetIds, isEmpty);
      expect(plan.questionIds, isEmpty);
      expect(plan.videoCount, 0);
    });

    test('saveTopicForOffline fetches the plan', () async {
      final fetcher = FakeFetcher();
      final steps = <int>[];
      final result = await saveTopicForOffline(
        fetcher,
        't1',
        onStep: steps.add,
      );
      expect(fetcher.calls, [
        'resources:t1',
        'assets:chart1,nested2',
        'questions:bankQ1,waecQ2',
        'topicQuestions:t1:$kOfflineTopicQuestions',
      ]);
      expect(steps, [1, 2, 3, 4]);
      expect(result.itemCount, 2 + 2 + 2 + kOfflineTopicQuestions);
      expect(result.videoCount, 2);
    });
  });

  group('SavedTopicsNotifier', () {
    SavedTopic topic(String id) => SavedTopic(
      topicId: id,
      name: 'Topic $id',
      subjectId: 'maths',
      courseKey: 'mathematics',
      savedAt: DateTime(2026, 9, 26),
      itemCount: 40,
      videoCount: 1,
    );

    Future<ProviderContainer> container() async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(readingPrefsProvider.future);
      return c;
    }

    test('persists, replaces and removes', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await container();
      final store = c.read(savedTopicsProvider.notifier);

      await store.add(topic('t1'));
      await store.add(topic('t2'));
      await store.add(topic('t1')); // a re-save moves it to the front
      expect(c.read(savedTopicsProvider).map((t) => t.topicId), ['t1', 't2']);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString(kSavedTopicsKey)!) as List;
      expect(stored, hasLength(2));

      // A fresh container reads it back.
      final again = await container();
      final restored = again.read(savedTopicsProvider);
      expect(restored.map((t) => t.topicId), ['t1', 't2']);
      expect(restored.first.name, 'Topic t1');
      expect(restored.first.savedAt, DateTime(2026, 9, 26));
      expect(restored.first.path, '/subject/mathematics/course/topic/t1');

      await again.read(savedTopicsProvider.notifier).remove('t1');
      expect(again.read(savedTopicsProvider).map((t) => t.topicId), ['t2']);
      final after = jsonDecode(prefs.getString(kSavedTopicsKey)!) as List;
      expect(after.map((e) => (e as Map)['topicId']), ['t2']);
    });

    test('corrupt storage reads as an empty list, not a crash', () async {
      SharedPreferences.setMockInitialValues({kSavedTopicsKey: '{not json'});
      final c = await container();
      expect(c.read(savedTopicsProvider), isEmpty);
    });

    test('formatSavedDate', () {
      expect(formatSavedDate(DateTime(2026, 9, 26)), '26 Sep 2026');
    });
  });

  group('SaveTopicOfflineButton', () {
    Future<void> pump(
      WidgetTester tester,
      FakeFetcher fetcher, {
      bool lowData = false,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (lowData) 'reading.lowDataMode': true,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineFetcherProvider.overrideWithValue(fetcher)],
          child: MaterialApp(
            home: Scaffold(
              body: SaveTopicOfflineButton(
                topicId: 't1',
                topicName: 'Number bases',
                subjectId: 'maths',
                courseKey: 'mathematics',
                resources: fetcher.served,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder byKey(String k) => find.byKey(ValueKey(k));

    testWidgets('idle, saving, saved, removed', (tester) async {
      final fetcher = FakeFetcher()..gate = Completer<void>();
      await pump(tester, fetcher);
      expect(byKey('offline.idle'), findsOneWidget);

      await tester.tap(byKey('offline.save'));
      await tester.pump();
      expect(byKey('offline.saving'), findsOneWidget);

      fetcher.gate!.complete();
      await tester.pumpAndSettle();
      expect(byKey('offline.saved'), findsOneWidget);
      expect(find.textContaining('Saved for offline ·'), findsOneWidget);
      expect(find.text('2 videos need internet.'), findsOneWidget);

      await tester.tap(byKey('offline.remove'));
      await tester.pumpAndSettle();
      expect(byKey('offline.idle'), findsOneWidget);
      expect(find.text(kOfflineRemoveNote), findsOneWidget);
    });

    testWidgets('a failed save says so and can be retried', (tester) async {
      await pump(tester, FakeFetcher(fail: true));
      await tester.tap(byKey('offline.save'));
      await tester.pumpAndSettle();
      expect(byKey('offline.idle'), findsOneWidget);
      expect(find.textContaining("Couldn't save"), findsOneWidget);
    });

    testWidgets('low-data mode asks first, and Cancel fetches nothing', (
      tester,
    ) async {
      final fetcher = FakeFetcher();
      await pump(tester, fetcher, lowData: true);

      await tester.tap(byKey('offline.save'));
      await tester.pumpAndSettle();
      final items = planOfflinePrefetch(fetcher.served).approximateItems;
      expect(
        find.textContaining('This will download about $items items'),
        findsOneWidget,
      );

      await tester.tap(byKey('offline.confirm.cancel'));
      await tester.pumpAndSettle();
      expect(fetcher.calls, isEmpty);
      expect(byKey('offline.idle'), findsOneWidget);

      await tester.tap(byKey('offline.save'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('offline.confirm.ok'));
      await tester.pumpAndSettle();
      expect(fetcher.calls, isNotEmpty);
      expect(byKey('offline.saved'), findsOneWidget);
    });

    testWidgets('CONTROL: without low-data mode there is no dialog', (
      tester,
    ) async {
      final fetcher = FakeFetcher();
      await pump(tester, fetcher);
      await tester.tap(byKey('offline.save'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(byKey('offline.saved'), findsOneWidget);
    });
  });
}
