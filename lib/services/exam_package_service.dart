import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/exam_compatibility.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/exam_service.dart';

/// Servizio per gestione pacchetti esami e regole di compatibilità
class ExamPackageService {
  final ExamService _examService = ExamService();

  // ==================== PACCHETTI ESAMI ====================

  /// Ottiene tutti i pacchetti per un'organizzazione
  Future<List<ExamPackage>> getPackagesForOrganization(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_packages')
          .select()
          .eq('organization_id', organizationId)
          .order('name');
      return (data as List).map((e) => ExamPackage.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExamPackageService] Errore caricamento pacchetti: $e');
      return [];
    }
  }

  /// Ottiene tutti i pacchetti attivi per un'organizzazione
  Future<List<ExamPackage>> getActivePackages(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_packages')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_active', true)
          .order('name');
      return (data as List).map((e) => ExamPackage.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExamPackageService] Errore caricamento pacchetti attivi: $e');
      return [];
    }
  }

  /// Ottiene un pacchetto per ID
  Future<ExamPackage?> getPackageById(String packageId) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_packages')
          .select()
          .eq('id', packageId)
          .maybeSingle();
      if (data == null) return null;
      return ExamPackage.fromJson(data);
    } catch (e) {
      debugPrint('[ExamPackageService] Errore caricamento pacchetto: $e');
      return null;
    }
  }

  /// Crea un nuovo pacchetto
  Future<ExamPackage?> createPackage(ExamPackage package) async {
    try {
      final json = package.toJson();
      json.remove('id');
      json['created_at'] = DateTime.now().toUtc().toIso8601String();
      json['updated_at'] = DateTime.now().toUtc().toIso8601String();
      
      final data = await SupabaseConfig.client
          .from('exam_packages')
          .insert(json)
          .select()
          .single();
      debugPrint('[ExamPackageService] ✅ Pacchetto creato: ${data['id']}');
      return ExamPackage.fromJson(data);
    } catch (e) {
      debugPrint('[ExamPackageService] ❌ Errore creazione pacchetto: $e');
      return null;
    }
  }

  /// Aggiorna un pacchetto esistente
  Future<ExamPackage?> updatePackage(ExamPackage package) async {
    try {
      final json = package.toJson();
      json['updated_at'] = DateTime.now().toUtc().toIso8601String();
      
      final data = await SupabaseConfig.client
          .from('exam_packages')
          .update(json)
          .eq('id', package.id)
          .select()
          .single();
      debugPrint('[ExamPackageService] ✅ Pacchetto aggiornato: ${package.id}');
      return ExamPackage.fromJson(data);
    } catch (e) {
      debugPrint('[ExamPackageService] ❌ Errore aggiornamento pacchetto: $e');
      return null;
    }
  }

  /// Ottiene tutti i pacchetti attivi (da tutte le organizzazioni)
  Future<List<ExamPackage>> getAllActivePackages() async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_packages')
          .select()
          .eq('is_active', true)
          .order('name');
      return (data as List).map((e) => ExamPackage.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExamPackageService] Errore caricamento tutti i pacchetti: $e');
      return [];
    }
  }

  /// Elimina un pacchetto
  Future<bool> deletePackage(String packageId) async {
    try {
      await SupabaseConfig.client
          .from('exam_packages')
          .delete()
          .eq('id', packageId);
      debugPrint('[ExamPackageService] ✅ Pacchetto eliminato: $packageId');
      return true;
    } catch (e) {
      debugPrint('[ExamPackageService] ❌ Errore eliminazione pacchetto: $e');
      return false;
    }
  }

  // ==================== COMPATIBILITÀ ESAMI ====================

  /// Ottiene tutte le regole di compatibilità per un'organizzazione
  Future<List<ExamCompatibility>> getCompatibilityRulesForOrganization(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_compatibility')
          .select()
          .eq('organization_id', organizationId)
          .order('created_at');
      return (data as List).map((e) => ExamCompatibility.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExamPackageService] Errore caricamento regole: $e');
      return [];
    }
  }

  /// Ottiene le regole attive per un'organizzazione
  Future<List<ExamCompatibility>> getActiveCompatibilityRules(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('exam_compatibility')
          .select()
          .eq('organization_id', organizationId)
          .eq('is_active', true);
      return (data as List).map((e) => ExamCompatibility.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ExamPackageService] Errore caricamento regole attive: $e');
      return [];
    }
  }

  /// Crea una nuova regola di compatibilità
  Future<ExamCompatibility?> createCompatibilityRule(ExamCompatibility rule) async {
    try {
      final json = rule.toJson();
      json.remove('id');
      json['created_at'] = DateTime.now().toUtc().toIso8601String();
      json['updated_at'] = DateTime.now().toUtc().toIso8601String();
      
      final data = await SupabaseConfig.client
          .from('exam_compatibility')
          .insert(json)
          .select()
          .single();
      debugPrint('[ExamPackageService] ✅ Regola creata: ${data['id']}');
      return ExamCompatibility.fromJson(data);
    } catch (e) {
      debugPrint('[ExamPackageService] ❌ Errore creazione regola: $e');
      return null;
    }
  }

  /// Aggiorna una regola esistente
  Future<ExamCompatibility?> updateCompatibilityRule(ExamCompatibility rule) async {
    try {
      final json = rule.toJson();
      json['updated_at'] = DateTime.now().toUtc().toIso8601String();
      
      final data = await SupabaseConfig.client
          .from('exam_compatibility')
          .update(json)
          .eq('id', rule.id)
          .select()
          .single();
      debugPrint('[ExamPackageService] ✅ Regola aggiornata: ${rule.id}');
      return ExamCompatibility.fromJson(data);
    } catch (e) {
      debugPrint('[ExamPackageService] ❌ Errore aggiornamento regola: $e');
      return null;
    }
  }

  /// Elimina una regola
  Future<bool> deleteCompatibilityRule(String ruleId) async {
    try {
      await SupabaseConfig.client
          .from('exam_compatibility')
          .delete()
          .eq('id', ruleId);
      debugPrint('[ExamPackageService] ✅ Regola eliminata: $ruleId');
      return true;
    } catch (e) {
      debugPrint('[ExamPackageService] ❌ Errore eliminazione regola: $e');
      return false;
    }
  }

  // ==================== CALCOLO DURATA ====================

  /// Calcola la durata totale per una lista di esami
  /// Considera le regole di compatibilità se disponibili
  Future<int> calculateTotalDuration({
    required List<String> examIds,
    required String organizationId,
    Map<String, int>? examDurations, // Map examId -> duration in minutes
  }) async {
    if (examIds.isEmpty) return 0;
    if (examIds.length == 1) {
      return examDurations?[examIds.first] ?? 30;
    }

    // Carica le regole di compatibilità
    final rules = await getActiveCompatibilityRules(organizationId);
    
    int totalDuration = 0;
    final processedExams = <String>{};
    
    for (final examId in examIds) {
      if (processedExams.contains(examId)) continue;
      
      final examDuration = examDurations?[examId] ?? 30;
      
      // Cerca se questo esame ha regole same_slot con altri esami nella lista
      bool foundSameSlot = false;
      for (final rule in rules) {
        if (rule.compatibilityType == CompatibilityType.sameSlot &&
            rule.involvesExam(examId)) {
          final otherExam = rule.getOtherExam(examId);
          if (otherExam != null && 
              examIds.contains(otherExam) && 
              !processedExams.contains(otherExam)) {
            // Esami same_slot: usa la durata maggiore
            final otherDuration = examDurations?[otherExam] ?? 30;
            totalDuration += examDuration > otherDuration ? examDuration : otherDuration;
            processedExams.add(examId);
            processedExams.add(otherExam);
            foundSameSlot = true;
            break;
          }
        }
      }
      
      if (!foundSameSlot) {
        // Esami sequential o different_room: somma le durate
        totalDuration += examDuration;
        processedExams.add(examId);
        
        // Aggiungi time_gap per different_room
        for (final rule in rules) {
          if (rule.compatibilityType == CompatibilityType.differentRoom &&
              rule.involvesExam(examId)) {
            final otherExam = rule.getOtherExam(examId);
            if (otherExam != null && examIds.contains(otherExam)) {
              totalDuration += rule.timeGapMinutes;
            }
          }
        }
      }
    }
    
    return totalDuration;
  }

  /// Verifica se due esami sono compatibili
  Future<bool> areExamsCompatible(
    String examId1, 
    String examId2, 
    String organizationId,
  ) async {
    final rules = await getActiveCompatibilityRules(organizationId);
    
    for (final rule in rules) {
      if ((rule.examId1 == examId1 && rule.examId2 == examId2) ||
          (rule.examId1 == examId2 && rule.examId2 == examId1)) {
        return true;
      }
    }
    
    // Se non c'è una regola esplicita, assumiamo compatibilità sequenziale di default
    return true;
  }

  /// Ottiene il tipo di compatibilità tra due esami
  Future<CompatibilityType?> getCompatibilityType(
    String examId1, 
    String examId2, 
    String organizationId,
  ) async {
    final rules = await getActiveCompatibilityRules(organizationId);
    
    for (final rule in rules) {
      if ((rule.examId1 == examId1 && rule.examId2 == examId2) ||
          (rule.examId1 == examId2 && rule.examId2 == examId1)) {
        return rule.compatibilityType;
      }
    }
    
    return null; // Nessuna regola definita
  }

  // ==================== IMPORT/EXPORT ====================

  /// Esporta tutti i pacchetti in formato JSON
  Future<String> exportPackagesToJson(String organizationId) async {
    final packages = await getPackagesForOrganization(organizationId);
    final exportData = packages.map((p) => p.toExportJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'exam_packages',
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'packages': exportData,
    });
  }

  /// Importa pacchetti da JSON
  Future<ImportResult> importPackagesFromJson(
    String jsonContent, 
    String organizationId,
  ) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      if (data['type'] != 'exam_packages') {
        return ImportResult(success: false, message: 'Formato file non valido');
      }
      
      final packages = data['packages'] as List<dynamic>? ?? [];
      int imported = 0;
      int failed = 0;
      final errors = <String>[];
      
      for (final pkgData in packages) {
        try {
          final package = ExamPackage(
            id: '',
            organizationId: organizationId,
            name: pkgData['name'] as String,
            description: (pkgData['description'] ?? '') as String,
            examIds: (pkgData['exam_ids'] as List<dynamic>).map((e) => e.toString()).toList(),
            totalDurationMinutes: (pkgData['total_duration_minutes'] as int?) ?? 30,
            isCumulative: (pkgData['is_cumulative'] as bool?) ?? true,
            packagePrice: pkgData['package_price'] != null 
                ? double.tryParse(pkgData['package_price'].toString()) 
                : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          final result = await createPackage(package);
          if (result != null) {
            imported++;
          } else {
            failed++;
            errors.add('Pacchetto "${package.name}": errore creazione');
          }
        } catch (e) {
          failed++;
          errors.add('Errore parsing: $e');
        }
      }
      
      return ImportResult(
        success: failed == 0,
        message: 'Importati $imported pacchetti' + (failed > 0 ? ', $failed falliti' : ''),
        importedCount: imported,
        failedCount: failed,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Errore parsing JSON: $e');
    }
  }

  /// Esporta regole di compatibilità in JSON
  Future<String> exportCompatibilityRulesToJson(String organizationId) async {
    final rules = await getCompatibilityRulesForOrganization(organizationId);
    final exportData = rules.map((r) => r.toExportJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'exam_compatibility',
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'rules': exportData,
    });
  }

  /// Importa regole di compatibilità da JSON
  Future<ImportResult> importCompatibilityRulesFromJson(
    String jsonContent, 
    String organizationId,
  ) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      if (data['type'] != 'exam_compatibility') {
        return ImportResult(success: false, message: 'Formato file non valido');
      }
      
      final rules = data['rules'] as List<dynamic>? ?? [];
      int imported = 0;
      int failed = 0;
      final errors = <String>[];
      
      for (final ruleData in rules) {
        try {
          final rule = ExamCompatibility(
            id: '',
            organizationId: organizationId,
            examId1: ruleData['exam_id_1'] as String,
            examId2: ruleData['exam_id_2'] as String,
            compatibilityType: CompatibilityType.fromDbValue(
              (ruleData['compatibility_type'] ?? 'sequential') as String
            ),
            timeGapMinutes: (ruleData['time_gap_minutes'] as int?) ?? 0,
            notes: ruleData['notes'] as String?,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          final result = await createCompatibilityRule(rule);
          if (result != null) {
            imported++;
          } else {
            failed++;
            errors.add('Regola ${rule.examId1}-${rule.examId2}: errore creazione');
          }
        } catch (e) {
          failed++;
          errors.add('Errore parsing: $e');
        }
      }
      
      return ImportResult(
        success: failed == 0,
        message: 'Importate $imported regole' + (failed > 0 ? ', $failed fallite' : ''),
        importedCount: imported,
        failedCount: failed,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Errore parsing JSON: $e');
    }
  }

  // ==================== HELPER ====================

  /// Ottiene i dettagli degli esami inclusi in un pacchetto
  Future<List<ExamType>> getExamsInPackage(ExamPackage package) async {
    final allExams = await _examService.getAllExams();
    return allExams.where((e) => package.examIds.contains(e.id)).toList();
  }
}

/// Risultato di un'operazione di import
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final int failedCount;
  final List<String> errors;

  ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.failedCount = 0,
    this.errors = const [],
  });
}
