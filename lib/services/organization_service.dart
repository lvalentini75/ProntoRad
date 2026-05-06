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

  /// Cerca organizzazioni per località E che offrono un determinato esame o pacchetto
  Future<List<Organization>> searchOrganizations({
    String? examId,
    String? packageId,
    String? country,
    String? region,
    String? province,
    String? city,
  }) async {
    try {
      debugPrint('[OrgService] 🔍 Searching: exam=$examId, package=$packageId, country=$country, region=$region, province=$province, city=$city');
      
      Set<String> orgIds = {};
      
      // 1a. Se c'è un examId, trova le organizzazioni che lo offrono
      if (examId != null) {
        // Cerca prima in tariffs
        final tariffs = await SupabaseConfig.client
            .from('tariffs')
            .select('organization_id, exam_type_id')
            .eq('exam_type_id', examId);
        
        debugPrint('[OrgService] 📋 Found ${(tariffs as List).length} tariffs for exam $examId');
        orgIds.addAll((tariffs as List).map((t) => t['organization_id'] as String));
        
        // Cerca anche in facility_exam_offerings
        try {
          // Prima ottieni i facility_id dalle offerte
          final offerings = await SupabaseConfig.client
              .from('facility_exam_offerings')
              .select('facility_id')
              .eq('exam_type_id', examId)
              .eq('is_active', true);
          
          final facilityIds = (offerings as List)
              .map((o) => o['facility_id'] as String)
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          
          debugPrint('[OrgService] 📋 Found ${facilityIds.length} facilities offering exam $examId');
          
          // Poi mappa facility_id -> organization_id
          if (facilityIds.isNotEmpty) {
            final facilities = await SupabaseConfig.client
                .from('facilities')
                .select('id, organization_id')
                .inFilter('id', facilityIds);
            
            for (final facility in (facilities as List)) {
              final orgId = facility['organization_id'];
              if (orgId != null && orgId is String && orgId.isNotEmpty) {
                orgIds.add(orgId);
                debugPrint('[OrgService] 🔗 Facility ${facility['id']} → Org $orgId');
              }
            }
          }
        } catch (offeringError) {
          debugPrint('[OrgService] ⚠️ Could not query facility_exam_offerings: $offeringError');
        }
      }
      
      // 1b. Se c'è un packageId, trova le organizzazioni che lo offrono
      if (packageId != null) {
        final packages = await SupabaseConfig.client
            .from('exam_packages')
            .select('organization_id')
            .eq('id', packageId)
            .eq('is_active', true);
        
        debugPrint('[OrgService] 📦 Found ${(packages as List).length} packages');
        orgIds.addAll((packages as List).map((p) => p['organization_id'] as String));
      }
      
      // 1c. Cerca anche organizzazioni con slot disponibili per questo esame o categoria
      if (examId != null) {
        try {
          // Cerca slot con examId corrispondente O con categoria corrispondente
          // Prima, ottieni la categoria dell'esame
          final examData = await SupabaseConfig.client
              .from('exam_types')
              .select('category')
              .eq('id', examId)
              .maybeSingle();
          
          final examCategory = (examData?['category'] as String?)?.toUpperCase();
          debugPrint('[OrgService] 📋 Exam category: $examCategory');
          
          // DEBUG: Prima vediamo TUTTI gli slot disponibili
          try {
            final allSlots = await SupabaseConfig.client
                .from('availability_slots')
                .select('id, organization_id, exam_type_id, exam_category, is_active, specific_date')
                .eq('is_active', true)
                .limit(20);
            
            debugPrint('[OrgService] 🔍 DEBUG - All active slots (first 20):');
            for (final slot in (allSlots as List)) {
              final orgId = slot['organization_id'] as String?;
              // Get org name
              String orgName = 'Unknown';
              if (orgId != null) {
                try {
                  final org = await SupabaseConfig.client
                      .from('organizations')
                      .select('name, country')
                      .eq('id', orgId)
                      .maybeSingle();
                  orgName = '${org?['name']} (${org?['country']})';
                } catch (_) {}
              }
              debugPrint('   📅 Slot: exam_type=${slot['exam_type_id']}, exam_cat=${slot['exam_category']}, date=${slot['specific_date']}, org=$orgName');
            }
          } catch (debugErr) {
            debugPrint('[OrgService] ⚠️ Debug query failed: $debugErr');
          }
          
          // Cerca slot per examId O categoria
          var slotsQuery = SupabaseConfig.client
              .from('availability_slots')
              .select('organization_id')
              .eq('is_active', true);
          
          if (examCategory != null) {
            // Slot che matchano per examId O per categoria
            slotsQuery = slotsQuery.or('exam_type_id.eq.$examId,exam_category.eq.$examCategory');
          } else {
            slotsQuery = slotsQuery.eq('exam_type_id', examId);
          }
          
          final slotsWithOrg = await slotsQuery;
          
          debugPrint('[OrgService] 📋 Slots matching exam/category: ${(slotsWithOrg as List).length}');
          
          final slotOrgIds = (slotsWithOrg as List)
              .map((s) => s['organization_id'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toSet();
          
          debugPrint('[OrgService] 📋 Found ${slotOrgIds.length} organizations with available slots');
          for (final oid in slotOrgIds) {
            debugPrint('   🏥 Org with slots: $oid');
          }
          orgIds.addAll(slotOrgIds);
        } catch (slotError) {
          debugPrint('[OrgService] ⚠️ Could not query availability_slots: $slotError');
        }
      }
      
      if (orgIds.isEmpty) {
        debugPrint('[OrgService] ❌ No organizations offer this exam/package');
        return [];
      }
      
      debugPrint('[OrgService] 🏥 Unique organizations (after all sources): ${orgIds.length}');
      
      // 2. Prima carichiamo TUTTE le org per vedere i valori di country
      final allOrgsDebug = await SupabaseConfig.client
          .from('organizations')
          .select('id, name, country, region, province, city')
          .inFilter('id', orgIds.toList());
      
      debugPrint('[OrgService] 🔍 DEBUG - Valori country nelle organizzazioni:');
      for (final org in (allOrgsDebug as List)) {
        debugPrint('   🏥 ${org['name']}: country="${org['country']}" region="${org['region']}"');
      }
      
      // 2. Filtra per località e paese
      dynamic query = SupabaseConfig.client
          .from('organizations')
          .select()
          .inFilter('id', orgIds.toList());
      
      // Filtro per paese (cruciale per separare Italia/Svizzera)
      if (country != null && country.isNotEmpty) {
        // Prova sia con match esatto che case-insensitive
        query = query.ilike('country', country);
        debugPrint('[OrgService] 🌍 Filtering by country (ilike): $country');
      }
      
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
