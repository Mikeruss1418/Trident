// Unit tests for VaultRepository — the vault lifecycle and DEK management.
//
// These tests use a fake VaultStorageService to test the repository logic
// without depending on actual secure storage.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/biometric/biometric_service.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_repository.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_storage_service.dart';

// A minimal fake BiometricService for testing
class FakeBiometricService implements BiometricService {
  bool available = true;
  bool authenticated = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    String? cancelButton,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async =>
      authenticated;

  @override
  Future<void> invalidate() async {}
}

// A minimal fake VaultStorageService for testing
class FakeVaultStorageService implements VaultStorageService {
  Uint8List? salt;
  EncryptedBlobModel? encryptedDekBlob;
  EncryptedBlobModel? passwordVerifierBlob;
  bool biometricEnabled = false;
  Uint8List? biometricEncryptedDek;
  Uint8List? biometricUnlockKey;

  @override
  Future<bool> vaultExists() async => salt != null;

  @override
  Future<void> saveVaultBlobs({
    required Uint8List salt,
    required EncryptedBlobModel encryptedDekBlob,
    required EncryptedBlobModel passwordVerifierBlob,
  }) async {
    this.salt = salt;
    this.encryptedDekBlob = encryptedDekBlob;
    this.passwordVerifierBlob = passwordVerifierBlob;
  }

  @override
  Future<VaultBlobs?> loadVaultBlobs() async {
    if (salt == null) return null;
    if (encryptedDekBlob == null || passwordVerifierBlob == null) {
      throw VaultCorruptedException();
    }
    return VaultBlobs(
      salt: salt!,
      encryptedDekBlob: encryptedDekBlob!,
      passwordVerifierBlob: passwordVerifierBlob!,
    );
  }

  @override
  Future<void> deleteVaultMetadata() async {
    salt = null;
    encryptedDekBlob = null;
    passwordVerifierBlob = null;
  }

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> enableBiometric({
    required Uint8List dek,
    required BiometricService biometricService,
  }) async {
    biometricEnabled = true;
  }

  @override
  Future<void> disableBiometric() async {
    biometricEnabled = false;
  }

  @override
  Future<Uint8List?> unlockWithBiometric({
    required BiometricService biometricService,
    String localizedReason = 'Unlock your Trident vault',
  }) async {
    if (!biometricEnabled) return null;
    return null;
  }
}

void main() {
  group('VaultRepository', () {
    late VaultEncryptionService crypto;
    late FakeVaultStorageService storage;
    late FakeBiometricService biometricService;
    late VaultRepository repository;

    setUp(() {
      crypto = VaultEncryptionService();
      storage = FakeVaultStorageService();
      biometricService = FakeBiometricService();
      repository = VaultRepository(crypto, storage);
    });

    group('createVault', () {
      test('creates vault and holds DEK in memory', () async {
        await repository.createVault('test_password_123');

        expect(repository.isUnlocked, isTrue);
      });

      test('stores vault blobs in secure storage', () async {
        await repository.createVault('test_password_123');

        expect(storage.salt, isNotNull);
        expect(storage.encryptedDekBlob, isNotNull);
        expect(storage.passwordVerifierBlob, isNotNull);
      });

      test('throws StateError if healthy vault already exists', () async {
        await repository.createVault('first_password');

        expect(
          () => repository.createVault('second_password'),
          throwsA(isA<StateError>()),
        );
      });

      test('allows re-creation after deleting vault metadata', () async {
        await repository.createVault('first_password');
        await storage.deleteVaultMetadata();
        repository.lockVault();

        await repository.createVault('second_password');

        expect(repository.isUnlocked, isTrue);
      });

      test('handles corrupted vault metadata by wiping and recreating', () async {
        await repository.createVault('first_password');

        // Simulate corruption: set salt but clear encrypted DEK
        storage.encryptedDekBlob = null;

        await repository.createVault('second_password');

        expect(repository.isUnlocked, isTrue);
        expect(storage.salt, isNotNull);
      });
    });

    group('unlockVault', () {
      test('unlocks with correct password', () async {
        await repository.createVault('correct_password');
        repository.lockVault();
        expect(repository.isUnlocked, isFalse);

        await repository.unlockVault('correct_password');

        expect(repository.isUnlocked, isTrue);
      });

      test('throws WrongPasswordException for wrong password', () async {
        await repository.createVault('correct_password');
        repository.lockVault();

        expect(
          () => repository.unlockVault('wrong_password'),
          throwsA(isA<WrongPasswordException>()),
        );
      });

      test('throws StateError if no vault exists', () async {
        expect(
          () => repository.unlockVault('any_password'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('lockVault', () {
      test('zeros DEK and sets isUnlocked to false', () async {
        await repository.createVault('password');
        expect(repository.isUnlocked, isTrue);

        repository.lockVault();

        expect(repository.isUnlocked, isFalse);
      });

      test('is a no-op if vault is already locked', () {
        // Vault starts locked
        expect(repository.isUnlocked, isFalse);

        // Should not throw
        repository.lockVault();

        expect(repository.isUnlocked, isFalse);
      });
    });

    group('vaultExists', () {
      test('returns false when no vault has been created', () async {
        expect(await repository.vaultExists(), isFalse);
      });

      test('returns true after vault creation', () async {
        await repository.createVault('password');
        expect(await repository.vaultExists(), isTrue);
      });

      test('returns false after vault metadata is deleted', () async {
        await repository.createVault('password');
        await storage.deleteVaultMetadata();
        expect(await repository.vaultExists(), isFalse);
      });
    });

    group('isBiometricEnabled', () {
      test('returns false when biometric is not enabled', () async {
        expect(await repository.isBiometricEnabled(), isFalse);
      });

      test('returns true after enabling biometric', () async {
        await repository.createVault('password');
        await repository.enableBiometric(biometricService: biometricService);
        expect(await repository.isBiometricEnabled(), isTrue);
      });
    });

    group('encryptDocument / decryptDocument', () {
      test('throws StateError if vault is locked', () async {
        expect(
          () => repository.encryptDocument(Uint8List(10)),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError if vault is locked (decrypt)', () async {
        expect(
          () => repository.decryptDocument(Uint8List(40)),
          throwsA(isA<StateError>()),
        );
      });

      test('round-trip: encrypt then decrypt returns original', () async {
        await repository.createVault('password');

        const plaintext = 'Secret document content';
        final encrypted = await repository.encryptDocument(
          Uint8List.fromList(plaintext.codeUnits),
        );

        final decrypted = await repository.decryptDocument(encrypted);

        expect(decrypted, equals(Uint8List.fromList(plaintext.codeUnits)));
      });

      test('encrypted document is different each time (random nonce)', () async {
        await repository.createVault('password');

        const plaintext = 'Same content';
        final encrypted1 = await repository.encryptDocument(
          Uint8List.fromList(plaintext.codeUnits),
        );
        final encrypted2 = await repository.encryptDocument(
          Uint8List.fromList(plaintext.codeUnits),
        );

        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });
  });
}
