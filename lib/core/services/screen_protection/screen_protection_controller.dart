import 'dart:io';

import 'package:screen_protector/screen_protector.dart';
import 'package:trident/core/utils/logger/app_logger.dart';

class ScreenProtectionController {
  ScreenProtectionController._();
  static final ScreenProtectionController instance =
      ScreenProtectionController._();

  bool? _current; // null = unknown/unset, forces first call through
  /// to prevent race condition when 2 setEnabled  is called in quick succession
  Future<void> _chain = Future.value();

  /// Idempotent, serialized. Call as often as you want — only
  /// transitions actually hit the platform channel.
  void setEnabled(bool enabled) {
    if (_current == enabled) return;
    _current = enabled;
    _chain = _chain.then((_) => enabled ? _enable() : _disable());
  }

  Future<void> _enable() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithBlur();
      }
    } catch (e, st) {
      AppLogger.errorWithContext(
        "Failed to enable screen protection",
        context: 'ScreenProtection',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _disable() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
      } else if (Platform.isIOS) {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageWithBlurOff();
      }
    } catch (e, st) {
      AppLogger.errorWithContext(
        "Failed to disable screen protection",
        context: 'ScreenProtection',
        error: e,
        stackTrace: st,
      );
    }
  }
}
