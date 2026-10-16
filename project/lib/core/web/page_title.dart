import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// The browser tab's title for each page (Plan v2 7.1). Until this, every
/// route showed "Paragon", and Flutter replaced the static `<title>` in
/// `web/index.html` with it on the first frame.
///
/// Built from the route pattern and the URL's own slugs, so it costs no
/// reads: `/subject/mathematics/course/topic/indices` is "Indices ·
/// Mathematics | Paragon". An old link that names a Firestore id instead
/// of a slug gets the page's kind without the name.

/// The site's own title, the same as `web/index.html`'s `<title>`.
const kHomeTitle = 'Paragon: free WAEC past questions and practice';

const _suffix = ' | Paragon';

/// Words left lower-case inside a title ("Indices and Logarithms").
const _small = {'and', 'or', 'of', 'in', 'on', 'the', 'a', 'an', 'to', 'for'};

/// `further-mathematics` → "Further Mathematics"; a Firestore id → null.
String? nameFromSlug(String? key) {
  if (key == null || key.isEmpty) return null;
  // Auto-ids are 20 mixed-case letters and digits; slugs are lower-case
  // words joined by hyphens.
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(key)) return null;
  final words = key.split('-');
  return [
    for (var i = 0; i < words.length; i++)
      i > 0 && _small.contains(words[i])
          ? words[i]
          : words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
}

/// The title for a route [pattern] (as declared in `app_router.dart`)
/// with its path [params].
String pageTitleFor(String pattern, Map<String, String> params) {
  final subject = nameFromSlug(params['subjectId']);
  final topic = nameFromSlug(params['topicId']);
  String t(String s) => '$s$_suffix';
  String withSubject(String Function(String) named, String plain) =>
      subject == null ? t(plain) : t(named(subject));

  switch (pattern) {
    case '/':
    case '/welcome':
      return kHomeTitle;
    case '/courses':
      return t('Courses');
    case '/subject/:subjectId/course':
      return withSubject((s) => s, 'Course');
    case '/subject/:subjectId/course/topic/:topicId':
      if (topic == null) return t('Topic');
      return t(subject == null ? topic : '$topic · $subject');
    case '/subject/:subjectId/course/topic/:topicId/drill':
    case '/subject/:subjectId/unit/:unitId/topic/:topicId':
      return t(topic == null ? 'Practice' : 'Practise $topic');
    case '/subject/:subjectId/course/topic/:topicId/test':
    case '/subject/:subjectId/unit/:unitId/topic/:topicId/test':
      return t(topic == null ? 'Topic test' : '$topic topic test');
    case '/subject/:subjectId/course/unit/:moduleId/test':
      return t('Unit test');
    case '/subject/:subjectId/course/challenge':
      return withSubject((s) => '$s course challenge', 'Course challenge');
    case '/learn/topic/:topicId/:resourceId':
      return t('Lesson');
    case '/waec':
      return t('WAEC Prep');
    case '/waec/:subjectId/setup':
      return withSubject((s) => 'WAEC $s paper', 'WAEC paper');
    case '/waec/:subjectId/exam':
      return withSubject((s) => 'WAEC $s exam', 'WAEC exam');
    case '/waec/:subjectId/theory':
      return withSubject((s) => 'WAEC $s theory', 'WAEC theory');
    case '/waec/review/:examId':
      return t('Exam review');
    case '/plan':
      return t('Study plan');
    case '/search':
      return t('Search');
    case '/review':
      return t('Review');
    case '/mistakes':
      return t('Mistakes notebook');
    case '/mistakes/practice':
      return t('Practise your mistakes');
    case '/saved':
      return t('Saved questions');
    case '/cards/:subjectId':
      return withSubject((s) => '$s revision cards', 'Revision cards');
    case '/join':
      return t('Join a live quiz');
    case '/rooms/new':
      return t('Host a live quiz');
    case '/rooms/:code/host':
    case '/rooms/:code':
      return t('Live quiz');
    case '/try':
      return t('Try five questions');
    case '/c/:id':
      return t('A challenge from a friend');
    case '/support':
      return t('Support');
    case '/about':
      return t('About');
    case '/privacy':
      return t('Privacy policy');
    case '/terms':
      return t('Terms');
    case '/signin':
      return t('Sign in');
    case '/legal/accept':
      return t('Updated terms');
    case '/me':
      return t('Me');
  }
  if (pattern.startsWith('/settings')) return t('Settings');
  if (pattern.startsWith('/onboarding')) return t('Welcome');
  if (pattern.startsWith('/account')) return t('Account');
  if (pattern.startsWith('/admin')) return t('Content studio');
  return 'Paragon';
}

/// Keeps the tab title in step with the router. [current] is what
/// `MaterialApp.onGenerateTitle` returns, so a rebuild of the app (a theme
/// change) keeps the page's title instead of going back to "Paragon".
class PageTitleBinding {
  PageTitleBinding(this._router) {
    _router.routerDelegate.addListener(_update);
    _update();
  }

  final GoRouter _router;
  String current = kHomeTitle;

  void _update() {
    try {
      final config = _router.routerDelegate.currentConfiguration;
      if (config.matches.isEmpty) return;
      final title = pageTitleFor(config.last.route.path, config.pathParameters);
      if (title == current) return;
      current = title;
      // On the web this is document.title; elsewhere the app switcher.
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: title),
      );
    } catch (_) {
      // A title is never worth an exception in the router's listener.
    }
  }

  void dispose() => _router.routerDelegate.removeListener(_update);
}

final pageTitleBindingProvider = Provider<PageTitleBinding>((ref) {
  final binding = PageTitleBinding(ref.watch(appRouterProvider));
  ref.onDispose(binding.dispose);
  return binding;
});
