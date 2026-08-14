import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/utils/logger/app_logger.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _biometricEnabled = ValueNotifier<bool>(false);
  final _isLoadingBiometric = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    AppLogger.debug('HomeScreen.initState: checking biometric status');
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final enabled = await getIt<AuthCubit>().isBiometricEnabled();
      if (!mounted) return;
      _biometricEnabled.value = enabled;
      AppLogger.debug('HomeScreen._checkBiometricStatus: biometric enabled=$enabled');
    } catch (e, st) {
      AppLogger.errorWithContext(
        'HomeScreen._checkBiometricStatus failed',
        context: 'HomeScreen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _biometricEnabled.value = false;
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    AppLogger.debug('HomeScreen._toggleBiometric: toggling biometric to $enable');
    if (enable) {
      await _enableBiometric();
    } else {
      await _disableBiometric();
    }
  }

  Future<void> _enableBiometric() async {
    AppLogger.debug('HomeScreen._enableBiometric: starting biometric enable flow');
    _isLoadingBiometric.value = true;
    try {
      final authCubit = getIt<AuthCubit>();
      final available = await authCubit.isBiometricAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometric authentication not available on this device',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        _biometricEnabled.value = false;
        return;
      }

      await authCubit.enableBiometric();
      _biometricEnabled.value = true;
      AppLogger.debug('HomeScreen._enableBiometric: biometric enabled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric unlock enabled'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      _biometricEnabled.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to enable biometric. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isLoadingBiometric.value = false;
    }
  }

  Future<void> _disableBiometric() async {
    AppLogger.debug('HomeScreen._disableBiometric: starting biometric disable flow');
    _isLoadingBiometric.value = true;
    try {
      await getIt<AuthCubit>().disableBiometric();
      _biometricEnabled.value = false;
      AppLogger.debug('HomeScreen._disableBiometric: biometric disabled successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric unlock disabled'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to disable biometric. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isLoadingBiometric.value = false;
    }
  }

  void _lockVault() {
    AppLogger.debug('HomeScreen._lockVault: locking vault and navigating to login');
    getIt<AuthCubit>().lockVault();
    getIt<NavigationService>().pushAndRemoveUntil(RouteNames.loginRoute);
  }

  @override
  void dispose() {
    _biometricEnabled.dispose();
    _isLoadingBiometric.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextWidget("Trident Vault", textType: TextType.headlineLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: _lockVault,
            tooltip: 'Lock Vault',
          ),
        ],
      ),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            20.verticalSpace,

            /// Vault Status
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                        12.horizontalSpace,
                        TextWidget(
                          'Vault Status',
                          textType: TextType.titleLarge,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                    16.verticalSpace,
                    _StatusRow(
                      label: 'Status',
                      value: 'Unlocked',
                      valueColor: AppColors.success,
                    ),
                    8.verticalSpace,
                    _StatusRow(label: 'Encryption', value: 'AES-256-GCM'),
                    8.verticalSpace,
                    _StatusRow(
                      label: 'Key Derivation',
                      value: 'Argon2id (64MB, 3 iter)',
                    ),
                  ],
                ),
              ),
            ),

            24.verticalSpace,

            /// Biometric Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                        12.horizontalSpace,
                        TextWidget(
                          'Biometric Unlock',
                          textType: TextType.titleLarge,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                    16.verticalSpace,
                    ValueListenableBuilder<bool>(
                      valueListenable: _biometricEnabled,
                      builder: (_, enabled, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _isLoadingBiometric,
                          builder: (_, loading, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile(
                                  title: TextWidget(
                                    'Unlock with Biometric',
                                    textType: TextType.bodyLarge,
                                  ),
                                  subtitle: TextWidget(
                                    enabled
                                        ? 'Face ID / Fingerprint enabled'
                                        : 'Use master password only',
                                    textType: TextType.bodySmall,
                                    color: AppColors.textSecondary,
                                  ),
                                  value: enabled,
                                  onChanged: loading ? null : _toggleBiometric,
                                  activeThumbColor: AppColors.primary,
                                  inactiveThumbColor: AppColors.textSecondary,
                                  inactiveTrackColor: AppColors.surfaceElevated,
                                ),
                                if (loading) ...[
                                  8.verticalSpace,
                                  Center(
                                    child: SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                    8.verticalSpace,
                    TextWidget(
                      'Biometric data never leaves your device. The vault key is encrypted with a key protected by your device\'s secure hardware.',
                      textType: TextType.bodySmall,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            24.verticalSpace,

            /// Actions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                        12.horizontalSpace,
                        TextWidget(
                          'Vault Actions',
                          textType: TextType.titleLarge,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                    16.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: TextWidget(
                          'Lock Vault',
                          color: AppColors.textPrimary,
                        ),
                        onPressed: _lockVault,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                      ),
                    ),
                    12.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.logout),
                        label: TextWidget(
                          'Logout',
                          color: AppColors.background,
                        ),
                        onPressed: () {
                          AppLogger.debug('HomeScreen.logout: logging out');
                          getIt<AuthCubit>().logout();
                          getIt<NavigationService>().pushAndRemoveUntil(
                            RouteNames.loginRoute,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextWidget(
          label,
          textType: TextType.bodyMedium,
          color: AppColors.textSecondary,
        ),
        TextWidget(
          value,
          textType: TextType.custom,
          color: valueColor ?? AppColors.textPrimary,
          textOptions: TextOptions(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
