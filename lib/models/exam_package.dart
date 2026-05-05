/// Pacchetto di esami predefiniti
/// Esempio: "RM Colonna Completa" = RM Cervicale + RM Dorsale + RM Lombare
class ExamPackage {
  final String id;
  final String? organizationId;
  final String name;
  final String description;
  /// Lista di exam_type IDs inclusi nel pacchetto
  final List<String> examIds;
  /// Durata totale in minuti
  final int totalDurationMinutes;
  /// Se true, i tempi degli esami si sommano; se false, usano lo slot più lungo
  final bool isCumulative;
  /// Prezzo pacchetto (opzionale)
  final double? packagePrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamPackage({
    required this.id,
    this.organizationId,
    required this.name,
    this.description = '',
    required this.examIds,
    this.totalDurationMinutes = 30,
    this.isCumulative = true,
    this.packagePrice,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'exam_ids': examIds,
      'total_duration_minutes': totalDurationMinutes,
      'is_cumulative': isCumulative,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty) map['id'] = id;
    if (organizationId != null) map['organization_id'] = organizationId;
    if (packagePrice != null) map['package_price'] = packagePrice;
    return map;
  }

  factory ExamPackage.fromJson(Map<String, dynamic> json) {
    // Parse exam_ids array
    List<String> examIds = [];
    if (json['exam_ids'] != null) {
      if (json['exam_ids'] is List) {
        examIds = (json['exam_ids'] as List).map((e) => e.toString()).toList();
      } else if (json['exam_ids'] is String) {
        // PostgreSQL array format: {uuid1,uuid2}
        final str = json['exam_ids'] as String;
        if (str.startsWith('{') && str.endsWith('}')) {
          examIds = str.substring(1, str.length - 1).split(',').where((s) => s.isNotEmpty).toList();
        }
      }
    }

    return ExamPackage(
      id: (json['id'] ?? '') as String,
      organizationId: json['organization_id'] as String?,
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      examIds: examIds,
      totalDurationMinutes: (json['total_duration_minutes'] as int?) ?? 30,
      isCumulative: (json['is_cumulative'] as bool?) ?? true,
      packagePrice: json['package_price'] != null 
          ? double.tryParse(json['package_price'].toString()) 
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  ExamPackage copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    List<String>? examIds,
    int? totalDurationMinutes,
    bool? isCumulative,
    double? packagePrice,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExamPackage(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    name: name ?? this.name,
    description: description ?? this.description,
    examIds: examIds ?? this.examIds,
    totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
    isCumulative: isCumulative ?? this.isCumulative,
    packagePrice: packagePrice ?? this.packagePrice,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Esporta in formato JSON per import/export
  Map<String, dynamic> toExportJson() => {
    'name': name,
    'description': description,
    'exam_ids': examIds,
    'total_duration_minutes': totalDurationMinutes,
    'is_cumulative': isCumulative,
    'package_price': packagePrice,
  };
}
