import 'dart:typed_data';

import 'package:trident/core/algorithms/aes_128.dart';
import 'package:trident/core/algorithms/sha256.dart';

/// Payload for the isolate-based encrypt-and-hash task.
///
/// Uses [List<int>] (not [Uint8List]) so [compute] can serialize
/// the message to the background isolate.
class EncryptionTask {
  final List<int> data;
  final List<int> key;

  EncryptionTask(this.data, this.key);
}

/// Result from [encryptAndHash].
class EncryptionResult {
  final List<int> encryptedData;
  final String hashHex;

  EncryptionResult(this.encryptedData, this.hashHex);
}

/// Payload for the isolate-based decrypt-and-verify task.
class DecryptionTask {
  final List<int> data;
  final List<int> key;
  final String expectedHashHex;

  DecryptionTask(this.data, this.key, this.expectedHashHex);
}

/// Result from [decryptAndVerify].
class DecryptionResult {
  final List<int> plaintext;
  final String computedHashHex;

  DecryptionResult(this.plaintext, this.computedHashHex);
}

/// Top-level function that runs SHA-256 hashing + AES-128-CBC encryption
/// in a background isolate via [compute].
///
/// This prevents the ~2 MB encrypt/hash from blocking the UI thread,
/// which was causing jank and OOM crashes on large files.
EncryptionResult encryptAndHash(EncryptionTask task) {
  final data = Uint8List.fromList(task.data);
  final key = Uint8List.fromList(task.key);

  // --- SHA-256 integrity hash ---
  final hash = Sha256.hash(data);
  final hashHex = _bytesToHex(hash);

  // --- AES-128-CBC encryption ---
  final encrypted = Aes128.encrypt(data, key);

  return EncryptionResult(encrypted, hashHex);
}

/// Top-level function that runs AES-128-CBC decryption + SHA-256 verification
/// in a background isolate via [compute].
DecryptionResult decryptAndVerify(DecryptionTask task) {
  final data = Uint8List.fromList(task.data);
  final key = Uint8List.fromList(task.key);

  // --- AES-128-CBC decryption ---
  final plaintext = Aes128.decrypt(data, key);

  // --- SHA-256 integrity verification ---
  final hash = Sha256.hash(plaintext);
  final computedHex = _bytesToHex(hash);

  return DecryptionResult(plaintext.toList(), computedHex);
}

String _bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
