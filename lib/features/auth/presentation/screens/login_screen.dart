import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/biometric/biometric.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _masterPasswordController =
      TextEditingController();
  final _obscurePassword = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String?>(null);
  final _isLoading = ValueNotifier<bool>(false);
  final _isBiometricLoading = ValueNotifier<bool>(false);
  final _isBiometricEnabled = ValueNotifier<bool>(false);

  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkBiometricEnabled();
  }

  Future<void> _checkBiometricEnabled() async {
    final enabled = await getIt<AuthCubit>().isBiometricEnabled();
    _isBiometricEnabled.value = enabled;
  }

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _obscurePassword.dispose();
    _errorMessage.dispose();
    _isLoading.dispose();
    _isBiometricLoading.dispose();
    _isBiometricEnabled.dispose();
    super.dispose();
  }

  void _login() async {
    if (formKey.currentState?.validate() ?? false) {
      _isLoading.value = true;
      _errorMessage.value = null;
      try {
        await getIt<AuthCubit>().login(_masterPasswordController.text);
      } on WrongPasswordException {
        _errorMessage.value = 'Wrong password, Provide the right one';
      } catch (e) {
        _errorMessage.value = "Something went wrong: ${e.toString()}";
      } finally {
        if (mounted) {
          _isLoading.value = false;
        }
      }
    }
  }

  void _unlockWithBiometric() async {
    final biometricService = getIt<BiometricService>();
    final available = await biometricService.isAvailable();
    if (!available) {
      _errorMessage.value = 'Biometric authentication not available';
      return;
    }

    final enabled = await getIt<AuthCubit>().isBiometricEnabled();
    if (!enabled) {
      _errorMessage.value = 'Biometric unlock is not enabled for this vault';
      return;
    }

    _isBiometricLoading.value = true;
    _errorMessage.value = null;
    try {
      final success = await getIt<AuthCubit>().unlockWithBiometric();
      if (!success && mounted) {
        _errorMessage.value =
            'Biometric authentication failed. Try again or use master password.';
      }
    } catch (e) {
      _errorMessage.value = "Something went wrong: ${e.toString()}";
    } finally {
      if (mounted) {
        _isBiometricLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          ScreenPadding(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  40.verticalSpace,

                  /// Logo and title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security_outlined,
                        color: AppColors.secondary,
                        size: 28.sp,
                      ),
                      10.horizontalSpace,
                      TextWidget(
                        'Trident',
                        textType: TextType.custom,
                        color: AppColors.primary,
                        textOptions: TextOptions(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  14.verticalSpace,
                  TextWidget(
                    'Unlock your encrypted vault. Everything stays on this device. Your master password never leaves your phone.',
                    textType: TextType.bodySmall,
                    color: AppColors.textSecondary,
                    textAlign: TextAlign.center,
                  ),
                  40.verticalSpace,
                  _buildMasterPswField(
                    title: 'Master password',
                    controller: _masterPasswordController,
                    obscurePassword: _obscurePassword,
                    hintText: 'Enter your master password',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your master password';
                      }
                      return null;
                    },
                  ),
                  _buildErrorWidget(),
                  20.verticalSpace,
                  _buildLoginBtn(),
                  16.verticalSpace,
                  _buildBiometricBtn(),
                ],
              ),
            ),
          ).onTap(() {
            FocusScope.of(context).unfocus();
          }),
    );
  }

  Widget _buildLoginBtn() {
    return BlocListener<AuthCubit, AuthStatus>(
      listener: (context, state) {
        if (state == AuthStatus.authenticated) {
          _isLoading.value = false;
          _isBiometricLoading.value = false;
          getIt<NavigationService>().pushAndRemoveUntil(RouteNames.homeRoute);
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (_, isLoading, _) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : _login,
              child: isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const TextWidget(
                      'Access Vault',
                      color: AppColors.background,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBiometricBtn() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isBiometricEnabled,
      builder: (_, biometricEnabled, _) {
        if (!biometricEnabled) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: _isBiometricLoading,
          builder: (_, isLoading, _) {
            return OutlinedButton.icon(
              onPressed: isLoading ? null : _unlockWithBiometric,
              icon: isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.fingerprint),
              label: const TextWidget('Unlock with Biometric'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
                side: BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return ValueListenableBuilder<String?>(
      valueListenable: _errorMessage,
      builder: (_, error, _) {
        if (error == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            20.verticalSpace,
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.background,
                    size: 16.sp,
                  ),
                  8.horizontalSpace,
                  Expanded(
                    child: TextWidget(
                      error,
                      textType: TextType.bodySmall,
                      color: AppColors.background,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMasterPswField({
    required String title,
    required TextEditingController controller,
    required ValueNotifier<bool> obscurePassword,
    required String hintText,
    required String? Function(String?) validator,
  }) {
    return ListenableBuilder(
      listenable: Listenable.merge([obscurePassword, _isLoading]),
      builder: (_, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: .min,
          children: [
            TextWidget(title, textType: TextType.labelLarge),
            10.verticalSpace,
            TextFormField(
              controller: controller,
              obscureText: obscurePassword.value,
              enabled: !_isLoading.value,
              textInputAction: TextInputAction.done,
              autofillHints: [AutofillHints.password],
              onFieldSubmitted: (_) => _login,
              decoration: InputDecoration(
                hintText: hintText,
                suffixIcon: Icon(
                  obscurePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ).onTap(() => obscurePassword.value = !obscurePassword.value),
              ),
              validator: validator,
            ),
          ],
        );
      },
    );
  }
}
