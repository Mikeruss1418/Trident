import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:trident/features/recent_activity/data/repositories/audit_log_repository.dart';
import 'package:trident/features/recent_activity/domain/models/audit_log_event.dart';

/// Service-layer facade for audit logging.
///
/// Wraps [AuditLogRepository] and exposes:
///   - [log] — append a new event (fire-and-forget, also returns a Future)
///   - [watchEvents] — a broadcast stream that emits the current list and
///     updates whenever a new event is logged
///   - [getAll] — one-shot read of all stored events
@lazySingleton
class AuditLogService {
  final AuditLogRepository _repository;

  AuditLogService(this._repository);

  final StreamController<List<AuditLogEvent>> _controller =
      StreamController<List<AuditLogEvent>>.broadcast();

  /// Stream of all stored events, newest-first. Emits the current list
  /// immediately to new subscribers, then again on every [log] call.
  Stream<List<AuditLogEvent>> watchEvents() {
    // Emit the current state synchronously to new listeners.
    _repository.loadAll().then((events) {
      if (!_controller.isClosed) {
        _controller.add(events);
      }
    });
    return _controller.stream;
  }

  /// Appends a single audit event and notifies stream listeners.
  ///
  /// This is `fire-and-forget` from the caller's perspective — the repository
  /// write happens in the background. Errors are swallowed (audit logging
  /// must never break the feature the user is performing).
  Future<void> log(AuditLogEvent event) async {
    try {
      await _repository.append(event);
      final all = await _repository.loadAll();
      if (!_controller.isClosed) {
        _controller.add(all);
      }
    } catch (e) {
      // Silently fail — audit logging must never break user flows.
    }
  }

  /// One-shot read of all stored events, newest-first.
  Future<List<AuditLogEvent>> getAll() => _repository.loadAll();

  /// Clears all stored audit events.
  Future<void> clear() async {
    await _repository.clear();
    if (!_controller.isClosed) {
      _controller.add([]);
    }
  }

  void dispose() {
    _controller.close();
  }
}
