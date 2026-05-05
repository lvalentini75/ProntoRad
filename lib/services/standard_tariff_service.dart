import 'package:flutter/foundation.dart';
import 'package:xraynow/models/standard_tariff.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/audit_log_service.dart';

/// Service for managing standard (system-wide) tariffs.
/// These are base prices that organizations can override with their own tariffs.
class StandardTariffService {
  static const String _tableName = 'standard_tariffs';

  /// Get all standard tariffs
  Future<List<StandardTariff>> getAll() async {
    try {
      final data = await SupabaseService.select(_tableName);
      return data.map((e) => StandardTariff.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[StandardTariffService] Failed to load standard tariffs: $e');
      return [];
    }
  }

  /// Get standard tariff for a specific exam type
  Future<StandardTariff?> getByExamTypeId(String examTypeId) async {
    try {
      final data = await SupabaseService.selectSingle(_tableName, filters: {
        'exam_type_id': examTypeId,
      });
      if (data == null) return null;
      return StandardTariff.fromJson(data);
    } catch (e) {
      debugPrint('[StandardTariffService] Failed to get tariff for exam $examTypeId: $e');
      return null;
    }
  }

  /// Get standard price for a specific exam type
  Future<double?> getPrice(String examTypeId) async {
    final tariff = await getByExamTypeId(examTypeId);
    return tariff?.price;
  }

  /// Get all standard tariffs as a map (examTypeId -> tariff)
  Future<Map<String, StandardTariff>> getAllAsMap() async {
    final tariffs = await getAll();
    return {for (var t in tariffs) t.examTypeId: t};
  }

  /// Create or update a standard tariff
  Future<StandardTariff> upsert({
    required String examTypeId,
    required double price,
    String currency = 'EUR',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      // Check if exists
      final existing = await SupabaseService.selectSingle(_tableName, filters: {
        'exam_type_id': examTypeId,
      });

      if (existing != null) {
        // Update
        final res = await SupabaseService.update(_tableName, {
          'price': price,
          'currency': currency,
          'updated_at': now,
        }, filters: {
          'id': existing['id'],
        });
        final updated = StandardTariff.fromJson(res.first);
        await AuditLogService.log(
          action: 'update',
          table: _tableName,
          recordId: updated.id,
          changes: {'price': price, 'currency': currency},
        );
        debugPrint('[StandardTariffService] ✅ Updated standard tariff for exam $examTypeId');
        return updated;
      }

      // Insert new
      final res = await SupabaseService.insert(_tableName, {
        'exam_type_id': examTypeId,
        'price': price,
        'currency': currency,
        'created_at': now,
        'updated_at': now,
      });
      final created = StandardTariff.fromJson(res.first);
      await AuditLogService.log(
        action: 'create',
        table: _tableName,
        recordId: created.id,
        changes: created.toJson(),
      );
      debugPrint('[StandardTariffService] ✅ Created standard tariff for exam $examTypeId');
      return created;
    } catch (e) {
      debugPrint('[StandardTariffService] ❌ Failed to upsert standard tariff: $e');
      rethrow;
    }
  }

  /// Delete a standard tariff
  Future<void> delete(String tariffId) async {
    try {
      await SupabaseService.delete(_tableName, filters: {'id': tariffId});
      await AuditLogService.log(action: 'delete', table: _tableName, recordId: tariffId);
      debugPrint('[StandardTariffService] ✅ Deleted standard tariff $tariffId');
    } catch (e) {
      debugPrint('[StandardTariffService] ❌ Failed to delete standard tariff: $e');
      rethrow;
    }
  }

  /// Delete standard tariff by exam type ID
  Future<void> deleteByExamTypeId(String examTypeId) async {
    try {
      final tariff = await getByExamTypeId(examTypeId);
      if (tariff != null) {
        await delete(tariff.id);
      }
    } catch (e) {
      debugPrint('[StandardTariffService] ❌ Failed to delete tariff for exam $examTypeId: $e');
      rethrow;
    }
  }

  /// Bulk upsert standard tariffs
  Future<void> bulkUpsert(List<Map<String, dynamic>> tariffData) async {
    for (final data in tariffData) {
      await upsert(
        examTypeId: data['exam_type_id'] as String,
        price: (data['price'] as num).toDouble(),
        currency: (data['currency'] as String?) ?? 'EUR',
      );
    }
  }
}
