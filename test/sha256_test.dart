import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:trident/core/algorithms/sha256.dart';

/// Parses a hex string into a [Uint8List].
Uint8List parseHex(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  group('Sha256', () {
    test('empty string produces known FIPS-180-4 hash', () {
      final result = Sha256.hash(Uint8List(0));
      expect(
        result,
        parseHex(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );
    });

    test('"abc" produces known FIPS-180-4 hash', () {
      final result = Sha256.hash(Uint8List.fromList(utf8.encode('abc')));
      expect(
        result,
        parseHex(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
    });

    test('quick brown fox produces known FIPS-180-4 hash', () {
      final result = Sha256.hash(
        Uint8List.fromList(
          utf8.encode('The quick brown fox jumps over the lazy dog'),
        ),
      );
      expect(
        result,
        parseHex(
          'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
        ),
      );
    });

    test('hashHex returns lowercase hex string', () {
      final hex = Sha256.hashHex(Uint8List.fromList(utf8.encode('abc')));
      expect(
        hex,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('output is always 32 bytes', () {
      expect(Sha256.hash(Uint8List.fromList(utf8.encode('a'))).length, 32);
      expect(
        Sha256.hash(Uint8List.fromList(utf8.encode('hello world'))).length,
        32,
      );
      expect(Sha256.hash(Uint8List(1000)).length, 32);
    });

    test('two different inputs produce different hashes', () {
      final a = Sha256.hash(Uint8List.fromList(utf8.encode('hello')));
      final b = Sha256.hash(Uint8List.fromList(utf8.encode('world')));
      expect(a, isNot(equals(b)));
    });
  });
}
