import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/analytics/presentation/spending_patterns_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/legal/presentation/terms_of_service_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/overview/presentation/category_drilldown_screen.dart';
import '../../features/overview/presentation/overview_screen.dart';
import '../../features/profile/presentation/manage_periods_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/signals/presentation/recurring_screen.dart';
import '../../features/signals/presentation/signals_screen.dart';
import '../../features/statements/presentation/period_providers.dart';
import '../../features/upload/presentation/analysing_screen.dart';
import '../../features/upload/presentation/rejected_screen.dart';
import '../../features/controller/presentation/controller_screen.dart';
import '../../features/controller/presentation/exceptions_list_screen.dart';
import '../../features/controller/presentation/exception_detail_screen.dart';
import '../../features/controller/domain/exception.dart';
import 'app_shell.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(periodsProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onAuthPages = loc == '/login' || loc == '/register';

      final authAsync = ref.read(authControllerProvider);
      if (authAsync.isLoading && !authAsync.hasValue) {
        return onAuthPages ? null : '/login';
      }

      final authState = authAsync.valueOrNull;
      if (authState == null || authState is AuthUnauthenticated) {
        return onAuthPages ? null : '/login';
      }

      // Authenticated from here on.
      final periodsAsync = ref.read(periodsProvider);
      if (periodsAsync.isLoading && !periodsAsync.hasValue) {
        return onAuthPages ? null : null;
      }
      final hasPeriods = (periodsAsync.valueOrNull ?? const []).isNotEmpty;

      if (onAuthPages) {
        return hasPeriods ? '/shell/overview' : '/onboarding';
      }
      if (loc == '/onboarding' && hasPeriods) return '/shell/overview';
      if (loc.startsWith('/shell') && !hasPeriods) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/upload/analysing/:jobId',
        builder: (context, state) => AnalysingScreen(jobId: state.pathParameters['jobId']!),
      ),
      GoRoute(
        path: '/upload/rejected',
        builder: (context, state) => RejectedScreen(message: state.extra as String?),
      ),
      GoRoute(
        path: '/category/:category',
        builder: (context, state) => CategoryDrilldownScreen(category: Uri.decodeComponent(state.pathParameters['category']!)),
      ),
      GoRoute(path: '/recurring', builder: (context, state) => const RecurringScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/profile/periods', builder: (context, state) => const ManagePeriodsScreen()),
      GoRoute(path: '/profile/analytics', builder: (context, state) => const SpendingPatternsScreen()),
      GoRoute(path: '/profile/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/profile/terms', builder: (context, state) => const TermsOfServiceScreen()),
      GoRoute(path: '/controller/exceptions', builder: (context, state) => const ExceptionsListScreen()),
      GoRoute(
        path: '/controller/exceptions/:id',
        builder: (context, state) => ExceptionDetailScreen(
          exception: state.extra as TransactionException,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/shell/overview', builder: (context, state) => const OverviewScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/shell/signals', builder: (context, state) => const SignalsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/shell/activity', builder: (context, state) => const ActivityScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/shell/controller', builder: (context, state) => const ControllerScreen())]),
        ],
      ),
    ],
  );
});
