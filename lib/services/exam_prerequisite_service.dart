import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xraynow/models/exam_prerequisite.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/exam_service.dart';

/// Risultato dell'import di prerequisiti
class PrerequisiteImportResult {
  final bool success;
  final int importedCount;
  final int skippedCount;
  final String message;

  PrerequisiteImportResult({
    required this.success,
    required this.importedCount,
    required this.skippedCount,
    required this.message,
  });
}

class ExamPrerequisiteService {
  final ExamService _examService = ExamService();

  /// Ottiene tutti i prerequisiti per un'organizzazione
  Future<List<ExamPrerequisite>> getPrerequisitesForOrganization(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_prerequisites')
          .select()
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);
      
      return (data as List)
          .map((json) => ExamPrerequisite.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('[ExamPrerequisiteService] Error loading prerequisites: $e');
      return [];
    }
  }

  /// Ottiene i prerequisiti per un esame specifico
  Future<List<ExamPrerequisite>> getPrerequisitesForExam(String examId, {String? organizationId}) async {
    try {
      var query = SupabaseConfig.client
          .from('exam_prerequisites')
          .select()
          .eq('exam_id', examId)
          .eq('is_active', true);
      
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      
      final data = await query;
      return (data as List)
          .map((json) => ExamPrerequisite.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('[ExamPrerequisiteService] Error loading prerequisites for exam: $e');
      return [];
    }
  }

  /// Crea un nuovo prerequisito
  Future<ExamPrerequisite?> createPrerequisite(ExamPrerequisite prerequisite) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_prerequisites')
          .insert(prerequisite.toJson())
          .select()
          .single();
      
      return ExamPrerequisite.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[ExamPrerequisiteService] Error creating prerequisite: $e');
      return null;
    }
  }

  /// Aggiorna un prerequisito
  Future<ExamPrerequisite?> updatePrerequisite(ExamPrerequisite prerequisite) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_prerequisites')
          .update(prerequisite.toJson())
          .eq('id', prerequisite.id)
          .select()
          .single();
      
      return ExamPrerequisite.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[ExamPrerequisiteService] Error updating prerequisite: $e');
      return null;
    }
  }

  /// Elimina un prerequisito
  Future<bool> deletePrerequisite(String id) async {
    try {
      await SupabaseConfig.client
          .from('exam_prerequisites')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[ExamPrerequisiteService] Error deleting prerequisite: $e');
      return false;
    }
  }

  /// Verifica se i prerequisiti sono soddisfatti per una prenotazione
  /// 
  /// [examId] - L'esame che l'utente vuole prenotare
  /// [bookingTime] - L'orario richiesto per la prenotazione
  /// [existingBookings] - Le prenotazioni già esistenti dell'utente per lo stesso giorno
  /// [organizationId] - L'organizzazione (opzionale)
  Future<PrerequisiteCheckResult> checkPrerequisites({
    required String examId,
    required DateTime bookingDate,
    required DateTime bookingTime,
    required List<Booking> existingBookings,
    String? organizationId,
  }) async {
    try {
      // Carica i prerequisiti per questo esame
      final prerequisites = await getPrerequisitesForExam(examId, organizationId: organizationId);
      
      if (prerequisites.isEmpty) {
        return PrerequisiteCheckResult.valid();
      }
      
      // Carica i nomi degli esami per i messaggi
      final examNames = <String, String>{};
      final allExams = await _examService.getAllExams();
      for (final exam in allExams) {
        examNames[exam.id] = exam.name;
      }
      
      final missingPrerequisites = <MissingPrerequisite>[];
      
      for (final prereq in prerequisites) {
        // Calcola l'orario in cui dovrebbe essere il prerequisito
        final requiredPrereqTime = bookingTime.subtract(Duration(minutes: prereq.timeGapMinutes));
        
        // Cerca tra le prenotazioni esistenti
        final hasPrerequisite = existingBookings.any((booking) {
          // Verifica che sia lo stesso giorno
          final sameDay = booking.bookingDate.year == bookingDate.year &&
                          booking.bookingDate.month == bookingDate.month &&
                          booking.bookingDate.day == bookingDate.day;
          
          if (!sameDay) return false;
          
          // Verifica che sia l'esame prerequisito
          if (booking.examTypeId != prereq.prerequisiteExamId) return false;
          
          // Verifica che sia prima dell'orario richiesto
          // Con una tolleranza di 5 minuti
          final bookingMinutes = booking.bookingTime.hour * 60 + booking.bookingTime.minute;
          final requiredMinutes = requiredPrereqTime.hour * 60 + requiredPrereqTime.minute;
          
          // Il prerequisito deve essere entro 5 minuti dall'orario richiesto
          final difference = (bookingMinutes - requiredMinutes).abs();
          return difference <= 5;
        });
        
        if (!hasPrerequisite) {
          missingPrerequisites.add(MissingPrerequisite(
            prerequisiteExamId: prereq.prerequisiteExamId,
            prerequisiteExamName: examNames[prereq.prerequisiteExamId] ?? 'Esame sconosciuto',
            requiredByExamId: prereq.examId,
            requiredByExamName: examNames[prereq.examId] ?? 'Esame sconosciuto',
            timeGapMinutes: prereq.timeGapMinutes,
            suggestedTime: requiredPrereqTime,
            isMandatory: prereq.isMandatory,
          ));
        }
      }
      
      if (missingPrerequisites.isEmpty) {
        return PrerequisiteCheckResult.valid();
      }
      
      // Filtra solo i prerequisiti obbligatori
      final mandatoryMissing = missingPrerequisites.where((p) => p.isMandatory).toList();
      
      if (mandatoryMissing.isEmpty) {
        // Solo prerequisiti consigliati mancanti - valido con warning
        return PrerequisiteCheckResult(
          isValid: true,
          missingPrerequisites: missingPrerequisites,
          errorMessage: 'Consigliato: ${missingPrerequisites.map((p) => p.prerequisiteExamName).join(", ")} prima di questo esame',
        );
      }
      
      // Prerequisiti obbligatori mancanti
      final errorMsg = StringBuffer('Per prenotare questo esame devi prima prenotare:\n');
      for (final missing in mandatoryMissing) {
        final suggestedTimeStr = missing.suggestedTime != null 
            ? '${missing.suggestedTime!.hour.toString().padLeft(2, '0')}:${missing.suggestedTime!.minute.toString().padLeft(2, '0')}'
            : '';
        errorMsg.writeln('• ${missing.prerequisiteExamName} alle $suggestedTimeStr');
      }
      
      return PrerequisiteCheckResult.invalid(
        missing: missingPrerequisites,
        message: errorMsg.toString(),
      );
    } catch (e) {
      debugPrint('[ExamPrerequisiteService] Error checking prerequisites: $e');
      // In caso di errore, permettiamo la prenotazione
      return PrerequisiteCheckResult.valid();
    }
  }

  /// Esporta i prerequisiti in JSON
  Future<String> exportPrerequisitesToJson(String organizationId) async {
    final prerequisites = await getPrerequisitesForOrganization(organizationId);
    final exportData = prerequisites.map((p) => p.toExportJson()).toList();
    return jsonEncode({'prerequisites': exportData});
  }

  /// Importa i prerequisiti da JSON
  Future<PrerequisiteImportResult> importPrerequisitesFromJson(String json, String organizationId) async {
    try {
      final data = jsonDecode(json);
      final List<dynamic> prerequisites = data['prerequisites'] ?? [];
      
      int imported = 0;
      int skipped = 0;
      
      for (final prereqJson in prerequisites) {
        try {
          final prerequisite = ExamPrerequisite(
            id: '',
            organizationId: organizationId,
            examId: prereqJson['exam_id'] ?? '',
            prerequisiteExamId: prereqJson['prerequisite_exam_id'] ?? '',
            timeGapMinutes: prereqJson['time_gap_minutes'] ?? 20,
            isMandatory: prereqJson['is_mandatory'] ?? true,
            notes: prereqJson['notes'],
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          final result = await createPrerequisite(prerequisite);
          if (result != null) {
            imported++;
          } else {
            skipped++;
          }
        } catch (e) {
          skipped++;
        }
      }
      
      return PrerequisiteImportResult(
        success: imported > 0,
        importedCount: imported,
        skippedCount: skipped,
        message: 'Importati $imported prerequisiti, $skipped saltati',
      );
    } catch (e) {
      return PrerequisiteImportResult(
        success: false,
        importedCount: 0,
        skippedCount: 0,
        message: 'Errore parsing JSON: $e',
      );
    }
  }
}
