import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trident/core/mixins/initial_app_mixins.dart';
import 'package:trident/core/services/screen_protection/screen_protection_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/utils/logger/app_logger.dart';
import 'package:trident/core/widgets/app_exit_alert.dart';
import 'package:trident/features/dashboard/data/constants/dashboard_constants.dart';
import 'package:trident/features/dashboard/presentation/cubits/bottom_nav_cubit.dart';
import 'package:trident/features/dashboard/presentation/widgets/bottom_nav_widget.dart';
import 'package:trident/features/documents/domain/services/document_services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with InitialAppMixins {
  void _fetchAccordingToNav(String tab) {
    switch (tab) {
      case BottomNavString.home:
        if (!visitedBottomNavBar.contains(BottomNavString.home)) {
          visitedBottomNavBar.add(BottomNavString.home);
          fetchHomeInitialData();
        }
        break;
      case BottomNavString.documents:
        if (!visitedBottomNavBar.contains(BottomNavString.documents)) {
          visitedBottomNavBar.add(BottomNavString.documents);
          fetchDocumentInitialData();
        }
        break;
      case BottomNavString.recentActivity:
        if (!visitedBottomNavBar.contains(BottomNavString.recentActivity)) {
          visitedBottomNavBar.add(BottomNavString.recentActivity);
          fetchRecentInitialData();
        }
        break;
      case BottomNavString.setting:
        if (!visitedBottomNavBar.contains(BottomNavString.setting)) {
          visitedBottomNavBar.add(BottomNavString.setting);
          fetchSettingInitialData();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BottomNavCubit, List<String>>(
      listener: (context, tabHistory) {
        final String currentScreen = tabHistory.last;
        AppLogger.debug('Tab history: ${tabHistory.toString()}');
        getIt<ScreenProtectionService>().syncFromBottomNav(tabHistory);

        /// --------------------fetch data According to the tab history---------------------
        _fetchAccordingToNav(currentScreen);
      },
      builder: (context, tabHistory) {
        final screens = DashboardConstants().screenMap;
        final String currentKey = tabHistory.last;
        final int currentIndex = screens.keys.toList().indexOf(currentKey);
        return AppExitAlert(
          isToDisplayExitMessage: currentKey == BottomNavString.home,
          optionalWillPopFunction: () {
            if (tabHistory.length > 1) {
              AppLogger.debug('Tab history on back: ${tabHistory.toString()}');
              getIt<BottomNavCubit>().goBack();
            }
          },
          child: Scaffold(
            bottomNavigationBar: BottomNavWidget(
              currentIndex: currentIndex,
              onTabSelected: (index) {
                final key = screens.keys.toList()[index];

                getIt<BottomNavCubit>().updateScreen(key);
              },
            ),
            floatingActionButton: InkWell(
              onTap: () => DocumentServices.instance.handleImport(context),
              child: CircleAvatar(
                radius: 25.r,
                child: Icon(Icons.add, size: 30.r),
              ),
            ),
            body: IndexedStack(
              index: currentIndex,
              children: screens.values.toList(),
            ),
          ),
        );
      },
    );
  }
}
