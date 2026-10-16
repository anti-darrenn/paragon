import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paragon/core/providers/auth_provider.dart';
import 'package:paragon/core/router/app_router.dart';
import 'package:paragon/core/web/page_title.dart';

/// Plan v2 7.1: every page names itself in the browser tab.
void main() {
  group('pageTitleFor', () {
    const s = {'subjectId': 'mathematics'};
    final cases = <(String, Map<String, String>), String>{
      ('/', {}): kHomeTitle,
      ('/subject/:subjectId/course', s): 'Mathematics | Paragon',
      (
        '/subject/:subjectId/course/topic/:topicId',
        {...s, 'topicId': 'indices'},
      ): 'Indices · Mathematics | Paragon',
      (
        '/subject/:subjectId/course/topic/:topicId/drill',
        {...s, 'topicId': 'indices'},
      ): 'Practise Indices | Paragon',
      ('/waec/:subjectId/setup', s): 'WAEC Mathematics paper | Paragon',
      ('/join', {}): 'Join a live quiz | Paragon',
      ('/subject/:subjectId/course', {'subjectId': 'further-mathematics'}):
          'Further Mathematics | Paragon',
      (
        '/subject/:subjectId/course/topic/:topicId',
        {...s, 'topicId': 'indices-and-logarithms'},
      ): 'Indices and Logarithms · Mathematics | Paragon',
      // An old link by Firestore id: the kind of page, never the id.
      (
        '/subject/:subjectId/course/topic/:topicId',
        {
          'subjectId': 'gdv7zeXkoASauMlcmMnV',
          'topicId': 'NjfU0QdBKJPAWpKSCjOX',
        },
      ): 'Topic | Paragon',
      ('/waec/:subjectId/setup', {'subjectId': 'gdv7zeXkoASauMlcmMnV'}):
          'WAEC paper | Paragon',
      ('/settings/reading', {}): 'Settings | Paragon',
      ('/admin/flag/:questionId', {'questionId': 'x'}):
          'Content studio | Paragon',
    };
    cases.forEach((input, expected) {
      test('${input.$1} ${input.$2}', () {
        expect(pageTitleFor(input.$1, input.$2), expected);
      });
    });

    test('CONTROL: an unknown pattern is plain "Paragon"', () {
      expect(pageTitleFor('/nowhere', const {}), 'Paragon');
    });
  });

  testWidgets('every route the router declares has its own title', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(const AsyncData(null)),
        userDataProvider.overrideWith((ref) => Stream.value(null)),
        idTokenResultProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(const SizedBox());
    final router = container.read(appRouterProvider);

    final untitled = <String>[];
    var walked = 0;
    void walk(List<RouteBase> routes) {
      for (final r in routes) {
        // Redirect-only routes never show a page.
        if (r is GoRoute && r.builder != null ||
            r is GoRoute && r.pageBuilder != null) {
          walked++;
          if (pageTitleFor(r.path, const {}) == 'Paragon') untitled.add(r.path);
        }
        walk(r.routes);
      }
    }

    walk(router.configuration.routes);
    expect(walked, greaterThan(40), reason: 'control: the walk found routes');
    expect(untitled, isEmpty, reason: 'add these to pageTitleFor');
  });
}
