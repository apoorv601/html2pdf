import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/logging/log_meal_screen.dart';
import '../features/logging/log_workout_screen.dart';
import '../features/chat/chat_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// Router with auth + onboarding redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final user = authState.asData?.value;
      final loggingIn = state.matchedLocation == '/login';

      // Not signed in -> force login.
      if (user == null) return loggingIn ? null : '/login';

      // Signed in but profile not onboarded -> force onboarding.
      final profile = ref.read(profileProvider).asData?.value;
      final onboarded = profile?.onboardingComplete ?? false;
      final onboarding = state.matchedLocation == '/onboarding';

      if (!onboarded && !onboarding) return '/onboarding';
      if ((loggingIn || onboarding) && onboarded) return '/';
      if (loggingIn && !onboarded) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/log-meal', builder: (_, __) => const LogMealScreen()),
      GoRoute(path: '/log-workout', builder: (_, __) => const LogWorkoutScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
    ],
  );
});

/// Bridges Riverpod auth/profile changes to GoRouter's refresh mechanism.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(profileProvider, (_, __) => notifyListeners());
  }
}
