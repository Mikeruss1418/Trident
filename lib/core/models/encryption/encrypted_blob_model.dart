import 'dart:typed_data';

/// Serialized blob of an AES-256-GCM encrypted value.
/// Wire format: [12-byte nonce][16-byte MAC][N-byte ciphertext]
/// Total overhead: 28 bytes per blob.
class EncryptedBlobModel {
  final Uint8List bytes; // full serialized wire format

  const EncryptedBlobModel(this.bytes);

  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int headerLength = _nonceLength + _macLength; // 28

  Uint8List get nonce => bytes.sublist(0, _nonceLength);
  Uint8List get mac => bytes.sublist(_nonceLength, headerLength);
  Uint8List get ciphertext => bytes.sublist(headerLength);

  /// Validates length. Throws [ArgumentError] if bytes are too short.
  factory EncryptedBlobModel.validate(Uint8List bytes) {
    if (bytes.length < headerLength) {
      throw ArgumentError(
        'EncryptedBlob too short: ${bytes.length} bytes (min $headerLength)',
      );
    }
    return EncryptedBlobModel(bytes);
  }
}
