enum FacilityType {
  private,
  public;

  String get displayName {
    switch (this) {
      case FacilityType.private:
        return 'Privato';
      case FacilityType.public:
        return 'Convenzionato SSN';
    }
  }
}

class Facility {
  final String id;
  final String? organizationId;
  final String? parentFacilityId;
  final String name;
  final String address;
  final String city;
  final String province;
  final String region;
  final double latitude;
  final double longitude;
  final FacilityType type;
  final List<String> availableExamIds;
  final double basePrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  Facility({
    required this.id,
    this.organizationId,
    this.parentFacilityId,
    required this.name,
    required this.address,
    required this.city,
    required this.province,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.availableExamIds,
    required this.basePrice,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress => '$address, $city, $province';
  bool get isBranch => parentFacilityId != null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'province': province,
      'region': region,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'available_exam_ids': availableExamIds,
      'base_price': basePrice,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (organizationId != null && organizationId!.isNotEmpty) {
      map['organization_id'] = organizationId;
    }
    if (parentFacilityId != null && parentFacilityId!.isNotEmpty) {
      map['parent_facility_id'] = parentFacilityId;
    }
    
    return map;
  }

  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
    id: (json['id'] ?? '') as String,
    organizationId: json['organization_id'] as String?,
    parentFacilityId: json['parent_facility_id'] as String?,
    name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : 'Ospedale',
    address: (json['address'] as String?) ?? '',
    city: (json['city'] as String?) ?? '',
    province: (json['province'] as String?) ?? '',
    region: (json['region'] as String?) ?? '',
    latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : 45.0,
    longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : 9.0,
    type: () {
      final t = (json['type'] as String?) ?? 'public';
      return FacilityType.values.firstWhere(
        (e) => e.name == t,
        orElse: () => FacilityType.public,
      );
    }(),
    availableExamIds: () {
      final v = json['available_exam_ids'];
      if (v is List) {
        return List<String>.from(v);
      }
      return <String>[];
    }(),
    basePrice: json['base_price'] != null ? (json['base_price'] as num).toDouble() : 0.0,
    createdAt: () {
      final v = json['created_at'];
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) {}
      }
      return DateTime.now();
    }(),
    updatedAt: () {
      final v = json['updated_at'];
      if (v is String && v.isNotEmpty) {
        try { return DateTime.parse(v); } catch (_) {}
      }
      return DateTime.now();
    }(),
  );

  Facility copyWith({
    String? id,
    String? organizationId,
    String? parentFacilityId,
    String? name,
    String? address,
    String? city,
    String? province,
    String? region,
    double? latitude,
    double? longitude,
    FacilityType? type,
    List<String>? availableExamIds,
    double? basePrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Facility(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    parentFacilityId: parentFacilityId ?? this.parentFacilityId,
    name: name ?? this.name,
    address: address ?? this.address,
    city: city ?? this.city,
    province: province ?? this.province,
    region: region ?? this.region,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    type: type ?? this.type,
    availableExamIds: availableExamIds ?? this.availableExamIds,
    basePrice: basePrice ?? this.basePrice,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
