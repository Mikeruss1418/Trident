import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:trident/core/algorithms/aes_128.dart';

/// Parses a hex string into a [Uint8List].
Uint8List parseHex(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  // FIPS 197 Appendix B test vectors
  final fipsKey = parseHex('000102030405060708090a0b0c0d0e0f');
  final fipsPlain = parseHex('00112233445566778899aabbccddeeff');
  final fipsCipher = parseHex('69c4e0d86a7b0430d8cdb78070b4c55a');

  group('Aes128 block operations (ECB)', () {
    test('FIPS-197 Appendix B: encrypt single block', () {
      final result = Aes128.encryptBlock(fipsPlain, fipsKey);
      expect(result, fipsCipher);
    });

    test('FIPS-197 Appendix B: decrypt single block', () {
      final result = Aes128.decryptBlock(fipsCipher, fipsKey);
      expect(result, fipsPlain);
    });

    test('encrypt then decrypt returns original', () {
      final decrypted = Aes128.decryptBlock(
        Aes128.encryptBlock(fipsPlain, fipsKey),
        fipsKey,
      );
      expect(decrypted, fipsPlain);
    });
  });

  group('Aes128 CBC mode with PKCS7', () {
    test('round-trip exact block size (16 bytes)', () {
      final plaintext = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        plaintext[i] = i;
      }
      final encrypted = Aes128.encrypt(plaintext, fipsKey);
      final decrypted = Aes128.decrypt(encrypted, fipsKey);
      expect(decrypted, plaintext);
    });

    test('round-trip with non-block-aligned data (15 bytes)', () {
      final plaintext = Uint8List.fromList(List.generate(15, (i) => i));
      final encrypted = Aes128.encrypt(plaintext, fipsKey);
      final decrypted = Aes128.decrypt(encrypted, fipsKey);
      expect(decrypted, plaintext);
    });

    test('round-trip empty plaintext', () {
      final plaintext = Uint8List(0);
      final encrypted = Aes128.encrypt(plaintext, fipsKey);
      final decrypted = Aes128.decrypt(encrypted, fipsKey);
      expect(decrypted, plaintext);
    });

    test('round-trip large data (1000 bytes)', () {
      final plaintext = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final encrypted = Aes128.encrypt(plaintext, fipsKey);
      final decrypted = Aes128.decrypt(encrypted, fipsKey);
      expect(decrypted, plaintext);
    });

    test('round-trip data exactly 256 bytes', () {
      final plaintext = Uint8List.fromList(
        List.generate(256, (i) => (i * 7) % 256),
      );
      final encrypted = Aes128.encrypt(plaintext, fipsKey);
      final decrypted = Aes128.decrypt(encrypted, fipsKey);
      expect(decrypted, plaintext);
    });

    test('encrypted output is IV + ciphertext (16 extra bytes for IV)', () {
      final plaintext = Uint8List(100);
      final encrypted = Aes128.encrypt(plaintext, fipsKey);
      // IV = 16, padded plaintext = 112 (next multiple of 16 above 100)
      expect(encrypted.length, 16 + 112);
    });

    test('different keys produce different ciphertext', () {
      final otherKey = parseHex('100102030405060708090a0b0c0d0e0f');
      final plaintext = Uint8List.fromList(List.generate(50, (i) => i));
      final enc1 = Aes128.encrypt(plaintext, fipsKey);
      final enc2 = Aes128.encrypt(plaintext, otherKey);
      expect(enc1, isNot(equals(enc2)));
    });

    test('tampered ciphertext fails to round-trip', () {
      final plaintext = Uint8List.fromList(List.generate(50, (i) => i));
      final encrypted = Uint8List.fromList(Aes128.encrypt(plaintext, fipsKey));
      // Flip one byte in the ciphertext portion (after IV)
      encrypted[17] ^= 0x01;
      final decrypted = Aes128.decrypt(encrypted, fipsKey);
      expect(decrypted, isNot(equals(plaintext)));
    });
  });
}
