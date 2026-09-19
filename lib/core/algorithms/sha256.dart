import 'dart:typed_data';

/// Pure-Dart implementation of SHA-256 as specified in FIPS 180-4.
///
/// No external packages are used — all round constants, initial hash
/// values, and logic are self-contained, making this suitable for
/// academic project review and verification.
///
/// Usage:
/// ```dart
/// final hash = Sha256.hash(Uint8List.fromList(utf8.encode('abc')));
/// // -> e3b0c442... (32 bytes)
/// ```
class Sha256 {
  // -----------------------------------------------------------------------
  // Round constants: first 32 bits of the fractional parts of the cube
  // roots of the first 64 prime numbers (2..311).
  // -----------------------------------------------------------------------
  static const List<int> _k = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  // -----------------------------------------------------------------------
  // Initial hash values: first 32 bits of the fractional parts of the
  // square roots of the first 8 prime numbers (2, 3, 5, 7, 11, 13, 17, 19).
  // -----------------------------------------------------------------------
  static const List<int> _h0 = [
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];

  static const int _blockSize = 64; // 512-bit blocks
  static const int _mask32 = 0xFFFFFFFF;

  /// Computes the SHA-256 digest of [input].
  /// Returns exactly 32 bytes (256 bits).
  static Uint8List hash(Uint8List input) {
    return Uint8List.fromList(_hashBytes(input));
  }

  /// Returns the digest as a lowercase hex string.
  static String hashHex(Uint8List input) {
    final digest = _hashBytes(input);
    final sb = StringBuffer();
    for (final b in digest) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static List<int> _hashBytes(List<int> data) {
    final padded = _pad(data);

    var h0 = _h0[0];
    var h1 = _h0[1];
    var h2 = _h0[2];
    var h3 = _h0[3];
    var h4 = _h0[4];
    var h5 = _h0[5];
    var h6 = _h0[6];
    var h7 = _h0[7];

    // Process each 512-bit (64-byte) chunk
    for (var offset = 0; offset < padded.length; offset += _blockSize) {
      // Build message schedule (64 32-bit words)
      final w = List<int>.filled(64, 0);

      // First 16 words from the chunk (big-endian)
      for (var i = 0; i < 16; i++) {
        final b = offset + i * 4;
        w[i] =
            (padded[b] << 24) |
            (padded[b + 1] << 16) |
            (padded[b + 2] << 8) |
            padded[b + 3];
      }

      // Extend to 64 words
      for (var i = 16; i < 64; i++) {
        final s0 =
            _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask32;
      }

      // Compression
      var a = h0, b = h1, c = h2, d = h3;
      var e = h4, f = h5, g = h6, hh = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & _mask32) & g);
        final temp1 = (hh + s1 + ch + _k[i] + w[i]) & _mask32;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & _mask32;

        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & _mask32;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & _mask32;
      }

      h0 = (h0 + a) & _mask32;
      h1 = (h1 + b) & _mask32;
      h2 = (h2 + c) & _mask32;
      h3 = (h3 + d) & _mask32;
      h4 = (h4 + e) & _mask32;
      h5 = (h5 + f) & _mask32;
      h6 = (h6 + g) & _mask32;
      h7 = (h7 + hh) & _mask32;
    }

    return [
      (h0 >> 24) & 0xFF,
      (h0 >> 16) & 0xFF,
      (h0 >> 8) & 0xFF,
      h0 & 0xFF,
      (h1 >> 24) & 0xFF,
      (h1 >> 16) & 0xFF,
      (h1 >> 8) & 0xFF,
      h1 & 0xFF,
      (h2 >> 24) & 0xFF,
      (h2 >> 16) & 0xFF,
      (h2 >> 8) & 0xFF,
      h2 & 0xFF,
      (h3 >> 24) & 0xFF,
      (h3 >> 16) & 0xFF,
      (h3 >> 8) & 0xFF,
      h3 & 0xFF,
      (h4 >> 24) & 0xFF,
      (h4 >> 16) & 0xFF,
      (h4 >> 8) & 0xFF,
      h4 & 0xFF,
      (h5 >> 24) & 0xFF,
      (h5 >> 16) & 0xFF,
      (h5 >> 8) & 0xFF,
      h5 & 0xFF,
      (h6 >> 24) & 0xFF,
      (h6 >> 16) & 0xFF,
      (h6 >> 8) & 0xFF,
      h6 & 0xFF,
      (h7 >> 24) & 0xFF,
      (h7 >> 16) & 0xFF,
      (h7 >> 8) & 0xFF,
      h7 & 0xFF,
    ];
  }

  /// Right-rotate a 32-bit value [value] by [n] bits.
  static int _rotr(int value, int n) {
    return ((value >> n) | (value << (32 - n))) & _mask32;
  }

  /// Pads [data] per SHA-256 (FIPS 180-4) specification:
  ///   1. Append 0x80
  ///   2. Append zeros until length ≡ 56 (mod 64)
  ///   3. Append 64-bit big-endian original bit length
  static List<int> _pad(List<int> data) {
    final originalBitLen = data.length * 8;
    final padded = <int>[...data];
    padded.add(0x80);
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    for (var i = 0; i < 8; i++) {
      padded.add((originalBitLen >> (56 - i * 8)) & 0xFF);
    }
    return padded;
  }
}
