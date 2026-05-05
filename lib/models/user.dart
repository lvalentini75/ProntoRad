class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional link to Supabase auth.users.id for authenticated accounts
  final String? authUserId;

  /// Role for RBAC across dashboards: super_admin | org_admin | end_user
  final String? role;

  /// Organization that the user belongs to (for org_admin and staff)
  final String? organizationId;

  /// Codice fiscale (Italian tax code)
  final String? fiscalCode;

  /// Data di nascita (date of birth)
  final DateTime? dateOfBirth;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.authUserId,
    this.role,
    this.organizationId,
    this.fiscalCode,
    this.dateOfBirth,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (authUserId != null && authUserId!.isNotEmpty) {
      map['auth_user_id'] = authUserId;
    }
    if (organizationId != null && organizationId!.isNotEmpty) {
      map['organization_id'] = organizationId;
    }
    
    // Include other optional fields if present
    if (role != null) {
      map['role'] = role;
    }
    if (fiscalCode != null) {
      map['fiscal_code'] = fiscalCode;
    }
    if (dateOfBirth != null) {
      map['date_of_birth'] = dateOfBirth!.toIso8601String().split('T').first;
    }
    
    return map;
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        phoneNumber: (json['phone_number'] ?? '') as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        authUserId: json['auth_user_id'] as String?,
        role: json['role'] as String?,
        organizationId: json['organization_id'] as String?,
        fiscalCode: json['fiscal_code'] as String?,
        dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth'] as String) : null,
      );

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authUserId,
    String? role,
    String? organizationId,
    String? fiscalCode,
    DateTime? dateOfBirth,
  }) => User(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    authUserId: authUserId ?? this.authUserId,
    role: role ?? this.role,
    organizationId: organizationId ?? this.organizationId,
    fiscalCode: fiscalCode ?? this.fiscalCode,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
  );
}
