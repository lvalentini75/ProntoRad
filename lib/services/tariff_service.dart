import 'package:flutter/foundation.dart';
import 'package:xraynow/models/tariff.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

class TariffService {
  Future<List<Tariff>> getTariffsForOrganization(String organizationId) async {
    try {
      final data = await SupabaseService.select('tariffs', filters: {'organization_id': organizationId});
      return data.map((e) => Tariff.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Failed to load tariffs: $e');
      return [];
    }
  }

  Future<Tariff?> getTariff(String organizationId, String examTypeId) async {
    try {
      final data = await SupabaseService.selectSingle('tariffs', filters: {
        'organization_id': organizationId,
        'exam_type_id': examTypeId,
      });
      if (data == null) return null;
      return Tariff.fromJson(data);
    } catch (e) {
      debugPrint('Failed to get tariff: $e');
      return null;
    }
  }

  Future<double?> getPrice(String organizationId, String examTypeId) async {
    try {
      final t = await getTariff(organizationId, examTypeId);
      return t?.price;
    } catch (e) {
      debugPrint('Failed to get price: $e');
      return null;
    }
  }

  Future<Tariff> upsertTariff({
    required String organizationId,
    required String examTypeId,
    required double price,
    String currency = 'EUR',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      // Try update first
      final existing = await SupabaseService.selectSingle('tariffs', filters: {
        'organization_id': organizationId,
        'exam_type_id': examTypeId,
      });
      if (existing != null) {
        try {
          final res = await SupabaseService.update('tariffs', {
            'price': price,
            'currency': currency,
            'updated_at': now,
          }, filters: {
            'id': existing['id'],
          });
          final updated = Tariff.fromJson(res.first);
          await AuditLogService.log(action: 'update', table: 'tariffs', recordId: updated.id, changes: updated.toJson());
          return updated;
        } catch (e) {
          // Schema-tolerant fallback: if some columns don't exist (e.g., currency/updated_at), update minimal fields
          debugPrint('Tariff update with full fields failed, retrying minimal set: $e');
          final res = await SupabaseService.update('tariffs', {
            'price': price,
          }, filters: {
            'id': existing['id'],
          });
          final updated = Tariff.fromJson(res.first);
          await AuditLogService.log(action: 'update', table: 'tariffs', recordId: updated.id, changes: {'price': price});
          return updated;
        }
      }
      try {
        final res = await SupabaseService.insert('tariffs', {
          'organization_id': organizationId,
          'exam_type_id': examTypeId,
          'price': price,
          'currency': currency,
          'created_at': now,
          'updated_at': now,
        });
        final created = Tariff.fromJson(res.first);
        await AuditLogService.log(action: 'create', table: 'tariffs', recordId: created.id, changes: created.toJson());
        return created;
      } catch (e) {
        // Schema-tolerant fallback: insert only mandatory fields
        debugPrint('Tariff insert with full fields failed, retrying minimal set: $e');
        final res = await SupabaseService.insert('tariffs', {
          'organization_id': organizationId,
          'exam_type_id': examTypeId,
          'price': price,
        });
        final created = Tariff.fromJson(res.first);
        await AuditLogService.log(action: 'create', table: 'tariffs', recordId: created.id, changes: {
          'organization_id': organizationId,
          'exam_type_id': examTypeId,
          'price': price,
        });
        return created;
      }
    } catch (e) {
      debugPrint('Failed to upsert tariff: $e');
      rethrow;
    }
  }

  Future<void> deleteTariff(String tariffId) async {
    try {
      await SupabaseService.delete('tariffs', filters: {'id': tariffId});
      await AuditLogService.log(action: 'delete', table: 'tariffs', recordId: tariffId);
    } catch (e) {
      debugPrint('Failed to delete tariff: $e');
      rethrow;
    }
  }

  /// Crea tariffe multiple in batch (per wizard di onboarding)
  Future<void> bulkCreateTariffs(List<Tariff> tariffs) async {
    if (tariffs.isEmpty) return;
    
    try {
      final payload = tariffs.map((t) {
        final now = DateTime.now().toUtc().toIso8601String();
        return {
          'organization_id': t.organizationId,
          'exam_type_id': t.examTypeId,
          'price': t.price,
          'currency': t.currency ?? 'EUR',
          'created_at': now,
          'updated_at': now,
        };
      }).toList();

      await SupabaseConfig.client.from('tariffs').insert(payload);
      debugPrint('[TariffService] Created ${tariffs.length} tariffs in bulk');
      
      // Log audit per ogni tariff
      for (final tariff in tariffs) {
        await AuditLogService.log(
          action: 'create',
          table: 'tariffs',
          recordId: tariff.id,
          changes: {'organization_id': tariff.organizationId, 'exam_type_id': tariff.examTypeId, 'price': tariff.price},
        );
      }
    } catch (e) {
      debugPrint('Failed to bulk create tariffs: $e');
      rethrow;
    }
  }
}
