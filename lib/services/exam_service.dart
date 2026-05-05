import 'package:flutter/foundation.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/audit_log_service.dart';
import 'package:xraynow/supabase/supabase_config.dart';

class ExamService {
  Future<List<ExamType>> getAllExams() async {
    try {
      final data = await SupabaseService.select('exam_types');
      return data.map((json) => ExamType.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load exams: $e');
      return [];
    }
  }

  Future<List<ExamType>> getExamsByCategory(ExamCategory category) async {
    try {
      final data = await SupabaseService.select(
        'exam_types',
        filters: {'category': category.name},
      );
      return data.map((json) => ExamType.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load exams by category: $e');
      return [];
    }
  }

  Future<List<ExamType>> getExamsByBodyDistrict(BodyDistrict district) async {
    try {
      final data = await SupabaseService.select(
        'exam_types',
        filters: {'body_district': district.name},
      );
      return data.map((json) => ExamType.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load exams by body district: $e');
      return [];
    }
  }

  Future<List<ExamType>> searchExams(String query) async {
    try {
      dynamic result = SupabaseConfig.client
          .from('exam_types')
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%');
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(await result);
      return data.map((json) => ExamType.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to search exams: $e');
      return [];
    }
  }

  Future<ExamType?> getExamById(String id) async {
    try {
      final data = await SupabaseService.selectSingle(
        'exam_types',
        filters: {'id': id},
      );
      return data != null ? ExamType.fromJson(data) : null;
    } catch (e) {
      debugPrint('Failed to get exam by id: $e');
      return null;
    }
  }

  Future<ExamType> createExam(ExamType exam) async {
    try {
      // Build minimal payload for insert to avoid issues with id/created_at provided by client
      final payload = <String, dynamic>{
        'name': exam.name,
        'category': exam.category.name,
        'body_district': exam.bodyDistrict.name,
        'description': exam.description,
        // Let DB defaults handle created_at/updated_at
      };
      debugPrint('[ExamService] createExam payload=$payload');
      final result = await SupabaseService.insert('exam_types', payload);
      
      if (result.isEmpty) {
        throw Exception('Insert failed: no data returned from database');
      }
      
      final created = ExamType.fromJson(result.first);
      await AuditLogService.log(action: 'create', table: 'exam_types', recordId: created.id, changes: created.toJson());
      return created;
    } catch (e) {
      debugPrint('[ExamService] Failed to create exam: $e');
      rethrow;
    }
  }

  Future<ExamType> updateExam(ExamType exam) async {
    try {
      // Exclude immutable fields from update (id, created_at). Keep updated_at to now
      final data = <String, dynamic>{
        'name': exam.name,
        'category': exam.category.name,
        'body_district': exam.bodyDistrict.name,
        'description': exam.description,
        'updated_at': DateTime.now().toIso8601String(),
      };
      debugPrint('[ExamService] updateExam id=${exam.id} data=$data');
      final result = await SupabaseService.update('exam_types', data, filters: {'id': exam.id});
      
      if (result.isEmpty) {
        throw Exception('Update failed: no data returned from database');
      }
      
      final updated = ExamType.fromJson(result.first);
      await AuditLogService.log(action: 'update', table: 'exam_types', recordId: updated.id, changes: updated.toJson());
      return updated;
    } catch (e) {
      debugPrint('[ExamService] Failed to update exam: $e');
      rethrow;
    }
  }

  Future<void> deleteExam(String examId) async {
    try {
      await SupabaseService.delete('exam_types', filters: {'id': examId});
      await AuditLogService.log(action: 'delete', table: 'exam_types', recordId: examId);
    } catch (e) {
      debugPrint('Failed to delete exam: $e');
      rethrow;
    }
  }
}
