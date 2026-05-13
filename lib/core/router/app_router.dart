import 'package:go_router/go_router.dart';
import '../../features/subject_list_screen.dart';
import '../../features/unit_list_screen.dart';
import '../../features/topic_list_screen.dart';
import '../../features/drill_screen.dart';
import '../../features/waec_subject_screen.dart';
import '../../features/waec_exam_screen.dart';
import '../../features/dashboard_screen.dart';
import '../../features/sign_in_screen.dart';
import '../../features/about_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SubjectListScreen()),
    GoRoute(
      path: '/subject/:subjectId',
      builder: (_, s) =>
          UnitListScreen(subjectId: s.pathParameters['subjectId']!),
    ),
    GoRoute(
      path: '/subject/:subjectId/unit/:unitId',
      builder: (_, s) => TopicListScreen(
        subjectId: s.pathParameters['subjectId']!,
        unitId: s.pathParameters['unitId']!,
      ),
    ),
    GoRoute(
      path: '/subject/:subjectId/unit/:unitId/topic/:topicId',
      builder: (_, s) =>
          DrillScreen(topicId: s.pathParameters['topicId']!),
    ),
    GoRoute(path: '/waec', builder: (_, __) => const WaecSubjectScreen()),
    GoRoute(
      path: '/waec/:subjectId/exam',
      builder: (_, s) =>
          WaecExamScreen(subjectId: s.pathParameters['subjectId']!),
    ),
    GoRoute(
        path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
  ],
);