import 'package:trident/core/utils/app_imports.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';
import 'package:trident/features/recent_activity/domain/services/audit_log_service.dart';

/// Quick date-range filters surfaced as horizontal chips.
enum DateFilter {
  all('All time'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days');

  const DateFilter(this.label);

  final String label;

  /// Whether [ts] falls inside this filter's range.
  bool matches(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(ts.year, ts.month, ts.day);
    switch (this) {
      case DateFilter.all:
        return true;
      case DateFilter.today:
        return date == today;
      case DateFilter.yesterday:
        return date == DateTime(now.year, now.month, now.day - 1);
      case DateFilter.last7Days:
        return !date.isBefore(today.subtract(const Duration(days: 6)));
      case DateFilter.last30Days:
        return !date.isBefore(today.subtract(const Duration(days: 29)));
    }
  }
}

class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  /// Currently active date-range filter (defaults to [DateFilter.all]).
  DateFilter _selectedFilter = DateFilter.all;

  /// Calendar dates whose groups are currently collapsed. Empty by default,
  /// so recent activity is visible immediately and can be folded away.
  final Set<DateTime> _collapsedDates = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextWidget(
          'Recent Activity',
          textType: TextType.headlineLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear all activity',
            onPressed: () => getIt<AuditLogService>().clear(),
          ),
        ],
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: _showScrollToTop
            ? FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                mini: true,
                child: const Icon(Icons.arrow_upward, size: 20),
              )
            : SizedBox(width: 56.w, height: 56.h),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: StreamBuilder<List<AuditLogEvent>>(
        stream: getIt<AuditLogService>().watchEvents(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return _buildEmptyState();
          }

          final filtered = _applyFilter(events);

          if (filtered.isEmpty) {
            return Column(
              children: [
                _buildFilterChips(),
                const Expanded(child: _FilteredEmptyState()),
              ],
            );
          }

          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 16.w,
                  ),
                  children: _buildGroupedChildren(filtered),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<AuditLogEvent> _applyFilter(List<AuditLogEvent> events) {
    if (_selectedFilter == DateFilter.all) return events;
    return events.where((e) => _selectedFilter.matches(e.timestamp)).toList();
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 56.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        itemCount: DateFilter.values.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final filter = DateFilter.values[index];
          final selected = filter == _selectedFilter;
          return ChoiceChip(
            label: Text(
              filter.label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
            ),
            selected: selected,
            onSelected: (_) => setState(() => _selectedFilter = filter),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceContainer,
            disabledColor: AppColors.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: _EmptyState());
  }

  /// Builds the flat [ListView] child list: for each calendar-date group a
  /// header (with expand chevron) followed by the cards for that date —
  /// bank-statement style, but collapsible for long histories.
  List<Widget> _buildGroupedChildren(List<AuditLogEvent> events) {
    final children = <Widget>[];
    for (final group in _groupByDate(events)) {
      final expanded = !_collapsedDates.contains(group.date);
      if (children.isNotEmpty) {
        children.add(16.verticalSpace);
      }
      children.add(_buildDateHeader(group.label, group.date, expanded));
      if (expanded) {
        children.add(14.verticalSpace);
        for (int i = 0; i < group.events.length; i++) {
          children.add(_buildEventCard(group.events[i]));
          if (i < group.events.length - 1) {
            children.add(12.verticalSpace);
          }
        }
      }
    }
    return children;
  }

  /// Buckets [events] (expected newest-first) into contiguous calendar-date
  /// groups, preserving the input order within each group.
  List<_DateGroup> _groupByDate(List<AuditLogEvent> events) {
    final groups = <_DateGroup>[];
    for (final event in events) {
      final date = DateTime(
        event.timestamp.year,
        event.timestamp.month,
        event.timestamp.day,
      );
      if (groups.isNotEmpty && groups.last.date == date) {
        groups.last.events.add(event);
      } else {
        groups.add(
          _DateGroup(
            date: date,
            label: _formatDateLabel(event.timestamp),
            events: [event],
          ),
        );
      }
    }
    return groups;
  }

  /// A header row: the date label, a chevron that rotates to indicate
  /// expand/collapse, and a tap target to toggle the group.
  Widget _buildDateHeader(String label, DateTime date, bool expanded) {
    return InkWell(
      onTap: () {
        setState(() {
          if (expanded) {
            _collapsedDates.add(date);
          } else {
            _collapsedDates.remove(date);
          }
        });
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        child: Row(
          children: [
            TextWidget(
              label,
              textType: TextType.labelMedium,
              color: AppColors.textSecondary,
            ),
            const Spacer(),
            AnimatedRotation(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              turns: expanded ? 0.0 : -0.25,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 18.sp,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(AuditLogEvent event) {
    final flavor = _flavorFromAuditType(event.type);
    final timeLabel = _formatTimeLabel(event.timestamp);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1AFFFFFF),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2.h),
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: flavor.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(flavor.icon, color: flavor.color, size: 22.sp),
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
                TextWidget(
                  timeLabel,
                  textType: TextType.labelSmall,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves a distinct [IconData] + color for each [AuditLogType] so security
  /// events don't all collapse into a single info icon.
  _AuditFlavor _flavorFromAuditType(AuditLogType type) {
    switch (type) {
      case AuditLogType.login:
        return const _AuditFlavor(Icons.login, AppColors.info);
      case AuditLogType.logout:
        return const _AuditFlavor(Icons.logout, AppColors.info);
      case AuditLogType.vaultCreated:
        return const _AuditFlavor(Icons.add_box, AppColors.success);
      case AuditLogType.vaultDeleted:
        return const _AuditFlavor(Icons.delete_forever, AppColors.error);
      case AuditLogType.lockVault:
        return const _AuditFlavor(Icons.lock, AppColors.info);
      case AuditLogType.unlockVault:
        return const _AuditFlavor(Icons.lock_open, AppColors.info);
      case AuditLogType.biometricEnabled:
        return const _AuditFlavor(Icons.fingerprint, AppColors.success);
      case AuditLogType.biometricDisabled:
        return const _AuditFlavor(Icons.fingerprint, AppColors.warning);
      case AuditLogType.biometricUnlockAttempt:
        return const _AuditFlavor(Icons.fingerprint, AppColors.info);
      case AuditLogType.vaultAccessed:
        return const _AuditFlavor(Icons.visibility, AppColors.info);
      case AuditLogType.documentAdded:
        return const _AuditFlavor(Icons.upload_file, AppColors.success);
      case AuditLogType.documentRemoved:
        return const _AuditFlavor(Icons.delete_outline, AppColors.warning);
      case AuditLogType.error:
        return const _AuditFlavor(Icons.error, AppColors.error);
      case AuditLogType.warning:
        return const _AuditFlavor(Icons.warning, AppColors.warning);
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

/// Shown when the current [DateFilter] excludes every event.
class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt, size: 48.sp, color: AppColors.textTertiary),
          16.verticalSpace,
          const TextWidget(
            'No activity in this period',
            textType: TextType.titleMedium,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          8.verticalSpace,
          const TextWidget(
            'Try a different filter.',
            textType: TextType.bodySmall,
            color: AppColors.textTertiary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The original empty-state shown when the audit log itself has no events.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64.sp, color: AppColors.textTertiary),
          16.verticalSpace,
          const TextWidget(
            'No activity yet',
            textType: TextType.titleMedium,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          8.verticalSpace,
          const TextWidget(
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
}

/// A contiguous run of [AuditLogEvent]s sharing a calendar date.
class _DateGroup {
  const _DateGroup({
    required this.date,
    required this.label,
    required this.events,
  });

  /// Calendar date (midnight) this group represents.
  final DateTime date;

  /// Human-readable header label, e.g. "Today" / "Yesterday" / "Sep 12".
  final String label;

  /// Events in this group, newest-first.
  final List<AuditLogEvent> events;
}

/// The icon + color pair resolved for a given [AuditLogType].
class _AuditFlavor {
  const _AuditFlavor(this.icon, this.color);

  final IconData icon;
  final Color color;
}
