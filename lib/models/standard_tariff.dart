/// Standard tariff for exam types (system-wide base pricing).
/// Each organization can override these with their own tariffs.
class StandardTariff {
  final String id;
  final String examTypeId;
  final double price;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  StandardTariff({
    required this.id,
    required this.examTypeId,
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
    
    return map;
  }

  factory StandardTariff.fromJson(Map<String, dynamic> json) => StandardTariff(
    id: (json['id'] as String?) ?? '',
    examTypeId: (json['exam_type_id'] as String?) ?? '',
    price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0,
    currency: (json['currency'] as String?) ?? 'EUR',
    createdAt: _parseDateTime(json['created_at']),
    updatedAt: _parseDateTime(json['updated_at']),
  );

  StandardTariff copyWith({
    String? id,
    String? examTypeId,
    double? price,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StandardTariff(
    id: id ?? this.id,
    examTypeId: examTypeId ?? this.examTypeId,
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
