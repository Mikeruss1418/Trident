import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';

/// Renders decrypted document bytes — an [Image.memory] for images,
/// or a [PdfView] (via pdfx) for PDFs.
///
/// All colors come from [AppColors], not Theme.of(context).
class DocumentPreview extends StatelessWidget {
  final Uint8List bytes;
  final DocumentType type;

  const DocumentPreview({super.key, required this.bytes, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == DocumentType.image) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              size: 64.r,
              color: AppColors.textTertiary,
            ),
          );
        },
      );
    }
    return PdfPreviewWidget(bytes: bytes);
  }
}

/// Internal widget that manages the [PdfController] lifecycle for [PdfView].
class PdfPreviewWidget extends StatefulWidget {
  final Uint8List bytes;

  const PdfPreviewWidget({super.key, required this.bytes});

  @override
  State<PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends State<PdfPreviewWidget> {
  late PdfController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(document: PdfDocument.openData(widget.bytes));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfView(controller: _controller);
  }
}
