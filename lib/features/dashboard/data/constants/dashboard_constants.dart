import 'package:flutter/material.dart';
import 'package:trident/features/documents/presentation/screens/document_screen.dart';
import 'package:trident/features/home/presentation/screens/home_screen.dart';
import 'package:trident/features/recent_activity/presentation/screens/recent_activity_screen.dart';
import 'package:trident/features/settings/presentation/screens/setting_screen.dart';

class BottomNavString {
  static const String home = "Home";
  static const String documents = "Documents";
  static const String recentActivity = "Activity";
  static const String setting = 'Settings';
}

class DashboardConstants {
  final Map<String, Widget> screenMap = {
    BottomNavString.home: HomeScreen(),
    BottomNavString.documents: DocumentScreen(),
    BottomNavString.recentActivity: RecentActivityScreen(),
    BottomNavString.setting: SettingScreen(),
  };
}
