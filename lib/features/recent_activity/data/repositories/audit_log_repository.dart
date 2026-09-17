import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';

/// Abstract contract for persisting and retrieving audit log events.
abstract class AuditLogRepository {
  /// Loads all stored events, newest-first.
  Future<List<AuditLogEvent>> loadAll();

  /// Stores the given list of events (replaces existing).
  Future<void> saveAll(List<AuditLogEvent> events);

  /// Appends a single event, evicting the oldest if the cap is exceeded.
  Future<void> append(AuditLogEvent event);

  /// Removes all stored events.
  Future<void> clear();
}
