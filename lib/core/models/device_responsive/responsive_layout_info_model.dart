
import 'package:trident/core/models/device_responsive/device_type_model.dart';

class ResponsiveLayoutInfoModel {
  final DeviceTypeEnum deviceType;
  final ScreenOrientation orientation;
  final WidthClass widthClass;
  final double screenWidth;
  final double screenHeight;

  ResponsiveLayoutInfoModel({
    required this.deviceType,
    required this.orientation,
    required this.widthClass,
    required this.screenWidth,
    required this.screenHeight,
  });

  // Helper getters for minor changes in UI
  bool get isCompact => widthClass == WidthClass.compact;
  bool get isMedium => widthClass == WidthClass.medium;
  bool get isExpanded => widthClass == WidthClass.expanded;

  bool get isPortrait => orientation == ScreenOrientation.portrait;
  bool get isLandscape => orientation == ScreenOrientation.landscape;
}
