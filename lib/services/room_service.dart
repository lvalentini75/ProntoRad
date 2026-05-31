import 'package:flutter/foundation.dart';
import 'package:xraynow/models/room.dart';
import 'package:xraynow/supabase/supabase_config.dart';

class RoomService {
  Future<List<Room>> getRoomsForOrganization(String organizationId,
      {bool onlyActive = true}) async {
    try {
      var query = SupabaseConfig.client
          .from('rooms')
          .select()
          .eq('organization_id', organizationId);
      if (onlyActive) {
        query = query.eq('is_active', true);
      }
      final data = await query.order('display_order').order('name');
      return (data as List)
          .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[RoomService] Error loading rooms: $e');
      return [];
    }
  }

  Future<Room?> createRoom(Room room) async {
    try {
      final data = await SupabaseConfig.client
          .from('rooms')
          .insert(room.toJson())
          .select()
          .single();
      return Room.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[RoomService] Error creating room: $e');
      rethrow;
    }
  }

  Future<Room?> updateRoom(Room room) async {
    try {
      final data = await SupabaseConfig.client
          .from('rooms')
          .update(room.toJson())
          .eq('id', room.id)
          .select()
          .single();
      return Room.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('[RoomService] Error updating room: $e');
      rethrow;
    }
  }

  Future<void> deleteRoom(String id) async {
    try {
      await SupabaseConfig.client.from('rooms').delete().eq('id', id);
    } catch (e) {
      debugPrint('[RoomService] Error deleting room: $e');
      rethrow;
    }
  }

  /// Update display_order for a list of rooms (used for drag-reorder of columns)
  Future<void> reorderRooms(List<Room> ordered) async {
    try {
      for (int i = 0; i < ordered.length; i++) {
        final r = ordered[i];
        if (r.displayOrder == i) continue;
        await SupabaseConfig.client
            .from('rooms')
            .update({'display_order': i}).eq('id', r.id);
      }
    } catch (e) {
      debugPrint('[RoomService] Error reordering rooms: $e');
    }
  }
}
