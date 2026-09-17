import 'package:flutter/foundation.dart';

import 'package:trident/core/utils/app_imports.dart';

class BottomNavWidget extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const BottomNavWidget({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  BottomNavWidgetState createState() => BottomNavWidgetState();
}

class BottomNavWidgetState extends State<BottomNavWidget> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 6.0),
            blurRadius: 6.0,
            spreadRadius: 3.0,
            color: Colors.black.withAlpha(50),
          ),
        ],
        borderRadius: BorderRadius.circular(10.r),
        color: AppColors.surfaceContainer,
      ),
      child: BottomAppBar(
        elevation: 20.r,
        height: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            ? 60.h
            : 70.h,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        shadowColor: Colors.transparent,
        notchMargin: 6.h,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: _buildNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                index: 0,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                label: 'Documents',
                icon: Icons.folder_outlined,
                index: 1,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                label: 'Recent',
                icon: Icons.history,
                index: 2,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                label: 'Settings',
                icon: Icons.settings_outlined,
                index: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InkWell _buildNavItem({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final isSelected = widget.currentIndex == index;
    return InkWell(
      onTap: () => widget.onTabSelected(index),
      splashColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          5.verticalSpace,
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),

          TextWidget(
            label,

            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
