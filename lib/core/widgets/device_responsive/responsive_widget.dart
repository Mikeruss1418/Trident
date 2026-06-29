import 'package:trident/core/models/device_responsive/device_type_model.dart';
import 'package:trident/core/models/device_responsive/responsive_layout_info_model.dart';
import 'package:trident/core/services/device_responsive/responsive_service.dart';
import 'package:trident/core/utils/app_imports.dart';

class ResponsiveLayoutWidget extends StatelessWidget {
  /// The default layout, primarily used for mobile devices in portrait orientation.
  /// This is required to guarantee there is always a fallback widget.
  final WidgetBuilder mobilePortrait;

  /// Optional layout for mobile devices in landscape orientation.
  final WidgetBuilder? mobileLandscape;

  /// Optional layout for tablets in portrait orientation.
  final WidgetBuilder? tabletPortrait;

  /// Optional layout for tablets in landscape orientation.
  final WidgetBuilder? tabletLandscape;

  /// An optional generic builder if you prefer to write custom switch logic
  /// inline using the [ResponsiveLayoutInfoModel].
  final Widget Function(BuildContext context, ResponsiveLayoutInfoModel layout)?
      builder;

  const ResponsiveLayoutWidget({
    super.key,
    required this.mobilePortrait,
    this.mobileLandscape,
    this.tabletPortrait,
    this.tabletLandscape,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.responsive;

    // 1. If a custom dynamic builder is supplied, use it.
    if (builder != null) {
      return builder!(context, layout);
    }

    // 2. Resolve layout based on DeviceTypeEnum and Orientation with safe fallbacks.
    switch (layout.deviceType) {
      case DeviceTypeEnum.mobile:
        if (layout.isPortrait) {
          return mobilePortrait(context);
        } else {
          // Fallback sequence for Mobile Landscape
          final widgetBuilder = mobileLandscape ?? mobilePortrait;
          return widgetBuilder(context);
        }

      case DeviceTypeEnum.tablet:
        if (layout.isPortrait) {
          // Fallback sequence for Tablet Portrait
          final widgetBuilder = tabletPortrait ?? mobilePortrait;
          return widgetBuilder(context);
        } else {
          // Fallback sequence for Tablet Landscape
          final widgetBuilder = tabletLandscape ??
              tabletPortrait ??
              mobileLandscape ??
              mobilePortrait;
          return widgetBuilder(context);
        }
    }
  }
}
