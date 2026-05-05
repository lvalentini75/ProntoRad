import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formattedTimestamp => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';

  String get levelIcon {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }

  String get fullMessage {
    final buffer = StringBuffer();
    buffer.write('[$formattedTimestamp] $levelIcon [$source] $message');
    if (error != null) {
      buffer.write('\n   Error: $error');
    }
    if (stackTrace != null) {
      final lines = stackTrace.toString().split('\n').take(5);
      buffer.write('\n   Stack:\n   ${lines.join('\n   ')}');
    }
    return buffer.toString();
  }
}

class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  final List<LogEntry> _logs = [];
  final List<Function(LogEntry)> _listeners = [];
  int _maxLogs = 500;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void addListener(Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  void clear() {
    _logs.clear();
    _notifyListeners(null);
  }

  void _notifyListeners(LogEntry? entry) {
    for (var listener in _listeners) {
      listener(entry ?? LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        source: 'System',
        message: 'Logs cleared',
      ));
    }
  }

  void log(LogLevel level, String source, String message, {dynamic error, StackTrace? stackTrace}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Also print to debugPrint
    debugPrint(entry.fullMessage);

    _notifyListeners(entry);
  }

  void debug(String source, String message) {
    log(LogLevel.debug, source, message);
  }

  void info(String source, String message) {
    log(LogLevel.info, source, message);
  }

  void warning(String source, String message, {dynamic error}) {
    log(LogLevel.warning, source, message, error: error);
  }

  void error(String source, String message, {dynamic error, StackTrace? stackTrace}) {
    log(LogLevel.error, source, message, error: error, stackTrace: stackTrace);
  }

  void critical(String source, String message, {dynamic error, StackTrace? stackTrace}) {
    log(LogLevel.critical, source, message, error: error, stackTrace: stackTrace);
  }

  String exportLogs() {
    return _logs.map((e) => e.fullMessage).join('\n\n');
  }
}
