import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';
import 'package:trident/features/documents/presentation/cubits/document_cubit.dart';
import 'package:trident/features/documents/presentation/widgets/document_grid_item.dart';

/// Screen displaying stored documents in a responsive grid.
///
/// Follows project conventions: [ScreenPadding] for insets, [TextWidget]
/// + [TextType] for typography, [AppColors] for all colors, `.verticalSpace`
/// for spacing, and `.r` for device-independent sizing.
class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  @override
  void initState() {
    super.initState();
    getIt<DocumentCubit>().loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<DocumentCubit>();
    return Scaffold(
      appBar: AppBar(
        title: TextWidget('My Documents', textType: TextType.headlineLarge),
      ),
      body: ScreenPadding(
        child: BlocBuilder<DocumentCubit, DocumentState>(
          bloc: cubit,
          builder: (context, state) {
            if (state is DocumentLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is DocumentError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48.r, color: AppColors.error),
                    16.verticalSpace,
                    TextWidget(state.message, textAlign: TextAlign.center),
                    16.verticalSpace,
                    ElevatedButton(
                      onPressed: cubit.loadDocuments,
                      child: const TextWidget(
                        'Retry',
                        textType: TextType.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }
            final docs = state is DocumentLoaded
                ? state.documents
                : <DocumentModel>[];
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 64.r,
                      color: AppColors.textTertiary,
                    ),
                    16.verticalSpace,
                    const TextWidget('No documents yet'),
                    8.verticalSpace,
                    TextWidget(
                      'Tap + to add your first document',
                      textType: TextType.bodySmall,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return DocumentGridItem(
                  document: doc,
                  onTap: () => getIt<NavigationService>().navigateTo(
                    RouteNames.documentPreviewRoute,
                    extra: doc,
                  ),
                  onDelete: () => cubit.deleteDocument(doc),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
