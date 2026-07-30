// Unit tests for EncryptedBlobModel wire format parsing and validation.
//
// These tests verify the AES-256-GCM wire format:
//   [12-byte nonce][16-byte MAC][N-byte ciphertext]
//   Total overhead: 28 bytes

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trident/core/models/encryption/encrypted_blob_model.dart';

void main() {
  group('EncryptedBlobModel', () {
    test('constructs from valid wire-format bytes', () {
      // 12 (nonce) + 16 (mac) + 4 (ciphertext) = 32 bytes
      final bytes = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        bytes[i] = i;
      }

      final blob = EncryptedBlobModel(bytes);

      expect(blob.bytes, equals(bytes));
      expect(blob.nonce.length, equals(12));
      expect(blob.mac.length, equals(16));
      expect(blob.ciphertext.length, equals(4));
    });

    test('validate() accepts minimum-length blob (28 bytes)', () {
      final bytes = Uint8List(28); // exactly header length, zero ciphertext
      final blob = EncryptedBlobModel.validate(bytes);

      expect(blob.bytes.length, equals(28));
      expect(blob.ciphertext.length, equals(0));
    });

    test('validate() throws ArgumentError for too-short blob', () {
      final shortBytes = Uint8List(27); // one byte too short

      expect(
        () => EncryptedBlobModel.validate(shortBytes),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validate() throws ArgumentError for empty blob', () {
      final emptyBytes = Uint8List(0);

      expect(
        () => EncryptedBlobModel.validate(emptyBytes),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('nonce, mac, and ciphertext are correctly sliced', () {
      final bytes = Uint8List(40);
      // Fill with recognizable patterns
      for (var i = 0; i < 12; i++) {
        bytes[i] = i; // nonce: 0-11
      }
      for (var i = 0; i < 16; i++) {
        bytes[12 + i] = 100 + i; // mac: 100-115
      }
      for (var i = 0; i < 12; i++) {
        bytes[28 + i] = 200 + i; // ciphertext: 200-211
      }

      final blob = EncryptedBlobModel(bytes);

      expect(blob.nonce, equals(bytes.sublist(0, 12)));
      expect(blob.mac, equals(bytes.sublist(12, 28)));
      expect(blob.ciphertext, equals(bytes.sublist(28)));
    });

    test('headerLength constant is 28', () {
      expect(EncryptedBlobModel.headerLength, equals(28));
    });
  });
}
