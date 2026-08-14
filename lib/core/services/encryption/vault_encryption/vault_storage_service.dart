import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/biometric/biometric.dart';
import 'package:trident/core/storage/secure_storage/secure_storage_service.dart';
import 'package:trident/core/storage/secured_storage_keys.dart';
import 'package:trident/core/utils/logger/app_logger.dart';

/// All vault metadata needed to attempt an unlock.
class VaultBlobs {
  final Uint8List salt;
  final EncryptedBlobModel encryptedDekBlob;
  final EncryptedBlobModel passwordVerifierBlob;

  const VaultBlobs({
    required this.salt,
    required this.encryptedDekBlob,
    required this.passwordVerifierBlob,
  });
}

@lazySingleton
class VaultStorageService {
  final SecureStorageService _secureStorage;

  VaultStorageService(this._secureStorage);

  /// to verify if the vault exists or not
  Future<bool> vaultExists() async {
    final value = await _secureStorage.readSecureData(
      key: SecureStorageKeys.salt,
    );

    final exists = value != null;
    AppLogger.debug('vaultExists: $exists');
    return exists;
  }

  /// saves the vault blobs in the secure storage
  Future<void> saveVaultBlobs({
    required Uint8List salt,
    required EncryptedBlobModel encryptedDekBlob,
    required EncryptedBlobModel passwordVerifierBlob,
  }) async {
    AppLogger.debug('saveVaultBlobs: deleting existing metadata before write');
    // Delete first to ensure no stale partial state from a prior failed write
    // survives. On Android, writing over a key that exists from a different
    // cipher generation can silently fail.
    await deleteVaultMetadata();

    AppLogger.debug('saveVaultBlobs: writing salt, encrypted DEK, and verifier to secure storage');
    await Future.wait([
      _secureStorage.writeSecureData(
        key: SecureStorageKeys.salt,
        value: _encode(salt),
      ),
      _secureStorage.writeSecureData(
        key: SecureStorageKeys.encryptedDEKBlob,
        value: _encode(encryptedDekBlob.bytes),
      ),
      _secureStorage.writeSecureData(
        key: SecureStorageKeys.passwordVerifierBlob,
        value: _encode(passwordVerifierBlob.bytes),
      ),
    ]);
    AppLogger.debug('saveVaultBlobs: vault blobs saved successfully');
  }

  /// Return null if vault has never been created.
  ///
  /// Throws [VaultCorruptedException] if any field is missing.
  /// Caller (VaultRepository) decides whether to treat this as a fresh-start
  /// or surface an error to the user.
  Future<VaultBlobs?> loadVaultBlobs() async {
    if (!await vaultExists()) {
      AppLogger.debug('loadVaultBlobs: no vault found');
      return null;
    }

    AppLogger.debug('loadVaultBlobs: reading vault blobs from secure storage');
    final results = await Future.wait([
      _secureStorage.readSecureData(key: SecureStorageKeys.salt),
      _secureStorage.readSecureData(
        key: SecureStorageKeys.encryptedDEKBlob,
      ),
      _secureStorage.readSecureData(
        key: SecureStorageKeys.passwordVerifierBlob,
      ),
    ]);

    // Treat empty strings the same as null — they are unreadable data.
    if (results.any((r) => r == null || r.isEmpty)) {
      AppLogger.warning('loadVaultBlobs: vault metadata incomplete or corrupted');
      throw VaultCorruptedException();
    }

    AppLogger.debug('loadVaultBlobs: vault blobs loaded successfully');
    return VaultBlobs(
      salt: _decode(results[0]!),
      encryptedDekBlob: EncryptedBlobModel.validate(_decode(results[1]!)),
      passwordVerifierBlob: EncryptedBlobModel.validate(_decode(results[2]!)),
    );
  }

  Future<void> deleteVaultMetadata() async {
    AppLogger.debug('deleteVaultMetadata: clearing salt, encrypted DEK, and verifier');
    await Future.wait([
      _secureStorage.deleteSecureData(
        key: SecureStorageKeys.salt,
      ),
      _secureStorage.deleteSecureData(
        key: SecureStorageKeys.encryptedDEKBlob,
      ),
      _secureStorage.deleteSecureData(
        key: SecureStorageKeys.passwordVerifierBlob,
      ),
    ]);
    AppLogger.debug('deleteVaultMetadata: vault metadata cleared');
  }

  // =========================================================================
  // BIOMETRIC STORAGE METHODS
  // =========================================================================

  /// Checks if biometric unlock is enabled for this vault
  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.readSecureData(
      key: SecureStorageKeys.biometricEnabled,
    );
    final enabled = value == 'true';
    AppLogger.debug('isBiometricEnabled: $enabled');
    return enabled;
  }

  /// Enables biometric unlock by storing the DEK encrypted with a biometric key
  Future<void> enableBiometric({
    required Uint8List dek,
    required BiometricService biometricService,
  }) async {
    AppLogger.debug('enableBiometric: clearing existing biometric metadata');
    // Clear any existing biometric metadata before writing new configuration
    // to prevent stale state from a previous vault or partial write.
    await disableBiometric();

    // Generate a random biometric unlock key (BUK)
    final buk = _randomBytes(32);
    AppLogger.debug('enableBiometric: BUK generated (32 bytes)');

    // Encrypt DEK with BUK
    final encryptedDek = await _encryptWithKey(buk, dek);
    AppLogger.debug('enableBiometric: DEK encrypted with BUK');

    // Store encrypted DEK and BUK
    AppLogger.debug('enableBiometric: writing biometric data to secure storage');
    await Future.wait([
      _secureStorage.writeSecureData(
        key: SecureStorageKeys.biometricEncryptedDEK,
        value: _encode(encryptedDek.bytes),
      ),
      _secureStorage.writeSecureData(
        key: SecureStorageKeys.biometricUnlockKey,
        value: _encode(buk),
      ),
      _secureStorage.writeSecureData(
        key: SecureStorageKeys.biometricEnabled,
        value: 'true',
      ),
    ]);
    AppLogger.debug('enableBiometric: biometric data stored successfully');
  }

  /// Disables biometric unlock and clears biometric data
  Future<void> disableBiometric() async {
    AppLogger.debug('disableBiometric: clearing biometric-enabled flag, encrypted DEK, and BUK');
    await Future.wait([
      _secureStorage.deleteSecureData(
        key: SecureStorageKeys.biometricEnabled,
      ),
      _secureStorage.deleteSecureData(
        key: SecureStorageKeys.biometricEncryptedDEK,
      ),
      _secureStorage.deleteSecureData(
        key: SecureStorageKeys.biometricUnlockKey,
      ),
    ]);
    AppLogger.debug('disableBiometric: biometric data cleared');
  }

  /// Attempts to unlock the vault using biometric authentication
  /// Returns the DEK if successful, null otherwise
  Future<Uint8List?> unlockWithBiometric({
    required BiometricService biometricService,
    String localizedReason = 'Unlock your Trident vault',
  }) async {
    // First verify biometric is enabled
    final biometricenabled = await isBiometricEnabled();
    if (!biometricenabled) {
      AppLogger.debug('unlockWithBiometric: biometric not enabled, aborting');
      return null;
    }

    // Authenticate with biometric
    AppLogger.debug('unlockWithBiometric: requesting biometric authentication');
    final authenticated = await biometricService.authenticate(
      localizedReason: localizedReason,
    );

    if (!authenticated) {
      AppLogger.warning('unlockWithBiometric: biometric authentication failed or cancelled');
      return null;
    }

    AppLogger.debug('unlockWithBiometric: biometric authenticated, reading encrypted DEK and BUK from secure storage');
    // Read biometric data
    final results = await Future.wait([
      _secureStorage.readSecureData(
        key: SecureStorageKeys.biometricEncryptedDEK,
      ),
      _secureStorage.readSecureData(
        key: SecureStorageKeys.biometricUnlockKey,
      ),
    ]);

    if (results.any((r) => r == null || r.isEmpty)) {
      AppLogger.warning('unlockWithBiometric: biometric data missing from secure storage');
      return null;
    }

    final encryptedDekBlob = EncryptedBlobModel.validate(_decode(results[0]!));
    final buk = _decode(results[1]!);

    try {
      // Decrypt DEK with BUK
      AppLogger.debug('unlockWithBiometric: decrypting DEK with BUK');
      final dek = await _decryptWithKey(buk, encryptedDekBlob);
      AppLogger.debug('unlockWithBiometric: DEK decrypted successfully');
      return dek;
    } catch (e, st) {
      AppLogger.errorWithContext(
        'unlockWithBiometric: DEK decryption failed',
        context: 'VaultStorageService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      // Zero the BUK after use — guaranteed on every exit path
      _zero(buk);
      AppLogger.debug('unlockWithBiometric: BUK zeroed from memory');
    }
  }

  // =========================================================================
  // INTERNAL CRYPTO HELPERS (for biometric operations)
  // =========================================================================

  final AesGcm _aesGcm = AesGcm.with256bits();
  static const int _nonceLength = 12;

  Future<EncryptedBlobModel> _encryptWithKey(
    Uint8List key,
    Uint8List plaintext,
  ) async {
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final blob = Uint8List(_nonceLength + 16 + secretBox.cipherText.length);
    blob.setRange(0, _nonceLength, secretBox.nonce);
    blob.setRange(_nonceLength, _nonceLength + 16, secretBox.mac.bytes);
    blob.setRange(_nonceLength + 16, blob.length, secretBox.cipherText);
    return EncryptedBlobModel(blob);
  }

  Future<Uint8List> _decryptWithKey(
    Uint8List key,
    EncryptedBlobModel blob,
  ) async {
    final secretBox = SecretBox(
      blob.ciphertext,
      nonce: blob.nonce,
      mac: Mac(blob.mac),
    );
    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(plaintext);
  }

  String _encode(Uint8List b) => base64Encode(b);
  Uint8List _decode(String s) => base64Decode(s);

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}

class VaultCorruptedException implements Exception {
  @override
  String toString() =>
      'VaultCorruptedException: vault metadata is incomplete or corrupted';
}
