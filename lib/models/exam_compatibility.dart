/// Tipo di compatibilità tra esami
enum CompatibilityType {
  /// Stesso slot, stessa sala (es: TAC addome + torace)
  sameSlot,
  /// Consecutivi, stessa sala (es: RM cervicale + dorsale)  
  sequential,
  /// Sale diverse, distanziati nel tempo (es: mammografia + eco mammaria)
  differentRoom;

  String get displayName {
    switch (this) {
      case CompatibilityType.sameSlot:
        return 'Stesso Slot';
      case CompatibilityType.sequential:
        return 'Sequenziale';
      case CompatibilityType.differentRoom:
        return 'Sale Diverse';
    }
  }

  String get description {
    switch (this) {
      case CompatibilityType.sameSlot:
        return 'Gli esami vengono eseguiti nello stesso slot temporale';
      case CompatibilityType.sequential:
        return 'Gli esami vengono eseguiti in sequenza nella stessa sala';
      case CompatibilityType.differentRoom:
        return 'Gli esami vengono eseguiti in sale diverse con intervallo';
    }
  }

  String get dbValue {
    switch (this) {
      case CompatibilityType.sameSlot:
        return 'same_slot';
      case CompatibilityType.sequential:
        return 'sequential';
      case CompatibilityType.differentRoom:
        return 'different_room';
    }
  }

  static CompatibilityType fromDbValue(String value) {
    switch (value) {
      case 'same_slot':
        return CompatibilityType.sameSlot;
      case 'sequential':
        return CompatibilityType.sequential;
      case 'different_room':
        return CompatibilityType.differentRoom;
      default:
        return CompatibilityType.sequential;
    }
  }
}

/// Regola di compatibilità tra due esami
/// Definisce come due esami possono essere combinati
class ExamCompatibility {
  final String id;
  final String? organizationId;
  /// ID del primo esame
  final String examId1;
  /// ID del secondo esame
  final String examId2;
  /// Tipo di compatibilità
  final CompatibilityType compatibilityType;
  /// Intervallo minimo tra gli esami in minuti (per different_room)
  final int timeGapMinutes;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamCompatibility({
    required this.id,
    this.organizationId,
    required this.examId1,
    required this.examId2,
    this.compatibilityType = CompatibilityType.sequential,
    this.timeGapMinutes = 0,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'exam_id_1': examId1,
      'exam_id_2': examId2,
      'compatibility_type': compatibilityType.dbValue,
      'time_gap_minutes': timeGapMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    if (organizationId != null) map['organization_id'] = organizationId;
    if (notes != null) map['notes'] = notes;
    return map;
  }

  factory ExamCompatibility.fromJson(Map<String, dynamic> json) => ExamCompatibility(
    id: (json['id'] ?? '') as String,
    organizationId: json['organization_id'] as String?,
    examId1: (json['exam_id_1'] ?? '') as String,
    examId2: (json['exam_id_2'] ?? '') as String,
    compatibilityType: CompatibilityType.fromDbValue(
      (json['compatibility_type'] ?? 'sequential') as String
    ),
    timeGapMinutes: (json['time_gap_minutes'] as int?) ?? 0,
    notes: json['notes'] as String?,
    isActive: (json['is_active'] as bool?) ?? true,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
  );

  ExamCompatibility copyWith({
    String? id,
    String? organizationId,
    String? examId1,
    String? examId2,
    CompatibilityType? compatibilityType,
    int? timeGapMinutes,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExamCompatibility(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    examId1: examId1 ?? this.examId1,
    examId2: examId2 ?? this.examId2,
    compatibilityType: compatibilityType ?? this.compatibilityType,
    timeGapMinutes: timeGapMinutes ?? this.timeGapMinutes,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Verifica se questa regola coinvolge un determinato esame
  bool involvesExam(String examId) => examId1 == examId || examId2 == examId;

  /// Ottiene l'altro esame dato uno dei due
  String? getOtherExam(String examId) {
    if (examId1 == examId) return examId2;
    if (examId2 == examId) return examId1;
    return null;
  }

  /// Esporta in formato JSON per import/export
  Map<String, dynamic> toExportJson() => {
    'exam_id_1': examId1,
    'exam_id_2': examId2,
    'compatibility_type': compatibilityType.dbValue,
    'time_gap_minutes': timeGapMinutes,
    'notes': notes,
  };
}
