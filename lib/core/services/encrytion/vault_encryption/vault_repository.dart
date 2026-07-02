import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/encrytion/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/encrytion/vault_encryption/vault_storage_service.dart';

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
    if (await _storage.vaultExists()) {
      // Verify the vault is actually complete and healthy before refusing.
      try {
        final blobs = await _storage.loadVaultBlobs();
        if (blobs != null) {
          // Genuinely healthy vault exists — refuse to overwrite.
          throw StateError(
            'createVault: a complete vault already exists. '
            'Use unlockVault() instead.',
          );
        }
        // blobs == null despite vaultExists() → inconsistent state, wipe it.
        await _storage.deleteVaultMetadata();
      } on StateError {
        rethrow; // propagate the intentional refusal above
      } on VaultCorruptedException {
        // Corrupted/empty metadata — primary path after RSA→AES migration
        // with 0 items. Wipe and proceed with fresh creation.
        await _storage.deleteVaultMetadata();
      } catch (_) {
        // Any other storage error during the health check — wipe and retry.
        await _storage.deleteVaultMetadata();
      }
    }

    final result = await _crypto.createVaultMaterial(masterPassword);

    await _storage.saveVaultBlobs(
      salt: result.salt,
      encryptedDekBlob: result.encryptedDekBlob,
      passwordVerifierBlob: result.passwordVerifierBlob,
    );

    _dek = result.dek;
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
    final blobs = await _storage.loadVaultBlobs();
    if (blobs == null) {
      throw StateError('unlockVault: no vault found');
    }

    final dek = await _crypto.unlockVault(
      masterPassword: masterPassword,
      salt: blobs.salt,
      encryptedDekBlob: blobs.encryptedDekBlob,
      passwordVerifierBlob: blobs.passwordVerifierBlob,
    );

    _dek = dek;
  }

  // -------------------------------------------------------------------------
  // Lock
  // -------------------------------------------------------------------------

  /// Destroys the in-memory DEK. Vault is inaccessible until next [unlockVault].
  void lockVault() {
    if (_dek != null) {
      for (var i = 0; i < _dek!.length; i++) {
        _dek![i] = 0;
      }
      _dek = null;
    }
  }

  // -------------------------------------------------------------------------
  // Vault existence check
  // -------------------------------------------------------------------------

  Future<bool> vaultExists() => _storage.vaultExists();

  // -------------------------------------------------------------------------
  // Document operations
  // -------------------------------------------------------------------------

  /// Encrypts [plaintext] with the in-memory DEK.
  /// Returns serialized [EncryptedBlobModel] bytes ready for disk/Isar storage.
  ///
  /// Throws [StateError] if vault is locked.
  Future<Uint8List> encryptDocument(Uint8List plaintext) async {
    _requireUnlocked();
    final blob = await _crypto.encryptDocument(plaintext, _dek!);
    return blob.bytes;
  }

  /// Decrypts [encryptedBytes] with the in-memory DEK.
  ///
  /// Throws [StateError] if vault is locked.
  Future<Uint8List> decryptDocument(Uint8List encryptedBytes) async {
    _requireUnlocked();
    final blob = EncryptedBlobModel.validate(encryptedBytes);
    return _crypto.decryptDocument(blob, _dek!);
  }

  void _requireUnlocked() {
    if (!isUnlocked) {
      throw StateError(
        'VaultRepository: vault is locked — unlock before accessing documents',
      );
    }
  }
}
