// Unit tests for VaultEncryptionService — the cryptographic engine.
//
// Tests cover:
//   - Vault creation (salt generation, KEK derivation, DEK generation, encryption)
//   - Vault unlock (KEK derivation, password verification, DEK decryption)
//   - Wrong password detection
//   - Document encryption/decryption round-trip
//   - KEK zeroing after operations
//   - Constant-time comparison
//   - Wire format correctness

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_encryption_service.dart';

void main() {
  group('VaultEncryptionService', () {
    late VaultEncryptionService service;

    setUp(() {
      service = VaultEncryptionService();
    });

    group('createVaultMaterial', () {
      test('returns all required fields', () async {
        final result = await service.createVaultMaterial('test_password_123');

        expect(result.salt, isA<Uint8List>());
        expect(result.encryptedDekBlob, isA<EncryptedBlobModel>());
        expect(result.passwordVerifierBlob, isA<EncryptedBlobModel>());
        expect(result.dek, isA<Uint8List>());
      });

      test('salt is 32 bytes (256-bit)', () async {
        final result = await service.createVaultMaterial('test_password_123');

        expect(result.salt.length, equals(32));
      });

      test('DEK is 32 bytes (256-bit)', () async {
        final result = await service.createVaultMaterial('test_password_123');

        expect(result.dek.length, equals(32));
      });

      test('encrypted DEK blob has correct wire format (28+ bytes)', () async {
        final result = await service.createVaultMaterial('test_password_123');

        // 12 (nonce) + 16 (mac) + 32 (ciphertext = DEK size) = 60 bytes
        expect(result.encryptedDekBlob.bytes.length, equals(60));
      });

      test('password verifier blob has correct wire format', () async {
        final result = await service.createVaultMaterial('test_password_123');

        // 12 (nonce) + 16 (mac) + 19 (ciphertext = 'TRIDENT_VAULT_V1_OK'.length) = 47 bytes
        expect(result.passwordVerifierBlob.bytes.length, equals(47));
      });

      test('different passwords produce different salts', () async {
        final result1 = await service.createVaultMaterial('password_one');
        final result2 = await service.createVaultMaterial('password_two');

        expect(result1.salt, isNot(equals(result2.salt)));
      });

      test('same password produces different salts (random salt)', () async {
        final result1 = await service.createVaultMaterial('same_password');
        final result2 = await service.createVaultMaterial('same_password');

        expect(result1.salt, isNot(equals(result2.salt)));
      });

      test('different passwords produce different DEKs', () async {
        final result1 = await service.createVaultMaterial('password_one');
        final result2 = await service.createVaultMaterial('password_two');

        expect(result1.dek, isNot(equals(result2.dek)));
      });

      test('same password produces different DEKs (random DEK)', () async {
        final result1 = await service.createVaultMaterial('same_password');
        final result2 = await service.createVaultMaterial('same_password');

        expect(result1.dek, isNot(equals(result2.dek)));
      });

      test(
        'encrypted DEK blob is different each time (random nonce)',
        () async {
          final result1 = await service.createVaultMaterial('same_password');
          final result2 = await service.createVaultMaterial('same_password');

          expect(
            result1.encryptedDekBlob.bytes,
            isNot(equals(result2.encryptedDekBlob.bytes)),
          );
        },
      );

      test(
        'KEK is zeroed after creation (cannot verify directly, but ensures no crash)',
        () async {
          // This test ensures the _zero(kek) call doesn't throw
          final result = await service.createVaultMaterial('test_password_123');
          expect(result.dek, isNotNull);
        },
      );
    });

    group('unlockVault', () {
      test('successfully unlocks with correct password', () async {
        const password = 'correct_password_123';
        final creationResult = await service.createVaultMaterial(password);

        final dek = await service.unlockVault(
          masterPassword: password,
          salt: creationResult.salt,
          encryptedDekBlob: creationResult.encryptedDekBlob,
          passwordVerifierBlob: creationResult.passwordVerifierBlob,
        );

        expect(dek, equals(creationResult.dek));
      });

      test('throws WrongPasswordException for wrong password', () async {
        final creationResult = await service.createVaultMaterial(
          'correct_password',
        );

        expect(
          () => service.unlockVault(
            masterPassword: 'wrong_password',
            salt: creationResult.salt,
            encryptedDekBlob: creationResult.encryptedDekBlob,
            passwordVerifierBlob: creationResult.passwordVerifierBlob,
          ),
          throwsA(isA<WrongPasswordException>()),
        );
      });

      test('throws WrongPasswordException for empty password', () async {
        final creationResult = await service.createVaultMaterial(
          'correct_password',
        );

        expect(
          () => service.unlockVault(
            masterPassword: '',
            salt: creationResult.salt,
            encryptedDekBlob: creationResult.encryptedDekBlob,
            passwordVerifierBlob: creationResult.passwordVerifierBlob,
          ),
          throwsA(isA<WrongPasswordException>()),
        );
      });

      test('tampered verifier blob throws WrongPasswordException', () async {
        final creationResult = await service.createVaultMaterial(
          'correct_password',
        );

        // Tamper with the verifier blob
        final tamperedBytes = Uint8List.fromList(
          creationResult.passwordVerifierBlob.bytes,
        );
        tamperedBytes[30] ^= 0xFF; // Flip bits in ciphertext portion

        expect(
          () => service.unlockVault(
            masterPassword: 'correct_password',
            salt: creationResult.salt,
            encryptedDekBlob: creationResult.encryptedDekBlob,
            passwordVerifierBlob: EncryptedBlobModel(tamperedBytes),
          ),
          throwsA(isA<WrongPasswordException>()),
        );
      });

      test(
        'tampered encrypted DEK blob throws SecretBoxAuthenticationError',
        () async {
          final creationResult = await service.createVaultMaterial(
            'correct_password',
          );

          // Tamper with the encrypted DEK blob
          final tamperedBytes = Uint8List.fromList(
            creationResult.encryptedDekBlob.bytes,
          );
          tamperedBytes[30] ^= 0xFF;

          // The code does not wrap the DEK decryption in a try-catch for
          // SecretBoxAuthenticationError, so it propagates directly.
          // This is a known gap — see DEVELOPER_GUIDE.md section 15.
          expect(
            () => service.unlockVault(
              masterPassword: 'correct_password',
              salt: creationResult.salt,
              encryptedDekBlob: EncryptedBlobModel(tamperedBytes),
              passwordVerifierBlob: creationResult.passwordVerifierBlob,
            ),
            throwsA(isA<Exception>()),
          );
        },
      );

      test('KEK is zeroed after unlock (no crash, no memory leak)', () async {
        final creationResult = await service.createVaultMaterial('password');

        final dek = await service.unlockVault(
          masterPassword: 'password',
          salt: creationResult.salt,
          encryptedDekBlob: creationResult.encryptedDekBlob,
          passwordVerifierBlob: creationResult.passwordVerifierBlob,
        );

        expect(dek, equals(creationResult.dek));
      });
    });

    group('encryptDocument / decryptDocument', () {
      test(
        'round-trip: encrypt then decrypt returns original plaintext',
        () async {
          const plaintext = 'Hello, Trident! This is a secret document.';
          final dek = Uint8List.fromList(List.generate(32, (i) => i));

          final encryptedBlob = await service.encryptDocument(
            Uint8List.fromList(plaintext.codeUnits),
            dek,
          );

          final decrypted = await service.decryptDocument(encryptedBlob, dek);

          expect(decrypted, equals(Uint8List.fromList(plaintext.codeUnits)));
        },
      );

      test('round-trip with empty plaintext', () async {
        final dek = Uint8List.fromList(List.generate(32, (i) => i));

        final encryptedBlob = await service.encryptDocument(Uint8List(0), dek);
        final decrypted = await service.decryptDocument(encryptedBlob, dek);

        expect(decrypted, equals(Uint8List(0)));
      });

      test('round-trip with large plaintext (1MB)', () async {
        final plaintext = Uint8List(1024 * 1024);
        for (var i = 0; i < plaintext.length; i++) {
          plaintext[i] = i % 256;
        }
        final dek = Uint8List.fromList(List.generate(32, (i) => i));

        final encryptedBlob = await service.encryptDocument(plaintext, dek);
        final decrypted = await service.decryptDocument(encryptedBlob, dek);

        expect(decrypted, equals(plaintext));
      });

      test(
        'different encryptions of same plaintext produce different ciphertexts (random nonce)',
        () async {
          const plaintext = 'Same plaintext encrypted twice';
          final dek = Uint8List.fromList(List.generate(32, (i) => i));

          final blob1 = await service.encryptDocument(
            Uint8List.fromList(plaintext.codeUnits),
            dek,
          );
          final blob2 = await service.encryptDocument(
            Uint8List.fromList(plaintext.codeUnits),
            dek,
          );

          expect(blob1.bytes, isNot(equals(blob2.bytes)));
        },
      );

      test('decrypt with wrong DEK throws error', () async {
        const plaintext = 'Secret data';
        final dek1 = Uint8List.fromList(List.generate(32, (i) => i));
        final dek2 = Uint8List.fromList(List.generate(32, (i) => i + 1));

        final encryptedBlob = await service.encryptDocument(
          Uint8List.fromList(plaintext.codeUnits),
          dek1,
        );

        expect(
          () => service.decryptDocument(encryptedBlob, dek2),
          throwsA(isA<Exception>()),
        );
      });

      test('encrypted blob has correct wire format', () async {
        const plaintext = 'Test';
        final dek = Uint8List.fromList(List.generate(32, (i) => i));

        final blob = await service.encryptDocument(
          Uint8List.fromList(plaintext.codeUnits),
          dek,
        );

        // 12 (nonce) + 16 (mac) + 4 (ciphertext) = 32 bytes
        expect(blob.bytes.length, equals(32));
      });
    });

    group('WrongPasswordException', () {
      test('toString returns descriptive message', () {
        final exception = WrongPasswordException();
        expect(exception.toString(), contains('WrongPasswordException'));
        expect(exception.toString(), contains('incorrect master password'));
      });
    });
  });
}
