import 'package:flutter/foundation.dart';
import 'package:xraynow/models/audit_log.dart';
import 'package:xraynow/supabase/supabase_config.dart';

class AuditLogService {
  /// Helper to safely resolve current application user id (users.id)
  static Future<String?> _getCurrentAppUserId() async {
    try {
      final authUser = SupabaseConfig.auth.currentUser;
      if (authUser == null) return null;
      final rec = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      if (rec == null) return null;
      return rec['id'] as String;
    } catch (e) {
      debugPrint('Audit get current app user error: $e');
      return null;
    }
  }

  static Future<void> log({
    required String action,
    required String table,
    required String recordId,
    Map<String, dynamic>? changes,
  }) async {
    try {
      final userId = await _getCurrentAppUserId();
      await SupabaseConfig.client.from('audit_logs').insert({
        'action': action,
        'table_name': table,
        'record_id': recordId,
        'user_id': userId,
        'changes': changes,
      });
    } catch (e) {
      // Never fail the business operation because of audit failure
      debugPrint('Audit log write failed: $e');
    }
  }

  /// Logs an authentication event such as login/logout/password_reset
  static Future<void> logAuthEvent(String event, {Map<String, dynamic>? details}) async {
    try {
      final authId = SupabaseConfig.auth.currentUser?.id ?? '-';
      await log(action: event, table: 'auth', recordId: authId, changes: {
        'platform': defaultTargetPlatform.name,
        if (details != null) ...details,
      });
    } catch (e) {
      debugPrint('Audit logAuthEvent failed: $e');
    }
  }

  /// Logs a generic user activity after authentication.
  /// Example: module='bookings', action='create', recordId=bookingId
  static Future<void> logActivity({
    required String module,
    required String action,
    String? recordId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await log(action: action, table: module, recordId: recordId ?? '-', changes: details);
    } catch (e) {
      debugPrint('Audit logActivity failed: $e');
    }
  }

  /// Fetch audit logs for a specific record, newest first
  static Future<List<AuditLog>> fetchForRecord({
    required String table,
    required String recordId,
  }) async {
    try {
      final data = await SupabaseConfig.client
          .from('audit_logs')
          .select()
          .eq('table_name', table)
          .eq('record_id', recordId)
          .order('created_at', ascending: false);
      final list = (data as List).map((e) => AuditLog.fromJson(Map<String, dynamic>.from(e))).toList();
      return list;
    } catch (e) {
      debugPrint('Audit fetchForRecord failed: $e');
      return [];
    }
  }
}
