import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/utils/logger/app_logger.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  final _isLoading = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _confirmationController.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  /// Validates that the user typed "DELETE" exactly (case-sensitive).
  bool get _isConfirmed => _confirmationController.text == 'DELETE';

  void _deleteAccount() {
    if (!_isConfirmed) return;

    AppLogger.debug(
      'DeleteAccountScreen._deleteAccount: confirming vault deletion',
    );
    _isLoading.value = true;

    try {
      getIt<AuthCubit>().deleteAccount();
      AppLogger.debug(
        'DeleteAccountScreen._deleteAccount: vault deleted, state emitted onboarding',
      );

      // AuthCubit emits onboarding → GoRouter redirect sends user to /sign-up.
      // Also explicitly clear the navigation stack so back button can't return.
      getIt<NavigationService>().pushAndRemoveUntil(RouteNames.signUpRoute);
    } catch (e, st) {
      AppLogger.errorWithContext(
        'DeleteAccountScreen._deleteAccount failed',
        context: 'DeleteAccountScreen',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete vault: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextWidget('Delete Account', textType: TextType.headlineLarge),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ScreenPadding(
        child: Container(
          color: AppColors.background,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading.value
                      ? null
                      : () {
                          AppLogger.debug(
                            'DeleteAccountScreen: cancelling deletion',
                          );
                          getIt<NavigationService>().goBack();
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: TextWidget('Cancel', color: AppColors.textPrimary),
                ),
              ),
              16.horizontalSpace,
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (_, isLoading, _) {
                    return FilledButton(
                      onPressed: _isConfirmed && !isLoading
                          ? _deleteAccount
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.background,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        disabledBackgroundColor: AppColors.surfaceElevated,
                        disabledForegroundColor: AppColors.textTertiary,
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : TextWidget(
                              'Delete Vault',
                              color: AppColors.background,
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: BlocListener<AuthCubit, AuthStatus>(
        listener: (context, state) {
          // After deletion, AuthCubit emits onboarding. The router redirect
          // will handle navigation to /sign-up, but we also handle it here
          // as a fallback in case the listener fires before the redirect.
          if (state == AuthStatus.onboarding) {
            getIt<NavigationService>().pushAndRemoveUntil(
              RouteNames.signUpRoute,
            );
          }
        },
        child: ScreenPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              24.verticalSpace,

              /// Warning header
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.error,
                    size: 28.sp,
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: TextWidget(
                      'Delete Vault Permanently',
                      textType: TextType.titleLarge,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              24.verticalSpace,

              /// Warning message
              TextWidget(
                'This action cannot be undone. All encrypted vault data — '
                'your master password salt, encrypted DEK, password verifier, '
                'and any biometric unlock keys — will be permanently destroyed. '
                'Once deleted, your vault cannot be recovered.',
                textType: TextType.bodyMedium,
                color: AppColors.textPrimary,
              ),
              16.verticalSpace,
              TextWidget(
                'Make sure you have a backup of any data you want to keep. '
                'Enter DELETE below to confirm.',
                textType: TextType.bodySmall,
                color: AppColors.textSecondary,
              ),
              32.verticalSpace,

              /// Confirmation input
              TextWidget(
                'Type DELETE to confirm',
                textType: TextType.labelLarge,
              ),
              10.verticalSpace,
              TextField(
                controller: _confirmationController,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onChanged: (_) {
                  // Trigger rebuild to update button state
                  setState(() {});
                },
                style: TextStyle(color: AppColors.textPrimary),
              ),
              8.verticalSpace,
              TextWidget(
                'Vault will be destroyed immediately upon confirmation.',
                textType: TextType.bodySmall,
                color: AppColors.textTertiary,
              ),
              32.verticalSpace,

              /// Action buttons
            ],
          ),
        ),
      ),
    );
  }
}
