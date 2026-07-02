import 'package:flutter/widgets.dart';
import 'package:trident/core/models/device_responsive/device_type_model.dart';
import 'package:trident/core/models/device_responsive/responsive_layout_info_model.dart';

class ResponsiveService {
  static ResponsiveLayoutInfoModel of(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double width = mediaQuery.size.width;
    final double height = mediaQuery.size.height;

    // 1. Determine Orientation
    final ScreenOrientation orientation =
        mediaQuery.orientation == Orientation.portrait
        ? ScreenOrientation.portrait
        : ScreenOrientation.landscape;

    // 2. Determine Physical Device Type (using shortestSide)
    final DeviceTypeEnum deviceType = mediaQuery.size.shortestSide < 600
        ? DeviceTypeEnum.mobile
        : DeviceTypeEnum.tablet;

    // 3. Determine Dynamic Width Class (using current available width)
    final WidthClass widthClass;
    if (width < 600) {
      widthClass = WidthClass.compact;
    } else if (width < 840) {
      widthClass = WidthClass.medium;
    } else {
      widthClass = WidthClass.expanded;
    }

    return ResponsiveLayoutInfoModel(
      deviceType: deviceType,
      orientation: orientation,
      widthClass: widthClass,
      screenWidth: width,
      screenHeight: height,
    );
  }
}

// Extension to easily access via context
extension ResponsiveContext on BuildContext {
  ResponsiveLayoutInfoModel get responsive => ResponsiveService.of(this);
}
