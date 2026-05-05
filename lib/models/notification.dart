/// Notification model for booking status changes and user alerts
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.bookingId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'message': message,
    'type': type.name,
    'booking_id': bookingId,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    message: json['message'] as String,
    type: NotificationType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => NotificationType.info,
    ),
    bookingId: json['booking_id'] as String?,
    isRead: json['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? bookingId,
    bool? isRead,
    DateTime? createdAt,
  }) => AppNotification(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    message: message ?? this.message,
    type: type ?? this.type,
    bookingId: bookingId ?? this.bookingId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt ?? this.createdAt,
  );
}

enum NotificationType {
  bookingConfirmed,
  bookingRejected,
  bookingCancelled,
  bookingCompleted,
  bookingReminder,
  info,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.bookingConfirmed:
        return 'Prenotazione Confermata';
      case NotificationType.bookingRejected:
        return 'Prenotazione Rifiutata';
      case NotificationType.bookingCancelled:
        return 'Prenotazione Annullata';
      case NotificationType.bookingCompleted:
        return 'Esame Completato';
      case NotificationType.bookingReminder:
        return 'Promemoria';
      case NotificationType.info:
        return 'Informazione';
    }
  }
  
  String get icon {
    switch (this) {
      case NotificationType.bookingConfirmed:
        return '✅';
      case NotificationType.bookingRejected:
        return '❌';
      case NotificationType.bookingCancelled:
        return '🚫';
      case NotificationType.bookingCompleted:
        return '🎉';
      case NotificationType.bookingReminder:
        return '⏰';
      case NotificationType.info:
        return 'ℹ️';
    }
  }
}
