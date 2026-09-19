import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/documents/presentation/cubits/document_cubit.dart';

class DocumentServices {
  static DocumentServices get instance => DocumentServices._();
  DocumentServices._();

  /// Opens the file picker, then shows an undismissible loading dialog
  /// while the document is encrypted and stored. If the operation fails
  /// (e.g. file exceeds the 5 MB limit), the loading dialog is dismissed
  /// and a dismissible error dialog is shown instead.
  Future<void> handleImport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            16.horizontalSpace,
            TextWidget('Encrypting document...'),
          ],
        ),
      ),
    );

    await getIt<DocumentCubit>().pickAndStoreDocument();

    // Dismiss the loading dialog.
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // If the document was rejected (e.g. too large), show a dismissible error.
    if (context.mounted && getIt<DocumentCubit>().state is DocumentError) {
      final message = (getIt<DocumentCubit>().state as DocumentError).message;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: TextWidget('Upload Failed', textType: TextType.titleMedium),
          content: TextWidget(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: TextWidget('OK'),
            ),
          ],
        ),
      );
    }
  }
}
