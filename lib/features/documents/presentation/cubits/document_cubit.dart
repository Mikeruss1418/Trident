import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/core/algorithms/aes_128.dart';
import 'package:trident/core/algorithms/sha256.dart';
import 'package:trident/core/services/documents/document_storage_service.dart';
import 'package:trident/core/services/encryption/vault_encryption/vault_repository.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';
import 'package:trident/features/recent_activity/domain/services/audit_log_service.dart';

/// ---------------------------------------------------------------------------
/// State classes
/// ---------------------------------------------------------------------------
abstract class DocumentState {}

class DocumentInitial extends DocumentState {}

class DocumentLoading extends DocumentState {}

class DocumentLoaded extends DocumentState {
  final List<DocumentModel> documents;

  DocumentLoaded(this.documents);
}

class DocumentError extends DocumentState {
  final String message;

  DocumentError(this.message);
}

/// ---------------------------------------------------------------------------
/// DocumentCubit
/// ---------------------------------------------------------------------------
@lazySingleton
class DocumentCubit extends Cubit<DocumentState> {
  final VaultRepository _vaultRepository;
  final DocumentStorageService _storageService;
  final AuditLogService _auditLogService;

  DocumentCubit(
    this._vaultRepository,
    this._storageService,
    this._auditLogService,
  ) : super(DocumentInitial());

  /// True when the vault is locked and the user cannot encrypt/decrypt.
  bool get isVaultLocked => !_vaultRepository.isUnlocked;

  // -------------------------------------------------------------------------
  // Document listing
  // -------------------------------------------------------------------------

  /// Loads all document metadata from local storage.
  Future<void> loadDocuments() async {
    emit(DocumentLoading());
    try {
      final docs = await _storageService.loadAllMetadata();
      emit(DocumentLoaded(docs));
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  // -------------------------------------------------------------------------
  // Document add (pick -> encrypt -> store)
  // -------------------------------------------------------------------------

  /// Picks an image or PDF from the device, encrypts it with AES-128-CBC
  /// (using the vault DEK), computes a SHA-256 integrity hash, and stores
  /// the encrypted file + metadata on disk.
  Future<void> pickAndStoreDocument() async {
    if (isVaultLocked) {
      emit(DocumentError('Vault is locked'));
      return;
    }
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'pdf'],
      );
      if (picked == null) return; // user cancelled

      final bytes = await picked.readAsBytes();

      emit(DocumentLoading());

      // Obtain the vault DEK (first 16 bytes -> AES-128 key)
      final dek = _vaultRepository.getDek();
      final key = Uint8List.fromList(dek.sublist(0, 16));
      final data = Uint8List.fromList(bytes);

      // --- Algorithm #1: SHA-256 integrity hash ---
      final hash = Sha256.hash(data);
      final hashHex = _bytesToHex(hash);

      // --- Algorithm #2: AES-128-CBC encryption ---
      final encrypted = Aes128.encrypt(data, key);

      // Determine document type from extension
      final ext = (picked.extension ?? '').toLowerCase();
      final docType = _extToType(ext);

      final id =
          'doc_${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(9999)}';
      final encryptedFileName = '$id.enc';

      final doc = DocumentModel(
        id: id,
        title: picked.name,
        type: docType,
        size: bytes.length,
        createdAt: DateTime.now(),
        sha256: hashHex,
        encryptedFileName: encryptedFileName,
      );

      await _storageService.saveDocument(doc, encrypted);

      // Audit log: document added
      _auditLogService.log(
        AuditLogEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: AuditLogType.documentAdded,
          title: doc.title,
          description: 'Document added to vault',
          metadata: {
            'documentId': doc.id,
            'type': doc.type.toString(),
            'size': doc.size,
          },
        ),
      );

      await loadDocuments();
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  // -------------------------------------------------------------------------
  // Document preview (decrypt)
  // -------------------------------------------------------------------------

  /// Decrypts the document content and verifies its SHA-256 hash.
  /// Returns the plaintext bytes suitable for rendering.
  Future<Uint8List> previewDocument(DocumentModel doc) async {
    final encryptedData = await _storageService.loadEncryptedData(
      doc.encryptedFileName,
    );
    if (encryptedData == null) {
      throw Exception('Document file not found on disk');
    }

    final dek = _vaultRepository.getDek();
    final key = Uint8List.fromList(dek.sublist(0, 16));
    final data = Uint8List.fromList(encryptedData);

    // Decrypt
    final plaintext = Aes128.decrypt(data, key);

    // Verify integrity via SHA-256
    final computedHash = Sha256.hash(plaintext);
    final computedHex = _bytesToHex(computedHash);
    if (computedHex != doc.sha256) {
      throw Exception(
        'Integrity check failed: SHA-256 mismatch (possible tampering)',
      );
    }

    return Uint8List.fromList(plaintext);
  }

  // -------------------------------------------------------------------------
  // Document delete
  // -------------------------------------------------------------------------

  Future<void> deleteDocument(DocumentModel doc) async {
    try {
      await _storageService.deleteDocument(doc);

      // Audit log: document removed
      _auditLogService.log(
        AuditLogEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          type: AuditLogType.documentRemoved,
          title: doc.title,
          description: 'Document removed from vault',
          metadata: {'documentId': doc.id},
        ),
      );

      await loadDocuments();
    } catch (e) {
      emit(DocumentError(e.toString()));
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static DocumentType _extToType(String ext) {
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic'};
    return imageExts.contains(ext) ? DocumentType.image : DocumentType.pdf;
  }
}
