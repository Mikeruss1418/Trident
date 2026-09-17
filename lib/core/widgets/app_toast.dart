import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:trident/core/constants/app_colors.dart';
import 'package:trident/core/widgets/text/text_widget.dart';

/// [ToastType] defines the semantic flavor of a toast, controlling
/// the icon and icon color shown alongside the message.
enum ToastType {
  /// Informational. Icon: [Icons.info_outline_rounded], color: [AppColors.primary].
  info,

  /// Success. Icon: [Icons.check_circle_outline_rounded], color: [AppColors.success].
  success,

  /// Warning. Icon: [Icons.warning_amber_outlined], color: [AppColors.warning].
  warning,

  /// Error. Icon: [Icons.error_outline], color: [AppColors.error].
  error,
}

/// Resolves the icon and icon color for a given [ToastType].
class ToastFlavor {
  const ToastFlavor(this.icon, this.color);

  final IconData icon;
  final Color color;

  static ToastFlavor fromType(ToastType type) {
    switch (type) {
      case ToastType.info:
        return const ToastFlavor(Icons.info_outline_rounded, AppColors.primary);
      case ToastType.success:
        return const ToastFlavor(
          Icons.check_circle_outline_rounded,
          AppColors.success,
        );
      case ToastType.warning:
        return const ToastFlavor(
          Icons.warning_amber_outlined,
          AppColors.warning,
        );
      case ToastType.error:
        return const ToastFlavor(Icons.error_outline, AppColors.error);
    }
  }
}

/// [AppToast] displays a non-blocking, auto-dismissable overlay toast
/// that follows the app's dark-theme surface/card styling.
///
/// Uses [AppColors.surfaceContainer] as the background (matching [AppTheme]
/// [CardThemeData]), [AppColors.border] for the side stroke,
/// [AppColors.shadow] for the drop shadow, and a 14.r radius to stay
/// consistent with cards in the rest of the UI.
class AppToast {
  static _ToastEntry? _active;

  static void showToast(
    String message,
    BuildContext context, {

    /// in seconds
    int? duration,

    /// Defaults to [ToastType.info].
    ToastType type = ToastType.info,

    /// Overrides the icon derived from [type].
    IconData? icon,

    /// Overrides the icon color derived from [type]. Defaults to the
    /// color resolved from [type].
    Color? iconColor,
  }) {
    if (!context.mounted) return;

    final overlay = Overlay.of(context);

    _dismissActive(animate: true);

    final flavor = icon == null && iconColor == null
        ? ToastFlavor.fromType(type)
        : ToastFlavor(
            icon ?? Icons.info_outline_rounded,
            iconColor ?? AppColors.primary,
          );

    final entry = _ToastEntry(
      message: message,
      overlay: overlay,
      duration: duration,
      icon: flavor.icon,
      iconColor: flavor.color,
    );
    _active = entry;
    entry.insert();
  }

  static void _dismissActive({bool animate = true}) {
    final entry = _active;
    if (entry == null) return;
    _active = null;
    entry.dismiss(animate: animate);
  }
}

class _ToastEntry extends TickerProvider {
  _ToastEntry({
    required this.message,
    required this.overlay,
    this.duration,
    required this.icon,
    required this.iconColor,
  });

  final String message;
  final OverlayState overlay;
  final int? duration;
  final IconData icon;
  final Color iconColor;

  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final OverlayEntry _overlayEntry;

  Timer? _dismissTimer;
  bool _disposed = false;

  void insert() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _overlayEntry = OverlayEntry(builder: _build);
    overlay.insert(_overlayEntry);

    _controller.forward().then((_) {
      _dismissTimer = Timer(Duration(seconds: duration ?? 3), () {
        dismiss(animate: true);
        if (AppToast._active == this) AppToast._active = null;
      });
    });
  }

  Future<void> dismiss({bool animate = true}) async {
    if (_disposed) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (animate && _controller.status != AnimationStatus.dismissed) {
      await _controller.reverse();
    }

    _overlayEntry.remove();
    _dispose();
  }

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.dispose();
  }

  Widget _build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20.h,
      left: 12.0.w,
      right: 12.0.w,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: 50.h, maxHeight: 120.h),
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 14.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12.r,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: iconColor),
                  10.horizontalSpace,
                  Expanded(
                    child: TextWidget(
                      message,
                      textType: TextType.bodyLarge,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final Set<Ticker> _tickers = {};

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    _tickers.add(ticker);
    return ticker;
  }
}
