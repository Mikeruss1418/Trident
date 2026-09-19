import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';

/// Displays a single document as a grid card with a type-appropriate
/// icon, title, file size, creation date, and a delete action.
///
/// All typography uses [TextWidget] + [TextType], all colors use
/// [AppColors] constants, and tap handling uses the `.onTap()` extension.
class DocumentGridItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const DocumentGridItem({
    super.key,
    required this.document,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail / icon area
          Expanded(
            child: Container(
              color: AppColors.surfaceContainer,
              child: Center(child: _buildIcon()),
            ),
          ),
          // Metadata
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textType: TextType.custom,
                  textOptions: TextOptions(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                4.verticalSpace,
                TextWidget(
                  _formatFileSize(document.size),
                  textType: TextType.bodySmall,
                  color: AppColors.textTertiary,
                ),
                2.verticalSpace,
                TextWidget(
                  _formatDate(document.createdAt),
                  textType: TextType.bodySmall,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          // Delete button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20.r,
              ),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    ).onTap(() => onTap?.call());
  }

  Widget _buildIcon() {
    if (document.type == DocumentType.image) {
      return Icon(
        Icons.image_outlined,
        size: 48.r,
        color: AppColors.textTertiary,
      );
    }
    return Icon(Icons.picture_as_pdf, size: 48.r, color: AppColors.error);
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
