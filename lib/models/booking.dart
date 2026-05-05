import 'package:xraynow/models/user.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/facility.dart';
import 'package:xraynow/models/organization.dart';

enum BookingStatus {
  requested,
  confirmed,
  rejected,
  cancelled,
  completed;

  String get displayName {
    switch (this) {
      case BookingStatus.requested:
        return 'In Attesa';
      case BookingStatus.confirmed:
        return 'Confermata';
      case BookingStatus.rejected:
        return 'Rifiutata';
      case BookingStatus.cancelled:
        return 'Annullata';
      case BookingStatus.completed:
        return 'Completata';
    }
  }

  String get colorHex {
    switch (this) {
      case BookingStatus.requested:
        return '#FFA000'; // amber
      case BookingStatus.confirmed:
        return '#4CAF50'; // green
      case BookingStatus.rejected:
        return '#F44336'; // red
      case BookingStatus.cancelled:
        return '#9E9E9E'; // grey
      case BookingStatus.completed:
        return '#2196F3'; // blue
    }
  }
}

enum UrgencyLevel {
  normal,
  urgent,
  veryUrgent;

  String get displayName {
    switch (this) {
      case UrgencyLevel.normal:
        return 'Normale';
      case UrgencyLevel.urgent:
        return 'Urgente';
      case UrgencyLevel.veryUrgent:
        return 'Molto Urgente';
    }
  }
}

class Booking {
  final String id;
  final String userId;
  final String examTypeId;
  final String? organizationId; // Primary reference - Organizzazione = Struttura
  final String? facilityId; // Legacy/optional - kept for backwards compatibility
  final DateTime bookingDate;
  final DateTime bookingTime;
  final BookingStatus status;
  final UrgencyLevel urgencyLevel;
  final double price;
  final bool needsTransport;
  final bool isHomeService;
  final String? notes;
  final String? slotId;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? operatorNotes;
  final String? rejectedReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  User? user;
  ExamType? examType;
  Facility? facility;
  Organization? organization;

  Booking({
    required this.id,
    required this.userId,
    required this.examTypeId,
    this.organizationId,
    this.facilityId,
    required this.bookingDate,
    required this.bookingTime,
    required this.status,
    required this.urgencyLevel,
    required this.price,
    this.needsTransport = false,
    this.isHomeService = false,
    this.notes,
    this.slotId,
    this.confirmedBy,
    this.confirmedAt,
    this.operatorNotes,
    this.rejectedReason,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.examType,
    this.facility,
    this.organization,
  });

  /// Returns the effective organization ID (from organizationId or from facility)
  String? get effectiveOrganizationId => organizationId ?? facility?.organizationId;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'exam_type_id': examTypeId,
      'booking_date': bookingDate.toIso8601String(),
      'booking_time': bookingTime.toIso8601String(),
      'status': status.name,
      'urgency_level': urgencyLevel.name,
      'price': price,
      'needs_transport': needsTransport,
      'is_home_service': isHomeService,
      'notes': notes,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'operator_notes': operatorNotes,
      'rejected_reason': rejectedReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    // Include organization_id (primary) - exclude if empty string
    if (organizationId != null && organizationId!.isNotEmpty) {
      map['organization_id'] = organizationId;
    }
    // Include facility_id only if provided (legacy support) - exclude if empty string
    if (facilityId != null && facilityId!.isNotEmpty) {
      map['facility_id'] = facilityId;
    }
    // Include slot_id only if not empty - exclude if empty string
    if (slotId != null && slotId!.isNotEmpty) {
      map['slot_id'] = slotId;
    }
    // Include confirmed_by only if not empty - exclude if empty string
    if (confirmedBy != null && confirmedBy!.isNotEmpty) {
      map['confirmed_by'] = confirmedBy;
    }
    return map;
  }

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    examTypeId: json['exam_type_id'] as String,
    organizationId: json['organization_id'] as String?,
    facilityId: json['facility_id'] as String?,
    bookingDate: DateTime.parse(json['booking_date'] as String),
    bookingTime: DateTime.parse(json['booking_time'] as String),
    status: BookingStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => BookingStatus.requested),
    urgencyLevel: UrgencyLevel.values.firstWhere((e) => e.name == json['urgency_level'], orElse: () => UrgencyLevel.normal),
    price: (json['price'] as num).toDouble(),
    needsTransport: json['needs_transport'] as bool? ?? false,
    isHomeService: json['is_home_service'] as bool? ?? false,
    notes: json['notes'] as String?,
    slotId: json['slot_id'] as String?,
    confirmedBy: json['confirmed_by'] as String?,
    confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at'] as String) : null,
    operatorNotes: json['operator_notes'] as String?,
    rejectedReason: json['rejected_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Booking copyWith({
    String? id,
    String? userId,
    String? examTypeId,
    String? organizationId,
    String? facilityId,
    DateTime? bookingDate,
    DateTime? bookingTime,
    BookingStatus? status,
    UrgencyLevel? urgencyLevel,
    double? price,
    bool? needsTransport,
    bool? isHomeService,
    String? notes,
    String? slotId,
    String? confirmedBy,
    DateTime? confirmedAt,
    String? operatorNotes,
    String? rejectedReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
    ExamType? examType,
    Facility? facility,
    Organization? organization,
  }) => Booking(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    examTypeId: examTypeId ?? this.examTypeId,
    organizationId: organizationId ?? this.organizationId,
    facilityId: facilityId ?? this.facilityId,
    bookingDate: bookingDate ?? this.bookingDate,
    bookingTime: bookingTime ?? this.bookingTime,
    status: status ?? this.status,
    urgencyLevel: urgencyLevel ?? this.urgencyLevel,
    price: price ?? this.price,
    needsTransport: needsTransport ?? this.needsTransport,
    isHomeService: isHomeService ?? this.isHomeService,
    notes: notes ?? this.notes,
    slotId: slotId ?? this.slotId,
    confirmedBy: confirmedBy ?? this.confirmedBy,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    operatorNotes: operatorNotes ?? this.operatorNotes,
    rejectedReason: rejectedReason ?? this.rejectedReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    user: user ?? this.user,
    examType: examType ?? this.examType,
    facility: facility ?? this.facility,
    organization: organization ?? this.organization,
  );
}
