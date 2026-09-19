import 'package:injectable/injectable.dart';
import 'package:trident/core/storage/shared_preferences/shared_prefs_service.dart';
import 'package:trident/features/recent_activity/data/constants/audit_log_keys.dart';
import 'package:trident/features/recent_activity/data/repositories/audit_log_repository.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';

/// Shared-preference-backed implementation of [AuditLogRepository].
///
/// Events are stored as a JSON-encoded list under
/// [AuditLogKeys.auditLogList], newest-first, capped at
/// [AuditLogKeys.maxEvents] entries.
@LazySingleton(as: AuditLogRepository)
class AuditLogRepositoryImpl implements AuditLogRepository {
  final SharedPrefsService _prefs;

  AuditLogRepositoryImpl(this._prefs);

  @override
  Future<List<AuditLogEvent>> loadAll() async {
    final raw = _prefs.getStringList(key: AuditLogKeys.auditLogList);
    if (raw == null || raw.isEmpty) return [];

    return raw.map((e) => AuditLogEvent.fromJsonString(e)).toList();
  }

  @override
  Future<void> saveAll(List<AuditLogEvent> events) async {
    final jsonList = events.map((e) => e.toJsonString()).toList();
    await _prefs.setStringList(key: AuditLogKeys.auditLogList, value: jsonList);
  }

  @override
  Future<void> append(AuditLogEvent event) async {
    final all = await loadAll();
    // Insert newest-first.
    all.insert(0, event);

    // Evict oldest if exceeding the cap.
    if (all.length > AuditLogKeys.maxEvents) {
      all.removeRange(AuditLogKeys.maxEvents, all.length);
    }

    await saveAll(all);
  }

  @override
  Future<void> clear() async {
    _prefs.removeKey(key: AuditLogKeys.auditLogList);
  }
}
