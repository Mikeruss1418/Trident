import 'package:equatable/equatable.dart';

/// The type of a stored document.
enum DocumentType { image, pdf }

/// String extensions to parse [DocumentType] from stored JSON values.
extension DocumentTypeExt on DocumentType {
  String get key => switch (this) {
    DocumentType.image => 'image',
    DocumentType.pdf => 'pdf',
  };

  static DocumentType fromKey(String key) => switch (key) {
    'image' => DocumentType.image,
    'pdf' => DocumentType.pdf,
    _ => DocumentType.image,
  };
}

/// Immutable model representing a metadata entry for a single
/// encrypted document stored on disk.
class DocumentModel extends Equatable {
  /// Unique identifier (UUID v4).
  final String id;

  /// Display title — typically the original file name without extension.
  final String title;

  /// Whether this document is an image or a PDF.
  final DocumentType type;

  /// Original file size in bytes (before encryption).
  final int size;

  /// When the document was added to the vault.
  final DateTime createdAt;

  /// SHA-256 digest of the **plaintext** document, hex-encoded.
  /// Used to verify integrity after decryption.
  final String sha256;

  /// Name of the file on disk that holds the encrypted document content.
  final String encryptedFileName;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.type,
    required this.size,
    required this.createdAt,
    required this.sha256,
    required this.encryptedFileName,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      type: DocumentTypeExt.fromKey(json['type'] as String),
      size: json['size'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sha256: json['sha256'] as String,
      encryptedFileName: json['encryptedFileName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.key,
    'size': size,
    'createdAt': createdAt.toIso8601String(),
    'sha256': sha256,
    'encryptedFileName': encryptedFileName,
  };

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    size,
    createdAt,
    sha256,
    encryptedFileName,
  ];
}
