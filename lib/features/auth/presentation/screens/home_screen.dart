import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/biometric/biometric.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_repository.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
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
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final repo = getIt<VaultRepository>();
    final enabled = await repo.isBiometricEnabled();
    _biometricEnabled.value = enabled;
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      _enableBiometric();
    } else {
      _disableBiometric();
    }
  }

  Future<void> _enableBiometric() async {
    _isLoadingBiometric.value = true;
    try {
      final biometricService = getIt<BiometricService>();
      final available = await biometricService.isAvailable();
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

      await getIt<VaultRepository>().enableBiometric(
        biometricService: biometricService,
      );
      _biometricEnabled.value = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric unlock enabled'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      
    } catch (e) {
      _biometricEnabled.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enable biometric: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isLoadingBiometric.value = false;
    }
  }

  Future<void> _disableBiometric() async {
    _isLoadingBiometric.value = true;
    try {
      await getIt<VaultRepository>().disableBiometric();
      _biometricEnabled.value = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric unlock disabled'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disable biometric: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isLoadingBiometric.value = false;
    }
  }

  void _lockVault() {
    getIt<AuthCubit>().lockVault();
    getIt<NavigationService>().pushAndRemoveUntil(RouteNames.loginRoute);
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
                            return SwitchListTile(
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
                            );
                          },
                        );
                      },
                    ),
                    if (_isLoadingBiometric.value) ...[
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
