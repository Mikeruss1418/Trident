import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/services/biometric/biometric.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_repository.dart';
import 'package:trident/core/utils/logger/app_logger.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';
import 'package:trident/features/recent_activity/domain/services/audit_log_service.dart';

// User registered
// ↓
// Authenticated
// ↓
// App goes background
// ↓
// Vault Locked
// ↓
// Biometric unlock
// ↓
// Authenticated

/// a more revised flow implementation

// First Launch
// ↓
// onboarding
// ↓
// User creates vault password
// ↓
// unauthenticated
// ↓
// Login
// ↓
// authenticated
// ↓
// Background > 5 min
// ↓
// vaultLocked
// ↓
// Biometric unlock
// ↓
// authenticated

enum AuthStatus { onboarding, unauthenticated, authenticated, vaultLocked }

/// AuthCubit owns auth state transitions only.
///
/// Hard rules:
///   - Never stores passwords
///   - Never stores keys
///   - Never performs cryptography
///   - Never accesses secure storage
///
/// All vault operations delegate to VaultRepository.
@lazySingleton
class AuthCubit extends Cubit<AuthStatus> {
  final VaultRepository _vaultRepository;
  final BiometricService _biometricService;
  final AuditLogService? _auditLogService;

  AuthCubit(
    this._vaultRepository,
    this._biometricService, [
    this._auditLogService,
  ]) : super(AuthStatus.onboarding);

  // -------------------------------------------------------------------------
  // App startup
  // -------------------------------------------------------------------------

  Future<void> initialize() async {
    AppLogger.debug('AuthCubit.initialize: checking vault existence');
    final exists = await _vaultRepository.vaultExists();
    AppLogger.debug('AuthCubit.initialize: vaultExists=$exists');
    emit(exists ? AuthStatus.unauthenticated : AuthStatus.onboarding);
  }

  // -------------------------------------------------------------------------
  // Onboarding (vault creation)
  // -------------------------------------------------------------------------

  /// Creates the vault. On success → [authenticated].
  /// Rethrows on failure so the UI can surface the error.
  Future<void> createVault(String masterPassword) async {
    AppLogger.debug('AuthCubit.createVault: creating new vault');
    try {
      await _vaultRepository.createVault(masterPassword);
      AppLogger.debug(
        'AuthCubit.createVault: vault created, transitioning to authenticated',
      );
      _auditLogService?.log(
        AuditLogEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: AuditLogType.vaultCreated,
          title: 'Vault Created',
          description: 'A new encrypted vault was created on this device.',
        ),
      );
      emit(AuthStatus.authenticated);
    } catch (e, st) {
      AppLogger.errorWithContext(
        'AuthCubit.createVault failed',
        context: 'AuthCubit',
        error: e,
        stackTrace: st,
      );
      emit(AuthStatus.onboarding);
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Login
  // -------------------------------------------------------------------------

  /// Throws [WrongPasswordException] on bad password.
  Future<void> login(String masterPassword) async {
    AppLogger.debug(
      'AuthCubit.login: attempting vault unlock with master password',
    );
    try {
      await _vaultRepository.unlockVault(masterPassword);
      AppLogger.debug(
        'AuthCubit.login: unlock successful, transitioning to authenticated',
      );
      _auditLogService?.log(
        AuditLogEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: AuditLogType.login,
          title: 'Vault Accessed',
          description: 'The vault was unlocked with the master password.',
        ),
      );
      emit(AuthStatus.authenticated);
    } catch (e, st) {
      AppLogger.errorWithContext(
        'AuthCubit.login failed',
        context: 'AuthCubit',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Lock / Unlock
  // -------------------------------------------------------------------------

  void lockVault() {
    if (state != AuthStatus.authenticated) {
      AppLogger.debug('AuthCubit.lockVault: ignored — current state is $state');
      return;
    }
    AppLogger.debug('AuthCubit.lockVault: locking vault');
    _vaultRepository.lockVault();
    _auditLogService?.log(
      AuditLogEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: AuditLogType.lockVault,
        title: 'Vault Locked',
        description:
            'The vault was locked and the encryption key was cleared from memory.',
      ),
    );
    emit(AuthStatus.vaultLocked);
    AppLogger.debug(
      'AuthCubit.lockVault: vault locked, state is now vaultLocked',
    );
  }

  Future<void> unlockVault(String masterPassword) async {
    if (state != AuthStatus.vaultLocked) {
      AppLogger.debug(
        'AuthCubit.unlockVault: ignored — current state is $state',
      );
      return;
    }
    AppLogger.debug(
      'AuthCubit.unlockVault: attempting unlock with master password',
    );
    _auditLogService?.log(
      AuditLogEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: AuditLogType.unlockVault,
        title: 'Vault Unlocked',
        description: 'The vault was unlocked with the master password.',
      ),
    );
    await _vaultRepository.unlockVault(masterPassword);
    emit(AuthStatus.authenticated);
    AppLogger.debug(
      'AuthCubit.unlockVault: vault unlocked, state is now authenticated',
    );
  }

  // -------------------------------------------------------------------------
  // Biometric methods
  // -------------------------------------------------------------------------

  /// Checks if biometric unlock is available on device
  Future<bool> isBiometricAvailable() async {
    final available = await _biometricService.isAvailable();
    AppLogger.debug('isBiometricAvailable: $available');
    return available;
  }

  /// Checks if biometric unlock is enabled for this vault
  Future<bool> isBiometricEnabled() async {
    final enabled = await _vaultRepository.isBiometricEnabled();
    AppLogger.debug('isBiometricEnabled: $enabled');
    return enabled;
  }

  /// Enables biometric unlock for the current vault
  /// Requires vault to be unlocked (DEK in memory)
  Future<void> enableBiometric() async {
    AppLogger.debug('AuthCubit.enableBiometric: enabling biometric unlock');
    await _vaultRepository.enableBiometric(biometricService: _biometricService);
    AppLogger.debug('AuthCubit.enableBiometric: biometric unlock enabled');
    _auditLogService?.log(
      AuditLogEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: AuditLogType.biometricEnabled,
        title: 'Biometric Enabled',
        description: 'Biometric unlock was enabled for this vault.',
      ),
    );
  }

  /// Disables biometric unlock and clears biometric data
  Future<void> disableBiometric() async {
    AppLogger.debug('AuthCubit.disableBiometric: disabling biometric unlock');
    await _vaultRepository.disableBiometric();
    AppLogger.debug('AuthCubit.disableBiometric: biometric unlock disabled');
    _auditLogService?.log(
      AuditLogEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: AuditLogType.biometricDisabled,
        title: 'Biometric Disabled',
        description: 'Biometric unlock was disabled for this vault.',
      ),
    );
  }

  /// Attempts to unlock the vault using biometric authentication
  /// Returns true on success, false on failure/cancellation
  ///
  /// Can be called from either [AuthStatus.vaultLocked] (after locking)
  /// or [AuthStatus.unauthenticated] (after logout), since biometric data
  /// persists in secure storage in both cases.
  Future<bool> unlockWithBiometric({
    String localizedReason = 'Unlock your Trident vault',
  }) async {
    if (state != AuthStatus.vaultLocked &&
        state != AuthStatus.unauthenticated) {
      AppLogger.debug(
        'AuthCubit.unlockWithBiometric: ignored — current state is $state',
      );
      return false;
    }

    AppLogger.debug(
      'AuthCubit.unlockWithBiometric: attempting biometric unlock from state $state',
    );
    final success = await _vaultRepository.unlockWithBiometric(
      biometricService: _biometricService,
      localizedReason: localizedReason,
    );

    if (success) {
      AppLogger.debug(
        'AuthCubit.unlockWithBiometric: biometric unlock successful, transitioning to authenticated',
      );
      _auditLogService?.log(
        AuditLogEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: AuditLogType.biometricUnlockAttempt,
          title: 'Biometric Unlock',
          description:
              'Vault unlocked successfully using biometric authentication.',
        ),
      );
      emit(AuthStatus.authenticated);
    } else {
      AppLogger.warning(
        'AuthCubit.unlockWithBiometric: biometric unlock failed or cancelled',
      );
      _auditLogService?.log(
        AuditLogEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: AuditLogType.biometricUnlockAttempt,
          title: 'Biometric Unlock Failed',
          description: 'Biometric authentication failed or was cancelled.',
        ),
      );
    }
    return success;
  }

  // -------------------------------------------------------------------------
  // Account deletion
  // -------------------------------------------------------------------------

  /// Permanently deletes the vault.
  ///
  /// Zeroes the in-memory DEK, wipes ALL vault metadata and biometric keys
  /// from secure storage, then emits [AuthStatus.onboarding] so the router
  /// redirects to the sign-up flow.
  ///
  /// After this call there is no vault — the user must create a new one.
  void deleteAccount() {
    AppLogger.debug('AuthCubit.deleteAccount: destroying vault');
    _vaultRepository.deleteVault();
    _auditLogService?.log(
      AuditLogEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: AuditLogType.vaultDeleted,
        title: 'Vault Deleted',
        description:
            'The encrypted vault was permanently destroyed and all data was wiped.',
      ),
    );
    emit(AuthStatus.onboarding);
    AppLogger.debug(
      'AuthCubit.deleteAccount: vault destroyed, state is now onboarding',
    );
  }

  // -------------------------------------------------------------------------
  // Logout
  // -------------------------------------------------------------------------

  void logout() {
    AppLogger.debug(
      'AuthCubit.logout: locking vault and transitioning to unauthenticated',
    );
    _vaultRepository.lockVault();
    _auditLogService?.log(
      AuditLogEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        type: AuditLogType.logout,
        title: 'Logged Out',
        description: 'The user logged out and the vault was locked.',
      ),
    );
    emit(AuthStatus.unauthenticated);
    AppLogger.debug(
      'AuthCubit.logout: logged out, state is now unauthenticated',
    );
  }
}
