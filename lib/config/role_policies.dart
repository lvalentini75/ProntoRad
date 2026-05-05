/// Centralized email-to-role policy mapping.
///
/// Use this to force specific emails to have a specific role in the app
/// (super_admin | org_admin | end_user). This is applied during profile sync
/// and also accessible from the Role Management panel.
class RolePolicies {
  /// Static mapping. Populate with the emails you want to enforce.
  /// Example:
  /// {
  ///   'founder@company.com': 'super_admin',
  ///   'hospital.admin@example.com': 'org_admin',
  /// }
  static final Map<String, String> enforcedEmailRoles = {
    // Add your mappings here. Keep emails lowercase for consistency.
    'admin@prontorad.demo': 'super_admin',
    'ospedale@prontorad.demo': 'org_admin',
  };

  /// Returns normalized role for an email if present in the mapping; otherwise null.
  static String? roleForEmail(String? email) {
    if (email == null) return null;
    final key = email.trim().toLowerCase();
    final value = enforcedEmailRoles[key];
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (['super_admin', 'org_admin', 'end_user'].contains(normalized)) return normalized;
    return null;
  }
}
