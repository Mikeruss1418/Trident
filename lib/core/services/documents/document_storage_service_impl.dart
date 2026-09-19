import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trident/core/services/documents/document_storage_service.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';

/// Concrete implementation of [DocumentStorageService] that stores
/// encrypted document files and a metadata JSON file in the app's
/// documents directory.
@LazySingleton(as: DocumentStorageService)
class DocumentStorageServiceImpl implements DocumentStorageService {
  static const String _docsSubdir = 'trident_vault_documents';
  static const String _metadataFileName = 'documents_metadata.json';

  Directory? _cachedDir;

  @override
  Future<Directory> getDocumentsDirectory() async {
    if (_cachedDir != null) return _cachedDir!;

    final appDocDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory('${appDocDir.path}/$_docsSubdir');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    _cachedDir = docsDir;
    return docsDir;
  }

  Future<File> _metadataFile() async {
    final dir = await getDocumentsDirectory();
    return File('${dir.path}/$_metadataFileName');
  }

  @override
  Future<void> saveDocument(
    DocumentModel document,
    List<int> encryptedData,
  ) async {
    final dir = await getDocumentsDirectory();

    // Write the encrypted document file
    final docFile = File('${dir.path}/${document.encryptedFileName}');
    await docFile.writeAsBytes(encryptedData, flush: true);

    // Update metadata: replace if same id exists, otherwise append
    final allDocs = await loadAllMetadata();
    allDocs.removeWhere((d) => d.id == document.id);
    allDocs.add(document);
    await _writeMetadata(allDocs);
  }

  @override
  Future<List<DocumentModel>> loadAllMetadata() async {
    final file = await _metadataFile();
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];

    final json = jsonDecode(content) as List<dynamic>;
    return json
        .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeMetadata(List<DocumentModel> documents) async {
    final file = await _metadataFile();
    final json = documents.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  @override
  Future<List<int>?> loadEncryptedData(String encryptedFileName) async {
    final dir = await getDocumentsDirectory();
    final file = File('${dir.path}/$encryptedFileName');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<void> deleteDocument(DocumentModel document) async {
    final dir = await getDocumentsDirectory();
    final file = File('${dir.path}/${document.encryptedFileName}');
    if (await file.exists()) {
      await file.delete();
    }

    final allDocs = await loadAllMetadata();
    allDocs.removeWhere((d) => d.id == document.id);
    await _writeMetadata(allDocs);
  }

  @override
  Future<int> countDocuments() async {
    final docs = await loadAllMetadata();
    return docs.length;
  }
}
