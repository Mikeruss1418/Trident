import 'package:injectable/injectable.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/screen_protection/screen_protection_controller.dart';
import 'package:trident/features/dashboard/data/constants/dashboard_constants.dart';

@lazySingleton
class ScreenProtectionService {
  static const Set<String> _protectedRoutes = <String>{
    RouteNames.loginRoute,
    RouteNames.signUpRoute,
  };

  /// only checked when the top-of-stack route is dashboardRoute —
  /// i.e. these are IndexedStack tabs, not named routes.
  static const Set<String> _protectedDashboardTabs = <String>{};

  List<String> _lastRoutes = const [];
  List<String> _lastTabHistory = const [BottomNavString.home];

  void syncFromRoutes(List<String> routes) {
    _lastRoutes = routes;
    _recompute();
  }

  void syncFromBottomNav(List<String> tabHistory) {
    _lastTabHistory = tabHistory;
    _recompute();
  }

  void _recompute() {
    final topRoute = _lastRoutes.isNotEmpty ? _lastRoutes.last : null;

    final bool shouldProtect;
    if (topRoute != null && _protectedRoutes.contains(topRoute)) {
      shouldProtect = true;
    } else if (topRoute == RouteNames.dashboardRoute) {
      final currentTab = _lastTabHistory.isNotEmpty
          ? _lastTabHistory.last
          : BottomNavString.home;
      shouldProtect = _protectedDashboardTabs.contains(currentTab);
    } else {
      shouldProtect = false;
    }

    ScreenProtectionController.instance.setEnabled(shouldProtect);
  }
}
