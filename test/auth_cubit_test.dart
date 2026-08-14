// Unit tests for AuthCubit — the authentication state machine.
//
// Tests cover:
//   - State transitions: onboarding → authenticated → vaultLocked → authenticated
//   - Vault creation from onboarding state
//   - Login from unauthenticated state
//   - Lock from authenticated state
//   - Unlock from vaultLocked state
//   - Biometric unlock from vaultLocked and unauthenticated states
//   - Logout from authenticated and vaultLocked states
//   - Guard conditions (no-op when state doesn't match)

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';
import 'package:trident/core/services/biometric/biometric_service.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_encryption_service.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_repository.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_storage_service.dart';
import 'package:trident/features/auth/presentation/cubits/auth_cubit/auth_cubit.dart';

// Fake BiometricService
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
  }) async => authenticated;

  @override
  Future<void> invalidate() async {}
}

// Fake VaultStorageService
class FakeVaultStorageService implements VaultStorageService {
  Uint8List? salt;
  EncryptedBlobModel? encryptedDekBlob;
  EncryptedBlobModel? passwordVerifierBlob;
  bool biometricEnabled = false;
  bool deleteAllVaultDataCalled = false;

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
  Future<void> deleteAllVaultData() async {
    deleteAllVaultDataCalled = true;
    salt = null;
    encryptedDekBlob = null;
    passwordVerifierBlob = null;
    biometricEnabled = false;
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
  group('AuthCubit', () {
    late VaultEncryptionService crypto;
    late FakeVaultStorageService storage;
    late FakeBiometricService biometricService;
    late VaultRepository repository;
    late AuthCubit authCubit;

    setUp(() {
      crypto = VaultEncryptionService();
      storage = FakeVaultStorageService();
      biometricService = FakeBiometricService();
      repository = VaultRepository(crypto, storage);
      authCubit = AuthCubit(repository, biometricService);
    });

    tearDown(() {
      authCubit.close();
    });

    group('initialize', () {
      test('emits onboarding when no vault exists', () async {
        await authCubit.initialize();

        expect(authCubit.state, equals(AuthStatus.onboarding));
      });

      test('emits unauthenticated when vault exists', () async {
        await repository.createVault('password');
        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);

        await authCubit.initialize();

        expect(authCubit.state, equals(AuthStatus.unauthenticated));
      });
    });

    group('createVault', () {
      test('transitions from onboarding to authenticated', () async {
        await authCubit.initialize();
        expect(authCubit.state, equals(AuthStatus.onboarding));

        await authCubit.createVault('new_password_123');

        expect(authCubit.state, equals(AuthStatus.authenticated));
      });

      test('returns to onboarding on failure', () async {
        await authCubit.initialize();

        // Make vaultExists return true with a healthy vault, so createVault
        // will throw StateError (refuse to overwrite)
        await repository.createVault('existing_password');
        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);
        await authCubit.initialize();
        // State is now unauthenticated (vault exists)

        // createVault should throw StateError because vault already exists
        await expectLater(
          authCubit.createVault('new_password'),
          throwsA(isA<StateError>()),
        );

        // Should be back to onboarding (AuthCubit catches and re-emits onboarding)
        expect(authCubit.state, equals(AuthStatus.onboarding));
      });
    });

    group('login', () {
      test('transitions from unauthenticated to authenticated', () async {
        await repository.createVault('correct_password');
        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);
        await authCubit.initialize();
        expect(authCubit.state, equals(AuthStatus.unauthenticated));

        await authCubit.login('correct_password');

        expect(authCubit.state, equals(AuthStatus.authenticated));
      });

      test('throws WrongPasswordException for wrong password', () async {
        await repository.createVault('correct_password');
        repository.lockVault();
        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);
        await authCubit.initialize();

        expect(
          () => authCubit.login('wrong_password'),
          throwsA(isA<WrongPasswordException>()),
        );

        expect(authCubit.state, equals(AuthStatus.unauthenticated));
      });
    });

    group('lockVault', () {
      test('transitions from authenticated to vaultLocked', () async {
        await authCubit.initialize();
        await authCubit.createVault('password');
        expect(authCubit.state, equals(AuthStatus.authenticated));

        authCubit.lockVault();

        expect(authCubit.state, equals(AuthStatus.vaultLocked));
      });

      test('is a no-op when not authenticated', () async {
        await authCubit.initialize();
        expect(authCubit.state, equals(AuthStatus.onboarding));

        authCubit.lockVault();

        expect(authCubit.state, equals(AuthStatus.onboarding));
      });
    });

    group('unlockVault', () {
      test('transitions from vaultLocked to authenticated', () async {
        await repository.createVault('correct_password');
        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);
        await authCubit.initialize();
        await authCubit.login('correct_password');
        authCubit.lockVault();
        expect(authCubit.state, equals(AuthStatus.vaultLocked));

        await authCubit.unlockVault('correct_password');

        expect(authCubit.state, equals(AuthStatus.authenticated));
      });

      test('is a no-op when not vaultLocked', () async {
        await authCubit.initialize();
        expect(authCubit.state, equals(AuthStatus.onboarding));

        await authCubit.unlockVault('password');

        expect(authCubit.state, equals(AuthStatus.onboarding));
      });
    });

    group('logout', () {
      test('transitions from authenticated to unauthenticated', () async {
        await authCubit.initialize();
        await authCubit.createVault('password');
        expect(authCubit.state, equals(AuthStatus.authenticated));

        authCubit.logout();

        expect(authCubit.state, equals(AuthStatus.unauthenticated));
      });

      test('transitions from vaultLocked to unauthenticated', () async {
        await repository.createVault('password');
        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);
        await authCubit.initialize();
        await authCubit.login('password');
        authCubit.lockVault();
        expect(authCubit.state, equals(AuthStatus.vaultLocked));

        authCubit.logout();

        expect(authCubit.state, equals(AuthStatus.unauthenticated));
      });
    });

    group('deleteAccount', () {
      test('wipes vault data and transitions to onboarding', () async {
        await authCubit.initialize();
        await authCubit.createVault('password');
        expect(authCubit.state, equals(AuthStatus.authenticated));
        expect(await repository.vaultExists(), isTrue);

        authCubit.deleteAccount();

        expect(authCubit.state, equals(AuthStatus.onboarding));
        expect(await repository.vaultExists(), isFalse);
        expect(repository.isUnlocked, isFalse);
        expect(storage.deleteAllVaultDataCalled, isTrue);
      });

      test('clears biometric data when vault is deleted', () async {
        await authCubit.initialize();
        await authCubit.createVault('password');
        await authCubit.enableBiometric();
        expect(await authCubit.isBiometricEnabled(), isTrue);

        authCubit.deleteAccount();

        expect(authCubit.state, equals(AuthStatus.onboarding));
        final fakeStorage = storage;
        expect(fakeStorage.biometricEnabled, isFalse);
      });

      test(
        'zeroes in-memory DEK when vault is deleted while unlocked',
        () async {
          await authCubit.initialize();
          await authCubit.createVault('password');
          expect(repository.isUnlocked, isTrue);

          authCubit.deleteAccount();

          expect(repository.isUnlocked, isFalse);
        },
      );

      test('can create a new vault after deletion', () async {
        await authCubit.initialize();
        await authCubit.createVault('old_password');
        expect(authCubit.state, equals(AuthStatus.authenticated));

        authCubit.deleteAccount();
        expect(authCubit.state, equals(AuthStatus.onboarding));

        // Should be able to create a fresh vault with a different password
        await authCubit.createVault('new_password_123');
        expect(authCubit.state, equals(AuthStatus.authenticated));

        // Should be able to unlock with the new password
        repository.lockVault();
        expect(repository.isUnlocked, isFalse);

        authCubit.close();
        authCubit = AuthCubit(repository, biometricService);
        await authCubit.initialize();
        expect(authCubit.state, equals(AuthStatus.unauthenticated));

        await authCubit.login('new_password_123');
        expect(authCubit.state, equals(AuthStatus.authenticated));
      });
    });

    group('biometric methods', () {
      test('isBiometricAvailable delegates to BiometricService', () async {
        biometricService.available = true;
        expect(await authCubit.isBiometricAvailable(), isTrue);

        biometricService.available = false;
        expect(await authCubit.isBiometricAvailable(), isFalse);
      });

      test('isBiometricEnabled delegates to VaultRepository', () async {
        await repository.createVault('password');

        expect(await authCubit.isBiometricEnabled(), isFalse);

        await authCubit.enableBiometric();
        expect(await authCubit.isBiometricEnabled(), isTrue);
      });

      test('enableBiometric requires vault to be unlocked', () async {
        await authCubit.initialize();

        // Vault not created, so enableBiometric should throw StateError
        expect(() => authCubit.enableBiometric(), throwsA(isA<StateError>()));
      });

      test(
        'unlockWithBiometric returns false when not in correct state',
        () async {
          await authCubit.initialize();
          // State is onboarding, not vaultLocked or unauthenticated
          final result = await authCubit.unlockWithBiometric();
          expect(result, isFalse);
        },
      );

      test(
        'unlockWithBiometric returns false when biometric not enabled',
        () async {
          await repository.createVault('password');
          authCubit.close();
          authCubit = AuthCubit(repository, biometricService);
          await authCubit.initialize();
          // State is unauthenticated, biometric not enabled

          final result = await authCubit.unlockWithBiometric();
          expect(result, isFalse);
        },
      );

      test(
        'unlockWithBiometric returns false when biometric auth fails',
        () async {
          await repository.createVault('password');
          await authCubit.enableBiometric();
          repository.lockVault();
          authCubit.close();
          authCubit = AuthCubit(repository, biometricService);
          await authCubit.initialize();
          // State is unauthenticated, biometric enabled

          biometricService.authenticated = false;
          final result = await authCubit.unlockWithBiometric();
          expect(result, isFalse);
        },
      );
    });
  });
}
