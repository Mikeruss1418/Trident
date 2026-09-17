import 'dart:convert';

/// Categories of auditable events that the app can log.
///
/// Follows the same conceptual model as Nepal's Nagarik app audit log:
/// every user-facing security or data action is recorded with a timestamp.
enum AuditLogType {
  // Auth
  login,
  logout,
  vaultCreated,
  vaultDeleted,
  lockVault,
  unlockVault,

  // Biometrics
  biometricEnabled,
  biometricDisabled,
  biometricUnlockAttempt,

  // Document vault operations
  vaultAccessed,
  documentAdded,
  documentRemoved,

  // Generic (for future use / general-purpose events)
  error,
  warning,
}

/// A single auditable event persisted to local storage.
///
/// Serialized to JSON for storage via [SharedPrefsService].
class AuditLogEvent {
  AuditLogEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.description,
    this.metadata,
  });

  /// Unique identifier — [DateTime.now().millisecondsSinceEpoch] as string.
  final String id;

  /// When the event occurred.
  final DateTime timestamp;

  /// The category of event.
  final AuditLogType type;

  /// Short human-readable summary, shown as the list title.
  final String title;

  /// Longer human-readable detail, shown as the subtitle.
  final String description;

  /// Optional structured metadata (e.g. document name, success/failure).
  final Map<String, dynamic>? metadata;

  AuditLogEvent copyWith({
    String? id,
    DateTime? timestamp,
    AuditLogType? type,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return AuditLogEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'title': title,
    'description': description,
    if (metadata != null) 'metadata': metadata,
  };

  factory AuditLogEvent.fromJson(Map<String, dynamic> json) => AuditLogEvent(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: AuditLogType.values.firstWhere(
      (e) => e.name == (json['type'] as String),
    ),
    title: json['title'] as String,
    description: json['description'] as String,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  String toJsonString() => jsonEncode(toJson());

  factory AuditLogEvent.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return AuditLogEvent.fromJson(json);
  }
}
