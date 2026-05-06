import 'package:flutter/foundation.dart';
import 'package:xraynow/models/user.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

class UserService {
  static const _rlsRecursionMarker = 'infinite recursion detected in policy for relation "users"';

  Future<User?> getCurrentUser() async {
    try {
      final authUser = SupabaseConfig.auth.currentUser;
      if (authUser == null) return null;
      // 1) Try by auth_user_id (canonical)
      final byAuthId = await getUserByAuthId(authUser.id);
      if (byAuthId != null) return byAuthId;

      // 2) Fallback: try by email when profiles were created before linking auth_user_id
      final email = authUser.email;
      if (email != null && email.isNotEmpty) {
        final byEmail = await getUserByEmail(email);
        if (byEmail != null) {
          // Best-effort: try to link auth_user_id for future lookups. Ignore RLS failures.
          try {
            await SupabaseService.update('users', {'auth_user_id': authUser.id}, filters: {'id': byEmail.id});
          } catch (e) {
            debugPrint('Non-critical: failed to link auth_user_id to existing profile: $e');
          }
          return byEmail;
        }
      }
      // 3) Strict mode: do not create automatically
      return null;
    } catch (e) {
      debugPrint('Failed to get current user: $e');
      return null;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      final data = await SupabaseService.select('users');
      return data.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load users: $e');
      return [];
    }
  }

  Future<User?> getUserById(String id) async {
    try {
      final data = await SupabaseService.selectSingle(
        'users',
        filters: {'id': id},
      );
      return data != null ? User.fromJson(data) : null;
    } catch (e) {
      debugPrint('Failed to get user by id: $e');
      return null;
    }
  }

  Future<User?> getUserByAuthId(String authUserId) async {
    try {
      final data = await SupabaseService.selectSingle(
        'users',
        filters: {'auth_user_id': authUserId},
      );
      return data != null ? User.fromJson(data) : null;
    } catch (e) {
      debugPrint('Failed to get user by auth_user_id: $e');
      return null;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    try {
      final data = await SupabaseService.selectSingle(
        'users',
        filters: {'email': email},
      );
      return data != null ? User.fromJson(data) : null;
    } catch (e) {
      debugPrint('Failed to get user by email: $e');
      return null;
    }
  }

  Future<User> createUser(User user) async {
    try {
      final result = await SupabaseService.insert('users', user.toJson());
      final created = User.fromJson(result.first);
      await AuditLogService.log(action: 'create', table: 'users', recordId: created.id, changes: created.toJson());
      return created;
    } catch (e) {
      debugPrint('Failed to create user: $e');
      // Fallback via Edge Function to bypass RLS when client insert is blocked.
      final msg = e.toString().toLowerCase();
      final isRls =
          msg.contains('violates row-level security policy') ||
          msg.contains('row-level security policy for table "users"') ||
          msg.contains('row level security') ||
          msg.contains('permission denied') ||
          msg.contains('policy for relation "users"') ||
          msg.contains('policy for relation \"users\"') ||
          msg.contains('infinite recursion') ||
          msg.contains('rls');
      if (isRls) {
        final created = await _ensurePatientViaEdge(user);
        await AuditLogService.log(action: 'create', table: 'users', recordId: created.id, changes: created.toJson());
        return created;
      }
      rethrow;
    }
  }

  Future<User> updateUser(User user) async {
    try {
      final result = await SupabaseService.update(
        'users',
        user.toJson(),
        filters: {'id': user.id},
      );
      // Se l'update non restituisce righe (RLS blocca), usa edge function
      if (result.isEmpty) {
        debugPrint('[UserService] Update returned empty result (RLS?), using edge function...');
        final updated = await _ensurePatientViaEdge(user);
        await AuditLogService.log(action: 'update', table: 'users', recordId: updated.id, changes: updated.toJson());
        return updated;
      }
      final updated = User.fromJson(result.first);
      await AuditLogService.log(action: 'update', table: 'users', recordId: updated.id, changes: updated.toJson());
      return updated;
    } catch (e) {
      debugPrint('Failed to update user: $e');
      final msg = e.toString().toLowerCase();
      final isRls =
          msg.contains('violates row-level security policy') ||
          msg.contains('row-level security policy for table "users"') ||
          msg.contains('row level security') ||
          msg.contains('permission denied') ||
          msg.contains('policy for relation "users"') ||
          msg.contains('policy for relation \"users\"') ||
          msg.contains('infinite recursion') ||
          msg.contains('no element') ||
          msg.contains('rls');
      if (isRls) {
        final updated = await _ensurePatientViaEdge(user);
        await AuditLogService.log(action: 'update', table: 'users', recordId: updated.id, changes: updated.toJson());
        return updated;
      }
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await SupabaseService.delete('users', filters: {'id': userId});
      await AuditLogService.log(action: 'delete', table: 'users', recordId: userId);
    } catch (e) {
      debugPrint('Failed to delete user: $e');
      rethrow;
    }
  }

  /// Update only the role of a user and audit the change
  Future<User> updateUserRole({required String userId, required String role}) async {
    try {
      final result = await SupabaseService.update('users', {
        'role': role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, filters: {'id': userId});
      final updated = User.fromJson(result.first);
      await AuditLogService.log(action: 'update', table: 'users', recordId: updated.id, changes: {'role': role});
      return updated;
    } catch (e) {
      debugPrint('Failed to update user role: $e');
      rethrow;
    }
  }

  /// Ensure a set of email->role mappings are applied. Returns number of updates performed.
  Future<int> applyEmailRoleMappings(Map<String, String> emailToRole) async {
    int updated = 0;
    try {
      if (emailToRole.isEmpty) return 0;
      // Fetch all users to map by email quickly; for large datasets, this should be paginated/filtered
      final rows = await SupabaseService.select('users');
      final byEmail = <String, Map<String, dynamic>>{};
      for (final m in rows) {
        final em = (m['email'] ?? '').toString().toLowerCase();
        if (em.isNotEmpty) byEmail[em] = m;
      }
      for (final entry in emailToRole.entries) {
        final email = entry.key.toLowerCase().trim();
        final role = entry.value.toLowerCase().trim();
        if (!['super_admin', 'org_admin', 'end_user'].contains(role)) continue;
        final target = byEmail[email];
        if (target == null) continue;
        final id = target['id'] as String;
        final currentRole = (target['role'] ?? '').toString();
        if (currentRole == role) continue;
        try {
          await SupabaseService.update('users', {
            'role': role,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, filters: {'id': id});
          await AuditLogService.log(action: 'update', table: 'users', recordId: id, changes: {'role': role});
          updated += 1;
        } catch (e) {
          debugPrint('Failed to apply role mapping for $email: $e');
        }
      }
    } catch (e) {
      debugPrint('applyEmailRoleMappings error: $e');
    }
    return updated;
  }

  Future<User> _ensurePatientViaEdge(User user) async {
    try {
      final payload = {
        if (user.id.isNotEmpty) 'id': user.id,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'email': user.email,
        'phone_number': user.phoneNumber,
        if (user.organizationId != null) 'organization_id': user.organizationId,
        'role': user.role ?? 'end_user',
        if (user.fiscalCode != null && user.fiscalCode!.isNotEmpty) 'fiscal_code': user.fiscalCode,
        if (user.dateOfBirth != null) 'date_of_birth': user.dateOfBirth!.toIso8601String().split('T').first,
        if (user.authUserId != null) 'auth_user_id': user.authUserId,
      };
      // Prefer user JWT if present; otherwise use anon key so guests can book
      final userToken = await SupabaseConfig.tryGetAccessToken();
      var usedToken = userToken ?? SupabaseConfig.anonKey;
      try { debugPrint('[UserService] Invoking ensure_patient with token prefix: ${usedToken.substring(0, 10)}…'); } catch (_) {}
      dynamic resp;
      try {
        resp = await SupabaseConfig.client.functions
            .invoke(
          'ensure_patient',
          body: payload,
          headers: {
            'Authorization': 'Bearer $usedToken',
            'apikey': SupabaseConfig.anonKey,
            'Content-Type': 'application/json',
          },
        )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        final msg = e.toString();
        final usedUserJwt = userToken != null;
        if (usedUserJwt && (msg.contains('status: 401') || msg.toLowerCase().contains('invalid jwt'))) {
          debugPrint('[UserService] ensure_patient retry with anon key Authorization');
          resp = await SupabaseConfig.client.functions
              .invoke(
            'ensure_patient',
            body: payload,
            headers: {
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
              'apikey': SupabaseConfig.anonKey,
              'Content-Type': 'application/json',
            },
          )
              .timeout(const Duration(seconds: 10));
        } else {
          rethrow;
        }
      }
      final data = resp.data;
      if (data is Map) {
        if (data['user'] != null && data['user'] is Map) {
          final map = Map<String, dynamic>.from(data['user'] as Map);
          return User.fromJson(map);
        }
        // Some implementations may return the user directly
        return User.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('ensure_patient returned unexpected payload: ${data.runtimeType}');
    } catch (e) {
      debugPrint('ensure_patient edge fallback failed: $e');
      rethrow;
    }
  }

  // Public wrapper to allow other layers (auth manager) to ensure a user via edge function
  Future<User> ensureUserViaEdge(User user) => _ensurePatientViaEdge(user);

  /// Upsert a user by email: if exists update, else create
  Future<User> upsertUser(User user) async {
    try {
      debugPrint('[UserService] upsertUser called for email: ${user.email}');
      // Check if user exists by email
      final existing = await getUserByEmail(user.email);
      if (existing != null) {
        debugPrint('[UserService] User exists with id: ${existing.id}, updating...');
        // Update existing user
        final updated = existing.copyWith(
          firstName: user.firstName,
          lastName: user.lastName,
          phoneNumber: user.phoneNumber,
          organizationId: user.organizationId ?? existing.organizationId,
          updatedAt: DateTime.now(),
        );
        return await updateUser(updated);
      } else {
        debugPrint('[UserService] User not found, creating new...');
        // Create new user
        return await createUser(user);
      }
    } catch (e) {
      debugPrint('[UserService] upsertUser failed: $e');
      // Fallback to edge function
      return await _ensurePatientViaEdge(user);
    }
  }
  
  /// Get user ID by email, returns null if not found
  Future<String?> getUserIdByEmail(String email) async {
    final user = await getUserByEmail(email);
    return user?.id;
  }

  /// Get all users associated with an organization
  Future<List<User>> getUsersByOrganization(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('organization_id', organizationId);
      return (data as List).map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to get users by organization: $e');
      return [];
    }
  }

  /// Get org_admin users for an organization
  Future<List<User>> getOrgAdmins(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('organization_id', organizationId)
          .eq('role', 'org_admin');
      return (data as List).map((json) => User.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to get org admins: $e');
      return [];
    }
  }
  
  /// Create a new end_user with the provided details
  Future<String> createEndUser({
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final newUser = User(
      id: '', // Will be generated by DB
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phone ?? '',
      role: 'end_user',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final created = await createUser(newUser);
    return created.id;
  }
}
