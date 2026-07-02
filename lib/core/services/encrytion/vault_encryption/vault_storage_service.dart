import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
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

  String _encode(Uint8List b) => base64Encode(b);
  Uint8List _decode(String s) => base64Decode(s);
}

class VaultCorruptedException implements Exception {
  @override
  String toString() =>
      'VaultCorruptedException: vault metadata is incomplete or corrupted';
}
