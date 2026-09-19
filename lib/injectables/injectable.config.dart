// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../core/services/biometric/biometric.dart' as _i222;
import '../core/services/biometric/biometric_service.dart' as _i677;
import '../core/services/biometric/biometric_service_impl.dart' as _i378;
import '../core/services/documents/document_storage_service.dart' as _i465;
import '../core/services/documents/document_storage_service_impl.dart' as _i551;
import '../core/services/encryption/vault_encryption/vault_encryption_service.dart'
    as _i607;
import '../core/services/encryption/vault_encryption/vault_repository.dart'
    as _i1014;
import '../core/services/encryption/vault_encryption/vault_storage_service.dart'
    as _i761;
import '../core/services/navigation/navigation_service.dart' as _i648;
import '../core/services/screen_protection/screen_protection_service.dart'
    as _i1002;
import '../core/storage/secure_storage/secure_storage_module.dart' as _i478;
import '../core/storage/secure_storage/secure_storage_service.dart' as _i21;
import '../core/storage/secure_storage/secure_storage_service_impl.dart'
    as _i332;
import '../core/storage/shared_preferences/shared_prefs_module.dart' as _i656;
import '../core/storage/shared_preferences/shared_prefs_service.dart' as _i376;
import '../core/storage/shared_preferences/shared_prefs_service_impl.dart'
    as _i723;
import '../features/auth/presentation/cubits/auth_cubit/auth_cubit.dart'
    as _i280;
import '../features/dashboard/presentation/cubits/bottom_nav_cubit.dart'
    as _i346;
import '../features/documents/presentation/cubits/document_cubit.dart' as _i771;
import '../features/recent_activity/data/repositories/audit_log_repository.dart'
    as _i631;
import '../features/recent_activity/data/repositories/shared_prefs_audit_log_repository.dart'
    as _i1013;
import '../features/recent_activity/domain/services/audit_log_service.dart'
    as _i160;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final sharedPrefsModule = _$SharedPrefsModule();
    final secureStorageModule = _$SecureStorageModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => sharedPrefsModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i607.VaultEncryptionService>(
      () => _i607.VaultEncryptionService(),
    );
    gh.lazySingleton<_i648.NavigationService>(() => _i648.NavigationService());
    gh.lazySingleton<_i1002.ScreenProtectionService>(
      () => _i1002.ScreenProtectionService(),
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => secureStorageModule.secureprefs,
    );
    gh.lazySingleton<_i346.BottomNavCubit>(() => _i346.BottomNavCubit());
    gh.lazySingleton<_i465.DocumentStorageService>(
      () => _i551.DocumentStorageServiceImpl(),
    );
    gh.lazySingleton<_i677.BiometricService>(
      () => _i378.BiometricServiceImpl(),
    );
    gh.lazySingleton<_i21.SecureStorageService>(
      () => _i332.SecureStorageServiceImpl(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i376.SharedPrefsService>(
      () => _i723.SharedPrefsServiceImpl(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i631.AuditLogRepository>(
      () => _i1013.AuditLogRepositoryImpl(gh<_i376.SharedPrefsService>()),
    );
    gh.lazySingleton<_i160.AuditLogService>(
      () => _i160.AuditLogService(gh<_i631.AuditLogRepository>()),
    );
    gh.lazySingleton<_i761.VaultStorageService>(
      () => _i761.VaultStorageService(gh<_i21.SecureStorageService>()),
    );
    gh.lazySingleton<_i1014.VaultRepository>(
      () => _i1014.VaultRepository(
        gh<_i607.VaultEncryptionService>(),
        gh<_i761.VaultStorageService>(),
        gh<_i160.AuditLogService>(),
      ),
    );
    gh.lazySingleton<_i771.DocumentCubit>(
      () => _i771.DocumentCubit(
        gh<_i1014.VaultRepository>(),
        gh<_i465.DocumentStorageService>(),
        gh<_i160.AuditLogService>(),
      ),
    );
    gh.lazySingleton<_i280.AuthCubit>(
      () => _i280.AuthCubit(
        gh<_i1014.VaultRepository>(),
        gh<_i222.BiometricService>(),
        gh<_i160.AuditLogService>(),
      ),
    );
    return this;
  }
}

class _$SharedPrefsModule extends _i656.SharedPrefsModule {}

class _$SecureStorageModule extends _i478.SecureStorageModule {}
