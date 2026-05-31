import 'package:flutter/foundation.dart';

/// Slot di disponibilità per prenotazioni - rappresenta un blocco temporale specifico
class AvailabilitySlot {
  final String id;
  /// In questo progetto utilizziamo un unico Ospedale/Istituto. Usiamo organizationId
  /// come chiave principale per gli slot. facilityId resta opzionale per retrocompatibilità.
  final String? facilityId; // opzionale
  final String organizationId; // OBBLIGATORIO per il nostro flusso
  /// ID del tipo di esame (schema Supabase: exam_type_id). Nel codice lo trattiamo come examId per brevità.
  /// Può essere null se lo slot è definito solo per macrocategoria
  final String? examId;
  /// Macrocategoria dell'esame (RM, TAC, ECO, RX). Se valorizzato, lo slot è disponibile
  /// per qualsiasi esame appartenente a questa categoria
  final String? examCategory;
  /// Manteniamo il campo per retrocompatibilità UI ma non viene scritto a DB
  final String staffUserId;
  /// Momento di inizio/fine come DateTime combinando specific_date + start_time (TIME) dal DB
  final DateTime startTime;
  final DateTime endTime;
  /// Stato attivo (schema Supabase: is_active). Mappato da/verso isAvailable per la UI
  final bool isAvailable;
  /// Campi opzionali/di servizio per futuri usi (non scritti a DB nello schema attuale)
  final String? bookingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Metadati aderenti allo schema di Supabase (non obbligatori nella UI)
  final int? dayOfWeek; // 0..6 quando slot ricorrente (non usato per inserimenti correnti)
  final DateTime? specificDate; // quando slot su data specifica (usato per gli inserimenti correnti)
  final int? maxBookings; // default 1
  final bool? isActive; // alias DB di isAvailable
  final String? notes;
  final String? roomId; // Optional: associated room/machine

  AvailabilitySlot({
    required this.id,
    this.facilityId,
    required this.organizationId,
    this.examId,
    this.examCategory,
    required this.staffUserId,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    this.bookingId,
    required this.createdAt,
    required this.updatedAt,
    this.dayOfWeek,
    this.specificDate,
    this.maxBookings,
    this.isActive,
    this.notes,
    this.roomId,
  }) {
    // Warning se entrambi sono null, ma non blocchiamo (potrebbe essere uno slot legacy)
    if (examId == null && examCategory == null) {
      debugPrint('⚠️ AvailabilitySlot $id: né examId né examCategory valorizzati');
    }
  }

  /// Nome giorno della settimana dallo startTime
  String get dayName {
    const days = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab'];
    return days[startTime.weekday % 7];
  }

  /// Durata dello slot in minuti
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  /// Formatta l'orario di inizio come HH:mm
  String get startTimeFormatted {
    final h = startTime.hour.toString().padLeft(2, '0');
    final m = startTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formatta l'orario di fine come HH:mm
  String get endTimeFormatted {
    final h = endTime.hour.toString().padLeft(2, '0');
    final m = endTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Serializzazione verso lo schema reale di Supabase (TIME + specific_date, exam_type_id)
  Map<String, dynamic> toJson() {
    // Calcola i formati richiesti dal DB
    final date = DateTime(startTime.year, startTime.month, startTime.day);
    String two(int v) => v.toString().padLeft(2, '0');
    final startHHMMSS = '${two(startTime.hour)}:${two(startTime.minute)}:00';
    final endHHMMSS = '${two(endTime.hour)}:${two(endTime.minute)}:00';
    final dateYYYYMMDD = '${startTime.year.toString().padLeft(4, '0')}-${two(startTime.month)}-${two(startTime.day)}';

    final map = <String, dynamic>{
      'specific_date': (specificDate ?? date).toIso8601String().substring(0, 10), // YYYY-MM-DD
      'day_of_week': dayOfWeek, // di norma null per slot su data
      'start_time': startHHMMSS,
      'end_time': endHHMMSS,
      'is_active': isAvailable,
    };
    
    // Include UUID fields only if not empty to avoid PostgreSQL errors
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (facilityId != null && facilityId!.isNotEmpty) {
      map['facility_id'] = facilityId;
    }
    if (organizationId.isNotEmpty) {
      map['organization_id'] = organizationId;
    }
    if (examId != null && examId!.isNotEmpty) {
      map['exam_type_id'] = examId;
    }
    if (examCategory != null && examCategory!.isNotEmpty) {
      map['exam_category'] = examCategory;
    }
    if (maxBookings != null) {
      map['max_bookings'] = maxBookings;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }
    if (roomId != null && roomId!.isNotEmpty) {
      map['room_id'] = roomId;
    }
    
    return map;
  }

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    // Lo schema DB può usare:
    // 1. TIME + specific_date (nuovo schema 24h)
    // 2. TIMESTAMPTZ completo (vecchio schema)
    final String? timeStart = json['start_time'] as String?;
    final String? timeEnd = json['end_time'] as String?;
    final String? dateStr = json['specific_date'] as String?; // YYYY-MM-DD o null
    DateTime start;
    DateTime end;
    
    // Rileva se start_time è un TIMESTAMP completo (contiene 'T' o '-')
    final isTimestampFormat = timeStart != null && (timeStart.contains('T') || (timeStart.contains('-') && timeStart.length > 8));
    
    if (isTimestampFormat) {
      // Schema TIMESTAMPTZ: parse diretto
      start = _parseDateTime(timeStart);
      end = _parseDateTime(timeEnd);
    } else if (dateStr != null && timeStart != null && timeEnd != null) {
      // Schema TIME + specific_date: combina data + orari
      try {
        final parts = dateStr.split('-').map((e) => int.tryParse(e) ?? 1).toList();
        final y = parts[0], m = parts[1], d = parts[2];
        final sParts = timeStart.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        final eParts = timeEnd.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        start = DateTime(y, m, d, sParts[0], sParts[1]);
        end = DateTime(y, m, d, eParts[0], eParts[1]);
      } catch (_) {
        start = _parseDateTime(json['created_at']);
        end = start.add(const Duration(minutes: 30));
      }
    } else if (timeStart != null) {
      // Fallback: prova parse diretto
      start = _parseDateTime(timeStart);
      end = _parseDateTime(timeEnd);
    } else {
      start = _parseDateTime(json['created_at']);
      end = start.add(const Duration(minutes: 30));
    }

    return AvailabilitySlot(
      id: (json['id'] ?? '') as String,
      facilityId: json['facility_id'] as String?,
      organizationId: (json['organization_id'] ?? '') as String,
      examId: (json['exam_id'] ?? json['exam_type_id']) as String?,
      examCategory: json['exam_category'] as String?,
      staffUserId: (json['staff_user_id'] ?? '') as String,
      startTime: start,
      endTime: end,
      isAvailable: (json['is_available'] as bool?) ?? (json['is_active'] as bool? ?? true),
      bookingId: json['booking_id'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      dayOfWeek: json['day_of_week'] as int?,
      specificDate: dateStr != null ? DateTime.tryParse('${dateStr}T00:00:00') : null,
      maxBookings: json['max_bookings'] as int?,
      isActive: json['is_active'] as bool?,
      notes: json['notes'] as String?,
      roomId: json['room_id'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String && value.isNotEmpty) {
      try { return DateTime.parse(value).toLocal(); } catch (_) {}
    }
    return DateTime.now();
  }

  AvailabilitySlot copyWith({
    String? id,
    String? facilityId,
    String? organizationId,
    String? examId,
    String? examCategory,
    String? staffUserId,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAvailable,
    String? bookingId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? dayOfWeek,
    DateTime? specificDate,
    int? maxBookings,
    bool? isActive,
    String? notes,
    String? roomId,
  }) => AvailabilitySlot(
    id: id ?? this.id,
    facilityId: facilityId ?? this.facilityId,
    organizationId: organizationId ?? this.organizationId,
    examId: examId ?? this.examId,
    examCategory: examCategory ?? this.examCategory,
    staffUserId: staffUserId ?? this.staffUserId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    isAvailable: isAvailable ?? this.isAvailable,
    bookingId: bookingId ?? this.bookingId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    specificDate: specificDate ?? this.specificDate,
    maxBookings: maxBookings ?? this.maxBookings,
    isActive: isActive ?? this.isActive,
    notes: notes ?? this.notes,
    roomId: roomId ?? this.roomId,
  );
}
