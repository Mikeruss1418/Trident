import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/biometric/biometric.dart';
import 'package:trident/core/storage/secure_storage/secure_storage_service.dart';
import 'package:trident/core/storage/secured_storage_keys.dart';
import 'package:trident/injectables/injectable.dart';

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
  /// to verify if the vault exists or not
  Future<bool> vaultExists() async {
    final value = await getIt<SecureStorageService>().readSecureData(
      key: SecureStorageKeys.salt,
    );

    return value != null;
  }

  /// saves the vault blobs in the secure storage
  Future<void> saveVaultBlobs({
    required Uint8List salt,
    required EncryptedBlobModel encryptedDekBlob,
    required EncryptedBlobModel passwordVerifierBlob,
  }) async {
    // Delete first to ensure no stale partial state from a prior failed write
    // survives. On Android, writing over a key that exists from a different
    // cipher generation can silently fail.
    await deleteVaultMetadata();

    await Future.wait([
      getIt<SecureStorageService>().writeSecureData(
        key: SecureStorageKeys.salt,
        value: _encode(salt),
      ),
      getIt<SecureStorageService>().writeSecureData(
        key: SecureStorageKeys.encryptedDEKBlob,
        value: _encode(encryptedDekBlob.bytes),
      ),
      getIt<SecureStorageService>().writeSecureData(
        key: SecureStorageKeys.passwordVerifierBlob,
        value: _encode(passwordVerifierBlob.bytes),
      ),
    ]);
  }

  /// Return null if vault has never been created.
  ///
  /// Throws [VaultCorruptedException] if any field is missing.
  /// Caller (VaultRepository) decides whether to treat this as a fresh-start
  /// or surface an error to the user.
  Future<VaultBlobs?> loadVaultBlobs() async {
    if (!await vaultExists()) return null;

    final results = await Future.wait([
      getIt<SecureStorageService>().readSecureData(key: SecureStorageKeys.salt),
      getIt<SecureStorageService>().readSecureData(
        key: SecureStorageKeys.encryptedDEKBlob,
      ),
      getIt<SecureStorageService>().readSecureData(
        key: SecureStorageKeys.passwordVerifierBlob,
      ),
    ]);

    // Treat empty strings the same as null — they are unreadable data.
    if (results.any((r) => r == null || r.isEmpty)) {
      throw VaultCorruptedException();
    }

    return VaultBlobs(
      salt: _decode(results[0]!),
      encryptedDekBlob: EncryptedBlobModel.validate(_decode(results[1]!)),
      passwordVerifierBlob: EncryptedBlobModel.validate(_decode(results[2]!)),
    );
  }

  Future<void> deleteVaultMetadata() async {
    await Future.wait([
      getIt<SecureStorageService>().deleteSecureData(
        key: SecureStorageKeys.salt,
      ),
      getIt<SecureStorageService>().deleteSecureData(
        key: SecureStorageKeys.encryptedDEKBlob,
      ),
      getIt<SecureStorageService>().deleteSecureData(
        key: SecureStorageKeys.passwordVerifierBlob,
      ),
    ]);
  }

  // =========================================================================
  // BIOMETRIC STORAGE METHODS
  // =========================================================================

  /// Checks if biometric unlock is enabled for this vault
  Future<bool> isBiometricEnabled() async {
    final value = await getIt<SecureStorageService>().readSecureData(
      key: SecureStorageKeys.biometricEnabled,
    );
    return value == 'true';
  }

  /// Enables biometric unlock by storing the DEK encrypted with a biometric key
  Future<void> enableBiometric({
    required Uint8List dek,
    required BiometricService biometricService,
  }) async {
    // Generate a random biometric unlock key (BUK)
    final buk = _randomBytes(32);

    // Encrypt DEK with BUK
    final encryptedDek = await _encryptWithKey(buk, dek);

    // Store encrypted DEK and BUK
    await Future.wait([
      getIt<SecureStorageService>().writeSecureData(
        key: SecureStorageKeys.biometricEncryptedDEK,
        value: _encode(encryptedDek.bytes),
      ),
      getIt<SecureStorageService>().writeSecureData(
        key: SecureStorageKeys.biometricUnlockKey,
        value: _encode(buk),
      ),
      getIt<SecureStorageService>().writeSecureData(
        key: SecureStorageKeys.biometricEnabled,
        value: 'true',
      ),
    ]);
  }

  /// Disables biometric unlock and clears biometric data
  Future<void> disableBiometric() async {
    await Future.wait([
      getIt<SecureStorageService>().deleteSecureData(
        key: SecureStorageKeys.biometricEnabled,
      ),
      getIt<SecureStorageService>().deleteSecureData(
        key: SecureStorageKeys.biometricEncryptedDEK,
      ),
      getIt<SecureStorageService>().deleteSecureData(
        key: SecureStorageKeys.biometricUnlockKey,
      ),
    ]);
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
      return null;
    }

    // Authenticate with biometric
    final authenticated = await biometricService.authenticate(
      localizedReason: localizedReason,
    );

    if (!authenticated) {
      return null;
    }

    // Read biometric data
    final results = await Future.wait([
      getIt<SecureStorageService>().readSecureData(
        key: SecureStorageKeys.biometricEncryptedDEK,
      ),
      getIt<SecureStorageService>().readSecureData(
        key: SecureStorageKeys.biometricUnlockKey,
      ),
    ]);

    if (results.any((r) => r == null || r.isEmpty)) {
      return null;
    }

    final encryptedDekBlob = EncryptedBlobModel.validate(_decode(results[0]!));
    final buk = _decode(results[1]!);

    // Decrypt DEK with BUK
    final dek = await _decryptWithKey(buk, encryptedDekBlob);

    // Zero the BUK after use
    _zero(buk);

    return dek;
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
