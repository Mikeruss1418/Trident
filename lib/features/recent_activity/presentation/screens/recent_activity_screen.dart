import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/core/widgets/app_toast.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';
import 'package:trident/features/recent_activity/domain/services/audit_log_service.dart';

class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextWidget(
          'Recent Activity',
          textType: TextType.headlineLarge,
        ),
      ),
      body: StreamBuilder<List<AuditLogEvent>>(
        stream: getIt<AuditLogService>().watchEvents(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            itemCount: events.length,
            separatorBuilder: (_, _) => 12.verticalSpace,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventCard(event);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64.sp, color: AppColors.textTertiary),
          16.verticalSpace,
          TextWidget(
            'No activity yet',
            textType: TextType.titleMedium,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          8.verticalSpace,
          TextWidget(
            'Actions like vault access, biometric changes, '
            'and document operations will appear here.',
            textType: TextType.bodySmall,
            color: AppColors.textTertiary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(AuditLogEvent event) {
    final flavor = ToastFlavor.fromType(_toastTypeFromAuditType(event.type));
    final timeLabel = _formatTimeLabel(event.timestamp);
    final dateLabel = _formatDateLabel(event.timestamp);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2.h),
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: flavor.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(flavor.icon, color: flavor.color, size: 20.sp),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  event.title,
                  textType: TextType.titleMedium,
                  color: AppColors.textPrimary,
                ),
                2.verticalSpace,
                TextWidget(
                  event.description,
                  textType: TextType.bodySmall,
                  color: AppColors.textSecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                4.verticalSpace,
                Row(
                  children: [
                    TextWidget(
                      dateLabel,
                      textType: TextType.labelSmall,
                      color: AppColors.textTertiary,
                    ),
                    8.horizontalSpace,
                    TextWidget(
                      timeLabel,
                      textType: TextType.labelSmall,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Maps an [AuditLogType] back to a [ToastType] for icon/color reuse.
  ToastType _toastTypeFromAuditType(AuditLogType type) {
    switch (type) {
      case AuditLogType.error:
        return ToastType.error;
      case AuditLogType.warning:
        return ToastType.warning;
      case AuditLogType.documentAdded:
        return ToastType.success;
      case AuditLogType.documentRemoved:
        return ToastType.warning;
      case AuditLogType.vaultDeleted:
        return ToastType.error;
      case AuditLogType.biometricEnabled:
      case AuditLogType.unlockVault:
      case AuditLogType.login:
      case AuditLogType.vaultCreated:
      case AuditLogType.vaultAccessed:
      case AuditLogType.lockVault:
      case AuditLogType.logout:
      case AuditLogType.biometricDisabled:
      case AuditLogType.biometricUnlockAttempt:
        return ToastType.info;
    }
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return 'Today';
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date == yesterday) {
      return 'Yesterday';
    }
    // Same year → show month + day; different year → include year.
    if (dt.year == now.year) {
      return '${_monthName(dt.month)} ${dt.day}';
    }
    return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _formatTimeLabel(DateTime dt) {
    final hour = dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : hour;
    return '$displayHour:$minute $period';
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }
}
