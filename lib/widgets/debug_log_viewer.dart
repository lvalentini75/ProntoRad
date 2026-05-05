import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xraynow/services/debug_log_service.dart';

class DebugLogViewer extends StatefulWidget {
  const DebugLogViewer({super.key});

  @override
  State<DebugLogViewer> createState() => _DebugLogViewerState();
}

class _DebugLogViewerState extends State<DebugLogViewer> {
  final _logService = DebugLogService();
  final _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel? _filterLevel;

  @override
  void initState() {
    super.initState();
    _logService.addListener(_onNewLog);
  }

  @override
  void dispose() {
    _logService.removeListener(_onNewLog);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewLog(LogEntry entry) {
    if (mounted) {
      setState(() {});
      if (_autoScroll && _scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  List<LogEntry> get _filteredLogs {
    if (_filterLevel == null) return _logService.logs;
    return _logService.logs.where((log) => log.level == _filterLevel).toList();
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildHeader(logs.length),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Nessun log disponibile',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) => _buildLogEntry(logs[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int logCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Debug Logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '$logCount log${logCount != 1 ? 's' : ''}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(width: 16),
          _buildFilterButton(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.arrow_downward : Icons.arrow_downward_outlined,
              color: _autoScroll ? Colors.green : Colors.grey,
              size: 20,
            ),
            tooltip: 'Auto-scroll',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
            tooltip: 'Copia tutti i log',
            onPressed: _copyAllLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'Cancella log',
            onPressed: () {
              _logService.clear();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<LogLevel?>(
      icon: Icon(
        Icons.filter_list,
        color: _filterLevel != null ? Colors.blue : Colors.grey,
        size: 20,
      ),
      tooltip: 'Filtra per livello',
      onSelected: (level) => setState(() => _filterLevel = level),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text('Tutti'),
        ),
        ...LogLevel.values.map((level) => PopupMenuItem(
              value: level,
              child: Row(
                children: [
                  Icon(_getLevelIcon(level), size: 16),
                  const SizedBox(width: 8),
                  Text(level.name.toUpperCase()),
                ],
              ),
            )),
      ],
    );
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.critical:
        return Icons.crisis_alert;
    }
  }

  Widget _buildLogEntry(LogEntry log) {
    final color = _getLevelColor(log.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.formattedTimestamp,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.levelIcon,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            log.source,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (log.error != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: SelectableText(
                          '${log.error}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                    if (log.stackTrace != null) ...[
                      const SizedBox(height: 4),
                      ExpansionTile(
                        title: const Text(
                          'Stack Trace',
                          style: TextStyle(color: Colors.orange, fontSize: 11),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.all(8),
                        backgroundColor: Colors.orange.withValues(alpha: 0.05),
                        children: [
                          SelectableText(
                            log.stackTrace.toString(),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                color: Colors.grey[600],
                tooltip: 'Copia log',
                onPressed: () => _copyLog(log),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyLog(LogEntry log) {
    Clipboard.setData(ClipboardData(text: log.fullMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copiato negli appunti'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyAllLogs() {
    final allLogs = _logService.exportLogs();
    Clipboard.setData(ClipboardData(text: allLogs));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_logService.logs.length} log copiati negli appunti'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
