import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xraynow/models/availability_slot.dart';
import 'package:xraynow/models/facility_exam_offering.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';
import 'package:xraynow/services/debug_log_service.dart';

class AvailabilityService {
  /// Ottiene le offerte esami per una struttura
  Future<List<FacilityExamOffering>> getOfferingsForFacility(String facilityId) async {
    try {
      final data = await SupabaseConfig.client
          .from('facility_exam_offerings')
          .select()
          .eq('facility_id', facilityId)
          .eq('is_active', true);
      return (data as List).map((e) => FacilityExamOffering.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading facility offerings: $e');
      return [];
    }
  }

  /// Crea più slot a partire da un intervallo [start] - [end].
  /// Se [autoSplit] è true, l'intervallo viene suddiviso in blocchi di [slotMinutes].
  /// Eventuali minuti residui non vengono inseriti (niente slot parziali).
  Future<List<AvailabilitySlot>> createSlotsFromRange({
    String? facilityId,
    required String organizationId,
    required String examId,
    required String staffUserId,
    required DateTime start,
    required DateTime end,
    bool autoSplit = false,
    int slotMinutes = 30,
  }) async {
    final created = <AvailabilitySlot>[];
    if (!end.isAfter(start)) {
      debugPrint('[AvailabilityService] createSlotsFromRange: end non successivo a start');
      return created;
    }

    if (!autoSplit) {
      final base = AvailabilitySlot(
        id: '',
        facilityId: facilityId,
        organizationId: organizationId,
        examId: examId,
        staffUserId: staffUserId,
        startTime: start,
        endTime: end,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final c = await createSlot(base);
      if (c != null) created.add(c);
      return created;
    }

    // Suddivisione per slotMinutes
    if (slotMinutes <= 0) slotMinutes = 30;
    var cursor = start;
    final step = Duration(minutes: slotMinutes);
    while (cursor.add(step).isBefore(end) || cursor.add(step).isAtSameMomentAs(end)) {
      final segStart = cursor;
      final segEnd = cursor.add(step);
      final seg = AvailabilitySlot(
        id: '',
        facilityId: facilityId,
        organizationId: organizationId,
        examId: examId,
        staffUserId: staffUserId,
        startTime: segStart,
        endTime: segEnd,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final c = await createSlot(seg);
      if (c != null) {
        created.add(c);
      } else {
        debugPrint('[AvailabilityService] ⚠️ Fallito inserimento split ${segStart.toIso8601String()} - ${segEnd.toIso8601String()}');
      }
      cursor = segEnd;
    }

    return created;
  }

  /// OTTIENI SLOT PER STRUTTURA (legacy) - mantenuto per compatibilità in alcune view
  Future<List<AvailabilitySlot>> getSlotsForFacilityAndExam({
    required String facilityId,
    required String examId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .select()
          .eq('facility_id', facilityId)
          .or('exam_id.eq.$examId,exam_type_id.eq.$examId')
          .eq('is_available', true)
          .gte('start_time', startDate.toUtc().toIso8601String())
          .lte('start_time', endDate.toUtc().toIso8601String())
          .order('start_time');
      return (data as List).map((e) => AvailabilitySlot.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading slots: $e');
      return [];
    }
  }

  /// Ottiene gli slot disponibili per un giorno specifico
  Future<List<AvailabilitySlot>> getSlotsForDate({
    required String facilityId,
    required String examId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getSlotsForFacilityAndExam(
      facilityId: facilityId,
      examId: examId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Crea un nuovo slot di disponibilità
  Future<AvailabilitySlot?> createSlot(AvailabilitySlot slot) async {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║         CREAZIONE SLOT DI DISPONIBILITÀ              ║');
    debugPrint('╚══════════════════════════════════════════════════════╝');
    
    // Validazione: l'orario fine deve essere dopo l'inizio
    if (!slot.endTime.isAfter(slot.startTime)) {
      debugPrint('⛔ ERRORE VALIDAZIONE: Orario fine non è dopo inizio');
      return null;
    }

    debugPrint('📋 INPUT RICEVUTO:');
    debugPrint('  • examId: ${slot.examId}');
    debugPrint('  • organizationId: ${slot.organizationId}');
    debugPrint('  • staffUserId: ${slot.staffUserId}');
    debugPrint('  • startTime: ${slot.startTime}');
    debugPrint('  • endTime: ${slot.endTime}');

    // Formati data/orario comuni
    String two(int v) => v.toString().padLeft(2, '0');
    final dateYYYYMMDD = '${slot.startTime.year.toString().padLeft(4, '0')}-${two(slot.startTime.month)}-${two(slot.startTime.day)}';
    final startHHMMSS = '${two(slot.startTime.hour)}:${two(slot.startTime.minute)}:00';
    final endHHMMSS = '${two(slot.endTime.hour)}:${two(slot.endTime.minute)}:00';

    // TENTATIVO 1: Schema con TIMESTAMPTZ (vecchio schema) + specific_date per compatibilità
    final timestampPayload = <String, dynamic>{
      'organization_id': slot.organizationId,
      if (slot.examId != null) 'exam_type_id': slot.examId,
      if (slot.examCategory != null) 'exam_category': slot.examCategory,
      'start_time': slot.startTime.toUtc().toIso8601String(),
      'end_time': slot.endTime.toUtc().toIso8601String(),
      'specific_date': dateYYYYMMDD, // Incluso per compatibilità con query
      'is_active': true,
    };
    // ⚠️ NON includere staff_user_id: può causare FK violation se l'utente non esiste in users
    // La FK è NULLABLE, quindi è sicuro omettere questo campo
    if (slot.facilityId != null && slot.facilityId!.isNotEmpty) {
      timestampPayload['facility_id'] = slot.facilityId;
    }

    debugPrint('');
    debugPrint('🔵 TENTATIVO 1: Schema TIMESTAMPTZ');
    debugPrint('📦 Payload: $timestampPayload');

    try {
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .insert(timestampPayload)
          .select()
          .single();
      debugPrint('✅ SUCCESSO con schema TIMESTAMPTZ! ID: ${data['id']}');
      final slot = AvailabilitySlot.fromJson(data);
      try { await AuditLogService.log(action: 'create', table: 'availability_slots', recordId: slot.id, changes: timestampPayload); } catch (_) {}
      return slot;
    } on PostgrestException catch (e1) {
      debugPrint('❌ FALLITO schema TIMESTAMPTZ:');
      debugPrint('  • code: ${e1.code}');
      debugPrint('  • message: ${e1.message}');
      if (e1.details != null) debugPrint('  • details: ${e1.details}');
      if (e1.hint != null) debugPrint('  • hint: ${e1.hint}');
      
      // TENTATIVO 2: Schema con TIME + DATE separati (riusa formati calcolati sopra)
      final timeDatePayload = <String, dynamic>{
        'organization_id': slot.organizationId,
        if (slot.examId != null) 'exam_type_id': slot.examId,
        if (slot.examCategory != null) 'exam_category': slot.examCategory,
        'specific_date': dateYYYYMMDD,
        'start_time': startHHMMSS,
        'end_time': endHHMMSS,
        'is_active': true,
      };
      // ⚠️ NON includere staff_user_id per evitare FK violation
      if (slot.facilityId != null && slot.facilityId!.isNotEmpty) {
        timeDatePayload['facility_id'] = slot.facilityId;
      }
      
      debugPrint('');
      debugPrint('🔵 TENTATIVO 2: Schema TIME + DATE separati');
      debugPrint('📦 Payload: $timeDatePayload');
      
      try {
        final data = await SupabaseConfig.client
            .from('availability_slots')
            .insert(timeDatePayload)
            .select()
            .single();
        debugPrint('✅ SUCCESSO con schema TIME+DATE! ID: ${data['id']}');
        final slot = AvailabilitySlot.fromJson(data);
        try { await AuditLogService.log(action: 'create', table: 'availability_slots', recordId: slot.id, changes: timeDatePayload); } catch (_) {}
        return slot;
      } on PostgrestException catch (e2) {
        debugPrint('❌ FALLITO schema TIME+DATE:');
        debugPrint('  • code: ${e2.code}');
        debugPrint('  • message: ${e2.message}');
        if (e2.details != null) debugPrint('  • details: ${e2.details}');
        if (e2.hint != null) debugPrint('  • hint: ${e2.hint}');
        
        // TENTATIVO 3: Payload minimo (solo campi essenziali)
        final minimalPayload = <String, dynamic>{
          'organization_id': slot.organizationId,
          'exam_type_id': slot.examId,
          'start_time': slot.startTime.toUtc().toIso8601String(),
          'end_time': slot.endTime.toUtc().toIso8601String(),
        };
        
        debugPrint('');
        debugPrint('🔵 TENTATIVO 3: Payload MINIMO');
        debugPrint('📦 Payload: $minimalPayload');
        
        try {
          final data = await SupabaseConfig.client
              .from('availability_slots')
              .insert(minimalPayload)
              .select()
              .single();
          debugPrint('✅ SUCCESSO con payload minimo! ID: ${data['id']}');
          final slot = AvailabilitySlot.fromJson(data);
          try { await AuditLogService.log(action: 'create', table: 'availability_slots', recordId: slot.id, changes: minimalPayload); } catch (_) {}
          return slot;
        } on PostgrestException catch (e3) {
          debugPrint('');
          debugPrint('════════════════════════════════════════════════════════');
          debugPrint('❌ TUTTI I TENTATIVI FALLITI');
          debugPrint('════════════════════════════════════════════════════════');
          debugPrint('ERRORE FINALE:');
          debugPrint('  • code: ${e3.code}');
          debugPrint('  • message: ${e3.message}');
          if (e3.details != null) debugPrint('  • details: ${e3.details}');
          if (e3.hint != null) debugPrint('  • hint: ${e3.hint}');
          
          // Diagnosi dettagliata
          final msg = e3.message.toLowerCase();
          final code = e3.code ?? '';
          debugPrint('');
          debugPrint('🔍 DIAGNOSI:');
          if (msg.contains('null value') || msg.contains('not-null')) {
            debugPrint('💡 CAUSA: Un campo obbligatorio è NULL');
            debugPrint('💡 VERIFICA: Lo schema della tabella availability_slots');
          } else if (msg.contains('rls') || msg.contains('row-level security') || code == '42501') {
            debugPrint('💡 CAUSA: Row-Level Security sta bloccando l\'insert');
            debugPrint('💡 SOLUZIONE: Aggiungere policy RLS per availability_slots');
          } else if (msg.contains('foreign key') || msg.contains('fkey') || code == '23503') {
            debugPrint('💡 CAUSA: Foreign key constraint violato');
            debugPrint('💡 VERIFICA: exam_type_id, organization_id, staff_user_id esistono nelle tabelle referenziate?');
          } else if (msg.contains('column') && msg.contains('does not exist')) {
            debugPrint('💡 CAUSA: Una colonna nel payload non esiste nella tabella');
          } else if (code == '42P01') {
            debugPrint('💡 CAUSA: La tabella availability_slots non esiste');
          }
          
          return null;
        }
      }
    } catch (e) {
      debugPrint('❌ ERRORE GENERICO: $e');
      return null;
    }
  }

  /// Aggiorna uno slot esistente
  Future<AvailabilitySlot?> updateSlot(AvailabilitySlot slot) async {
    try {
      String two(int v) => v.toString().padLeft(2, '0');
      final dateYYYYMMDD = '${slot.startTime.year.toString().padLeft(4, '0')}-${two(slot.startTime.month)}-${two(slot.startTime.day)}';
      final startHHMMSS = '${two(slot.startTime.hour)}:${two(slot.startTime.minute)}:00';
      final endHHMMSS = '${two(slot.endTime.hour)}:${two(slot.endTime.minute)}:00';

      final json = <String, dynamic>{
        if (slot.examId != null) 'exam_type_id': slot.examId,
        if (slot.examCategory != null) 'exam_category': slot.examCategory,
        'specific_date': dateYYYYMMDD,
        'start_time': startHHMMSS,
        'end_time': endHHMMSS,
        'is_active': slot.isAvailable,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        // ⚠️ NON aggiornare staff_user_id per evitare FK violation
      };
      
      if (slot.organizationId.isNotEmpty) {
        json['organization_id'] = slot.organizationId;
      }
      if (slot.facilityId != null) {
        json['facility_id'] = slot.facilityId;
      }
      if (slot.maxBookings != null) json['max_bookings'] = slot.maxBookings;

      final data = await SupabaseConfig.client
          .from('availability_slots')
          .update(json)
          .eq('id', slot.id)
          .select()
          .single();
      final updated = AvailabilitySlot.fromJson(data);
      try { await AuditLogService.log(action: 'update', table: 'availability_slots', recordId: updated.id, changes: json); } catch (_) {}
      return updated;
    } on PostgrestException catch (e) {
      debugPrint('❌ Update slot failed (PostgrestException)');
      debugPrint('• message: ${e.message}');
      if (e.details != null) debugPrint('• details: ${e.details}');
      if (e.hint != null) debugPrint('• hint: ${e.hint}');
      if (e.code != null) debugPrint('• code: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('Error updating slot: $e');
      return null;
    }
  }

  /// Elimina uno slot
  Future<bool> deleteSlot(String slotId) async {
    try {
      await SupabaseConfig.client
          .from('availability_slots')
          .delete()
          .eq('id', slotId);
      try { await AuditLogService.log(action: 'delete', table: 'availability_slots', recordId: slotId); } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error deleting slot: $e');
      return false;
    }
  }

  /// Verifica sovrapposizioni (API legacy – non più usata)
  Future<bool> checkSlotOverlap({
    required String staffUserId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeSlotId,
  }) async => false;

  /// Ottiene tutti gli slot per una struttura (legacy)
  Future<List<AvailabilitySlot>> getAllSlotsForFacility(String facilityId) async {
    try {
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .select()
          .eq('facility_id', facilityId)
          .order('start_time');
      return (data as List).map((e) => AvailabilitySlot.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading all slots: $e');
      return [];
    }
  }

  /// Ottiene tutti gli slot per un Ospedale/Istituto (organization).
  /// Se [staffUserId] è fornito, include anche gli slot creati da quello staff
  /// come fallback, così gli slot restano visibili anche in presenza di RLS o
  /// cambi di organization non ancora propagati sul profilo utente.
  Future<List<AvailabilitySlot>> getAllSlotsForOrganization(
    String organizationId, {
    String? staffUserId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      DebugLogService().debug('AvailabilityService', 'Caricamento slot per organization: $organizationId (staffUserId=${staffUserId ?? '-'}, range=${startDate != null ? '${startDate.toIso8601String().split('T')[0]} - ${endDate?.toIso8601String().split('T')[0]}' : 'ALL'})');
      
      // Query con filtri per performance
      dynamic query = SupabaseConfig.client.from('availability_slots').select();
      
      if (staffUserId != null && staffUserId.isNotEmpty) {
        // Includi sia quelli dell'organizzazione sia quelli legati allo staff corrente
        query = query.or('organization_id.eq.$organizationId,staff_user_id.eq.$staffUserId');
      } else {
        query = query.eq('organization_id', organizationId);
      }
      
      // OTTIMIZZAZIONE: Filtra per range di date se specificato
      if (startDate != null) {
        final startStr = startDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
        query = query.gte('specific_date', startStr);
      }
      if (endDate != null) {
        final endStr = endDate.toIso8601String().split('T')[0];
        query = query.lte('specific_date', endStr);
      }
      
      // OTTIMIZZAZIONE: Limita i risultati per evitare sovraccarico
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }
      
      final data = await query;
      DebugLogService().info('AvailabilityService', '📥 Ricevuti ${(data as List).length} slot dal DB');
      if ((data as List).isNotEmpty) {
        final firstSlot = data[0] as Map<String, dynamic>;
        DebugLogService().debug('AvailabilityService', '🔍 Primo slot raw JSON: ${firstSlot.toString()}');
        DebugLogService().debug('AvailabilityService', '🔍 Chiavi disponibili: ${firstSlot.keys.toList()}');
        DebugLogService().debug('AvailabilityService', '🔍 Ha exam_category? ${firstSlot.containsKey('exam_category')} (valore: ${firstSlot['exam_category']})');
      }
      final slots = <AvailabilitySlot>[];
      for (final e in data) {
        try {
          final slot = AvailabilitySlot.fromJson(e as Map<String, dynamic>);
          slots.add(slot);
        } catch (parseErr) {
          DebugLogService().error('AvailabilityService', '⚠️ Errore parsing slot ${e['id']}', error: parseErr);
        }
      }
      // Ordina in Dart per gestire entrambi gli schemi
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
      DebugLogService().info('AvailabilityService', '✅ Parsed ${slots.length} slots');
      return slots;
    } catch (e) {
      DebugLogService().error('AvailabilityService', 'Error loading org slots', error: e);
      return [];
    }
  }

  /// Ottiene gli slot per uno specifico staff member
  Future<List<AvailabilitySlot>> getSlotsForStaff(String staffUserId) async {
    try {
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .select()
          .eq('staff_user_id', staffUserId)
          .order('start_time');
      return (data as List).map((e) => AvailabilitySlot.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading staff slots: $e');
      return [];
    }
  }

  /// Crea slot in blocco per una settimana.
  /// [daysOfWeek] usa il sistema DateTime.weekday: 1=Lun, 2=Mar, ..., 7=Dom
  Future<List<AvailabilitySlot>> createWeeklySlots({
    String? facilityId,
    required String organizationId,
    required String examId,
    required String staffUserId,
    required DateTime weekStart,
    required List<int> daysOfWeek,
    required String startTimeHHMM,
    required String endTimeHHMM,
    bool autoSplit = false,
    int slotMinutes = 30,
  }) async {
    final results = <AvailabilitySlot>[];
    debugPrint('[AvailabilityService] createWeeklySlots: weekStart=$weekStart, daysOfWeek=$daysOfWeek');
    
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = weekStart.add(Duration(days: dayOffset));
      final dow = date.weekday; // 1=Lun, 2=Mar, ..., 7=Dom
      
      debugPrint('[AvailabilityService] dayOffset=$dayOffset, date=$date, dow=$dow, cercato in $daysOfWeek');
      
      if (!daysOfWeek.contains(dow)) continue;
      
      // Salta date nel passato
      if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        debugPrint('[AvailabilityService] -> SKIP: data nel passato');
        continue;
      }
      
      final startParts = startTimeHHMM.split(':');
      final endParts = endTimeHHMM.split(':');
      final startTime = DateTime(date.year, date.month, date.day, int.parse(startParts[0]), int.parse(startParts[1]));
      final endTime = DateTime(date.year, date.month, date.day, int.parse(endParts[0]), int.parse(endParts[1]));
      
      debugPrint('[AvailabilityService] -> Creo slot: $startTime - $endTime');
      
      final createdList = await createSlotsFromRange(
        facilityId: facilityId,
        organizationId: organizationId,
        examId: examId,
        staffUserId: staffUserId,
        start: startTime,
        end: endTime,
        autoSplit: autoSplit,
        slotMinutes: slotMinutes,
      );
      debugPrint('[AvailabilityService] -> Creati ${createdList.length} slot');
      results.addAll(createdList);
    }
    
    debugPrint('[AvailabilityService] createWeeklySlots: totale ${results.length} slot');
    return results;
  }

  /// Inserimento batch di più slot in una singola transazione.
  /// Molto più veloce rispetto all'inserimento uno alla volta.
  Future<List<AvailabilitySlot>> createSlotsBatch(List<AvailabilitySlot> slots) async {
    if (slots.isEmpty) return [];
    
    final debugLog = DebugLogService();
    debugPrint('[AvailabilityService] Batch insert di ${slots.length} slot...');
    debugLog.info('AvailabilityService', '🚀 Batch insert: ${slots.length} slot');
    final stopwatch = Stopwatch()..start();
    
    try {
      // Prepara tutti i payload
      final payloads = <Map<String, dynamic>>[];
      for (final slot in slots) {
        if (!slot.endTime.isAfter(slot.startTime)) continue;
        
        String two(int v) => v.toString().padLeft(2, '0');
        final dateYYYYMMDD = '${slot.startTime.year.toString().padLeft(4, '0')}-${two(slot.startTime.month)}-${two(slot.startTime.day)}';
        
        final payload = <String, dynamic>{
          'organization_id': slot.organizationId,
          if (slot.examId != null) 'exam_type_id': slot.examId,
          if (slot.examCategory != null) 'exam_category': slot.examCategory,
          'start_time': slot.startTime.toUtc().toIso8601String(),
          'end_time': slot.endTime.toUtc().toIso8601String(),
          'specific_date': dateYYYYMMDD,
          'is_active': true,
        };
        // ⚠️ NON includere staff_user_id per evitare FK violation
        if (slot.facilityId != null && slot.facilityId!.isNotEmpty) {
          payload['facility_id'] = slot.facilityId;
        }
        payloads.add(payload);
      }
      
      if (payloads.isEmpty) {
        debugLog.warning('AvailabilityService', '⚠️ Nessun payload valido da inserire');
        return [];
      }
      
      // Log del primo payload per debug
      debugLog.debug('AvailabilityService', '📦 Primo payload: ${payloads.first}');
      
      // Inserimento batch singolo
      debugLog.info('AvailabilityService', '📤 Invio ${payloads.length} payloads a Supabase...');
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .insert(payloads)
          .select();
      
      stopwatch.stop();
      debugPrint('[AvailabilityService] ✅ Batch insert completato in ${stopwatch.elapsedMilliseconds}ms');
      
      final created = <AvailabilitySlot>[];
      for (final row in (data as List)) {
        try {
          created.add(AvailabilitySlot.fromJson(row as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[AvailabilityService] ⚠️ Errore parsing slot: $e');
        }
      }
      
      debugLog.info('AvailabilityService', '✅ Batch completato: ${created.length}/${payloads.length} creati in ${stopwatch.elapsedMilliseconds}ms');
      
      // Log audit per il batch
      try {
        await AuditLogService.log(
          action: 'batch_create',
          table: 'availability_slots',
          recordId: 'batch_${created.length}',
          changes: {'count': created.length, 'first_date': slots.first.startTime.toIso8601String()},
        );
      } catch (_) {}
      
      return created;
    } on PostgrestException catch (e, stackTrace) {
      final errorMsg = 'Batch insert fallito - Code: ${e.code}, Message: ${e.message}';
      debugLog.error('AvailabilityService', errorMsg, error: e.details ?? e.message, stackTrace: stackTrace);
      debugPrint('[AvailabilityService] ❌ $errorMsg');
      debugPrint('  • code: ${e.code}');
      if (e.details != null) debugPrint('  • details: ${e.details}');
      if (e.hint != null) debugPrint('  • hint: ${e.hint}');
      
      // Fallback: prova con schema TIME+DATE
      debugLog.info('AvailabilityService', '🔄 Tentativo fallback con schema TIME+DATE...');
      return _createSlotsBatchFallback(slots);
    } catch (e, stackTrace) {
      debugLog.error('AvailabilityService', 'Errore generico batch insert', error: e, stackTrace: stackTrace);
      debugPrint('[AvailabilityService] ❌ Errore generico batch: $e');
      return [];
    }
  }
  
  /// Fallback per batch insert con schema TIME+DATE separati
  Future<List<AvailabilitySlot>> _createSlotsBatchFallback(List<AvailabilitySlot> slots) async {
    final debugLog = DebugLogService();
    try {
      final payloads = <Map<String, dynamic>>[];
      for (final slot in slots) {
        if (!slot.endTime.isAfter(slot.startTime)) continue;
        
        String two(int v) => v.toString().padLeft(2, '0');
        final dateYYYYMMDD = '${slot.startTime.year.toString().padLeft(4, '0')}-${two(slot.startTime.month)}-${two(slot.startTime.day)}';
        final startHHMMSS = '${two(slot.startTime.hour)}:${two(slot.startTime.minute)}:00';
        final endHHMMSS = '${two(slot.endTime.hour)}:${two(slot.endTime.minute)}:00';
        
        final payload = <String, dynamic>{
          'organization_id': slot.organizationId,
          if (slot.examId != null) 'exam_type_id': slot.examId,
          if (slot.examCategory != null) 'exam_category': slot.examCategory,
          'specific_date': dateYYYYMMDD,
          'start_time': startHHMMSS,
          'end_time': endHHMMSS,
          'is_active': true,
        };
        // ⚠️ NON includere staff_user_id per evitare FK violation
        if (slot.facilityId != null && slot.facilityId!.isNotEmpty) {
          payload['facility_id'] = slot.facilityId;
        }
        payloads.add(payload);
      }
      
      if (payloads.isEmpty) {
        debugLog.warning('AvailabilityService', '⚠️ Fallback: nessun payload valido');
        return [];
      }
      
      debugLog.debug('AvailabilityService', '📦 Fallback primo payload: ${payloads.first}');
      
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .insert(payloads)
          .select();
      
      final created = <AvailabilitySlot>[];
      for (final row in (data as List)) {
        try {
          created.add(AvailabilitySlot.fromJson(row as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[AvailabilityService] ⚠️ Errore parsing slot fallback: $e');
        }
      }
      
      debugLog.info('AvailabilityService', '✅ Fallback completato: ${created.length}/${payloads.length} creati');
      return created;
    } on PostgrestException catch (e, stackTrace) {
      final errorMsg = 'Fallback fallito - Code: ${e.code}, Msg: ${e.message}';
      debugLog.error('AvailabilityService', errorMsg, error: e.details ?? e.message, stackTrace: stackTrace);
      debugPrint('[AvailabilityService] ❌ $errorMsg');
      return [];
    } catch (e, stackTrace) {
      debugLog.error('AvailabilityService', 'Fallback errore generico', error: e, stackTrace: stackTrace);
      debugPrint('[AvailabilityService] ❌ Fallback batch failed: $e');
      return [];
    }
  }

  /// Crea/aggiorna un'offerta esame
  Future<FacilityExamOffering?> upsertOffering(FacilityExamOffering offering) async {
    try {
      final json = offering.toJson();
      if (offering.id.isEmpty) {
        json.remove('id');
      }
      json['updated_at'] = DateTime.now().toUtc().toIso8601String();
      
      final data = await SupabaseConfig.client
          .from('facility_exam_offerings')
          .upsert(json, onConflict: 'facility_id,exam_id')
          .select()
          .single();
      final created = FacilityExamOffering.fromJson(data);
      try { await AuditLogService.log(action: 'update', table: 'facility_exam_offerings', recordId: created.id, changes: json); } catch (_) {}
      return created;
    } catch (e) {
      debugPrint('Error upserting offering: $e');
      return null;
    }
  }

  /// Ottiene uno slot specifico per ID
  Future<AvailabilitySlot?> getSlotById(String slotId) async {
    try {
      final data = await SupabaseConfig.client
          .from('availability_slots')
          .select()
          .eq('id', slotId)
          .maybeSingle();
      if (data == null) return null;
      return AvailabilitySlot.fromJson(data);
    } catch (e) {
      debugPrint('Error loading slot: $e');
      return null;
    }
  }
}
