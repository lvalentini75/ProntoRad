class AuditLog {
  final String id;
  final String tableName;
  final String recordId;
  final String action; // create | update | delete
  final String? userId; // app user id (not auth id)
  final Map<String, dynamic>? changes;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.userId,
    this.changes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'table_name': tableName,
      'action': action,
      'changes': changes,
      'created_at': createdAt.toIso8601String(),
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (recordId.isNotEmpty) {
      map['record_id'] = recordId;
    }
    if (userId != null && userId!.isNotEmpty) {
      map['user_id'] = userId;
    }
    
    return map;
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String,
        tableName: json['table_name'] as String,
        recordId: json['record_id'] as String,
        action: json['action'] as String,
        userId: json['user_id'] as String?,
        changes: json['changes'] == null ? null : Map<String, dynamic>.from(json['changes'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
