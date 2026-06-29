import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/encrytion/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _masterPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _obscurePassword = ValueNotifier(true);
  final _obscureConfirm = ValueNotifier(true);
  final _formKey = GlobalKey<FormState>();

  // Whether the vault creation crypto work is in flight.
  // Drives loading state — disables button, shows spinner.
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _confirmPasswordController.dispose();
    _obscurePassword.dispose();
    _obscureConfirm.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // createVault is expensive — Argon2id runs for ~800ms–1.2s.
      // This runs on the platform thread via the cryptography package's
      // isolate management. The UI stays responsive.
      
      await getIt<AuthCubit>().createVault(_masterPasswordController.text);
      getIt<NavigationService>().navigateTo(RouteNames.homeRoute);
      // AuthCubit emits authenticated → router handles navigation.
      // No Navigator.push here — routing is BlocListener's job.
    } on WrongPasswordException {
      // Shouldn't happen during creation, but handle defensively.
      setState(() => _errorMessage = 'Unexpected error. Please try again.');
    } catch (e) {
      setState(
        () => _errorMessage =
            'Failed to create vault. Please try again.${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    // final colorScheme = theme.colorScheme;

    return Scaffold(
      body: ScreenPadding(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                40.verticalSpace,

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
                  'Offline encrypted vault. Your documents stay on this device — end-to-end encrypted, no cloud, no servers.',
                  textType: TextType.bodySmall,
                  color: AppColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
                18.verticalSpace,

                Align(
                  alignment: Alignment.topLeft,
                  child: TextWidget(
                    'Master password',
                    textType: TextType.labelLarge,
                  ),
                ),
                10.verticalSpace,

                ValueListenableBuilder<bool>(
                  valueListenable: _obscurePassword,
                  builder: (_, obscure, _) {
                    return TextFormField(
                      controller: _masterPasswordController,
                      obscureText: obscure,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Enter master password',
                        suffixIcon: _VisibilityToggle(
                          obscure: obscure,
                          onToggle: () =>
                              _obscurePassword.value = !_obscurePassword.value,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) {
                          return 'At least 8 characters required';
                        }
                        return null;
                      },
                    );
                  },
                ),
                20.verticalSpace,

                // ── Confirm password label ────────────────────────────
                Align(
                  alignment: Alignment.topLeft,
                  child: TextWidget(
                    'Confirm password',
                    textType: TextType.labelLarge,
                  ),
                ),
                10.verticalSpace,

                // ── Confirm password field ────────────────────────────
                ValueListenableBuilder<bool>(
                  valueListenable: _obscureConfirm,
                  builder: (_, obscure, _) {
                    return TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: obscure,
                      enabled: !_isLoading,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSignUp(),
                      decoration: InputDecoration(
                        hintText: 'Confirm master password',
                        suffixIcon: _VisibilityToggle(
                          obscure: obscure,
                          onToggle: () =>
                              _obscureConfirm.value = !_obscureConfirm.value,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _masterPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    );
                  },
                ),
                20.verticalSpace,

                // ── Error message ─────────────────────────────────────
                if (_errorMessage != null) ...[
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
                          color: AppColors.error,
                          size: 16.sp,
                        ),
                        8.horizontalSpace,
                        Expanded(
                          child: TextWidget(
                            _errorMessage!,
                            textType: TextType.bodySmall,
                            color: AppColors.background,
                          ),
                        ),
                      ],
                    ),
                  ),
                  16.verticalSpace,
                ],

                // ── Sign Up button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _onSignUp,
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const TextWidget(
                            'Create Vault',
                            color: AppColors.background,
                          ),
                  ),
                ),
                24.verticalSpace,

                // ── Security notice ───────────────────────────────────
                _SecurityNotice(),
                40.verticalSpace,
              ],
            ),
          ),
        ),
      ).onTap(() => FocusScope.of(context).unfocus()),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;

  const _VisibilityToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
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
