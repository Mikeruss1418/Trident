import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';
import 'package:trident/features/documents/presentation/cubits/document_cubit.dart';
import 'package:trident/features/documents/presentation/widgets/document_preview.dart';

/// Screen that decrypts and previews a single document.
///
/// Receives a [DocumentModel] via the go_router `extra` parameter, decrypts
/// the encrypted file with AES-128-CBC (vault DEK), verifies the SHA-256
/// integrity hash, and renders the content via [DocumentPreview].
class DocumentPreviewScreen extends StatelessWidget {
  final DocumentModel document;

  const DocumentPreviewScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<DocumentCubit>();
    return Scaffold(
      appBar: AppBar(
        title: TextWidget(document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: cubit.previewDocument(document),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48.r, color: AppColors.error),
                  16.verticalSpace,
                  TextWidget(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final bytes = snapshot.data!;
          return DocumentPreview(bytes: bytes, type: document.type);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const TextWidget(
          'Delete Document?',
          textType: TextType.titleMedium,
        ),
        content: const TextWidget(
          'This action cannot be undone. The document will be '
          'permanently removed from the vault.',
          textType: TextType.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextWidget(
              'Cancel',
              textType: TextType.bodyMedium,
              color: AppColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () {
              getIt<DocumentCubit>().deleteDocument(document);
              Navigator.pop(ctx);
              context.pop();
            },
            child: const TextWidget(
              'Delete',
              textType: TextType.bodyMedium,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
