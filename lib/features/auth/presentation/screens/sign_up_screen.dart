import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/utils/logger/app_logger.dart';
import 'package:trident/features/auth/domains/models/password_requirements_model.dart';
import 'package:trident/features/auth/domains/services/password_validator_service.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';
import 'package:trident/features/auth/presentation/widgets/password_strength_indicator_widget.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _masterPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _isLoading = ValueNotifier(false);

  final _errorMessage = ValueNotifier<String?>(null);
  final _obscurePassword = ValueNotifier(true);
  final _obscureConfirm = ValueNotifier(true);

  final _passwordRequirements = ValueNotifier(
    PasswordValidatorService.validate(''),
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _masterPasswordController.addListener(() {
      _passwordRequirements.value = PasswordValidatorService.validate(
        _masterPasswordController.text,
      );
    });
  }

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _confirmPasswordController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    _obscurePassword.dispose();
    _obscureConfirm.dispose();
    _passwordRequirements.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    AppLogger.debug('SignUpScreen._onSignUp: starting vault creation');
    _isLoading.value = true;
    _errorMessage.value = null;

    try {
      // createVault is expensive — Argon2id runs for ~800ms–1.2s.
      // This runs on the platform thread via the cryptography package's
      // isolate management. The UI stays responsive.

      await getIt<AuthCubit>().createVault(_masterPasswordController.text);
      AppLogger.debug('SignUpScreen._onSignUp: vault created successfully');
      getIt<NavigationService>().pushAndRemoveUntil(RouteNames.homeRoute);
      // AuthCubit emits authenticated → router handles navigation.
      // No Navigator.push here — routing is BlocListener's job.
    } on WrongPasswordException {
      // Shouldn't happen during creation, but handle defensively.
      AppLogger.warning(
        'SignUpScreen._onSignUp: WrongPasswordException during creation',
      );
      _errorMessage.value = 'Unexpected error. Please try again.';
    } catch (e, st) {
      AppLogger.errorWithContext(
        'SignUpScreen._onSignUp failed',
        context: 'SignUpScreen',
        error: e,
        stackTrace: st,
      );
      _errorMessage.value =
          'Failed to create vault. Please try again.${e.toString()}';
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenPadding(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                    14.horizontalSpace,
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
                  'Offline encrypted vault. Your documents stay on this device — end-to-end encrypted, no cloud, no servers.',
                  textType: TextType.bodySmall,
                  color: AppColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
                18.verticalSpace,

                /// Master password field
                _buildMasterPswField(
                  title: 'Master password',
                  controller: _masterPasswordController,
                  obscurePassword: _obscurePassword,
                  hintText: 'Enter master password',
                  validator: PasswordValidatorService.validator,
                ),
                20.verticalSpace,

                /// Confirm password field
                _buildMasterPswField(
                  title: 'Confirm password',
                  controller: _confirmPasswordController,
                  obscurePassword: _obscureConfirm,
                  hintText: 'Confirm master password',
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _masterPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                20.verticalSpace,
                ValueListenableBuilder<PasswordRequirementsModel>(
                  valueListenable: _passwordRequirements,
                  builder: (_, requirements, _) {
                    return PasswordStrengthIndicator(
                      requirements: requirements,
                    );
                  },
                ),

                /// Error message
                _buildErrorWidget(),
                20.verticalSpace,

                ///Sign Up button
                _buildSignUpBtn(),
                24.verticalSpace,

                ///Security notice
                _SecurityNotice(),
                40.verticalSpace,
              ],
            ),
          ),
        ),
      ).onTap(() => FocusScope.of(context).unfocus()),
    );
  }

  Widget _buildSignUpBtn() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (_, isLoading, _) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : _onSignUp,
            child: isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const TextWidget('Create Vault', color: AppColors.background),
          ),
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
            16.verticalSpace,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            TextWidget(title, textType: TextType.labelLarge),
            10.verticalSpace,
            TextFormField(
              controller: controller,
              obscureText: obscurePassword.value,
              enableIMEPersonalizedLearning: false,
              enableSuggestions: false,
              enableInteractiveSelection: false,
              enabled: !_isLoading.value,
              textInputAction: TextInputAction.next,
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

class _SecurityNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14.sp),
              6.horizontalSpace,
              TextWidget(
                'Your master password cannot be recovered.',
                textType: TextType.labelSmall,
              ),
            ],
          ),
          6.verticalSpace,
          TextWidget(
            'It is never stored. If you forget it, your vault cannot be unlocked. There is no account recovery.',
            textType: TextType.bodySmall,
          ),
        ],
      ),
    );
  }
}
