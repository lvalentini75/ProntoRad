import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/models/user.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/organization.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';
import 'package:xraynow/services/debug_log_service.dart';

class BookingService {
  final ExamService _examService = ExamService();
  final OrganizationService _organizationService = OrganizationService();
  final UserService _userService = UserService();
  
  /// Get all bookings with related data using optimized single query with JOINs
  /// Much faster than N+1 queries - loads everything in one database roundtrip
  Future<List<Booking>> getAllBookings() async {
    try {
      debugPrint('[BookingService] 🚀 Loading all bookings with optimized query...');
      final stopwatch = Stopwatch()..start();
      
      // Single query with JOINs - loads bookings + users + exam_types + organizations
      final data = await SupabaseConfig.client
          .from('bookings')
          .select('''
            *,
            users:user_id(*),
            exam_types:exam_type_id(*),
            organizations:organization_id(*)
          ''')
          .order('booking_date', ascending: false)
          .order('booking_time', ascending: false);
      
      final bookings = <Booking>[];
      for (final json in (data as List)) {
        try {
          debugPrint('[BookingService] 🔍 Raw booking JSON keys: ${json.keys.toList()}');
          debugPrint('[BookingService] 🔍 users data: ${json['users']}');
          
          final booking = Booking.fromJson(json);
          
          // Extract joined data
          if (json['users'] != null) {
            booking.user = User.fromJson(Map<String, dynamic>.from(json['users']));
            debugPrint('[BookingService] ✅ User parsed: ${booking.user?.firstName} ${booking.user?.lastName}');
          } else {
            debugPrint('[BookingService] ⚠️ No users data in JSON!');
          }
          if (json['exam_types'] != null) {
            booking.examType = ExamType.fromJson(Map<String, dynamic>.from(json['exam_types']));
          }
          if (json['organizations'] != null) {
            booking.organization = Organization.fromJson(Map<String, dynamic>.from(json['organizations']));
          }
          
          bookings.add(booking);
        } catch (e) {
          debugPrint('[BookingService] ⚠️ Failed to parse booking: $e');
        }
      }
      
      stopwatch.stop();
      debugPrint('[BookingService] ✅ Loaded ${bookings.length} bookings in ${stopwatch.elapsedMilliseconds}ms');
      return bookings;
    } catch (e) {
      debugPrint('[BookingService] ❌ Failed to load bookings: $e');
      return [];
    }
  }

  Future<List<Booking>> getUserBookings(String userId) async {
    try {
      // Optimized query with JOINs
      final data = await SupabaseConfig.client
          .from('bookings')
          .select('''
            *,
            users:user_id(*),
            exam_types:exam_type_id(*),
            organizations:organization_id(*)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final bookings = <Booking>[];
      for (final json in (data as List)) {
        try {
          final booking = Booking.fromJson(json);
          
          if (json['users'] != null) {
            booking.user = User.fromJson(Map<String, dynamic>.from(json['users']));
          }
          if (json['exam_types'] != null) {
            booking.examType = ExamType.fromJson(Map<String, dynamic>.from(json['exam_types']));
          }
          if (json['organizations'] != null) {
            booking.organization = Organization.fromJson(Map<String, dynamic>.from(json['organizations']));
          }
          
          bookings.add(booking);
        } catch (e) {
          debugPrint('[BookingService] Failed to parse user booking: $e');
        }
      }
      
      return bookings;
    } catch (e) {
      debugPrint('Failed to load user bookings: $e');
      return [];
    }
  }

  Future<Booking?> getBookingById(String id) async {
    try {
      // Try RPC function first (if available)
      try {
        final response = await SupabaseConfig.client
            .rpc('get_booking_with_user', params: {'p_booking_id': id});
        
        if (response != null) {
          // Parse the response as a Map
          Map<String, dynamic> bookingData;
          if (response is String) {
            bookingData = Map<String, dynamic>.from(jsonDecode(response));
          } else {
            bookingData = Map<String, dynamic>.from(response);
          }
          
          final booking = Booking.fromJson(bookingData);
          
          // Extract user from response
          if (bookingData['user'] != null) {
            try {
              booking.user = User.fromJson(Map<String, dynamic>.from(bookingData['user']));
              debugPrint('[BookingService] User loaded: ${booking.user?.fullName}');
            } catch (e) {
              debugPrint('[BookingService] Failed to parse user: $e');
            }
          }
          
          // Extract exam_type from response
          if (bookingData['exam_type'] != null) {
            try {
              booking.examType = ExamType.fromJson(Map<String, dynamic>.from(bookingData['exam_type']));
              debugPrint('[BookingService] ExamType loaded: ${booking.examType?.name}');
            } catch (e) {
              debugPrint('[BookingService] Failed to parse exam_type: $e');
            }
          }
          
          // Extract organization from response
          if (bookingData['organization'] != null) {
            try {
              booking.organization = Organization.fromJson(Map<String, dynamic>.from(bookingData['organization']));
              debugPrint('[BookingService] Organization loaded: ${booking.organization?.name}');
            } catch (e) {
              debugPrint('[BookingService] Failed to parse organization: $e');
            }
          }
          
          return booking;
        }
      } catch (rpcError) {
        debugPrint('[BookingService] RPC failed, using fallback: $rpcError');
      }
      
      // Fallback: Direct query with JOINs if RPC is not available
      debugPrint('[BookingService] Using direct query fallback for booking: $id');
      
      // Query booking with related data using Supabase's foreign key syntax
      final data = await SupabaseConfig.client
          .from('bookings')
          .select('''
            *,
            users:user_id(*),
            exam_types:exam_type_id(*),
            organizations:organization_id(*)
          ''')
          .eq('id', id)
          .maybeSingle();
      
      if (data == null) {
        debugPrint('[BookingService] Booking not found: $id');
        return null;
      }
      
      final booking = Booking.fromJson(data);
      
      // Extract related data from joined query
      if (data['users'] != null) {
        try {
          booking.user = User.fromJson(Map<String, dynamic>.from(data['users']));
          debugPrint('[BookingService] Fallback User loaded: ${booking.user?.fullName}');
        } catch (e) {
          debugPrint('[BookingService] Fallback failed to parse user: $e');
          // If join failed, try direct query
          booking.user = await _userService.getUserById(booking.userId);
        }
      } else {
        // No joined data, try direct query
        booking.user = await _userService.getUserById(booking.userId);
      }
      
      if (data['exam_types'] != null) {
        try {
          booking.examType = ExamType.fromJson(Map<String, dynamic>.from(data['exam_types']));
          debugPrint('[BookingService] Fallback ExamType loaded: ${booking.examType?.name}');
        } catch (e) {
          debugPrint('[BookingService] Fallback failed to parse exam_type: $e');
          booking.examType = await _examService.getExamById(booking.examTypeId);
        }
      } else {
        booking.examType = await _examService.getExamById(booking.examTypeId);
      }
      
      if (data['organizations'] != null) {
        try {
          booking.organization = Organization.fromJson(Map<String, dynamic>.from(data['organizations']));
          debugPrint('[BookingService] Fallback Organization loaded: ${booking.organization?.name}');
        } catch (e) {
          debugPrint('[BookingService] Fallback failed to parse organization: $e');
          if (booking.organizationId != null) {
            booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
          }
        }
      } else if (booking.organizationId != null) {
        booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
      }
      
      debugPrint('[BookingService] Booking loaded via fallback: ${booking.id}');
      debugPrint('[BookingService] Fallback result - User: ${booking.user?.fullName}, Exam: ${booking.examType?.name}, Org: ${booking.organization?.name}');
      return booking;
    } catch (e, stack) {
      debugPrint('[BookingService] Failed to get booking by id: $e');
      debugPrint('[BookingService] Stack trace: $stack');
      return null;
    }
  }

  Future<Booking> createBooking(Booking booking) async {
    try {
      final result = await SupabaseService.insert('bookings', booking.toJson());
      final newBooking = Booking.fromJson(result.first);
      
      newBooking.user = await _userService.getUserById(newBooking.userId);
      newBooking.examType = await _examService.getExamById(newBooking.examTypeId);
      // Load organization instead of facility
      if (newBooking.organizationId != null) {
        newBooking.organization = await _organizationService.getOrganizationById(newBooking.organizationId!);
      }
      
      try {
        await AuditLogService.log(action: 'create', table: 'bookings', recordId: newBooking.id, changes: newBooking.toJson());
      } catch (e) {
        debugPrint('Audit create booking failed: $e');
      }
      return newBooking;
    } catch (e) {
      debugPrint('Failed to create booking: $e');
      rethrow;
    }
  }

  /// Create booking with optimized strategy
  /// Uses organization_id directly - Organizzazione = Struttura
  /// Strategy: REST API first (fastest), then fallback to client insert
  Future<Booking> createBookingWithLock({
    required String userId,
    required String organizationId,
    required String examTypeId,
    required DateTime bookingDate,
    required DateTime bookingTime,
    String? slotId,
    required UrgencyLevel urgency,
    required double price,
    String? notes,
  }) async {
    // Validate UUID fields are not empty strings
    if (userId.isEmpty) {
      throw Exception('userId non può essere vuoto');
    }
    if (organizationId.isEmpty) {
      throw Exception('organizationId non può essere vuoto');
    }
    if (examTypeId.isEmpty) {
      throw Exception('examTypeId non può essere vuoto');
    }
    
    debugPrint('[BookingService] Validazione UUID: userId=$userId, orgId=$organizationId, examId=$examTypeId, slotId=$slotId');
    
    // ============ ATTEMPT 1: Direct REST API insert (fastest) ============
    try {
      debugPrint('[BookingService] Creating booking via REST API...');
      final booking = await _insertViaRestApi(userId, organizationId, examTypeId, bookingDate, bookingTime, slotId, urgency, price, notes);
      if (booking != null) {
        booking.user = await _userService.getUserById(booking.userId);
        booking.examType = await _examService.getExamById(booking.examTypeId);
        if (booking.organizationId != null) {
          booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
        }
        debugPrint('[BookingService] ✅ Booking created successfully: ${booking.id}');
        return booking;
      }
    } catch (restError) {
      debugPrint('[BookingService] REST API failed: $restError');
    }
    
    // ============ ATTEMPT 2: Direct Supabase client insert (fallback) ============
    try {
      debugPrint('[BookingService] 🔄 Fallback: trying Supabase client insert...');
      final now = DateTime.now();
      // Convert empty strings to null for UUID fields to avoid PostgreSQL errors
      final cleanSlotId = (slotId == null || slotId.isEmpty) ? null : slotId;
      final cleanNotes = (notes == null || notes.isEmpty) ? null : notes;
      
      debugPrint('[BookingService] 📋 Preparazione bookingData (fallback):');
      debugPrint('  - userId: $userId (length: ${userId.length})');
      debugPrint('  - organizationId: $organizationId (length: ${organizationId.length})');
      debugPrint('  - examTypeId: $examTypeId (length: ${examTypeId.length})');
      debugPrint('  - slotId: ${slotId ?? "NULL"} -> cleanSlotId: ${cleanSlotId ?? "NULL"}');
      
      final bookingData = <String, dynamic>{
        'user_id': userId,
        'organization_id': organizationId,
        'exam_type_id': examTypeId,
        'booking_date': bookingDate.toIso8601String().split('T').first,
        'booking_time': bookingTime.toIso8601String(),
        'urgency_level': urgency.name,
        'price': price,
        'status': 'requested',
        'needs_transport': false,
        'is_home_service': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      
      // Add optional fields only if they have valid values
      if (cleanSlotId != null) {
        bookingData['slot_id'] = cleanSlotId;
      }
      if (cleanNotes != null) {
        bookingData['notes'] = cleanNotes;
      }
      
      debugPrint('[BookingService] 📋 bookingData keys (fallback): ${bookingData.keys.join(", ")}');
      
      final result = await SupabaseService.insert('bookings', bookingData);
      debugPrint('[BookingService] ✅ Insert fallback riuscito!');
      
      final booking = Booking.fromJson(result.first);
      booking.user = await _userService.getUserById(booking.userId);
      booking.examType = await _examService.getExamById(booking.examTypeId);
      if (booking.organizationId != null) {
        booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
      }
      debugPrint('[BookingService] ✅ Booking created via client: ${booking.id}');
      
      // Mark slot as unavailable if provided
      if (cleanSlotId != null) {
        try {
          debugPrint('[BookingService] 🔒 Tentativo update slot (fallback): $cleanSlotId');
          await SupabaseService.update('availability_slots', 
            {'is_available': false, 'is_active': false, 'updated_at': now.toIso8601String()}, 
            filters: {'id': cleanSlotId});
          debugPrint('[BookingService] ✅ Slot marked as unavailable (fallback)');
        } catch (e) {
          debugPrint('[BookingService] ⚠️ Warning: Failed to mark slot as unavailable: $e');
        }
      }
      
      return booking;
    } catch (directError, stackTrace) {
      DebugLogService().critical(
        'BookingService',
        'Errore critico creazione prenotazione - UserId: $userId, OrgId: $organizationId, ExamId: $examTypeId, SlotId: $slotId',
        error: directError,
        stackTrace: stackTrace,
      );
      debugPrint('[BookingService] ❌ Booking creation failed: $directError');
      debugPrint('[BookingService] ❌ Stack trace: $stackTrace');
      throw Exception('Impossibile creare la prenotazione. Errore: $directError');
    }
  }
  
  
  /// Insert booking via REST API directly (fastest method)
  Future<Booking?> _insertViaRestApi(
    String userId,
    String organizationId,
    String examTypeId,
    DateTime bookingDate,
    DateTime bookingTime,
    String? slotId,
    UrgencyLevel urgency,
    double price,
    String? notes,
  ) async {
    final now = DateTime.now();
    // Convert empty strings to null for UUID fields to avoid PostgreSQL errors
    final cleanSlotId = (slotId == null || slotId.isEmpty) ? null : slotId;
    final cleanNotes = (notes == null || notes.isEmpty) ? null : notes;
    
    debugPrint('[BookingService] 📋 Preparazione bookingData:');
    debugPrint('  - userId: $userId (length: ${userId.length})');
    debugPrint('  - organizationId: $organizationId (length: ${organizationId.length})');
    debugPrint('  - examTypeId: $examTypeId (length: ${examTypeId.length})');
    debugPrint('  - slotId: ${slotId ?? "NULL"} -> cleanSlotId: ${cleanSlotId ?? "NULL"}');
    
    final bookingData = <String, dynamic>{
      'user_id': userId,
      'organization_id': organizationId,
      'exam_type_id': examTypeId,
      'booking_date': bookingDate.toIso8601String().split('T').first,
      'booking_time': bookingTime.toIso8601String(),
      'urgency_level': urgency.name,
      'price': price,
      'status': 'requested',
      'needs_transport': false,
      'is_home_service': false,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    
    // Add optional fields only if they have valid values
    if (cleanSlotId != null) {
      bookingData['slot_id'] = cleanSlotId;
    }
    if (cleanNotes != null) {
      bookingData['notes'] = cleanNotes;
    }
    
    debugPrint('[BookingService] 📋 bookingData keys: ${bookingData.keys.join(", ")}');
    
    final url = Uri.parse('${SupabaseConfig.supabaseUrl}/rest/v1/bookings');
    final userToken = await SupabaseConfig.tryGetAccessToken();
    
    final requestBody = jsonEncode(bookingData);
    debugPrint('[BookingService] 🌐 Invio richiesta REST API...');
    debugPrint('[BookingService] 📝 Body: $requestBody');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${userToken ?? SupabaseConfig.anonKey}',
        'apikey': SupabaseConfig.anonKey,
        'Prefer': 'return=representation',
      },
      body: requestBody,
    ).timeout(const Duration(seconds: 15));
    
    debugPrint('[BookingService] 📡 Risposta: ${response.statusCode}');
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      debugPrint('[BookingService] ✅ Insert riuscito!');
      final data = jsonDecode(response.body);
      Booking? booking;
      if (data is List && data.isNotEmpty) {
        booking = Booking.fromJson(Map<String, dynamic>.from(data.first));
      } else if (data is Map<String, dynamic>) {
        booking = Booking.fromJson(data);
      }
      
      // Mark slot as unavailable if provided
      if (booking != null && cleanSlotId != null) {
        try {
          debugPrint('[BookingService] 🔒 Tentativo update slot: $cleanSlotId');
          await SupabaseService.update('availability_slots', 
            {'is_available': false, 'is_active': false, 'updated_at': now.toIso8601String()}, 
            filters: {'id': cleanSlotId});
          debugPrint('[BookingService] ✅ Slot marked as unavailable');
        } catch (e) {
          debugPrint('[BookingService] ⚠️ Warning: Failed to mark slot unavailable: $e');
        }
      }
      
      return booking;
    } else {
      debugPrint('[BookingService] ❌ Errore REST API: ${response.statusCode}');
      debugPrint('[BookingService] ❌ Body: ${response.body}');
      throw Exception('REST API returned ${response.statusCode}: ${response.body}');
    }
  }
  

  Future<Booking> updateBooking(Booking booking) async {
    try {
      final result = await SupabaseService.update(
        'bookings',
        booking.toJson(),
        filters: {'id': booking.id},
      );
      
      final updatedBooking = Booking.fromJson(result.first);
      updatedBooking.user = await _userService.getUserById(updatedBooking.userId);
      updatedBooking.examType = await _examService.getExamById(updatedBooking.examTypeId);
      if (updatedBooking.organizationId != null) {
        updatedBooking.organization = await _organizationService.getOrganizationById(updatedBooking.organizationId!);
      }
      try { await AuditLogService.log(action: 'update', table: 'bookings', recordId: updatedBooking.id, changes: updatedBooking.toJson()); } catch (_) {}
      return updatedBooking;
    } catch (e) {
      debugPrint('Failed to update booking: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking != null) {
        final updatedBooking = booking.copyWith(
          status: BookingStatus.cancelled,
          updatedAt: DateTime.now(),
        );
        await updateBooking(updatedBooking);
      }
    } catch (e) {
      debugPrint('Failed to cancel booking: $e');
      rethrow;
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    try {
      await SupabaseService.delete('bookings', filters: {'id': bookingId});
      try { await AuditLogService.log(action: 'delete', table: 'bookings', recordId: bookingId); } catch (_) {}
    } catch (e) {
      debugPrint('Failed to delete booking: $e');
      rethrow;
    }
  }

  /// Ottiene le prenotazioni per una struttura/organizzazione specifica
  /// DEPRECATED: Use getBookingsForOrganization instead - Organizzazione = Struttura
  Future<List<Booking>> getBookingsForFacility(String facilityId, {BookingStatus? status}) async {
    // Redirect to organization-based query since Organizzazione = Struttura
    return getBookingsForOrganization(facilityId, status: status);
  }

  /// Ottiene le prenotazioni per un'organizzazione (tutte le sue strutture)
  Future<List<Booking>> getBookingsForOrganization(String organizationId, {BookingStatus? status}) async {
    try {
      debugPrint('[BookingService] ═══════════════════════════════════════════════════');
      debugPrint('[BookingService] 🔍 Querying bookings for organization: $organizationId');
      debugPrint('[BookingService] 🔍 Status filter: ${status?.name ?? "ALL"}');
      
      // Optimized query with JOINs - Organizzazione = Struttura
      var query = SupabaseConfig.client
          .from('bookings')
          .select('''
            *,
            users:user_id(*),
            exam_types:exam_type_id(*),
            organizations:organization_id(*)
          ''')
          .eq('organization_id', organizationId);
      
      if (status != null) {
        debugPrint('[BookingService] 📊 Filtering by status: ${status.name}');
        query = query.eq('status', status.name);
      }
      
      final data = await query
          .order('booking_date', ascending: true)
          .order('booking_time', ascending: true);
      
      debugPrint('[BookingService] 📦 Raw data received: ${(data as List).length} rows');
      
      final bookings = <Booking>[];
      for (final json in (data as List)) {
        try {
          debugPrint('[BookingService] 🔍 Org booking - Raw JSON keys: ${json.keys.toList()}');
          debugPrint('[BookingService] 🔍 Org booking - users data: ${json['users']}');
          
          final booking = Booking.fromJson(json);
          
          if (json['users'] != null) {
            booking.user = User.fromJson(Map<String, dynamic>.from(json['users']));
            debugPrint('[BookingService] ✅ User parsed: ${booking.user?.firstName} ${booking.user?.lastName}');
          } else {
            debugPrint('[BookingService] ⚠️ No users data in JSON for org booking!');
          }
          if (json['exam_types'] != null) {
            booking.examType = ExamType.fromJson(Map<String, dynamic>.from(json['exam_types']));
          }
          if (json['organizations'] != null) {
            booking.organization = Organization.fromJson(Map<String, dynamic>.from(json['organizations']));
          }
          
          bookings.add(booking);
        } catch (e) {
          debugPrint('[BookingService] ⚠️ Failed to parse org booking: $e');
        }
      }
      
      debugPrint('[BookingService] ✅ Successfully parsed ${bookings.length} bookings for org $organizationId');
      debugPrint('[BookingService] ═══════════════════════════════════════════════════');
      return bookings;
    } catch (e, stack) {
      debugPrint('[BookingService] ❌ Failed to load organization bookings: $e');
      debugPrint('[BookingService] Stack: $stack');
      return [];
    }
  }

  /// Conferma una prenotazione
  Future<Booking?> confirmBooking(String bookingId, String operatorId, {String? notes}) async {
    try {
      final now = DateTime.now().toUtc();
      final data = await SupabaseConfig.client
          .from('bookings')
          .update({
            'status': 'confirmed',
            'confirmed_by': operatorId,
            'confirmed_at': now.toIso8601String(),
            'operator_notes': notes,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', bookingId)
          .select()
          .single();
      
      final booking = Booking.fromJson(data);
      booking.user = await _userService.getUserById(booking.userId);
      booking.examType = await _examService.getExamById(booking.examTypeId);
      if (booking.organizationId != null) {
        booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
      }
      await AuditLogService.log(
        action: 'confirm',
        table: 'bookings',
        recordId: booking.id,
        changes: {
          'status': 'confirmed',
          'confirmed_by': operatorId,
          if (notes != null && notes.isNotEmpty) 'operator_notes': notes,
        },
      );
      return booking;
    } catch (e) {
      debugPrint('Failed to confirm booking: $e');
      return null;
    }
  }

  /// Rifiuta una prenotazione
  Future<Booking?> rejectBooking(String bookingId, String operatorId, String reason) async {
    try {
      final now = DateTime.now().toUtc();
      final data = await SupabaseConfig.client
          .from('bookings')
          .update({
            'status': 'rejected',
            'confirmed_by': operatorId,
            'confirmed_at': now.toIso8601String(),
            'rejected_reason': reason,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', bookingId)
          .select()
          .single();
      
      final booking = Booking.fromJson(data);
      booking.user = await _userService.getUserById(booking.userId);
      booking.examType = await _examService.getExamById(booking.examTypeId);
      if (booking.organizationId != null) {
        booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
      }
      await AuditLogService.log(
        action: 'reject',
        table: 'bookings',
        recordId: booking.id,
        changes: {
          'status': 'rejected',
          'rejected_reason': reason,
          'confirmed_by': operatorId,
        },
      );
      return booking;
    } catch (e) {
      debugPrint('Failed to reject booking: $e');
      return null;
    }
  }

  /// Conferma in blocco più prenotazioni
  Future<List<Booking>> confirmMany(List<String> bookingIds, String operatorId, {String? notes}) async {
    if (bookingIds.isEmpty) return [];
    try {
      final now = DateTime.now().toUtc();
      final data = await SupabaseConfig.client
          .from('bookings')
          .update({
            'status': 'confirmed',
            'confirmed_by': operatorId,
            'confirmed_at': now.toIso8601String(),
            'operator_notes': notes,
            'updated_at': now.toIso8601String(),
          })
          .inFilter('id', bookingIds)
          .select();

      final list = (data as List).map((e) => Booking.fromJson(Map<String, dynamic>.from(e))).toList();
      // hydrate and audit
      final result = <Booking>[];
      for (final b in list) {
        b.user = await _userService.getUserById(b.userId);
        b.examType = await _examService.getExamById(b.examTypeId);
        if (b.organizationId != null) {
          b.organization = await _organizationService.getOrganizationById(b.organizationId!);
        }
        result.add(b);
        try {
          await AuditLogService.log(
            action: 'confirm',
            table: 'bookings',
            recordId: b.id,
            changes: {
              'status': 'confirmed',
              'confirmed_by': operatorId,
              if (notes != null && notes.isNotEmpty) 'operator_notes': notes,
            },
          );
        } catch (e) {
          debugPrint('Audit bulk confirm failed for ${b.id}: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('Failed to confirm many bookings: $e');
      return [];
    }
  }

  /// Segna una prenotazione come completata
  Future<Booking?> completeBooking(String bookingId) async {
    try {
      final now = DateTime.now().toUtc();
      final data = await SupabaseConfig.client
          .from('bookings')
          .update({
            'status': 'completed',
            'updated_at': now.toIso8601String(),
          })
          .eq('id', bookingId)
          .select()
          .single();
      
      final booking = Booking.fromJson(data);
      booking.user = await _userService.getUserById(booking.userId);
      booking.examType = await _examService.getExamById(booking.examTypeId);
      if (booking.organizationId != null) {
        booking.organization = await _organizationService.getOrganizationById(booking.organizationId!);
      }
      return booking;
    } catch (e) {
      debugPrint('Failed to complete booking: $e');
      return null;
    }
  }

  /// Conta prenotazioni in attesa per organizzazione
  Future<int> countPendingBookings(String organizationId) async {
    try {
      // Query directly by organization_id - Organizzazione = Struttura
      final data = await SupabaseConfig.client
          .from('bookings')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('status', 'requested');
      return (data as List).length;
    } catch (e) {
      debugPrint('Failed to count pending bookings: $e');
      return 0;
    }
  }
}
