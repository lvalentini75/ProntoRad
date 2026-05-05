import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/exam_compatibility.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/exam_package_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/theme.dart';

/// Schermata gestione regole di compatibilità tra esami
class ExamCompatibilityScreen extends StatefulWidget {
  const ExamCompatibilityScreen({super.key});

  @override
  State<ExamCompatibilityScreen> createState() => _ExamCompatibilityScreenState();
}

class _ExamCompatibilityScreenState extends State<ExamCompatibilityScreen> {
  final _service = ExamPackageService();
  final _examService = ExamService();
  
  List<ExamCompatibility> _rules = [];
  List<ExamType> _allExams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) {
        setState(() {
          _error = 'Organizzazione non trovata';
          _loading = false;
        });
        return;
      }
      
      final rules = await _service.getCompatibilityRulesForOrganization(orgId);
      final exams = await _examService.getAllExams();
      
      setState(() {
        _rules = rules;
        _allExams = exams;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Errore caricamento: $e';
        _loading = false;
      });
    }
  }

  String _getExamName(String examId) {
    final exam = _allExams.firstWhere(
      (e) => e.id == examId,
      orElse: () => ExamType(
        id: examId,
        name: 'Esame sconosciuto',
        category: ExamCategory.rm,
        bodyDistrict: BodyDistrict.testa,
        description: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return exam.name;
  }

  Future<void> _showRuleDialog([ExamCompatibility? existing]) async {
    final result = await showDialog<ExamCompatibility>(
      context: context,
      builder: (ctx) => ExamCompatibilityDialog(
        existing: existing,
        allExams: _allExams,
        organizationId: SupabaseAuthManager.instance.cachedProfile?.organizationId ?? '',
      ),
    );
    
    if (result != null) {
      setState(() => _loading = true);
      try {
        if (existing != null) {
          await _service.updateCompatibilityRule(result);
        } else {
          await _service.createCompatibilityRule(result);
        }
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(existing != null ? 'Regola aggiornata' : 'Regola creata')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteRule(ExamCompatibility rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Eliminare la regola di compatibilità tra "${_getExamName(rule.examId1)}" e "${_getExamName(rule.examId2)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _loading = true);
      final success = await _service.deleteCompatibilityRule(rule.id);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Regola eliminata')),
          );
        }
      }
    }
  }

  Future<void> _exportRules() async {
    try {
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final json = await _service.exportCompatibilityRulesToJson(orgId);
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON copiato negli appunti')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importRules() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      final content = utf8.decode(file.bytes!);
      
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final importResult = await _service.importCompatibilityRulesFromJson(content, orgId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(importResult.message),
            backgroundColor: importResult.success ? Colors.green : Colors.orange,
          ),
        );
        if (importResult.importedCount > 0) {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore import: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getTypeColor(CompatibilityType type) {
    switch (type) {
      case CompatibilityType.sameSlot:
        return Colors.green;
      case CompatibilityType.sequential:
        return Colors.blue;
      case CompatibilityType.differentRoom:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(CompatibilityType type) {
    switch (type) {
      case CompatibilityType.sameSlot:
        return Icons.merge_type;
      case CompatibilityType.sequential:
        return Icons.arrow_forward;
      case CompatibilityType.differentRoom:
        return Icons.compare_arrows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: colorScheme.error)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: AppSpacing.paddingLg,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, color: colorScheme.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Compatibilità Esami', style: context.textStyles.titleLarge?.bold),
                                Text(
                                  'Definisci come gli esami possono essere combinati',
                                  style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _importRules,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Importa'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _rules.isEmpty ? null : _exportRules,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Esporta'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _showRuleDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nuova Regola'),
                          ),
                        ],
                      ),
                    ),
                    
                    // Info cards
                    Padding(
                      padding: AppSpacing.paddingMd,
                      child: Row(
                        children: [
                          _TypeInfoCard(
                            type: CompatibilityType.sameSlot,
                            description: 'Esami nello stesso slot (es. TAC multi-distretto)',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _TypeInfoCard(
                            type: CompatibilityType.sequential,
                            description: 'Esami consecutivi, stessa sala (tempi sommati)',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _TypeInfoCard(
                            type: CompatibilityType.differentRoom,
                            description: 'Sale diverse con intervallo (es. mammografia + eco)',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: _rules.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link_off, size: 64, color: colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text('Nessuna regola configurata', style: context.textStyles.titleMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Definisci come gli esami possono essere combinati nelle prenotazioni',
                                    style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: AppSpacing.paddingLg,
                              itemCount: _rules.length,
                              itemBuilder: (ctx, i) => _RuleCard(
                                rule: _rules[i],
                                exam1Name: _getExamName(_rules[i].examId1),
                                exam2Name: _getExamName(_rules[i].examId2),
                                typeColor: _getTypeColor(_rules[i].compatibilityType),
                                typeIcon: _getTypeIcon(_rules[i].compatibilityType),
                                onEdit: () => _showRuleDialog(_rules[i]),
                                onDelete: () => _deleteRule(_rules[i]),
                                onToggleActive: () async {
                                  final updated = _rules[i].copyWith(isActive: !_rules[i].isActive);
                                  await _service.updateCompatibilityRule(updated);
                                  await _loadData();
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _TypeInfoCard extends StatelessWidget {
  final CompatibilityType type;
  final String description;
  final Color color;

  const _TypeInfoCard({
    required this.type,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                  Text(description, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case CompatibilityType.sameSlot:
        return Icons.merge_type;
      case CompatibilityType.sequential:
        return Icons.arrow_forward;
      case CompatibilityType.differentRoom:
        return Icons.compare_arrows;
    }
  }
}

class _RuleCard extends StatelessWidget {
  final ExamCompatibility rule;
  final String exam1Name;
  final String exam2Name;
  final Color typeColor;
  final IconData typeIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _RuleCard({
    required this.rule,
    required this.exam1Name,
    required this.exam2Name,
    required this.typeColor,
    required this.typeIcon,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            // Exam 1
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Esame 1', style: context.textStyles.labelSmall?.withColor(colorScheme.primary)),
                    const SizedBox(height: 4),
                    Text(exam1Name, style: context.textStyles.bodyMedium?.bold),
                  ],
                ),
              ),
            ),
            
            // Arrow with type
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Icon(typeIcon, color: typeColor, size: 28),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      rule.compatibilityType.displayName,
                      style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (rule.timeGapMinutes > 0) ...[
                    const SizedBox(height: 4),
                    Text('+${rule.timeGapMinutes} min', style: context.textStyles.labelSmall?.withColor(typeColor)),
                  ],
                ],
              ),
            ),
            
            // Exam 2
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Esame 2', style: context.textStyles.labelSmall?.withColor(colorScheme.tertiary)),
                    const SizedBox(height: 4),
                    Text(exam2Name, style: context.textStyles.bodyMedium?.bold),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Status & Actions
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rule.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rule.isActive ? 'Attiva' : 'Inattiva',
                    style: TextStyle(fontSize: 11, color: rule.isActive ? Colors.green : Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(rule.isActive ? Icons.toggle_on : Icons.toggle_off, 
                        size: 24, 
                        color: rule.isActive ? colorScheme.primary : colorScheme.outline,
                      ),
                      onPressed: onToggleActive,
                      tooltip: rule.isActive ? 'Disattiva' : 'Attiva',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                      tooltip: 'Modifica',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: colorScheme.error,
                      onPressed: onDelete,
                      tooltip: 'Elimina',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog per creare/modificare una regola di compatibilità
class ExamCompatibilityDialog extends StatefulWidget {
  final ExamCompatibility? existing;
  final List<ExamType> allExams;
  final String organizationId;

  const ExamCompatibilityDialog({
    super.key,
    this.existing,
    required this.allExams,
    required this.organizationId,
  });

  @override
  State<ExamCompatibilityDialog> createState() => _ExamCompatibilityDialogState();
}

class _ExamCompatibilityDialogState extends State<ExamCompatibilityDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _timeGapCtrl;
  late TextEditingController _notesCtrl;
  
  String? _selectedExam1;
  String? _selectedExam2;
  CompatibilityType _compatibilityType = CompatibilityType.sequential;

  @override
  void initState() {
    super.initState();
    _selectedExam1 = widget.existing?.examId1;
    _selectedExam2 = widget.existing?.examId2;
    _compatibilityType = widget.existing?.compatibilityType ?? CompatibilityType.sequential;
    _timeGapCtrl = TextEditingController(text: widget.existing?.timeGapMinutes.toString() ?? '0');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _timeGapCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExam1 == null || _selectedExam2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona entrambi gli esami'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedExam1 == _selectedExam2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona due esami diversi'), backgroundColor: Colors.orange),
      );
      return;
    }

    final rule = ExamCompatibility(
      id: widget.existing?.id ?? '',
      organizationId: widget.organizationId,
      examId1: _selectedExam1!,
      examId2: _selectedExam2!,
      compatibilityType: _compatibilityType,
      timeGapMinutes: int.tryParse(_timeGapCtrl.text) ?? 0,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      isActive: widget.existing?.isActive ?? true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, rule);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.link, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(widget.existing != null ? 'Modifica Regola' : 'Nuova Regola'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Esame 1
                Text('Esame 1 *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedExam1,
                  decoration: const InputDecoration(
                    hintText: 'Seleziona primo esame',
                  ),
                  items: widget.allExams.map((exam) {
                    return DropdownMenuItem(
                      value: exam.id,
                      child: Text('${exam.name} (${exam.category.displayName})'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedExam1 = v),
                ),
                
                const SizedBox(height: 24),
                
                // Tipo compatibilità
                Text('Tipo di Compatibilità *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                ...CompatibilityType.values.map((type) {
                  return RadioListTile<CompatibilityType>(
                    title: Text(type.displayName),
                    subtitle: Text(type.description, style: context.textStyles.bodySmall),
                    value: type,
                    groupValue: _compatibilityType,
                    onChanged: (v) => setState(() => _compatibilityType = v!),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }),
                
                const SizedBox(height: 24),
                
                // Esame 2
                Text('Esame 2 *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedExam2,
                  decoration: const InputDecoration(
                    hintText: 'Seleziona secondo esame',
                  ),
                  items: widget.allExams.map((exam) {
                    return DropdownMenuItem(
                      value: exam.id,
                      child: Text('${exam.name} (${exam.category.displayName})'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedExam2 = v),
                ),
                
                const SizedBox(height: 24),
                
                // Time gap (solo per different_room)
                if (_compatibilityType == CompatibilityType.differentRoom) ...[
                  TextFormField(
                    controller: _timeGapCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Intervallo tra esami (minuti)',
                      hintText: 'Es: 20',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],
                
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Note opzionali',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
