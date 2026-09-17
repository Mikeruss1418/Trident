import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/routes/route_config.dart';
import 'package:trident/core/services/screen_protection/screen_protection_service.dart';
import 'package:trident/injectables/injectable.dart';

@lazySingleton
class NavigationService {
  static GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static BuildContext? get ctx =>
      RouteConfig.router.routerDelegate.navigatorKey.currentState?.context ??
      rootNavigatorKey.currentContext;

  List<String> _routes = [];
  List<String> get routes => List.unmodifiable(_routes);

  /// Do not call this method from directly.
  /// It is handled by route observer
  void addRoute(String routeName) {
    _routes.add(routeName);
    getIt<ScreenProtectionService>().syncFromRoutes(_routes);
  }

  /// Do not call this method from directly.
  /// It is handled by route observer
  void removeRoute(String routeName) {
    if (_routes.isNotEmpty && _routes.last == routeName) {
      _routes.removeLast();
    } else {
      _routes.removeWhere((e) => e == routeName);
    }
    getIt<ScreenProtectionService>().syncFromRoutes(_routes);
  }

  Future<dynamic> navigateTo(String routeName, {dynamic extra}) {
    return ctx!.pushNamed(routeName, extra: extra);
  }

  void pushAndRemoveUntil(String routeName, {Object? extra}) {
    ctx?.goNamed(routeName, extra: extra);
  }

  void popUntil(String targetRoute) {
    if (ctx == null) return;

    Navigator.of(ctx!).popUntil((route) {
      final name = route.settings.name;
      return name == targetRoute;
    });

    // Rebuild the routes list after popping
    final index = _routes.indexOf(targetRoute);
    if (index != -1) {
      _routes = _routes.sublist(0, index + 1);
    }
  }

  void goBack([Object? data]) {
    ctx?.pop(data);
  }

  bool? canPop() => ctx?.canPop();

  void pushReplacement(String routeName, {Object? extra}) {
    ctx?.pushReplacementNamed(routeName, extra: extra);
  }

  BuildContext getNavigationContext() {
    if (rootNavigatorKey.currentState == null) {
      throw Exception("Navigation is not initialized");
    }
    return ctx!;
  }
}

class MyNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    getIt<NavigationService>().addRoute(route.settings.name ?? "");
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    getIt<NavigationService>().removeRoute(route.settings.name ?? "");
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    getIt<NavigationService>().removeRoute(route.settings.name ?? "");
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute?.settings.name != null) {
      getIt<NavigationService>().removeRoute(oldRoute!.settings.name!);
    }
    if (newRoute?.settings.name != null) {
      getIt<NavigationService>().addRoute(newRoute!.settings.name!);
    }
  }
}
