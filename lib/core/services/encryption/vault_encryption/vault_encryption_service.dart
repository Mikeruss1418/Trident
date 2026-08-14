import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/models/encryption/vault_creation_result_model.dart';
import 'package:trident/core/utils/logger/app_logger.dart';

@lazySingleton
class VaultEncryptionService {
  // -------------------------------------------------------------------------
  // Argon2id parameters
  //
  // 64 MB / 3 iterations / parallelism 1.
  //
  // OWASP minimum for Argon2id is 19 MB / 2 iterations.
  // 64 MB / 3 iterations is comfortably above it.
  //
  // On a mid-range Android (Snapdragon 6xx) this takes ~800ms–1.2s.
  // If you need faster unlock, reduce memory to 32768 (32 MB).
  // Do NOT reduce iterations below 2.
  // -------------------------------------------------------------------------
  static const int _argon2Memory = 65536; // 64 MB in KiB
  static const int _argon2Iterations = 3;
  static const int _argon2Parallelism = 1;
  static const int _keyLength = 32; // 256-bit
  static const int _saltLength = 32; // 256-bit
  static const int _nonceLength = 12; // 96-bit GCM nonce

  // Verifier: a known plaintext encrypted with KEK.
  // On unlock we decrypt it; if it matches, password is correct.
  // This avoids storing the password or the KEK.
  static final Uint8List _verifierPlaintext = Uint8List.fromList(
    'TRIDENT_VAULT_V1_OK'.codeUnits,
  );

  final Argon2id _argon2 = Argon2id(
    memory: _argon2Memory,
    parallelism: _argon2Parallelism,
    iterations: _argon2Iterations,
    hashLength: _keyLength,
  );

  final AesGcm _aesGcm = AesGcm.with256bits();

  // -------------------------------------------------------------------------
  // Vault creation
  // -------------------------------------------------------------------------

  /// Derives KEK, generates DEK, encrypts both DEK and verifier.
  /// Returns [VaultCreationResultModel] — persist everything except [dek].
  Future<VaultCreationResultModel> createVaultMaterial(
    String masterPassword,
  ) async {
    AppLogger.debug('createVaultMaterial: starting vault material creation');
    final salt = _randomBytes(_saltLength);
    final kek = await _deriveKek(masterPassword, salt);
    AppLogger.debug('createVaultMaterial: KEK derived, salt generated (${salt.length} bytes)');

    try {
      // Random 256-bit DEK — this is what protects all documents.
      final dek = _randomBytes(_keyLength);
      AppLogger.debug('createVaultMaterial: DEK generated (${dek.length} bytes)');

      // Encrypt DEK and verifier with KEK.
      final encryptedDekBlob = await _encrypt(kek, dek);
      AppLogger.debug('createVaultMaterial: DEK encrypted with KEK (${encryptedDekBlob.bytes.length} bytes)');

      final passwordVerifierBlob = await _encrypt(kek, _verifierPlaintext);
      AppLogger.debug('createVaultMaterial: password verifier created (${passwordVerifierBlob.bytes.length} bytes)');

      return VaultCreationResultModel(
        salt: salt,
        encryptedDekBlob: encryptedDekBlob,
        passwordVerifierBlob: passwordVerifierBlob,
        dek: dek,
      );
    } catch (e, st) {
      AppLogger.errorWithContext(
        'createVaultMaterial failed',
        context: 'VaultEncryptionService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      _zero(kek); // KEK is no longer needed — guaranteed on every exit path
      AppLogger.debug('createVaultMaterial: KEK zeroed from memory');
    }
  }

  // -------------------------------------------------------------------------
  // Vault unlock
  // -------------------------------------------------------------------------

  /// Derives KEK from [masterPassword] + [salt], verifies the password verifier,
  /// then decrypts and returns the DEK.
  ///
  /// Throws [WrongPasswordException] if the password is wrong.
  /// The caller (VaultRepository) owns the returned DEK's lifetime.
  Future<Uint8List> unlockVault({
    required String masterPassword,
    required Uint8List salt,
    required EncryptedBlobModel encryptedDekBlob,
    required EncryptedBlobModel passwordVerifierBlob,
  }) async {
    AppLogger.debug('unlockVault: deriving KEK from password');
    final kek = await _deriveKek(masterPassword, salt);
    AppLogger.debug('unlockVault: KEK derived successfully');

    try {
      // Verify password via the known plaintext verifier.
      try {
        final decryptedVerifier = await _decrypt(kek, passwordVerifierBlob);
        final matches = _constantTimeEquals(
          decryptedVerifier,
          _verifierPlaintext,
        );
        if (!matches) {
          AppLogger.warning('unlockVault: password verification failed (plaintext mismatch)');
          throw WrongPasswordException();
        }
      } on SecretBoxAuthenticationError {
        // AES-GCM MAC verification failed — wrong password or tampered data.
        AppLogger.warning('unlockVault: password verification failed (MAC error)');
        throw WrongPasswordException();
      }

      // Decrypt DEK.
      final dek = await _decrypt(kek, encryptedDekBlob);
      AppLogger.debug('unlockVault: DEK decrypted successfully, returning to caller');
      return dek;
    } catch (e, st) {
      AppLogger.errorWithContext(
        'unlockVault failed',
        context: 'VaultEncryptionService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      _zero(kek); // KEK is no longer needed — guaranteed on every exit path
      AppLogger.debug('unlockVault: KEK zeroed from memory');
    }
  }

  // -------------------------------------------------------------------------
  // Document encryption / decryption
  // -------------------------------------------------------------------------

  /// Encrypts [plaintext] with the in-memory [dek].
  /// Returns an [EncryptedBlobModel] — call [.bytes] for storage.
  Future<EncryptedBlobModel> encryptDocument(
    Uint8List plaintext,
    Uint8List dek,
  ) async {
    AppLogger.debug('encryptDocument: encrypting ${plaintext.length} bytes with DEK');
    final blob = await _encrypt(dek, plaintext);
    AppLogger.debug('encryptDocument: encryption complete, blob size ${blob.bytes.length} bytes');
    return blob;
  }

  /// Decrypts [blob] with the in-memory [dek].
  Future<Uint8List> decryptDocument(
    EncryptedBlobModel blob,
    Uint8List dek,
  ) async {
    AppLogger.debug('decryptDocument: decrypting ${blob.bytes.length} byte blob with DEK');
    try {
      final plaintext = await _decrypt(dek, blob);
      AppLogger.debug('decryptDocument: decryption successful, plaintext ${plaintext.length} bytes');
      return plaintext;
    } catch (e, st) {
      AppLogger.errorWithContext(
        'decryptDocument failed',
        context: 'VaultEncryptionService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  Future<Uint8List> _deriveKek(String password, Uint8List salt) async {
    final secretKey = await _argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  Future<EncryptedBlobModel> _encrypt(
    Uint8List keyBytes,
    Uint8List plaintext,
  ) async {
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );
    // Wire format: nonce(12) + mac(16) + ciphertext
    final blob = Uint8List(12 + 16 + secretBox.cipherText.length);
    blob.setRange(0, 12, secretBox.nonce);
    blob.setRange(12, 28, secretBox.mac.bytes);
    blob.setRange(28, blob.length, secretBox.cipherText);
    return EncryptedBlobModel(blob);
  }

  Future<Uint8List> _decrypt(
    Uint8List keyBytes,
    EncryptedBlobModel blob,
  ) async {
    final secretBox = SecretBox(
      blob.ciphertext,
      nonce: blob.nonce,
      mac: Mac(blob.mac),
    );
    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );
    return Uint8List.fromList(plaintext);
  }

  /// Constant-time byte comparison — avoids timing side-channels.
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}

class WrongPasswordException implements Exception {
  @override
  String toString() => 'WrongPasswordException: incorrect master password';
}
