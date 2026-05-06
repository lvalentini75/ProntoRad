/// Modello per la relazione di prerequisito tra esami
/// Definisce che un esame richiede che un altro esame sia prenotato PRIMA
/// 
/// Esempio: "Ecografia Mammaria" richiede "Mammografia" come prerequisito
/// Se l'utente prenota l'ecografia alle 8:20, deve avere la mammografia 
/// prenotata alle 8:00 (20 minuti prima)
class ExamPrerequisite {
  final String id;
  final String? organizationId;
  
  /// ID dell'esame che richiede il prerequisito (es: Ecografia Mammaria)
  final String examId;
  
  /// ID dell'esame prerequisito (es: Mammografia)
  final String prerequisiteExamId;
  
  /// Minuti che il prerequisito deve essere PRIMA dell'esame principale
  /// Esempio: 20 = la mammografia deve essere 20 minuti prima dell'ecografia
  final int timeGapMinutes;
  
  /// Se true, il prerequisito è obbligatorio
  /// Se false, è consigliato ma non bloccante
  final bool isMandatory;
  
  /// Note descrittive
  final String? notes;
  
  /// Se attivo o meno
  final bool isActive;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamPrerequisite({
    required this.id,
    this.organizationId,
    required this.examId,
    required this.prerequisiteExamId,
    this.timeGapMinutes = 20,
    this.isMandatory = true,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'exam_id': examId,
      'prerequisite_exam_id': prerequisiteExamId,
      'time_gap_minutes': timeGapMinutes,
      'is_mandatory': isMandatory,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    if (organizationId != null) map['organization_id'] = organizationId;
    if (notes != null) map['notes'] = notes;
    return map;
  }

  factory ExamPrerequisite.fromJson(Map<String, dynamic> json) => ExamPrerequisite(
    id: (json['id'] ?? '') as String,
    organizationId: json['organization_id'] as String?,
    examId: (json['exam_id'] ?? '') as String,
    prerequisiteExamId: (json['prerequisite_exam_id'] ?? '') as String,
    timeGapMinutes: (json['time_gap_minutes'] as int?) ?? 20,
    isMandatory: (json['is_mandatory'] as bool?) ?? true,
    notes: json['notes'] as String?,
    isActive: (json['is_active'] as bool?) ?? true,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
  );

  ExamPrerequisite copyWith({
    String? id,
    String? organizationId,
    String? examId,
    String? prerequisiteExamId,
    int? timeGapMinutes,
    bool? isMandatory,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExamPrerequisite(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    examId: examId ?? this.examId,
    prerequisiteExamId: prerequisiteExamId ?? this.prerequisiteExamId,
    timeGapMinutes: timeGapMinutes ?? this.timeGapMinutes,
    isMandatory: isMandatory ?? this.isMandatory,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Esporta in formato JSON per import/export
  Map<String, dynamic> toExportJson() => {
    'exam_id': examId,
    'prerequisite_exam_id': prerequisiteExamId,
    'time_gap_minutes': timeGapMinutes,
    'is_mandatory': isMandatory,
    'notes': notes,
  };
}

/// Risultato della verifica dei prerequisiti per una prenotazione
class PrerequisiteCheckResult {
  /// Se tutti i prerequisiti sono soddisfatti
  final bool isValid;
  
  /// Lista di prerequisiti mancanti
  final List<MissingPrerequisite> missingPrerequisites;
  
  /// Messaggio di errore per l'utente
  final String? errorMessage;

  PrerequisiteCheckResult({
    required this.isValid,
    this.missingPrerequisites = const [],
    this.errorMessage,
  });
  
  factory PrerequisiteCheckResult.valid() => PrerequisiteCheckResult(isValid: true);
  
  factory PrerequisiteCheckResult.invalid({
    required List<MissingPrerequisite> missing,
    String? message,
  }) => PrerequisiteCheckResult(
    isValid: false,
    missingPrerequisites: missing,
    errorMessage: message,
  );
}

/// Informazioni su un prerequisito mancante
class MissingPrerequisite {
  /// L'esame prerequisito mancante
  final String prerequisiteExamId;
  final String prerequisiteExamName;
  
  /// L'esame che lo richiede
  final String requiredByExamId;
  final String requiredByExamName;
  
  /// Quanti minuti prima deve essere prenotato
  final int timeGapMinutes;
  
  /// Orario suggerito per il prerequisito
  final DateTime? suggestedTime;
  
  /// Se è obbligatorio o solo consigliato
  final bool isMandatory;

  MissingPrerequisite({
    required this.prerequisiteExamId,
    required this.prerequisiteExamName,
    required this.requiredByExamId,
    required this.requiredByExamName,
    required this.timeGapMinutes,
    this.suggestedTime,
    this.isMandatory = true,
  });
}
