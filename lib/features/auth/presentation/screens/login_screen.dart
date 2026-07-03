import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/routes/route_names.dart';
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

  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _obscurePassword.dispose();
    _errorMessage.dispose();
    _isLoading.dispose();
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
          crossAxisAlignment: .start,
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
