import 'package:flutter/foundation.dart';
import 'package:xraynow/models/notification.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/supabase/supabase_config.dart';

class NotificationService {
  /// Get all notifications for a user
  Future<List<AppNotification>> getUserNotifications(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return (data as List)
          .map((json) => AppNotification.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('[NotificationService] Failed to load notifications: $e');
      return [];
    }
  }

  /// Get unread notifications count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      return (data as List).length;
    } catch (e) {
      debugPrint('[NotificationService] Failed to count unread: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[NotificationService] Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationService] Failed to mark all as read: $e');
    }
  }

  /// Create a notification for booking status change
  Future<AppNotification?> createBookingNotification({
    required String userId,
    required Booking booking,
    required BookingStatus newStatus,
    String? additionalMessage,
  }) async {
    try {
      final examName = booking.examType?.name ?? 'Esame';
      final (title, message, type) = _getNotificationContent(
        examName: examName,
        status: newStatus,
        additionalMessage: additionalMessage,
      );

      final data = await SupabaseConfig.client
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type.name,
            'booking_id': booking.id,
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('[NotificationService] ✅ Notification created for user $userId');
      return AppNotification.fromJson(data);
    } catch (e) {
      debugPrint('[NotificationService] ❌ Failed to create notification: $e');
      return null;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[NotificationService] Failed to delete notification: $e');
    }
  }

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[NotificationService] Failed to delete all notifications: $e');
    }
  }

  (String title, String message, NotificationType type) _getNotificationContent({
    required String examName,
    required BookingStatus status,
    String? additionalMessage,
  }) {
    switch (status) {
      case BookingStatus.confirmed:
        return (
          'Prenotazione Confermata ✅',
          'La tua prenotazione per "$examName" è stata confermata. ${additionalMessage ?? "Ti aspettiamo!"}',
          NotificationType.bookingConfirmed,
        );
      case BookingStatus.rejected:
        return (
          'Prenotazione Rifiutata ❌',
          'La tua prenotazione per "$examName" non è stata accettata. ${additionalMessage ?? "Contattaci per maggiori informazioni."}',
          NotificationType.bookingRejected,
        );
      case BookingStatus.cancelled:
        return (
          'Prenotazione Annullata 🚫',
          'La prenotazione per "$examName" è stata annullata. ${additionalMessage ?? ""}',
          NotificationType.bookingCancelled,
        );
      case BookingStatus.completed:
        return (
          'Esame Completato 🎉',
          'Il tuo esame "$examName" è stato completato. ${additionalMessage ?? "Grazie per aver scelto i nostri servizi!"}',
          NotificationType.bookingCompleted,
        );
      case BookingStatus.requested:
        return (
          'Prenotazione Ricevuta 📋',
          'La tua richiesta per "$examName" è stata ricevuta. ${additionalMessage ?? "Ti contatteremo presto."}',
          NotificationType.info,
        );
    }
  }
}
