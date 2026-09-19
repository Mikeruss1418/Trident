import 'dart:math';
import 'dart:typed_data';

/// Pure-Dart implementation of AES-128 (FIPS 197) with CBC mode
/// and PKCS7 padding.
///
/// No external packages are used — all S-boxes, inverse S-boxes, and
/// GF(2^8) arithmetic are self-contained, making this suitable for
/// academic project review and verification.
///
/// Usage:
/// ```dart
/// final encrypted = Aes128.encrypt(plaintext, key);  // key = 16 bytes
/// final decrypted = Aes128.decrypt(encrypted, key);
/// ```
class Aes128 {
  static const int _blockSize = 16;
  static const int _keySize = 16;

  // -----------------------------------------------------------------------
  // S-box — substitution table for SubBytes (FIPS 197 Appendix C.1)
  // -----------------------------------------------------------------------
  static const List<int> _sbox = [
    0x63,
    0x7c,
    0x77,
    0x7b,
    0xf2,
    0x6b,
    0x6f,
    0xc5,
    0x30,
    0x01,
    0x67,
    0x2b,
    0xfe,
    0xd7,
    0xab,
    0x76,
    0xca,
    0x82,
    0xc9,
    0x7d,
    0xfa,
    0x59,
    0x47,
    0xf0,
    0xad,
    0xd4,
    0xa2,
    0xaf,
    0x9c,
    0xa4,
    0x72,
    0xc0,
    0xb7,
    0xfd,
    0x93,
    0x26,
    0x36,
    0x3f,
    0xf7,
    0xcc,
    0x34,
    0xa5,
    0xe5,
    0xf1,
    0x71,
    0xd8,
    0x31,
    0x15,
    0x04,
    0xc7,
    0x23,
    0xc3,
    0x18,
    0x96,
    0x05,
    0x9a,
    0x07,
    0x12,
    0x80,
    0xe2,
    0xeb,
    0x27,
    0xb2,
    0x75,
    0x09,
    0x83,
    0x2c,
    0x1a,
    0x1b,
    0x6e,
    0x5a,
    0xa0,
    0x52,
    0x3b,
    0xd6,
    0xb3,
    0x29,
    0xe3,
    0x2f,
    0x84,
    0x53,
    0xd1,
    0x00,
    0xed,
    0x20,
    0xfc,
    0xb1,
    0x5b,
    0x6a,
    0xcb,
    0xbe,
    0x39,
    0x4a,
    0x4c,
    0x58,
    0xcf,
    0xd0,
    0xef,
    0xaa,
    0xfb,
    0x43,
    0x4d,
    0x33,
    0x85,
    0x45,
    0xf9,
    0x02,
    0x7f,
    0x50,
    0x3c,
    0x9f,
    0xa8,
    0x51,
    0xa3,
    0x40,
    0x8f,
    0x92,
    0x9d,
    0x38,
    0xf5,
    0xbc,
    0xb6,
    0xda,
    0x21,
    0x10,
    0xff,
    0xf3,
    0xd2,
    0xcd,
    0x0c,
    0x13,
    0xec,
    0x5f,
    0x97,
    0x44,
    0x17,
    0xc4,
    0xa7,
    0x7e,
    0x3d,
    0x64,
    0x5d,
    0x19,
    0x73,
    0x60,
    0x81,
    0x4f,
    0xdc,
    0x22,
    0x2a,
    0x90,
    0x88,
    0x46,
    0xee,
    0xb8,
    0x14,
    0xde,
    0x5e,
    0x0b,
    0xdb,
    0xe0,
    0x32,
    0x3a,
    0x0a,
    0x49,
    0x06,
    0x24,
    0x5c,
    0xc2,
    0xd3,
    0xac,
    0x62,
    0x91,
    0x95,
    0xe4,
    0x79,
    0xe7,
    0xc8,
    0x37,
    0x6d,
    0x8d,
    0xd5,
    0x4e,
    0xa9,
    0x6c,
    0x56,
    0xf4,
    0xea,
    0x65,
    0x7a,
    0xae,
    0x08,
    0xba,
    0x78,
    0x25,
    0x2e,
    0x1c,
    0xa6,
    0xb4,
    0xc6,
    0xe8,
    0xdd,
    0x74,
    0x1f,
    0x4b,
    0xbd,
    0x8b,
    0x8a,
    0x70,
    0x3e,
    0xb5,
    0x66,
    0x48,
    0x03,
    0xf6,
    0x0e,
    0x61,
    0x35,
    0x57,
    0xb9,
    0x86,
    0xc1,
    0x1d,
    0x9e,
    0xe1,
    0xf8,
    0x98,
    0x11,
    0x69,
    0xd9,
    0x8e,
    0x94,
    0x9b,
    0x1e,
    0x87,
    0xe9,
    0xce,
    0x55,
    0x28,
    0xdf,
    0x8c,
    0xa1,
    0x89,
    0x0d,
    0xbf,
    0xe6,
    0x42,
    0x68,
    0x41,
    0x99,
    0x2d,
    0x0f,
    0xb0,
    0x54,
    0xbb,
    0x16,
  ];

  // -----------------------------------------------------------------------
  // Inverse S-box — for InvSubBytes (FIPS 197 Appendix C.2)
  // -----------------------------------------------------------------------
  static const List<int> _invSbox = [
    0x52,
    0x09,
    0x6a,
    0xd5,
    0x30,
    0x36,
    0xa5,
    0x38,
    0xbf,
    0x40,
    0xa3,
    0x9e,
    0x81,
    0xf3,
    0xd7,
    0xfb,
    0x7c,
    0xe3,
    0x39,
    0x82,
    0x9b,
    0x2f,
    0xff,
    0x87,
    0x34,
    0x8e,
    0x43,
    0x44,
    0xc4,
    0xde,
    0xe9,
    0xcb,
    0x54,
    0x7b,
    0x94,
    0x32,
    0xa6,
    0xc2,
    0x23,
    0x3d,
    0xee,
    0x4c,
    0x95,
    0x0b,
    0x42,
    0xfa,
    0xc3,
    0x4e,
    0x08,
    0x2e,
    0xa1,
    0x66,
    0x28,
    0xd9,
    0x24,
    0xb2,
    0x76,
    0x5b,
    0xa2,
    0x49,
    0x6d,
    0x8b,
    0xd1,
    0x25,
    0x72,
    0xf8,
    0xf6,
    0x64,
    0x86,
    0x68,
    0x98,
    0x16,
    0xd4,
    0xa4,
    0x5c,
    0xcc,
    0x5d,
    0x65,
    0xb6,
    0x92,
    0x6c,
    0x70,
    0x48,
    0x50,
    0xfd,
    0xed,
    0xb9,
    0xda,
    0x5e,
    0x15,
    0x46,
    0x57,
    0xa7,
    0x8d,
    0x9d,
    0x84,
    0x90,
    0xd8,
    0xab,
    0x00,
    0x8c,
    0xbc,
    0xd3,
    0x0a,
    0xf7,
    0xe4,
    0x58,
    0x05,
    0xb8,
    0xb3,
    0x45,
    0x06,
    0xd0,
    0x2c,
    0x1e,
    0x8f,
    0xca,
    0x3f,
    0x0f,
    0x02,
    0xc1,
    0xaf,
    0xbd,
    0x03,
    0x01,
    0x13,
    0x8a,
    0x6b,
    0x3a,
    0x91,
    0x11,
    0x41,
    0x4f,
    0x67,
    0xdc,
    0xea,
    0x97,
    0xf2,
    0xcf,
    0xce,
    0xf0,
    0xb4,
    0xe6,
    0x73,
    0x96,
    0xac,
    0x74,
    0x22,
    0xe7,
    0xad,
    0x35,
    0x85,
    0xe2,
    0xf9,
    0x37,
    0xe8,
    0x1c,
    0x75,
    0xdf,
    0x6e,
    0x47,
    0xf1,
    0x1a,
    0x71,
    0x1d,
    0x29,
    0xc5,
    0x89,
    0x6f,
    0xb7,
    0x62,
    0x0e,
    0xaa,
    0x18,
    0xbe,
    0x1b,
    0xfc,
    0x56,
    0x3e,
    0x4b,
    0xc6,
    0xd2,
    0x79,
    0x20,
    0x9a,
    0xdb,
    0xc0,
    0xfe,
    0x78,
    0xcd,
    0x5a,
    0xf4,
    0x1f,
    0xdd,
    0xa8,
    0x33,
    0x88,
    0x07,
    0xc7,
    0x31,
    0xb1,
    0x12,
    0x10,
    0x59,
    0x27,
    0x80,
    0xec,
    0x5f,
    0x60,
    0x51,
    0x7f,
    0xa9,
    0x19,
    0xb5,
    0x4a,
    0x0d,
    0x2d,
    0xe5,
    0x7a,
    0x9f,
    0x93,
    0xc9,
    0x9c,
    0xef,
    0xa0,
    0xe0,
    0x3b,
    0x4d,
    0xae,
    0x2a,
    0xf5,
    0xb0,
    0xc8,
    0xeb,
    0xbb,
    0x3c,
    0x83,
    0x53,
    0x99,
    0x61,
    0x17,
    0x2b,
    0x04,
    0x7e,
    0xba,
    0x77,
    0xd6,
    0x26,
    0xe1,
    0x69,
    0x14,
    0x63,
    0x55,
    0x21,
    0x0c,
    0x7d,
  ];

  // -----------------------------------------------------------------------
  // Round constants (FIPS 197 Appendix R)
  // -----------------------------------------------------------------------
  static const List<int> _rcon = [
    0x01,
    0x02,
    0x04,
    0x08,
    0x10,
    0x20,
    0x40,
    0x80,
    0x1b,
    0x36,
  ];

  // -----------------------------------------------------------------------
  // GF(2^8) multiplication tables — precomputed for performance.
  // AES uses irreducible polynomial m(x) = x^8 + x^4 + x^3 + x + 1 (0x11b)
  // -----------------------------------------------------------------------
  static final List<int> _mul2 = List<int>.generate(256, (i) => _gfMul(i, 2));
  static final List<int> _mul3 = List<int>.generate(256, (i) => _gfMul(i, 3));
  static final List<int> _mul9 = List<int>.generate(256, (i) => _gfMul(i, 9));
  static final List<int> _mul11 = List<int>.generate(256, (i) => _gfMul(i, 11));
  static final List<int> _mul13 = List<int>.generate(256, (i) => _gfMul(i, 13));
  static final List<int> _mul14 = List<int>.generate(256, (i) => _gfMul(i, 14));

  /// Multiplies [a] by [b] in GF(2^8) with the AES reduction polynomial.
  static int _gfMul(int a, int b) {
    var p = 0;
    for (var i = 0; i < 8; i++) {
      if (b & 1 != 0) p ^= a;
      final hi = a & 0x80;
      a = (a << 1) & 0xFF;
      if (hi != 0) a ^= 0x1b;
      b >>= 1;
    }
    return p;
  }

  // -----------------------------------------------------------------------
  // Key expansion — expands 16-byte key into 11 round keys
  // (44 words; each round key = 4 words = 4 columns × 4 rows)
  // Returns List of 11 round keys. roundKeys[r][c][row] = byte.
  // -----------------------------------------------------------------------
  static List<List<List<int>>> _expandKey(Uint8List key) {
    assert(key.length == _keySize, 'AES-128 requires a 16-byte key');

    final w = List<List<int>>.filled(44, const <int>[0, 0, 0, 0]);
    for (var i = 0; i < 4; i++) {
      w[i] = [key[i * 4], key[i * 4 + 1], key[i * 4 + 2], key[i * 4 + 3]];
    }

    for (var i = 4; i < 44; i++) {
      final temp = List<int>.from(w[i - 1]);
      if (i % 4 == 0) {
        // RotWord: rotate left by one position
        temp.removeAt(0);
        temp.add(w[i - 1][0]);
        // SubWord: apply S-box
        for (var j = 0; j < 4; j++) {
          temp[j] = _sbox[temp[j]];
        }
        // XOR with round constant
        temp[0] ^= _rcon[i ~/ 4 - 1];
      }
      w[i] = [
        w[i - 4][0] ^ temp[0],
        w[i - 4][1] ^ temp[1],
        w[i - 4][2] ^ temp[2],
        w[i - 4][3] ^ temp[3],
      ];
    }

    // Group into 11 round keys, each with 4 columns
    return List.generate(
      11,
      (r) => [w[r * 4], w[r * 4 + 1], w[r * 4 + 2], w[r * 4 + 3]],
    );
  }

  // -----------------------------------------------------------------------
  // Single-block operations (ECB) — for unit tests and FIPS-197 verification
  // -----------------------------------------------------------------------

  /// Encrypts a single 16-byte block with AES-128 (ECB mode).
  static Uint8List encryptBlock(Uint8List block, Uint8List key) {
    assert(block.length == 16, 'Block must be 16 bytes');
    assert(key.length == 16, 'Key must be 16 bytes');

    // State: state[row][col] = block[col*4 + row] (column-major per FIPS 197)
    final state = List.generate(4, (row) => List.filled(4, 0));
    for (var i = 0; i < 16; i++) {
      state[i % 4][i ~/ 4] = block[i];
    }

    final roundKeys = _expandKey(key);

    // Initial round key
    _addRoundKey(state, roundKeys[0]);

    // 9 main rounds
    for (var rnd = 1; rnd < 10; rnd++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, roundKeys[rnd]);
    }

    // Final round (no MixColumns)
    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, roundKeys[10]);

    return _stateToBytes(state);
  }

  /// Decrypts a single 16-byte block with AES-128 (ECB mode).
  static Uint8List decryptBlock(Uint8List block, Uint8List key) {
    assert(block.length == 16, 'Block must be 16 bytes');
    assert(key.length == 16, 'Key must be 16 bytes');

    final state = List.generate(4, (row) => List.filled(4, 0));
    for (var i = 0; i < 16; i++) {
      state[i % 4][i ~/ 4] = block[i];
    }

    final roundKeys = _expandKey(key);

    // Initial round key (round 10)
    _addRoundKey(state, roundKeys[10]);

    // 9 inverse rounds
    for (var rnd = 9; rnd >= 1; rnd--) {
      _invShiftRows(state);
      _invSubBytes(state);
      _addRoundKey(state, roundKeys[rnd]);
      _invMixColumns(state);
    }

    // Final inverse round
    _invShiftRows(state);
    _invSubBytes(state);
    _addRoundKey(state, roundKeys[0]);

    return _stateToBytes(state);
  }

  // -----------------------------------------------------------------------
  // CBC mode with PKCS7 padding
  // -----------------------------------------------------------------------

  /// Encrypts [plaintext] using AES-128-CBC with PKCS7 padding.
  /// Returns [IV (16 bytes) | ciphertext].
  /// [key] must be exactly 16 bytes.
  static Uint8List encrypt(Uint8List plaintext, Uint8List key) {
    assert(key.length == _keySize, 'Key must be 16 bytes for AES-128');

    final rng = Random.secure();
    final iv = Uint8List.fromList(
      List<int>.generate(_blockSize, (_) => rng.nextInt(256)),
    );

    final padded = _pkcs7Pad(plaintext);
    final ciphertext = Uint8List(padded.length);
    var prev = List<int>.from(iv);

    for (var i = 0; i < padded.length; i += _blockSize) {
      final block = Uint8List(_blockSize);
      for (var j = 0; j < _blockSize; j++) {
        block[j] = padded[i + j] ^ prev[j];
      }
      prev = List<int>.from(encryptBlock(block, key));
      for (var j = 0; j < _blockSize; j++) {
        ciphertext[i + j] = prev[j];
      }
    }

    // Prepend IV
    final result = Uint8List(iv.length + ciphertext.length);
    result.setRange(0, _blockSize, iv);
    result.setRange(_blockSize, result.length, ciphertext);
    return result;
  }

  /// Decrypts [data] (IV prepended) using AES-128-CBC.
  /// Removes PKCS7 padding and returns the plaintext.
  static Uint8List decrypt(Uint8List data, Uint8List key) {
    assert(key.length == _keySize, 'Key must be 16 bytes for AES-128');
    assert(
      data.length >= _blockSize * 2,
      'Ciphertext must be at least IV + one block',
    );

    final iv = data.sublist(0, _blockSize);
    final ciphertext = data.sublist(_blockSize);
    final plaintext = Uint8List(ciphertext.length);
    var prev = List<int>.from(iv);

    for (var i = 0; i < ciphertext.length; i += _blockSize) {
      final block = ciphertext.sublist(i, i + _blockSize);
      final decrypted = decryptBlock(Uint8List.fromList(block), key);
      for (var j = 0; j < _blockSize; j++) {
        plaintext[i + j] = decrypted[j] ^ prev[j];
      }
      prev = List<int>.from(block);
    }

    return _pkcs7Unpad(plaintext);
  }

  // -----------------------------------------------------------------------
  // PKCS7 padding
  // -----------------------------------------------------------------------
  static Uint8List _pkcs7Pad(Uint8List data) {
    final padLen = _blockSize - (data.length % _blockSize);
    final result = Uint8List(data.length + padLen);
    result.setRange(0, data.length, data);
    for (var i = data.length; i < result.length; i++) {
      result[i] = padLen;
    }
    return result;
  }

  static Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data[data.length - 1];
    if (padLen == 0 || padLen > _blockSize || padLen > data.length) {
      return data;
    }
    for (var i = data.length - padLen; i < data.length; i++) {
      if (data[i] != padLen) return data;
    }
    return data.sublist(0, data.length - padLen);
  }

  // -----------------------------------------------------------------------
  // AES round operations
  // -----------------------------------------------------------------------

  static Uint8List _stateToBytes(List<List<int>> state) {
    final result = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      result[i] = state[i % 4][i ~/ 4];
    }
    return result;
  }

  static void _addRoundKey(List<List<int>> state, List<List<int>> roundKey) {
    for (var col = 0; col < 4; col++) {
      for (var row = 0; row < 4; row++) {
        state[row][col] ^= roundKey[col][row];
      }
    }
  }

  static void _subBytes(List<List<int>> state) {
    for (var col = 0; col < 4; col++) {
      for (var row = 0; row < 4; row++) {
        state[row][col] = _sbox[state[row][col]];
      }
    }
  }

  static void _invSubBytes(List<List<int>> state) {
    for (var col = 0; col < 4; col++) {
      for (var row = 0; row < 4; row++) {
        state[row][col] = _invSbox[state[row][col]];
      }
    }
  }

  static void _shiftRows(List<List<int>> state) {
    // Row 0: no shift, Row 1: left 1, Row 2: left 2, Row 3: left 3
    for (var row = 1; row < 4; row++) {
      state[row] = List<int>.from(
        state[row].sublist(row) + state[row].sublist(0, row),
      );
    }
  }

  static void _invShiftRows(List<List<int>> state) {
    for (var row = 1; row < 4; row++) {
      state[row] = List<int>.from(
        state[row].sublist(4 - row) + state[row].sublist(0, 4 - row),
      );
    }
  }

  static void _mixColumns(List<List<int>> state) {
    for (var col = 0; col < 4; col++) {
      final s = [state[0][col], state[1][col], state[2][col], state[3][col]];
      state[0][col] = _mul2[s[0]] ^ _mul3[s[1]] ^ s[2] ^ s[3];
      state[1][col] = s[0] ^ _mul2[s[1]] ^ _mul3[s[2]] ^ s[3];
      state[2][col] = s[0] ^ s[1] ^ _mul2[s[2]] ^ _mul3[s[3]];
      state[3][col] = _mul3[s[0]] ^ s[1] ^ s[2] ^ _mul2[s[3]];
    }
  }

  static void _invMixColumns(List<List<int>> state) {
    for (var col = 0; col < 4; col++) {
      final s = [state[0][col], state[1][col], state[2][col], state[3][col]];
      state[0][col] = _mul14[s[0]] ^ _mul11[s[1]] ^ _mul13[s[2]] ^ _mul9[s[3]];
      state[1][col] = _mul9[s[0]] ^ _mul14[s[1]] ^ _mul11[s[2]] ^ _mul13[s[3]];
      state[2][col] = _mul13[s[0]] ^ _mul9[s[1]] ^ _mul14[s[2]] ^ _mul11[s[3]];
      state[3][col] = _mul11[s[0]] ^ _mul13[s[1]] ^ _mul9[s[2]] ^ _mul14[s[3]];
    }
  }
}
