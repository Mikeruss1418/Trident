/// Shared preference keys for the audit log feature.
class AuditLogKeys {
  AuditLogKeys._();

  /// SharedPrefs key under which the JSON-encoded [List<AuditLogEvent>]
  /// is stored.
  static const String auditLogList = 'audit_log_list';

  /// Maximum number of events retained. Oldest entries are evicted
  /// beyond this count to avoid unbounded growth.
  static const int maxEvents = 200;
}
