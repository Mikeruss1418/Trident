import 'dart:io' if (dart.library.html) '../utils/io_platform_stub.dart' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension WidgetExtension on Widget {
  //for tapping
  InkWell onTap(GestureTapCallback callback, {bool haptics = false}) => InkWell(
        onTap: () {
          if (haptics) {
            if (io.Platform.isIOS) {
              HapticFeedback.heavyImpact();
            } else {
              HapticFeedback.vibrate();
            }
          }
          callback();
        },
        splashColor: Colors.transparent,
        child: this,
      );

  //for padding
  Padding padding({
    EdgeInsetsGeometry padding = const EdgeInsets.all(0),
  }) =>
      Padding(
        padding: padding,
        child: this,
      );
}
