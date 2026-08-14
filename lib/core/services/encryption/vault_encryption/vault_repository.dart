import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/biometric/biometric.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_storage_service.dart';
import 'package:trident/core/utils/logger/app_logger.dart';

/// VaultRepository is the only class that holds the in-memory DEK.
///
/// Rules:
///   - AuthCubit calls this. AuthCubit never sees a key or password hash.
///   - UI never calls this directly.
///   - DEK is zeroed and nulled on [lockVault].
@lazySingleton
class VaultRepository {
  final VaultEncryptionService _crypto;
  final VaultStorageService _storage;

  VaultRepository(this._crypto, this._storage);

  Uint8List? _dek;

  bool get isUnlocked => _dek != null;

  // -------------------------------------------------------------------------
  // Vault creation
  // -------------------------------------------------------------------------

  /// Creates a new vault from [masterPassword].
  /// On success, the vault is automatically unlocked (DEK is in memory).
  ///
  /// Throws [StateError] only if a healthy, complete vault already exists.
  ///
  /// Handles two edge cases silently:
  ///   1. Storage has stale/empty keys from a failed algorithm migration
  ///      (flutter_secure_storage RSA→AES migration with 0 items) →
  ///      detected by vaultExists() returning true but loadVaultBlobs()
  ///      throwing [VaultCorruptedException]. We wipe and re-create.
  ///   2. vaultExists() returns true but loadVaultBlobs() returns null
  ///      (empty-string false positive). Same path.
  Future<void> createVault(String masterPassword) async {
    AppLogger.debug('createVault: checking for existing vault');
    if (await _storage.vaultExists()) {
      AppLogger.debug('createVault: existing vault found, checking health');
      // Verify the vault is actually complete and healthy before refusing.
      try {
        final blobs = await _storage.loadVaultBlobs();
        if (blobs != null) {
          // Genuinely healthy vault exists — refuse to overwrite.
          AppLogger.warning(
            'createVault: healthy vault already exists, refusing to overwrite',
          );
          throw StateError(
            'createVault: a complete vault already exists. '
            'Use unlockVault() instead.',
          );
        }
        // blobs == null despite vaultExists() → inconsistent state, wipe it.
        AppLogger.warning(
          'createVault: inconsistent vault state detected (vaultExists=true, blobs=null), wiping',
        );
        await _storage.deleteVaultMetadata();
        await _storage.disableBiometric();
      } on StateError {
        rethrow; // propagate the intentional refusal above
      } on VaultCorruptedException {
        // Corrupted/empty metadata — primary path after RSA→AES migration
        // with 0 items. Wipe and proceed with fresh creation.
        AppLogger.warning(
          'createVault: corrupted vault metadata detected, wiping and recreating',
        );
        await _storage.deleteVaultMetadata();
        await _storage.disableBiometric();
      } catch (e, st) {
        AppLogger.errorWithContext(
          'createVault: unexpected error during health check',
          context: 'VaultRepository',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }

    AppLogger.debug('createVault: generating vault material');
    final result = await _crypto.createVaultMaterial(masterPassword);
    AppLogger.debug(
      'createVault: vault material created, saving to secure storage',
    );

    await _storage.saveVaultBlobs(
      salt: result.salt,
      encryptedDekBlob: result.encryptedDekBlob,
      passwordVerifierBlob: result.passwordVerifierBlob,
    );

    _dek = result.dek;
    AppLogger.debug('createVault: vault created and unlocked (DEK in memory)');
  }

  // -------------------------------------------------------------------------
  // Unlock
  // -------------------------------------------------------------------------

  /// Unlocks an existing vault with [masterPassword].
  ///
  /// Throws [WrongPasswordException] for wrong password.
  /// Throws [VaultCorruptedException] if metadata is missing/damaged.
  /// Throws [StateError] if no vault exists.
  Future<void> unlockVault(String masterPassword) async {
    AppLogger.debug('unlockVault: loading vault blobs from secure storage');
    final blobs = await _storage.loadVaultBlobs();
    if (blobs == null) {
      AppLogger.warning('unlockVault: no vault found');
      throw StateError('unlockVault: no vault found');
    }

    AppLogger.debug('unlockVault: attempting to decrypt DEK with password');
    final dek = await _crypto.unlockVault(
      masterPassword: masterPassword,
      salt: blobs.salt,
      encryptedDekBlob: blobs.encryptedDekBlob,
      passwordVerifierBlob: blobs.passwordVerifierBlob,
    );

    _dek = dek;
    AppLogger.debug('unlockVault: vault unlocked successfully (DEK in memory)');
  }

  // -------------------------------------------------------------------------
  // Lock
  // -------------------------------------------------------------------------

  /// Destroys the in-memory DEK. Vault is inaccessible until next [unlockVault].
  void lockVault() {
    if (_dek != null) {
      AppLogger.debug('lockVault: zeroing DEK from memory');
      for (var i = 0; i < _dek!.length; i++) {
        _dek![i] = 0;
      }
      _dek = null;
      AppLogger.debug('lockVault: DEK zeroed and vault locked');
    }
  }

  // -------------------------------------------------------------------------
  // Vault existence check
  // -------------------------------------------------------------------------

  Future<bool> vaultExists() => _storage.vaultExists();

  // -------------------------------------------------------------------------
  // Biometric methods
  // -------------------------------------------------------------------------

  /// Checks if biometric unlock is enabled for this vault
  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.isBiometricEnabled();
    AppLogger.debug('isBiometricEnabled: $enabled');
    return enabled;
  }

  /// Enables biometric unlock for the current vault
  /// Requires vault to be unlocked (DEK in memory)
  Future<void> enableBiometric({
    required BiometricService biometricService,
  }) async {
    AppLogger.debug('enableBiometric: checking vault is unlocked');
    _requireUnlocked();
    AppLogger.debug('enableBiometric: vault is unlocked, enabling biometric');
    await _storage.enableBiometric(
      dek: _dek!,
      biometricService: biometricService,
    );
    AppLogger.debug('enableBiometric: biometric unlock enabled successfully');
  }

  /// Disables biometric unlock and clears biometric data
  Future<void> disableBiometric() async {
    AppLogger.debug(
      'disableBiometric: clearing biometric data from secure storage',
    );
    await _storage.disableBiometric();
    AppLogger.debug('disableBiometric: biometric data cleared');
  }

  /// Attempts to unlock the vault using biometric authentication
  /// Returns true if successful, false otherwise
  Future<bool> unlockWithBiometric({
    required BiometricService biometricService,
    String localizedReason = 'Unlock your Trident vault',
  }) async {
    AppLogger.debug('unlockWithBiometric: attempting biometric unlock');
    final dek = await _storage.unlockWithBiometric(
      biometricService: biometricService,

      localizedReason: localizedReason,
    );

    if (dek != null) {
      _dek = dek;
      AppLogger.debug(
        'unlockWithBiometric: biometric unlock successful (DEK in memory)',
      );
      return true;
    }
    AppLogger.warning(
      'unlockWithBiometric: biometric unlock failed or cancelled',
    );
    return false;
  }

  // -------------------------------------------------------------------------
  // Document operations
  // -------------------------------------------------------------------------

  /// Encrypts [plaintext] with the in-memory DEK.
  /// Returns serialized [EncryptedBlobModel] bytes ready for disk/Isar storage.
  ///
  /// Throws [StateError] if vault is locked.
  Future<Uint8List> encryptDocument(Uint8List plaintext) async {
    _requireUnlocked();
    AppLogger.debug(
      'encryptDocument: encrypting ${plaintext.length} bytes with DEK',
    );
    final blob = await _crypto.encryptDocument(plaintext, _dek!);
    AppLogger.debug(
      'encryptDocument: encryption complete, output ${blob.bytes.length} bytes',
    );
    return blob.bytes;
  }

  /// Decrypts [encryptedBytes] with the in-memory DEK.
  ///
  /// Throws [StateError] if vault is locked.
  Future<Uint8List> decryptDocument(Uint8List encryptedBytes) async {
    _requireUnlocked();
    AppLogger.debug(
      'decryptDocument: decrypting ${encryptedBytes.length} bytes with DEK',
    );
    final blob = EncryptedBlobModel.validate(encryptedBytes);
    final plaintext = await _crypto.decryptDocument(blob, _dek!);
    AppLogger.debug(
      'decryptDocument: decryption complete, output ${plaintext.length} bytes',
    );
    return plaintext;
  }

  void _requireUnlocked() {
    if (!isUnlocked) {
      throw StateError(
        'VaultRepository: vault is locked — unlock before accessing documents',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Vault deletion
  // -------------------------------------------------------------------------

  /// Permanently destroys the vault.
  ///
  /// Zeroes the in-memory DEK (if any) and wipes ALL vault metadata and
  /// biometric keys from secure storage. After this call:
  ///   - [vaultExists] returns false
  ///   - [isUnlocked] is false (DEK is nulled)
  ///   - The vault cannot be unlocked — no recovery is possible
  ///
  /// The caller (AuthCubit) is responsible for emitting the post-deletion
  /// auth state ([AuthStatus.onboarding]).
  void deleteVault() {
    AppLogger.debug('deleteVault: destroying vault and wiping all data');
    // Zero the DEK if it's in memory
    if (_dek != null) {
      for (var i = 0; i < _dek!.length; i++) {
        _dek![i] = 0;
      }
      _dek = null;
      AppLogger.debug('deleteVault: in-memory DEK zeroed');
    }
    // Wipe all vault metadata + biometric data from secure storage
    _storage.deleteAllVaultData();
    AppLogger.debug('deleteVault: vault permanently destroyed');
  }
}
