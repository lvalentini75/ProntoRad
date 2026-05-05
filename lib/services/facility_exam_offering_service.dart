import 'package:flutter/foundation.dart';
import 'package:xraynow/models/facility_exam_offering.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

import 'package:xraynow/models/exam_type.dart' as models;

class FacilityExamOfferingService {
  /// Ottiene tutte le offerte per una facility
  Future<List<FacilityExamOffering>> getOfferingsByFacility(String facilityId) async {
    try {
      final data = await SupabaseConfig.client
          .from('facility_exam_offerings')
          .select()
          .eq('facility_id', facilityId);
      return (data as List).map((json) => FacilityExamOffering.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[FacilityExamOfferingService] Failed to load offerings: $e');
      return [];
    }
  }

  /// Carica tutti gli esami con le offerte esistenti per una facility (query ottimizzata)
  Future<Map<String, dynamic>> getExamsWithOfferings(String facilityId) async {
    try {
      // Query parallele per massima velocità
      final results = await Future.wait([
        SupabaseConfig.client.from('exam_types').select().order('name'),
        SupabaseConfig.client
            .from('facility_exam_offerings')
            .select()
            .eq('facility_id', facilityId),
      ]);

      final exams = (results[0] as List).map((json) => models.ExamType.fromJson(json)).toList();
      final offerings = (results[1] as List).map((json) => FacilityExamOffering.fromJson(json)).toList();
      
      // Mappa exam_type_id -> offering per lookup veloce
      final offeringMap = <String, FacilityExamOffering>{};
      for (final offering in offerings) {
        offeringMap[offering.examTypeId] = offering;
      }

      return {
        'exams': exams,
        'offerings': offeringMap,
      };
    } catch (e) {
      debugPrint('[FacilityExamOfferingService] ❌ Failed to load exams with offerings: $e');
      return {'exams': <models.ExamType>[], 'offerings': <String, FacilityExamOffering>{}};
    }
  }

  /// Ottiene le offerte con i dettagli degli esami
  Future<List<Map<String, dynamic>>> getOfferingsWithExamDetails(String facilityId) async {
    try {
      final data = await SupabaseConfig.client
          .from('facility_exam_offerings')
          .select('*, exam_types(*)')
          .eq('facility_id', facilityId);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('[FacilityExamOfferingService] Failed to load offerings with details: $e');
      return [];
    }
  }

  /// Crea una nuova offerta usando RPC (bypassa cache schema PostgREST)
  Future<FacilityExamOffering> createOffering(FacilityExamOffering offering) async {
    try {
      debugPrint('[FacilityExamOfferingService] 📤 Creazione offerta via RPC...');
      debugPrint('[FacilityExamOfferingService]    facility_id: ${offering.facilityId}');
      debugPrint('[FacilityExamOfferingService]    exam_type_id: ${offering.examTypeId}');
      debugPrint('[FacilityExamOfferingService]    user: ${SupabaseConfig.auth.currentUser?.email}');
      
      // Usa RPC per bypassare il bug della cache schema di PostgREST
      final result = await SupabaseConfig.client.rpc(
        'create_facility_exam_offering',
        params: {
          'p_facility_id': offering.facilityId,
          'p_exam_type_id': offering.examTypeId,
          'p_price': offering.price,
          'p_ssn_price': offering.ssnPrice,
        },
      );

      if (result == null) {
        throw Exception('RPC create_facility_exam_offering ha restituito null');
      }

      final created = FacilityExamOffering.fromJson(result as Map<String, dynamic>);
      
      // Audit log - non bloccare se fallisce
      try {
        await AuditLogService.log(
          action: 'create',
          table: 'facility_exam_offerings',
          recordId: created.id,
          changes: {'facility_id': offering.facilityId, 'exam_type_id': offering.examTypeId},
        );
      } catch (auditError) {
        debugPrint('[FacilityExamOfferingService] ⚠️ Audit log fallito (non critico): $auditError');
      }
      
      debugPrint('[FacilityExamOfferingService] ✅ Created offering via RPC: ${created.id}');
      return created;
    } catch (e, stack) {
      debugPrint('[FacilityExamOfferingService] ❌ Failed to create offering');
      debugPrint('[FacilityExamOfferingService] ❌ Error type: ${e.runtimeType}');
      debugPrint('[FacilityExamOfferingService] ❌ Error message: $e');
      debugPrint('[FacilityExamOfferingService] ❌ Stack trace: $stack');
      rethrow; // Propaga l'errore per mostrarlo all'utente
    }
  }

  /// Aggiorna un'offerta esistente
  Future<FacilityExamOffering?> updateOffering(FacilityExamOffering offering) async {
    try {
      final payload = {
        'price': offering.price,
        'ssn_price': offering.ssnPrice,
        // 'duration_minutes': offering.durationMinutes, // Temporaneo: disabilitato per cache schema
        'preparation_notes': offering.preparationNotes,
        'is_available': offering.isAvailable,
        'max_daily_bookings': offering.maxDailyBookings,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await SupabaseConfig.client
          .from('facility_exam_offerings')
          .update(payload)
          .eq('id', offering.id)
          .select()
          .single();

      final updated = FacilityExamOffering.fromJson(result);
      await AuditLogService.log(
        action: 'update',
        table: 'facility_exam_offerings',
        recordId: updated.id,
        changes: payload,
      );
      debugPrint('[FacilityExamOfferingService] ✅ Updated offering: ${updated.id}');
      return updated;
    } catch (e) {
      debugPrint('[FacilityExamOfferingService] ❌ Failed to update offering: $e');
      return null;
    }
  }

  /// Elimina un'offerta usando RPC (bypassa cache schema PostgREST)
  Future<void> deleteOffering(String offeringId) async {
    try {
      debugPrint('[FacilityExamOfferingService] 🗑️ Eliminazione offerta via RPC $offeringId...');
      
      // Usa RPC per bypassare il bug della cache schema di PostgREST
      await SupabaseConfig.client.rpc(
        'delete_facility_exam_offering',
        params: {'p_offering_id': offeringId},
      );

      // Audit log - non bloccare se fallisce
      try {
        await AuditLogService.log(
          action: 'delete',
          table: 'facility_exam_offerings',
          recordId: offeringId,
        );
      } catch (auditError) {
        debugPrint('[FacilityExamOfferingService] ⚠️ Audit log fallito (non critico): $auditError');
      }
      
      debugPrint('[FacilityExamOfferingService] ✅ Deleted offering via RPC: $offeringId');
    } catch (e, stack) {
      debugPrint('[FacilityExamOfferingService] ❌ Failed to delete offering: $e');
      debugPrint('[FacilityExamOfferingService] Stack trace: $stack');
      rethrow; // Propaga l'errore per mostrarlo all'utente
    }
  }

  /// Verifica se un esame è già offerto da una facility
  Future<FacilityExamOffering?> getOfferingByExam(String facilityId, String examTypeId) async {
    try {
      final data = await SupabaseConfig.client
          .from('facility_exam_offerings')
          .select()
          .eq('facility_id', facilityId)
          .eq('exam_type_id', examTypeId)
          .maybeSingle();

      return data != null ? FacilityExamOffering.fromJson(data) : null;
    } catch (e) {
      debugPrint('[FacilityExamOfferingService] Failed to check offering: $e');
      return null;
    }
  }

  /// Abilita o disabilita un'offerta (toggle is_available)
  Future<bool> toggleOfferingAvailability(String offeringId, bool isAvailable) async {
    try {
      await SupabaseConfig.client
          .from('facility_exam_offerings')
          .update({
            'is_available': isAvailable,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', offeringId);

      debugPrint('[FacilityExamOfferingService] ✅ Toggled offering $offeringId to $isAvailable');
      return true;
    } catch (e) {
      debugPrint('[FacilityExamOfferingService] ❌ Failed to toggle offering: $e');
      return false;
    }
  }
}
