import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:xraynow/models/user.dart' as app;
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/config/role_policies.dart';

/// Ensures the current Supabase Auth user has a linked application profile in `users`
/// with correct role and optional organization mapping.
class ProfileSyncService {
  final UserService _userService = UserService();

  /// Perform reconciliation and return the application user profile.
  /// - If a profile exists by auth_user_id, returns it (and patches role/email if missing).
  /// - If not, tries to link existing profile by email (best-effort; may be blocked by RLS).
  /// - If still missing, creates a fresh profile using combined appMetadata + userMetadata.
  Future<app.User?> syncCurrentUser() async {
    final authUser = SupabaseConfig.auth.currentUser;
    if (authUser == null) return null;

    try {
      // 1) Canonical lookup by auth_user_id
      final existing = await _userService.getUserByAuthId(authUser.id);
      if (existing != null) {
        // Patch missing role/email if any (non-breaking, best-effort)
        final merged = _mergeMetadata(authUser);
        // Enforce role from policy mapping if present
        final policyRole = RolePolicies.roleForEmail(authUser.email);
        final role = (policyRole ?? merged['role'] ?? existing.role ?? 'end_user').toString();
        final email = authUser.email ?? existing.email;
        final needsUpdate = ((existing.role == null || existing.role != role) && role.isNotEmpty) || (existing.email.isEmpty && email.isNotEmpty);
        if (needsUpdate) {
          try {
            final updated = await SupabaseService.update('users', {
              'role': role,
              'email': email,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, filters: {'id': existing.id});
            return app.User.fromJson(updated.first);
          } catch (e) {
            debugPrint('Non-critical: failed to patch role/email on existing profile: $e');
          }
        }
        return existing;
      }

      // 2) Try to find by email then link auth_user_id (may fail due to RLS; ignore)
      final email = authUser.email;
      if (email != null && email.isNotEmpty) {
        final byEmail = await _userService.getUserByEmail(email);
        if (byEmail != null) {
          try {
            await SupabaseService.update('users', {
              'auth_user_id': authUser.id,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, filters: {'id': byEmail.id});
          } catch (e) {
            debugPrint('Non-critical: RLS prevented linking auth_user_id to existing email profile: $e');
          }
          return byEmail;
        }
      }

      // 3) Create a new profile now
      final now = DateTime.now().toUtc();
      final md = _mergeMetadata(authUser);
      // Enforce policy-mapped role if present
      final policyRole = RolePolicies.roleForEmail(authUser.email);
      final role = (policyRole ?? md['role'] ?? 'end_user').toString();

      String? organizationId;
      // If org_admin and org details are provided in metadata, try to bootstrap minimal org
      if (role == 'org_admin' && md['org'] is Map) {
        final orgMap = Map<String, dynamic>.from(md['org'] as Map);
        try {
          final createdOrg = await SupabaseService.insert('organizations', {
            'name': (orgMap['name'] ?? '').toString(),
            'org_type': (orgMap['org_type'] ?? 'hospital').toString(),
            'address': (orgMap['address'] ?? '').toString(),
            'city': (orgMap['city'] ?? '').toString(),
            'province': (orgMap['province'] ?? '').toString(),
            'region': (orgMap['region'] ?? '').toString(),
          });
          if (createdOrg.isNotEmpty) organizationId = createdOrg.first['id'] as String;
        } catch (e) {
          debugPrint('Failed to bootstrap organization during sync: $e');
        }
      }

      final firstName = (md['first_name'] ?? md['given_name'] ?? _nameFromEmail(authUser.email).$1).toString();
      final lastName = (md['last_name'] ?? md['family_name'] ?? _nameFromEmail(authUser.email).$2).toString();

      try {
        final created = await SupabaseService.insert('users', {
          'first_name': firstName,
          'last_name': lastName,
          'email': authUser.email ?? '',
          'phone_number': (md['phone_number'] ?? authUser.phone ?? '').toString(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'auth_user_id': authUser.id,
          'role': role,
          if (organizationId != null) 'organization_id': organizationId,
        });
        return app.User.fromJson(created.first);
      } catch (e) {
        debugPrint('Failed to create users profile during sync: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Profile sync error: $e');
      return null;
    }
  }

  Map<String, dynamic> _mergeMetadata(sb.User authUser) {
    final Map<String, dynamic> appMd = (authUser.appMetadata ?? {}) as Map<String, dynamic>;
    final Map<String, dynamic> userMd = (authUser.userMetadata ?? {}) as Map<String, dynamic>;
    return {...appMd, ...userMd};
  }

  (String, String) _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return ('', '');
    final local = email.split('@').first.replaceAll('.', ' ').trim();
    if (local.isEmpty) return ('', '');
    final parts = local.split(' ');
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(' '));
  }
}
