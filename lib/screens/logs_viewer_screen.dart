import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xraynow/utils/app_logger.dart';
import 'package:xraynow/theme.dart';

/// Schermata per visualizzare i log dell'applicazione
class LogsViewerScreen extends StatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  State<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerScreen> {
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();
  String _filter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<LogEntry> _getFilteredLogs() {
    final logs = AppLogger.instance.allLogs;
    if (_filter.isEmpty) return logs;
    
    return logs.where((log) {
      return log.category.toLowerCase().contains(_filter.toLowerCase()) ||
             log.message.toLowerCase().contains(_filter.toLowerCase());
    }).toList();
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.success:
        return Colors.green;
      case LogLevel.init:
        return Colors.blue;
      case LogLevel.auth:
        return Colors.purple;
      case LogLevel.storage:
        return Colors.teal;
      case LogLevel.debug:
        return Colors.grey;
      default:
        return Colors.black87;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.success:
        return Icons.check_circle;
      case LogLevel.init:
        return Icons.rocket_launch;
      case LogLevel.auth:
        return Icons.lock;
      case LogLevel.storage:
        return Icons.storage;
      case LogLevel.debug:
        return Icons.bug_report;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _getFilteredLogs();
    
    // Auto-scroll quando vengono aggiunti nuovi log
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Applicazione'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.lock : Icons.lock_open),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: _autoScroll ? 'Auto-scroll attivo' : 'Auto-scroll disattivo',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: AppLogger.instance.exportAsText()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copiati negli appunti')),
              );
            },
            tooltip: 'Copia log',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              AppLogger.instance.clear();
              setState(() {});
            },
            tooltip: 'Pulisci log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Filtra log',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
          
          // Statistiche
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Totale', logs.length.toString(), Colors.blue),
                _buildStat('Errori', logs.where((l) => l.level == LogLevel.error).length.toString(), Colors.red),
                _buildStat('Warning', logs.where((l) => l.level == LogLevel.warning).length.toString(), Colors.orange),
                _buildStat('Storage', logs.where((l) => l.level == LogLevel.storage).length.toString(), Colors.teal),
              ],
            ),
          ),
          
          // Lista log
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('Nessun log disponibile'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                          color: index.isEven ? Colors.white : Colors.grey[50],
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            _getLevelIcon(log.level),
                            color: _getLevelColor(log.level),
                            size: 20,
                          ),
                          title: Text(
                            log.message,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                          subtitle: Text(
                            '${log.timeFormatted} - ${log.category}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(log.category),
                                content: SelectableText(log.toString()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Chiudi'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
