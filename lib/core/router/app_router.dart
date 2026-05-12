import 'package:go_router/go_router.dart';
import '../../features/topic_list_screen.dart';
import '../../features/topic_detail_screen.dart';
import '../../features/question_screen.dart';
import '../../features/dashboard_screen.dart';
import '../../features/sign_in_screen.dart';
import '../../features/about_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TopicListScreen(),
    ),
    GoRoute(
      path: '/topic/:topicId',
      builder: (context, state) => TopicDetailScreen(
        topicId: state.pathParameters['topicId']!,
      ),
    ),
    GoRoute(
      path: '/question',
      builder: (context, state) => const QuestionScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
  ],
);