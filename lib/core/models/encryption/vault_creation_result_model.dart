import 'dart:typed_data';

import 'package:trident/core/models/encryption/encrypted_blob_model.dart';

/// Produced by [createVaultMaterial].
/// Persist [salt], [encryptedDekBlob], [passwordVerifierBlob].
/// Keep [dek] in memory only — never write it anywhere.
class VaultCreationResultModel {
  final Uint8List salt;
  final EncryptedBlobModel encryptedDekBlob;
  final EncryptedBlobModel passwordVerifierBlob;
  final Uint8List dek; // IN-MEMORY ONLY

  const VaultCreationResultModel({
    required this.salt,
    required this.encryptedDekBlob,
    required this.passwordVerifierBlob,
    required this.dek,
  });
}
