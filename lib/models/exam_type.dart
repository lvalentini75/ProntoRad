enum ExamCategory {
  rm,
  tac,
  eco,
  rx;

  String get displayName {
    switch (this) {
      case ExamCategory.rm:
        return 'RM (Risonanza)';
      case ExamCategory.tac:
        return 'TAC (Tomografia)';
      case ExamCategory.eco:
        return 'ECO (Ecografia)';
      case ExamCategory.rx:
        return 'RX (Radiografia)';
    }
  }

  String get description {
    switch (this) {
      case ExamCategory.rm:
        return 'Risonanza Magnetica';
      case ExamCategory.tac:
        return 'Tomografia Assiale Computerizzata';
      case ExamCategory.eco:
        return 'Ecografia';
      case ExamCategory.rx:
        return 'Radiografia';
    }
  }
}

enum BodyDistrict {
  testa,
  torace,
  addome,
  estremita;

  String get displayName {
    switch (this) {
      case BodyDistrict.testa:
        return 'Testa';
      case BodyDistrict.torace:
        return 'Torace';
      case BodyDistrict.addome:
        return 'Addome';
      case BodyDistrict.estremita:
        return 'Estremità';
    }
  }
}

class ExamType {
  final String id;
  final String name;
  final ExamCategory category;
  final BodyDistrict bodyDistrict;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamType({
    required this.id,
    required this.name,
    required this.category,
    required this.bodyDistrict,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'category': category.name,
      'body_district': bodyDistrict.name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  factory ExamType.fromJson(Map<String, dynamic> json) => ExamType(
    id: json['id'] as String,
    name: json['name'] as String,
    category: ExamCategory.values.firstWhere((e) => e.name == json['category']),
    bodyDistrict: BodyDistrict.values.firstWhere((e) => e.name == json['body_district']),
    description: json['description'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  ExamType copyWith({
    String? id,
    String? name,
    ExamCategory? category,
    BodyDistrict? bodyDistrict,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExamType(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    bodyDistrict: bodyDistrict ?? this.bodyDistrict,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
