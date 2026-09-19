import 'dart:io';

import 'package:trident/features/documents/domain/models/document_model.dart';

/// Service interface for persisting encrypted documents and their
/// metadata on local disk.
abstract class DocumentStorageService {
  /// Root directory that holds all encrypted document files and the
  /// metadata JSON. Created lazily on first use.
  Future<Directory> getDocumentsDirectory();

  /// Persists the encrypted document content to disk under
  /// [encryptedFileName], and updates the metadata list.
  Future<void> saveDocument(DocumentModel document, List<int> encryptedData);

  /// Loads all document metadata from the metadata JSON file.
  /// Returns an empty list when no documents have been stored yet.
  Future<List<DocumentModel>> loadAllMetadata();

  /// Reads the raw encrypted bytes for a given [encryptedFileName].
  /// Returns `null` if the file does not exist.
  Future<List<int>?> loadEncryptedData(String encryptedFileName);

  /// Removes both the encrypted file and its metadata entry.
  Future<void> deleteDocument(DocumentModel document);

  /// Returns the number of document metadata entries stored on disk.
  Future<int> countDocuments();
}
