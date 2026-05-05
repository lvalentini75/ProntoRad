/// Collegamento tra struttura ed esame con prezzo e durata specifici
class FacilityExamOffering {
  final String id;
  final String facilityId;
  final String examTypeId;
  final double price;
  final double ssnPrice;
  final int durationMinutes;
  final String? preparationNotes;
  final bool isAvailable;
  final int maxDailyBookings;
  final DateTime createdAt;
  final DateTime updatedAt;

  FacilityExamOffering({
    required this.id,
    required this.facilityId,
    required this.examTypeId,
    required this.price,
    this.ssnPrice = 0,
    this.durationMinutes = 30,
    this.preparationNotes,
    this.isAvailable = true,
    this.maxDailyBookings = 10,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'price': price,
      'ssn_price': ssnPrice,
      'duration_minutes': durationMinutes,
      'preparation_notes': preparationNotes,
      'is_available': isAvailable,
      'max_daily_bookings': maxDailyBookings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (facilityId.isNotEmpty) {
      map['facility_id'] = facilityId;
    }
    if (examTypeId.isNotEmpty) {
      map['exam_type_id'] = examTypeId;
    }
    
    return map;
  }

  factory FacilityExamOffering.fromJson(Map<String, dynamic> json) => FacilityExamOffering(
    id: json['id'] as String,
    facilityId: json['facility_id'] as String,
    examTypeId: json['exam_type_id'] as String,
    price: (json['price'] as num).toDouble(),
    ssnPrice: (json['ssn_price'] as num?)?.toDouble() ?? 0,
    durationMinutes: json['duration_minutes'] as int? ?? 30,
    preparationNotes: json['preparation_notes'] as String?,
    isAvailable: json['is_available'] as bool? ?? true,
    maxDailyBookings: json['max_daily_bookings'] as int? ?? 10,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  FacilityExamOffering copyWith({
    String? id,
    String? facilityId,
    String? examTypeId,
    double? price,
    double? ssnPrice,
    int? durationMinutes,
    String? preparationNotes,
    bool? isAvailable,
    int? maxDailyBookings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FacilityExamOffering(
    id: id ?? this.id,
    facilityId: facilityId ?? this.facilityId,
    examTypeId: examTypeId ?? this.examTypeId,
    price: price ?? this.price,
    ssnPrice: ssnPrice ?? this.ssnPrice,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    preparationNotes: preparationNotes ?? this.preparationNotes,
    isAvailable: isAvailable ?? this.isAvailable,
    maxDailyBookings: maxDailyBookings ?? this.maxDailyBookings,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
