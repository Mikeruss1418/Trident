import 'dart:async';

import 'package:trident/core/constants/assets_path.dart';
import 'package:trident/core/extensions/widget_extension.dart';
import 'package:trident/core/routes/route_names.dart';
import 'package:trident/core/services/navigation/navigation_service.dart';
import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/services/documents/document_storage_service.dart';
import 'package:trident/features/documents/domain/models/document_model.dart';
import 'package:trident/features/documents/domain/services/document_services.dart';
import 'package:trident/features/documents/presentation/cubits/document_cubit.dart';
import 'package:trident/features/home/data/constants/home_constants.dart';
import 'package:trident/features/home/domain/models/services_model.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';
import 'package:trident/features/recent_activity/domain/services/audit_log_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Latest successful unlock event, derived from the audit log so the
  /// overview row can report the unlock method (password/biometric) and time.
  AuditLogEvent? _lastUnlock;

  /// Current count of encrypted documents in the vault, shown on the
  /// overview card. Refreshed via the audit log stream when documents
  /// are added or removed.
  int _documentCount = 0;

  /// Documents matching the current search query.
  List<DocumentModel> _searchResults = [];

  /// Re-evaluates "X min ago" labels every 30s so they stay current.
  Timer? _timeAgoTimer;
  StreamSubscription<List<AuditLogEvent>>? _unlockSubscription;

  /// Reads the document count from the storage service and updates state.
  Future<void> _loadDocumentCount() async {
    final count = await getIt<DocumentStorageService>().countDocuments();
    if (mounted) {
      setState(() => _documentCount = count);
    }
  }

  /// Searches documents by title as the user types.
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await getIt<DocumentCubit>().searchDocuments(query);
    if (mounted) {
      setState(() => _searchResults = results);
    }
  }

  @override
  void initState() {
    super.initState();
    _timeAgoTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
    // Subscribe once (not in build) to avoid re-entrancy: watchEvents() emits
    // the current log immediately, then again on every new logged event.
    _unlockSubscription = getIt<AuditLogService>().watchEvents().listen((
      events,
    ) {
      if (!mounted) return;
      setState(() {
        _lastUnlock = _latestSuccessfulUnlock(events);
      });
      // Refresh document count on any document add/remove event.
      if (events.isNotEmpty &&
          (events.first.type == AuditLogType.documentAdded ||
              events.first.type == AuditLogType.documentRemoved)) {
        _loadDocumentCount();
      }
    });
    _loadDocumentCount();
  }

  @override
  void dispose() {
    _unlockSubscription?.cancel();
    _timeAgoTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboardWidget(
      child: Scaffold(
        body: SingleChildScrollView(
          child: ScreenPadding(
            child: Column(
              children: [
                20.verticalSpace,
                _buildLogo(),
                24.verticalSpace,
                _buildSearchBar(),
                14.verticalSpace,
                _buildSearchResults(),
                if (_searchResults.isEmpty) ...[
                  _buildOverviewCard(),
                  14.verticalSpace,
                  _buildServiceGrid(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _performSearch,
        decoration: InputDecoration(
          hintText: 'Search documents',
          prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
          border: InputBorder.none,
          isDense: true,
          hintStyle: TextStyle(color: AppColors.textTertiary),
        ),
        style: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isNotEmpty) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final doc = _searchResults[index];
          return _buildSearchResultItem(doc);
        },
      );
    }
    // Show a "no results" hint only when a non-empty query has been typed.
    if (_searchController.text.trim().isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(16.r),
        child: TextWidget(
          'No documents found',
          textType: TextType.bodyMedium,
          color: AppColors.textTertiary,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSearchResultItem(DocumentModel doc) {
    final icon = doc.type == DocumentType.pdf
        ? Icons.picture_as_pdf
        : Icons.image;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28.r),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  doc.title,
                  textType: TextType.bodyLarge,
                  color: AppColors.textPrimary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                TextWidget(
                  '${doc.size ~/ 1024} KB',
                  textType: TextType.bodySmall,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    ).onTap(() {
      _searchController.clear();
      _performSearch('');
      getIt<NavigationService>().navigateTo(
        RouteNames.documentPreviewRoute,
        extra: doc,
      );
    });
  }

  // -------------------------------------------------------------------------
  // Overview card
  // -------------------------------------------------------------------------

  Container _buildOverviewCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              TextWidget(
                _documentCount.toString(),
                textType: TextType.custom,
                textOptions: TextOptions(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.h,
                      decoration: ShapeDecoration(
                        color: AppColors.success,
                        shape: CircleBorder(),
                      ),
                    ),
                    6.horizontalSpace,
                    TextWidget(
                      'Unlocked',
                      textType: TextType.custom,
                      color: AppColors.success,
                      textOptions: TextOptions(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          TextWidget(
            'documents encrypted',
            color: AppColors.textTertiary,
            textType: TextType.bodySmall,
          ),
          24.verticalSpace,
          _buildUnlockInfoRow(),
          8.verticalSpace,
          _buildRow(
            icon: Icons.access_time_rounded,
            content: Text.rich(
              TextSpan(
                style: TextTheme.of(context).bodySmall,
                children: [
                  TextSpan(
                    text: 'Auto-locks after ',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  TextSpan(
                    text: ' 2 min ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'idle',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Unlock info row
  // -------------------------------------------------------------------------

  /// The "how did you open the vault and when" row. The icon + label are
  /// derived from the latest *successful* audit event so they reflect the
  /// real unlock method (password vs biometric), not a hardcoded placeholder.
  Widget _buildUnlockInfoRow() {
    final unlock = _lastUnlock;
    if (unlock == null) {
      // No recorded successful unlock yet (e.g. a freshly created vault).
      return _buildRow(
        icon: Icons.lock_open,
        content: const TextWidget(
          'Vault unlocked',
          textType: TextType.bodySmall,
          color: AppColors.textSecondary,
        ),
      );
    }

    final isBiometric = unlock.type == AuditLogType.biometricUnlockAttempt;
    return _buildRow(
      icon: isBiometric ? Icons.fingerprint : Icons.lock_open,
      content: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: 'Unlocked with ',
              style: TextStyle(color: AppColors.textTertiary),
            ),
            TextSpan(
              text: isBiometric ? 'biometric' : 'password',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(
              text: ' ${_timeAgo(unlock.timestamp)}',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Service grid
  // -------------------------------------------------------------------------

  /// Builds a grid of service tiles: the built-in services (Import,
  /// Backup/Export, Lock Vault) plus a "Documents" tile that opens the
  /// secure document list.
  Widget _buildServiceGrid() {
    final services = HomeConstants.services;

    return GridView.builder(
      itemCount: services.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceTile(service);
      },
    );
  }

  Widget _buildServiceTile(ServiceModel service) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          service.icon,
          8.verticalSpace,
          TextWidget(
            service.title,
            textType: TextType.bodySmall,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ).onTap(() => _handleServiceTap(service.title));
  }

  void _handleServiceTap(String title) {
    switch (title) {
      case 'Import':
        DocumentServices.instance.handleImport(context);
        break;
      case 'Documents':
        getIt<NavigationService>().navigateTo(RouteNames.documentRoute);
        break;
      case 'Lock Vault':
        // Lock the vault via the vault repository.
        // (Placeholder — not yet implemented.)
        break;
      case 'Backup /Export':
        // Backup/export feature placeholder.
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Logo
  // -------------------------------------------------------------------------

  Hero _buildLogo() {
    return Hero(
      tag: 'logo',
      curve: Curves.easeIn,
      child:
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.onPrimary,
                radius: 24.r,
                child: Image.asset(AssetsPath.logoPNG),
              ),
              14.horizontalSpace,
              TextWidget(
                'Trident',
                textType: TextType.custom,
                color: AppColors.primary,
                textOptions: TextOptions(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ).onTap(
            () =>
                getIt<NavigationService>().navigateTo(RouteNames.profileRoute),
          ),
    );
  }

  // -------------------------------------------------------------------------
  // Row helper
  // -------------------------------------------------------------------------

  Widget _buildRow({required IconData icon, required dynamic content}) {
    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 15.r),
        12.horizontalSpace,
        content is Widget
            ? content
            : TextWidget(
                content,
                textType: TextType.bodySmall,
                color: AppColors.textTertiary,
              ),
      ],
    );
  }
}

/// Picks the most recent *successful* unlock event from [events] (expected
/// newest-first). Failed biometric attempts are skipped, so the overview row
/// never reports a method that didn't actually grant access.
AuditLogEvent? _latestSuccessfulUnlock(List<AuditLogEvent> events) {
  for (final event in events) {
    final isSuccessfulBiometric =
        event.type == AuditLogType.biometricUnlockAttempt &&
        !event.title.toLowerCase().contains('failed');
    if (event.type == AuditLogType.login ||
        event.type == AuditLogType.unlockVault ||
        isSuccessfulBiometric) {
      return event;
    }
  }
  return null;
}

/// A compact, auto-ticking "time ago" label: `just now`, `4 min ago`, ...
String _timeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 30) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} d ago';
}
