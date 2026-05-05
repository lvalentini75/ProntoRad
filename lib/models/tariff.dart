class Tariff {
  final String id;
  final String examTypeId;
  final String organizationId;
  final double price;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tariff({
    required this.id,
    required this.examTypeId,
    required this.organizationId,
    required this.price,
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'price': price,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (examTypeId.isNotEmpty) {
      map['exam_type_id'] = examTypeId;
    }
    if (organizationId.isNotEmpty) {
      map['organization_id'] = organizationId;
    }
    
    return map;
  }

  /// Schema-tolerant factory: works even if some columns are missing/null
  /// (e.g., currency, created_at, updated_at) on the tariffs table.
  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
        id: (json['id'] as String?) ?? '',
        examTypeId: (json['exam_type_id'] as String?) ?? '',
        organizationId: (json['organization_id'] as String?) ?? '',
        price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0,
        currency: (json['currency'] as String?) ?? 'EUR',
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );

  Tariff copyWith({
    String? id,
    String? examTypeId,
    String? organizationId,
    double? price,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Tariff(
        id: id ?? this.id,
        examTypeId: examTypeId ?? this.examTypeId,
        organizationId: organizationId ?? this.organizationId,
        price: price ?? this.price,
        currency: currency ?? this.currency,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

DateTime _parseDateTime(dynamic value) {
  try {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
  } catch (_) {}
  return DateTime.now();
}
