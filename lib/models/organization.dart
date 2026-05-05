enum OrganizationType {
  hospital,
  institute;

  String get displayName {
    switch (this) {
      case OrganizationType.hospital:
        return 'Ospedale';
      case OrganizationType.institute:
        return 'Istituto';
    }
  }
}

class Organization {
  final String id;
  final String name;
  final OrganizationType orgType;
  final String address;
  final String city;
  final String province;
  final String region;
  final String? phone;
  final String? email;
  final String? website;
  final String? vatNumber;
  final String? logoUrl;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  Organization({
    required this.id,
    required this.name,
    required this.orgType,
    required this.address,
    required this.city,
    required this.province,
    required this.region,
    this.phone,
    this.email,
    this.website,
    this.vatNumber,
    this.logoUrl,
    this.notes,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress => '$address, $city, $province';

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'org_type': orgType.name,
      'address': address,
      'city': city,
      'province': province,
      'region': region,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    
    // Include optional fields if present
    if (phone != null) map['phone'] = phone;
    if (email != null) map['email'] = email;
    if (website != null) map['website'] = website;
    if (vatNumber != null) map['vat_number'] = vatNumber;
    if (logoUrl != null) map['logo_url'] = logoUrl;
    if (notes != null) map['notes'] = notes;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    
    return map;
  }

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    orgType: OrganizationType.values.firstWhere(
      (e) => e.name == (json['org_type'] as String? ?? 'hospital'),
      orElse: () => OrganizationType.hospital,
    ),
    address: json['address'] as String? ?? '',
    city: json['city'] as String? ?? '',
    province: json['province'] as String? ?? '',
    region: json['region'] as String? ?? '',
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    website: json['website'] as String?,
    vatNumber: json['vat_number'] as String?,
    logoUrl: json['logo_url'] as String?,
    notes: json['notes'] as String?,
    latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
    longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'] as String) 
        : DateTime.now(),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at'] as String) 
        : DateTime.now(),
  );

  Organization copyWith({
    String? id,
    String? name,
    OrganizationType? orgType,
    String? address,
    String? city,
    String? province,
    String? region,
    String? phone,
    String? email,
    String? website,
    String? vatNumber,
    String? logoUrl,
    String? notes,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Organization(
    id: id ?? this.id,
    name: name ?? this.name,
    orgType: orgType ?? this.orgType,
    address: address ?? this.address,
    city: city ?? this.city,
    province: province ?? this.province,
    region: region ?? this.region,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    website: website ?? this.website,
    vatNumber: vatNumber ?? this.vatNumber,
    logoUrl: logoUrl ?? this.logoUrl,
    notes: notes ?? this.notes,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
