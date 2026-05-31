/// Rappresenta una "sala" o macchinario fisico di un ospedale
/// (es. OCL_04_ANGIO_NEURO_01, OCL_05_US_01)
/// Le sale sono colonne nella vista calendario multi-sala.
class Room {
  final String id;
  final String organizationId;
  final String name;
  final String? code;
  final String? color; // hex es. "#3B82F6"
  final String? description;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Room({
    required this.id,
    required this.organizationId,
    required this.name,
    this.code,
    this.color,
    this.description,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'organization_id': organizationId,
      'name': name,
      'display_order': displayOrder,
      'is_active': isActive,
    };
    if (id.isNotEmpty) map['id'] = id;
    if (code != null) map['code'] = code;
    if (color != null) map['color'] = color;
    if (description != null) map['description'] = description;
    return map;
  }

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: (json['id'] ?? '') as String,
        organizationId: (json['organization_id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        code: json['code'] as String?,
        color: json['color'] as String?,
        description: json['description'] as String?,
        displayOrder: (json['display_order'] as int?) ?? 0,
        isActive: (json['is_active'] as bool?) ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );

  Room copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? code,
    String? color,
    String? description,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Room(
        id: id ?? this.id,
        organizationId: organizationId ?? this.organizationId,
        name: name ?? this.name,
        code: code ?? this.code,
        color: color ?? this.color,
        description: description ?? this.description,
        displayOrder: displayOrder ?? this.displayOrder,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
