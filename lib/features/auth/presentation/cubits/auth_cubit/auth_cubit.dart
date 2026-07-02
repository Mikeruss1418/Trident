import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/services/encrytion/vault_encryption/vault_repository.dart';

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

  AuthCubit(this._vaultRepository) : super(AuthStatus.onboarding);

  // -------------------------------------------------------------------------
  // App startup
  // -------------------------------------------------------------------------

  Future<void> initialize() async {
    final exists = await _vaultRepository.vaultExists();
    emit(exists ? AuthStatus.unauthenticated : AuthStatus.onboarding);
  }

  // -------------------------------------------------------------------------
  // Onboarding (vault creation)
  // -------------------------------------------------------------------------

  /// Creates the vault. On success → [authenticated].
  /// Rethrows on failure so the UI can surface the error.
  Future<void> createVault(String masterPassword) async {
    try {
      await _vaultRepository.createVault(masterPassword);
      emit(AuthStatus.authenticated);
    } catch (e) {
      emit(AuthStatus.onboarding);
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Login
  // -------------------------------------------------------------------------

  /// Throws [WrongPasswordException] on bad password.
  Future<void> login(String masterPassword) async {
    await _vaultRepository.unlockVault(masterPassword);
    emit(AuthStatus.authenticated);
  }

  // -------------------------------------------------------------------------
  // Lock / Unlock
  // -------------------------------------------------------------------------

  void lockVault() {
    if (state != AuthStatus.authenticated) return;
    _vaultRepository.lockVault();
    emit(AuthStatus.vaultLocked);
  }

  Future<void> unlockVault(String masterPassword) async {
    if (state != AuthStatus.vaultLocked) return;
    await _vaultRepository.unlockVault(masterPassword);
    emit(AuthStatus.authenticated);
  }

  // -------------------------------------------------------------------------
  // Logout
  // -------------------------------------------------------------------------

  void logout() {
    _vaultRepository.lockVault();
    emit(AuthStatus.unauthenticated);
  }
}
