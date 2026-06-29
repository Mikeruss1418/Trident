import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/logger/app_logger.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';
import 'package:trident/features/auth/presentation/screens/home_screen.dart';
import 'package:trident/features/auth/presentation/screens/login_screen.dart';
import 'package:trident/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:trident/injectables/injectable.dart';

class RouteConfig {
  static final GoRouter router = GoRouter(
    navigatorKey: NavigationService.rootNavigatorKey,
    initialLocation: RouteNames.initialRoute,
    errorBuilder: (context, state) {
      AppLogger.error("error triggered on navigation service");

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        getIt<NavigationService>().pushAndRemoveUntil(RouteNames.initialRoute);
      });
      return const SizedBox.shrink();
    },
    observers: [MyNavigatorObserver(navigationService: NavigationService())],
    routes: [
      GoRoute(
        path: RouteNames.initialRoute,
        name: RouteNames.initialRoute,
        redirect: (context, state) {
          final authState = getIt<AuthCubit>().state;
          final location = state.matchedLocation;

          switch (authState) {
            case AuthStatus.onboarding:
              return location == RouteNames.signUpRoute
                  ? null
                  : RouteNames.signUpRoute;

            case AuthStatus.unauthenticated:
              return location == RouteNames.loginRoute
                  ? null
                  : RouteNames.loginRoute;

            case AuthStatus.authenticated:
              return location == RouteNames.homeRoute
                  ? null
                  : RouteNames.homeRoute;

            case AuthStatus.vaultLocked:
              return location == RouteNames.loginRoute
                  ? null
                  : RouteNames.loginRoute;
          }
        },
      ),
      GoRoute(
        path: RouteNames.signUpRoute,
        name: RouteNames.signUpRoute,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: RouteNames.homeRoute,
        name: RouteNames.homeRoute,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.loginRoute,
        name: RouteNames.loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}
