import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:xraynow/models/facility.dart';
import 'package:xraynow/models/facility_exam_offering.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

class FacilityService {
  /// Ensure there is a facility record that mirrors the organization itself.
  /// Many users think of "struttura" == "organizzazione" (ospedale/istituto),
  /// so we support that model by creating a facility with the SAME id as the organization.
  /// Returns the facility id (which will be the organization id).
  Future<String?> ensureFacilityMirrorOfOrganization(String organizationId, {String? organizationName}) async {
    try {
      debugPrint('[FacilityService] ensureFacilityMirrorOfOrganization org=$organizationId name=${organizationName ?? '(null)'}');
      // 1) If any facility exists for this org, return the first one
      final existing = await SupabaseConfig.client
          .from('facilities')
          .select('id')
          .eq('organization_id', organizationId)
          .limit(1);
      if ((existing as List).isNotEmpty) {
        final id = existing.first['id'] as String?;
        if (id != null && id.isNotEmpty) {
          debugPrint('[FacilityService] org already has facility: $id');
          return id;
        }
      }

      // 2) Upsert a facility using the organizationId as the facility id
      final resolvedName = (organizationName == null || organizationName.trim().isEmpty)
          ? 'Istituto/Ospedale'
          : organizationName.trim();

      final payload = <String, dynamic>{
        'id': organizationId, // mirror id
        'organization_id': organizationId,
        'name': resolvedName,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        final inserted = await SupabaseConfig.client
            .from('facilities')
            .upsert(payload)
            .select()
            .maybeSingle();
        final createdId = inserted?['id'] as String?;
        debugPrint('[FacilityService] created/ensured mirror facility id=$createdId');
        return createdId;
      } catch (e) {
        debugPrint('[FacilityService] upsert mirror facility failed, trying insert fallback. Error: $e');
        final inserted2 = await SupabaseConfig.client
            .from('facilities')
            .insert(payload)
            .select()
            .maybeSingle();
        final createdId2 = inserted2?['id'] as String?;
        debugPrint('[FacilityService] created mirror facility via insert id=$createdId2');
        return createdId2;
      }
    } catch (e) {
      debugPrint('ensureFacilityMirrorOfOrganization error: $e');
      return null;
    }
  }
  /// Ensure the main facility exists for an organization. If none is found
  /// it creates one using the organization name as facility name. Returns the
  /// main facility id.
  Future<String?> ensureMainFacilityForOrganization(String organizationId, {String? organizationName}) async {
    try {
      debugPrint('[FacilityService] ensureMainFacilityForOrganization org=$organizationId name=${organizationName ?? '(null)'}');
      // 1) Try to find any existing facility for this organization
      // Note: parent_facility_id may not exist. Select only known-safe columns.
      final rows = await SupabaseConfig.client
          .from('facilities')
          .select('id,name')
          .eq('organization_id', organizationId);

      // Return first facility if exists
      if ((rows as List).isNotEmpty) {
        final mainId = rows.first['id'] as String?;
        debugPrint('[FacilityService] facility already exists: $mainId');
        return mainId;
      }

      // 2) If no facility exists, prefer creating a mirror facility (id == organizationId)
      final mirror = await ensureFacilityMirrorOfOrganization(organizationId, organizationName: organizationName);
      if (mirror != null && mirror.isNotEmpty) return mirror;

      // 3) Create a default main facility filling required columns only.
      final resolvedName = (organizationName == null || organizationName.trim().isEmpty)
          ? 'Istituto/Ospedale'
          : organizationName.trim();

      // Provide safe defaults for NOT NULL columns
      final Map<String, dynamic> payload = {
        'organization_id': organizationId,
        'name': resolvedName,
        'address': '',
        'city': '',
        'province': '',
        'region': '',
        'latitude': 45.4642, // default Milano
        'longitude': 9.1900,
        'type': 'public',
        'available_exam_ids': <String>[],
        'base_price': 120.0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      debugPrint('[FacilityService] creating main facility with payload=${payload.toString()}');
      try {
        final inserted = await SupabaseConfig.client
            .from('facilities')
            .insert(payload)
            .select()
            .maybeSingle();
        final createdId = inserted?['id'] as String?;
        debugPrint('[FacilityService] created main facility id=$createdId');
        return createdId;
      } catch (e) {
        // Fallback for schemas that miss some optional columns: retry with a minimal payload
        debugPrint('[FacilityService] create main facility failed, retrying with minimal payload. Error: $e');
        final minimal = {
          'organization_id': organizationId,
          'name': resolvedName,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        final inserted2 = await SupabaseConfig.client
            .from('facilities')
            .insert(minimal)
            .select()
            .maybeSingle();
        final createdId2 = inserted2?['id'] as String?;
        debugPrint('[FacilityService] created main facility (minimal) id=$createdId2');
        return createdId2;
      }
    } catch (e) {
      debugPrint('ensureMainFacilityForOrganization error: $e');
      return null;
    }
  }
  Future<List<Facility>> getAllFacilities() async {
    try {
      final data = await SupabaseService.select('facilities');
      return data.map((json) => Facility.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load facilities: $e');
      return [];
    }
  }

  Future<List<Facility>> getFacilitiesByExam(String examId) async {
    try {
      dynamic result = SupabaseConfig.client
          .from('facilities')
          .select()
          .contains('available_exam_ids', [examId]);
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(await result);
      return data.map((json) => Facility.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load facilities by exam: $e');
      return [];
    }
  }

  Future<List<Facility>> getFacilitiesByLocation({String? region, String? province, String? city}) async {
    try {
      debugPrint('Loading facilities for region=$region, province=$province, city=$city');
      dynamic query = SupabaseConfig.client.from('facilities').select();
      
      if (region != null && region.isNotEmpty) {
        query = query.ilike('region', '%$region%');
      }
      if (province != null && province.isNotEmpty) {
        // Province in DB can be full name or abbreviation - use ilike for flexibility
        query = query.ilike('province', '%$province%');
      }
      if (city != null && city.isNotEmpty) {
        // Use ILIKE with wildcards to allow matching entries like "Milano" vs "Milano Centro"
        query = query.ilike('city', '%$city%');
      }
      
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(await query);
      debugPrint('Found ${data.length} facilities');
      return data.map((json) => Facility.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to load facilities by location: $e');
      return [];
    }
  }

  Future<List<Facility>> getFacilitiesSortedByDistance(double userLat, double userLon, List<Facility> facilities) async {
    final facilitiesWithDistance = facilities.map((f) {
      final distance = _calculateDistance(userLat, userLon, f.latitude, f.longitude);
      return {'facility': f, 'distance': distance};
    }).toList();
    
    facilitiesWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    return facilitiesWithDistance.map((item) => item['facility'] as Facility).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<Facility?> getFacilityById(String? id) async {
    // Return null if id is null or empty
    if (id == null || id.isEmpty) return null;
    try {
      final data = await SupabaseService.selectSingle(
        'facilities',
        filters: {'id': id},
      );
      return data != null ? Facility.fromJson(data) : null;
    } catch (e) {
      debugPrint('Failed to get facility by id: $e');
      return null;
    }
  }

  /// Returns facility IDs that belong to an organization
  Future<List<String>> getFacilityIdsByOrganization(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('facilities')
          .select('id')
          .eq('organization_id', organizationId);
      return (data as List).map((e) => e['id'] as String).toList();
    } catch (e) {
      debugPrint('Failed to load facility ids for organization: $e');
      return [];
    }
  }

  /// Returns all facilities that belong to an organization
  Future<List<Facility>> getFacilitiesByOrganization(String organizationId) async {
    try {
      final data = await SupabaseConfig.client
          .from('facilities')
          .select()
          .eq('organization_id', organizationId);
      return (data as List).map((e) => Facility.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Failed to load facilities for organization: $e');
      return [];
    }
  }

  Future<Facility> createFacility(Facility facility) async {
    try {
      final result = await SupabaseService.insert('facilities', facility.toJson());
      final created = Facility.fromJson(result.first);
      await AuditLogService.log(action: 'create', table: 'facilities', recordId: created.id, changes: created.toJson());
      return created;
    } catch (e) {
      debugPrint('Failed to create facility: $e');
      rethrow;
    }
  }

  Future<Facility> updateFacility(Facility facility) async {
    try {
      final result = await SupabaseService.update(
        'facilities',
        facility.toJson(),
        filters: {'id': facility.id},
      );
      final updated = Facility.fromJson(result.first);
      await AuditLogService.log(action: 'update', table: 'facilities', recordId: updated.id, changes: updated.toJson());
      return updated;
    } catch (e) {
      debugPrint('Failed to update facility: $e');
      rethrow;
    }
  }

  Future<void> deleteFacility(String facilityId) async {
    try {
      await SupabaseService.delete('facilities', filters: {'id': facilityId});
      await AuditLogService.log(action: 'delete', table: 'facilities', recordId: facilityId);
    } catch (e) {
      debugPrint('Failed to delete facility: $e');
      rethrow;
    }
  }

  /// Crea facility_exam_offerings multiple in batch (per wizard di onboarding)
  Future<void> bulkCreateOfferings(List<FacilityExamOffering> offerings) async {
    if (offerings.isEmpty) return;
    
    try {
      final payload = offerings.map((o) {
        final now = DateTime.now().toUtc().toIso8601String();
        return {
          'facility_id': o.facilityId,
          'exam_type_id': o.examTypeId,
          'price': o.price,
          'ssn_price': o.ssnPrice,
          'duration_minutes': o.durationMinutes,
          'is_available': o.isAvailable,
          'max_daily_bookings': o.maxDailyBookings,
          'created_at': now,
          'updated_at': now,
        };
      }).toList();

      await SupabaseConfig.client.from('facility_exam_offerings').insert(payload);
      debugPrint('[FacilityService] Created ${offerings.length} offerings in bulk');
      
      // Log audit per ogni offering
      for (final offering in offerings) {
        await AuditLogService.log(
          action: 'create',
          table: 'facility_exam_offerings',
          recordId: offering.id,
          changes: {'facility_id': offering.facilityId, 'exam_type_id': offering.examTypeId},
        );
      }
    } catch (e) {
      debugPrint('Failed to bulk create offerings: $e');
      rethrow;
    }
  }
}
