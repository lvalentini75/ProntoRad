import 'package:flutter/foundation.dart';

/// Sistema di logging centralizzato per debug
/// Salva tutti i log in memoria e li espone tramite getter
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  static AppLogger get instance => _instance;
  factory AppLogger() => _instance;
  AppLogger._internal();

  final List<LogEntry> _logs = [];
  final int _maxLogs = 500;

  /// Ottieni tutti i log
  List<LogEntry> get allLogs => List.unmodifiable(_logs);

  /// Ottieni solo i log recenti (ultimi N)
  List<LogEntry> getRecentLogs([int count = 100]) {
    final start = _logs.length > count ? _logs.length - count : 0;
    return _logs.sublist(start);
  }

  /// Log generico
  void log(String category, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      message: message,
      level: level,
    );
    
    _logs.add(entry);
    
    // Mantieni solo gli ultimi N log
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    // Stampa anche in console con emoji
    final emoji = _getEmoji(level);
    debugPrint('[$category] $emoji $message');
  }

  /// Log di inizializzazione
  void init(String category, String message) => 
      log(category, message, level: LogLevel.init);

  /// Log di successo
  void success(String category, String message) => 
      log(category, message, level: LogLevel.success);

  /// Log di errore
  void error(String category, String message) => 
      log(category, message, level: LogLevel.error);

  /// Log di warning
  void warning(String category, String message) => 
      log(category, message, level: LogLevel.warning);

  /// Log di debug
  void debug(String category, String message) => 
      log(category, message, level: LogLevel.debug);

  /// Log per eventi di storage
  void storage(String operation, String key, {String? value}) {
    final msg = value != null 
        ? '$operation: $key = ${value.length > 50 ? "${value.substring(0, 50)}..." : value}'
        : '$operation: $key';
    log('STORAGE', msg, level: LogLevel.storage);
  }

  /// Log per eventi di autenticazione
  void auth(String event, String details) {
    log('AUTH', '$event - $details', level: LogLevel.auth);
  }

  /// Pulisci i log
  void clear() {
    _logs.clear();
    debugPrint('[AppLogger] Log puliti');
  }

  /// Esporta i log come testo
  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('========== APP LOGS ==========');
    buffer.writeln('Esportato: ${DateTime.now()}');
    buffer.writeln('Totale log: ${_logs.length}');
    buffer.writeln('==============================\n');
    
    for (final log in _logs) {
      buffer.writeln(log.toString());
    }
    
    return buffer.toString();
  }

  String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.init:
        return '🚀';
      case LogLevel.success:
        return '✅';
      case LogLevel.error:
        return '❌';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.debug:
        return '🔍';
      case LogLevel.storage:
        return '💾';
      case LogLevel.auth:
        return '🔐';
      case LogLevel.info:
      default:
        return 'ℹ️';
    }
  }
}

/// Entry di log
class LogEntry {
  final DateTime timestamp;
  final String category;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    required this.level,
  });

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
    return '[$time] [$category] ${level.name.toUpperCase()}: $message';
  }

  /// Formattazione colorata per UI
  String get displayText => '[$category] $message';
  
  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

/// Livelli di log
enum LogLevel {
  init,
  success,
  error,
  warning,
  debug,
  info,
  storage,
  auth,
}
