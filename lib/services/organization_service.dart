import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:xraynow/models/organization.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

class OrganizationService {
  Future<List<Organization>> getAllOrganizations() async {
    try {
      final data = await SupabaseService.select('organizations');
      return data.map((json) => Organization.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load organizations: $e');
      return [];
    }
  }

  /// Cerca organizzazioni per località (regione, provincia, città)
  Future<List<Organization>> getOrganizationsByLocation({
    String? region, 
    String? province, 
    String? city,
  }) async {
    try {
      debugPrint('[OrgService] Searching: region=$region, province=$province, city=$city');
      dynamic query = SupabaseConfig.client.from('organizations').select();
      
      if (region != null && region.isNotEmpty) {
        query = query.ilike('region', '%$region%');
      }
      if (province != null && province.isNotEmpty) {
        query = query.ilike('province', '%$province%');
      }
      if (city != null && city.isNotEmpty) {
        query = query.ilike('city', '%$city%');
      }
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(await query);
      debugPrint('[OrgService] Found ${data.length} organizations');
      return data.map((json) => Organization.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load organizations by location: $e');
      return [];
    }
  }

  /// Cerca organizzazioni che offrono un determinato esame
  /// (basato sulla presenza di tariffari per quell'esame)
  Future<List<Organization>> getOrganizationsByExam(String examId) async {
    try {
      debugPrint('[OrgService] Searching organizations offering exam: $examId');
      
      // 1. Trova tutti gli organization_id che hanno tariffari per questo esame
      final tariffs = await SupabaseConfig.client
          .from('tariffs')
          .select('organization_id')
          .eq('exam_type_id', examId);
      
      final orgIds = (tariffs as List)
          .map((t) => t['organization_id'] as String)
          .toSet()
          .toList();
      
      if (orgIds.isEmpty) {
        debugPrint('[OrgService] No organizations offer this exam');
        return [];
      }
      
      // 2. Carica le organizzazioni corrispondenti
      final orgs = await SupabaseConfig.client
          .from('organizations')
          .select()
          .inFilter('id', orgIds);
      
      final result = (orgs as List).map((json) => Organization.fromJson(json)).toList();
      debugPrint('[OrgService] Found ${result.length} organizations offering exam $examId');
      return result;
    } catch (e) {
      debugPrint('Failed to load organizations by exam: $e');
      return [];
    }
  }

  /// Cerca organizzazioni per località E che offrono un determinato esame
  Future<List<Organization>> searchOrganizations({
    required String examId,
    String? region,
    String? province,
    String? city,
  }) async {
    try {
      debugPrint('[OrgService] 🔍 Searching: exam=$examId, region=$region, province=$province, city=$city');
      
      // 1. Trova organization_id che offrono l'esame
      final tariffs = await SupabaseConfig.client
          .from('tariffs')
          .select('organization_id, exam_type_id')
          .eq('exam_type_id', examId);
      
      debugPrint('[OrgService] 📋 Found ${(tariffs as List).length} tariffs for exam $examId');
      for (final t in tariffs) {
        debugPrint('   - org: ${t['organization_id']}');
      }
      
      final orgIds = (tariffs as List)
          .map((t) => t['organization_id'] as String)
          .toSet()
          .toList();
      
      if (orgIds.isEmpty) {
        debugPrint('[OrgService] ❌ No organizations offer exam $examId');
        return [];
      }
      
      debugPrint('[OrgService] 🏥 Unique organizations offering exam: ${orgIds.length}');
      
      // 2. Filtra per località
      dynamic query = SupabaseConfig.client
          .from('organizations')
          .select()
          .inFilter('id', orgIds);
      
      if (region != null && region.isNotEmpty) {
        query = query.ilike('region', '%$region%');
      }
      if (province != null && province.isNotEmpty) {
        query = query.ilike('province', '%$province%');
      }
      if (city != null && city.isNotEmpty) {
        query = query.ilike('city', '%$city%');
      }
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(await query);
      debugPrint('[OrgService] 🎯 After location filter: ${data.length} organizations');
      for (final org in data) {
        debugPrint('   - ${org['name']} (${org['city']}, ${org['province']}, ${org['region']})');
      }
      
      final result = data.map((json) => Organization.fromJson(json)).toList();
      debugPrint('[OrgService] ✅ Found ${result.length} matching organizations');
      return result;
    } catch (e) {
      debugPrint('[OrgService] ❌ Failed to search organizations: $e');
      return [];
    }
  }

  Future<Organization?> getOrganizationById(String id) async {
    try {
      final data = await SupabaseService.selectSingle(
        'organizations',
        filters: {'id': id},
      );
      return data != null ? Organization.fromJson(data) : null;
    } catch (e) {
      debugPrint('Failed to get organization by id: $e');
      return null;
    }
  }

  Future<Organization> createOrganization(Organization org) async {
    try {
      final result = await SupabaseService.insert('organizations', org.toJson());
      final created = Organization.fromJson(result.first);
      await AuditLogService.log(
        action: 'create', 
        table: 'organizations', 
        recordId: created.id, 
        changes: created.toJson(),
      );
      return created;
    } catch (e) {
      debugPrint('Failed to create organization: $e');
      rethrow;
    }
  }

  Future<Organization> updateOrganization(Organization org) async {
    try {
      final result = await SupabaseService.update(
        'organizations',
        org.toJson(),
        filters: {'id': org.id},
      );
      final updated = Organization.fromJson(result.first);
      await AuditLogService.log(
        action: 'update', 
        table: 'organizations', 
        recordId: updated.id, 
        changes: updated.toJson(),
      );
      return updated;
    } catch (e) {
      debugPrint('Failed to update organization: $e');
      rethrow;
    }
  }

  Future<void> deleteOrganization(String orgId) async {
    try {
      await SupabaseService.delete('organizations', filters: {'id': orgId});
      await AuditLogService.log(action: 'delete', table: 'organizations', recordId: orgId);
    } catch (e) {
      debugPrint('Failed to delete organization: $e');
      rethrow;
    }
  }

  /// Calcola la distanza in km tra due coordinate geografiche (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + 
              cos(lat1 * p) * cos(lat2 * p) * 
              (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
