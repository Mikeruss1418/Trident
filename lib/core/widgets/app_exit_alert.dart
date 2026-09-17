import 'package:flutter/services.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/widgets/app_toast.dart';

class AppExitAlert extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPop;
  final bool isToDisplayExitMessage;
  final Function()? optionalWillPopFunction;

  const AppExitAlert({
    super.key,
    required this.child,
    this.onPop,
    this.isToDisplayExitMessage = true,
    this.optionalWillPopFunction,
  });

  @override
  State<AppExitAlert> createState() => _AppExitAlertState();
}

class _AppExitAlertState extends State<AppExitAlert> {
  DateTime? _lastBackPressTime;

  void _showExitToast() {
    AppToast.showToast('Press again to exit', context);
  }

  void _exitApp() {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }

  Future<void> _handleBackPress() async {
    DateTime now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      _showExitToast();
    } else {
      widget.onPop?.call();
      _exitApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (widget.isToDisplayExitMessage) {
          _handleBackPress();
        }
        widget.optionalWillPopFunction?.call();
      },
      child: widget.child,
    );
  }
}
