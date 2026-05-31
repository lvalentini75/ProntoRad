import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/exam_compatibility.dart';
import 'package:xraynow/models/exam_prerequisite.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/exam_package_service.dart';
import 'package:xraynow/services/exam_prerequisite_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/theme.dart';

/// Schermata gestione "Esami in Relazione":
/// - Tab 1: Regole di Compatibilità (stesso slot, sequenziale, sale diverse)
/// - Tab 2: Prerequisiti (esame A richiede esame B prima)
class ExamCompatibilityScreen extends StatefulWidget {
  const ExamCompatibilityScreen({super.key});

  @override
  State<ExamCompatibilityScreen> createState() => _ExamCompatibilityScreenState();
}

class _ExamCompatibilityScreenState extends State<ExamCompatibilityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _packageService = ExamPackageService();
  final _prerequisiteService = ExamPrerequisiteService();
  final _examService = ExamService();
  
  List<ExamCompatibility> _compatibilityRules = [];
  List<ExamPrerequisite> _prerequisites = [];
  List<ExamType> _allExams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      
      final rules = await _packageService.getCompatibilityRulesForOrganization(orgId);
      final prerequisites = await _prerequisiteService.getPrerequisitesForOrganization(orgId);
      final exams = await _examService.getAllExams();
      
      setState(() {
        _compatibilityRules = rules;
        _prerequisites = prerequisites;
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
                  children: [
                    // Header
                    Container(
                      padding: AppSpacing.paddingLg,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link_rounded, color: colorScheme.primary, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Esami in Relazione', style: context.textStyles.titleLarge?.bold),
                                    Text(
                                      'Gestisci compatibilità e prerequisiti tra esami',
                                      style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Tab bar
                          TabBar(
                            controller: _tabController,
                            tabs: [
                              Tab(
                                icon: const Icon(Icons.compare_arrows, size: 20),
                                text: 'Relazione (${_compatibilityRules.length})',
                              ),
                              Tab(
                                icon: const Icon(Icons.arrow_forward, size: 20),
                                text: 'Prerequisiti (${_prerequisites.length})',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _CompatibilityTab(
                            rules: _compatibilityRules,
                            allExams: _allExams,
                            onRefresh: _loadData,
                            getExamName: _getExamName,
                          ),
                          _PrerequisitesTab(
                            prerequisites: _prerequisites,
                            allExams: _allExams,
                            onRefresh: _loadData,
                            getExamName: _getExamName,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ============================================================================
// TAB COMPATIBILITÀ
// ============================================================================

class _CompatibilityTab extends StatelessWidget {
  final List<ExamCompatibility> rules;
  final List<ExamType> allExams;
  final VoidCallback onRefresh;
  final String Function(String) getExamName;

  const _CompatibilityTab({
    required this.rules,
    required this.allExams,
    required this.onRefresh,
    required this.getExamName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Actions bar
        Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              // Info cards
              Expanded(
                child: Row(
                  children: [
                    _TypeInfoCard(
                      type: CompatibilityType.sameSlot,
                      description: 'Stesso slot (es: TAC multi-distretto)',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _TypeInfoCard(
                      type: CompatibilityType.sequential,
                      description: 'Consecutivi, stessa sala',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _TypeInfoCard(
                      type: CompatibilityType.differentRoom,
                      description: 'Sale diverse con intervallo',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _importRules(context),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Importa'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: rules.isEmpty ? null : () => _exportRules(context),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Esporta'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showRuleDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuova Regola'),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off, size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('Nessuna regola di compatibilità', style: context.textStyles.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Definisci come gli esami possono essere combinati',
                        style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: AppSpacing.paddingLg,
                  itemCount: rules.length,
                  itemBuilder: (ctx, i) => _RuleCard(
                    rule: rules[i],
                    exam1Name: getExamName(rules[i].examId1),
                    exam2Name: getExamName(rules[i].examId2),
                    typeColor: _getTypeColor(rules[i].compatibilityType),
                    typeIcon: _getTypeIcon(rules[i].compatibilityType),
                    onEdit: () => _showRuleDialog(ctx, rules[i]),
                    onDelete: () => _deleteRule(ctx, rules[i]),
                    onToggleActive: () => _toggleRuleActive(ctx, rules[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Color _getTypeColor(CompatibilityType type) {
    switch (type) {
      case CompatibilityType.sameSlot: return Colors.green;
      case CompatibilityType.sequential: return Colors.blue;
      case CompatibilityType.differentRoom: return Colors.orange;
    }
  }

  IconData _getTypeIcon(CompatibilityType type) {
    switch (type) {
      case CompatibilityType.sameSlot: return Icons.merge_type;
      case CompatibilityType.sequential: return Icons.arrow_forward;
      case CompatibilityType.differentRoom: return Icons.compare_arrows;
    }
  }

  Future<void> _showRuleDialog(BuildContext context, [ExamCompatibility? existing]) async {
    final result = await showDialog<ExamCompatibility>(
      context: context,
      builder: (ctx) => ExamCompatibilityDialog(
        existing: existing,
        allExams: allExams,
        organizationId: SupabaseAuthManager.instance.cachedProfile?.organizationId ?? '',
      ),
    );
    
    if (result != null) {
      try {
        final service = ExamPackageService();
        if (existing != null) {
          await service.updateCompatibilityRule(result);
        } else {
          await service.createCompatibilityRule(result);
        }
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(existing != null ? 'Regola aggiornata' : 'Regola creata')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteRule(BuildContext context, ExamCompatibility rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Eliminare la regola tra "${getExamName(rule.examId1)}" e "${getExamName(rule.examId2)}"?'),
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
      final success = await ExamPackageService().deleteCompatibilityRule(rule.id);
      if (success) {
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Regola eliminata')));
        }
      }
    }
  }

  Future<void> _toggleRuleActive(BuildContext context, ExamCompatibility rule) async {
    final updated = rule.copyWith(isActive: !rule.isActive);
    await ExamPackageService().updateCompatibilityRule(updated);
    onRefresh();
  }

  Future<void> _exportRules(BuildContext context) async {
    try {
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final json = await ExamPackageService().exportCompatibilityRulesToJson(orgId);
      await Clipboard.setData(ClipboardData(text: json));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copiato negli appunti')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore export: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _importRules(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null || result.files.isEmpty) return;
      
      final content = utf8.decode(result.files.first.bytes!);
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final importResult = await ExamPackageService().importCompatibilityRulesFromJson(content, orgId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(importResult.message),
          backgroundColor: importResult.success ? Colors.green : Colors.orange,
        ));
        if (importResult.importedCount > 0) onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore import: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ============================================================================
// TAB PREREQUISITI
// ============================================================================

class _PrerequisitesTab extends StatelessWidget {
  final List<ExamPrerequisite> prerequisites;
  final List<ExamType> allExams;
  final VoidCallback onRefresh;
  final String Function(String) getExamName;

  const _PrerequisitesTab({
    required this.prerequisites,
    required this.allExams,
    required this.onRefresh,
    required this.getExamName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Info + Actions bar
        Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I prerequisiti definiscono esami che devono essere prenotati PRIMA di un altro esame. '
                          'Es: "Ecografia Mammaria" richiede "Mammografia" 20 minuti prima.',
                          style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _importPrerequisites(context),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Importa'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: prerequisites.isEmpty ? null : () => _exportPrerequisites(context),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Esporta'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showPrerequisiteDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuovo Prerequisito'),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: prerequisites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_forward, size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('Nessun prerequisito configurato', style: context.textStyles.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Definisci quali esami richiedono altri esami prima',
                        style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: AppSpacing.paddingLg,
                  itemCount: prerequisites.length,
                  itemBuilder: (ctx, i) => _PrerequisiteCard(
                    prerequisite: prerequisites[i],
                    examName: getExamName(prerequisites[i].examId),
                    prerequisiteExamName: getExamName(prerequisites[i].prerequisiteExamId),
                    onEdit: () => _showPrerequisiteDialog(ctx, prerequisites[i]),
                    onDelete: () => _deletePrerequisite(ctx, prerequisites[i]),
                    onToggleActive: () => _togglePrerequisiteActive(ctx, prerequisites[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _showPrerequisiteDialog(BuildContext context, [ExamPrerequisite? existing]) async {
    final result = await showDialog<ExamPrerequisite>(
      context: context,
      builder: (ctx) => ExamPrerequisiteDialog(
        existing: existing,
        allExams: allExams,
        organizationId: SupabaseAuthManager.instance.cachedProfile?.organizationId ?? '',
      ),
    );
    
    if (result != null) {
      try {
        final service = ExamPrerequisiteService();
        if (existing != null) {
          await service.updatePrerequisite(result);
        } else {
          await service.createPrerequisite(result);
        }
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(existing != null ? 'Prerequisito aggiornato' : 'Prerequisito creato')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _deletePrerequisite(BuildContext context, ExamPrerequisite prereq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Eliminare il prerequisito "${getExamName(prereq.prerequisiteExamId)}" → "${getExamName(prereq.examId)}"?'),
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
      final success = await ExamPrerequisiteService().deletePrerequisite(prereq.id);
      if (success) {
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prerequisito eliminato')));
        }
      }
    }
  }

  Future<void> _togglePrerequisiteActive(BuildContext context, ExamPrerequisite prereq) async {
    final updated = prereq.copyWith(isActive: !prereq.isActive);
    await ExamPrerequisiteService().updatePrerequisite(updated);
    onRefresh();
  }

  Future<void> _exportPrerequisites(BuildContext context) async {
    try {
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final json = await ExamPrerequisiteService().exportPrerequisitesToJson(orgId);
      await Clipboard.setData(ClipboardData(text: json));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copiato negli appunti')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore export: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _importPrerequisites(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null || result.files.isEmpty) return;
      
      final content = utf8.decode(result.files.first.bytes!);
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final importResult = await ExamPrerequisiteService().importPrerequisitesFromJson(content, orgId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(importResult.message),
          backgroundColor: importResult.success ? Colors.green : Colors.orange,
        ));
        if (importResult.importedCount > 0) onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore import: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class _TypeInfoCard extends StatelessWidget {
  final CompatibilityType type;
  final String description;
  final Color color;

  const _TypeInfoCard({required this.type, required this.description, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
                  Text(description, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      case CompatibilityType.sameSlot: return Icons.merge_type;
      case CompatibilityType.sequential: return Icons.arrow_forward;
      case CompatibilityType.differentRoom: return Icons.compare_arrows;
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
    required this.rule, required this.exam1Name, required this.exam2Name,
    required this.typeColor, required this.typeIcon,
    required this.onEdit, required this.onDelete, required this.onToggleActive,
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
                    child: Text(rule.compatibilityType.displayName, style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.bold)),
                  ),
                  if (rule.timeGapMinutes > 0) ...[
                    const SizedBox(height: 4),
                    Text('+${rule.timeGapMinutes} min', style: context.textStyles.labelSmall?.withColor(typeColor)),
                  ],
                ],
              ),
            ),
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
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rule.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(rule.isActive ? 'Attiva' : 'Inattiva', style: TextStyle(fontSize: 11, color: rule.isActive ? Colors.green : Colors.grey)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(rule.isActive ? Icons.toggle_on : Icons.toggle_off, size: 24, color: rule.isActive ? colorScheme.primary : colorScheme.outline), onPressed: onToggleActive, tooltip: rule.isActive ? 'Disattiva' : 'Attiva', visualDensity: VisualDensity.compact),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit, tooltip: 'Modifica', visualDensity: VisualDensity.compact),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20), color: colorScheme.error, onPressed: onDelete, tooltip: 'Elimina', visualDensity: VisualDensity.compact),
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

class _PrerequisiteCard extends StatelessWidget {
  final ExamPrerequisite prerequisite;
  final String examName;
  final String prerequisiteExamName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _PrerequisiteCard({
    required this.prerequisite, required this.examName, required this.prerequisiteExamName,
    required this.onEdit, required this.onDelete, required this.onToggleActive,
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
            // Prerequisito (da fare PRIMA)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.purple),
                        const SizedBox(width: 4),
                        Text('PRIMA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(prerequisiteExamName, style: context.textStyles.bodyMedium?.bold),
                  ],
                ),
              ),
            ),
            // Freccia + tempo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Icon(Icons.arrow_forward, color: Colors.purple, size: 28),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${prerequisite.timeGapMinutes} min prima', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: prerequisite.isMandatory ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prerequisite.isMandatory ? 'OBBLIGATORIO' : 'Consigliato',
                      style: TextStyle(fontSize: 8, color: prerequisite.isMandatory ? Colors.red : Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Esame principale (da prenotare DOPO)
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
                    Row(
                      children: [
                        Icon(Icons.flag, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('POI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(examName, style: context.textStyles.bodyMedium?.bold),
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
                    color: prerequisite.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(prerequisite.isActive ? 'Attivo' : 'Inattivo', style: TextStyle(fontSize: 11, color: prerequisite.isActive ? Colors.green : Colors.grey)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(prerequisite.isActive ? Icons.toggle_on : Icons.toggle_off, size: 24, color: prerequisite.isActive ? colorScheme.primary : colorScheme.outline), onPressed: onToggleActive, tooltip: prerequisite.isActive ? 'Disattiva' : 'Attiva', visualDensity: VisualDensity.compact),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit, tooltip: 'Modifica', visualDensity: VisualDensity.compact),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20), color: colorScheme.error, onPressed: onDelete, tooltip: 'Elimina', visualDensity: VisualDensity.compact),
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

// ============================================================================
// DIALOGS
// ============================================================================

class ExamCompatibilityDialog extends StatefulWidget {
  final ExamCompatibility? existing;
  final List<ExamType> allExams;
  final String organizationId;

  const ExamCompatibilityDialog({super.key, this.existing, required this.allExams, required this.organizationId});

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona entrambi gli esami'), backgroundColor: Colors.orange));
      return;
    }
    if (_selectedExam1 == _selectedExam2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona due esami diversi'), backgroundColor: Colors.orange));
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
                Text('Esame 1 *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedExam1,
                  decoration: const InputDecoration(hintText: 'Seleziona primo esame'),
                  items: widget.allExams.map((exam) => DropdownMenuItem(value: exam.id, child: Text('${exam.name} (${exam.category.displayName})'))).toList(),
                  onChanged: (v) => setState(() => _selectedExam1 = v),
                ),
                const SizedBox(height: 24),
                Text('Tipo di Compatibilità *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                ...CompatibilityType.values.map((type) => RadioListTile<CompatibilityType>(
                  title: Text(type.displayName),
                  subtitle: Text(type.description, style: context.textStyles.bodySmall),
                  value: type,
                  groupValue: _compatibilityType,
                  onChanged: (v) => setState(() => _compatibilityType = v!),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )),
                const SizedBox(height: 24),
                Text('Esame 2 *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedExam2,
                  decoration: const InputDecoration(hintText: 'Seleziona secondo esame'),
                  items: widget.allExams.map((exam) => DropdownMenuItem(value: exam.id, child: Text('${exam.name} (${exam.category.displayName})'))).toList(),
                  onChanged: (v) => setState(() => _selectedExam2 = v),
                ),
                const SizedBox(height: 24),
                if (_compatibilityType == CompatibilityType.differentRoom) ...[
                  TextFormField(
                    controller: _timeGapCtrl,
                    decoration: const InputDecoration(labelText: 'Intervallo tra esami (minuti)', hintText: 'Es: 20'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Note', hintText: 'Note opzionali'), maxLines: 2),
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

class ExamPrerequisiteDialog extends StatefulWidget {
  final ExamPrerequisite? existing;
  final List<ExamType> allExams;
  final String organizationId;

  const ExamPrerequisiteDialog({super.key, this.existing, required this.allExams, required this.organizationId});

  @override
  State<ExamPrerequisiteDialog> createState() => _ExamPrerequisiteDialogState();
}

class _ExamPrerequisiteDialogState extends State<ExamPrerequisiteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _timeGapCtrl;
  late TextEditingController _notesCtrl;
  
  String? _selectedExam;
  String? _selectedPrerequisiteExam;
  bool _isMandatory = true;

  @override
  void initState() {
    super.initState();
    _selectedExam = widget.existing?.examId;
    _selectedPrerequisiteExam = widget.existing?.prerequisiteExamId;
    _isMandatory = widget.existing?.isMandatory ?? true;
    _timeGapCtrl = TextEditingController(text: widget.existing?.timeGapMinutes.toString() ?? '20');
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
    if (_selectedExam == null || _selectedPrerequisiteExam == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona entrambi gli esami'), backgroundColor: Colors.orange));
      return;
    }
    if (_selectedExam == _selectedPrerequisiteExam) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona due esami diversi'), backgroundColor: Colors.orange));
      return;
    }

    final prereq = ExamPrerequisite(
      id: widget.existing?.id ?? '',
      organizationId: widget.organizationId,
      examId: _selectedExam!,
      prerequisiteExamId: _selectedPrerequisiteExam!,
      timeGapMinutes: int.tryParse(_timeGapCtrl.text) ?? 20,
      isMandatory: _isMandatory,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      isActive: widget.existing?.isActive ?? true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, prereq);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.arrow_forward, color: Colors.purple),
          const SizedBox(width: 8),
          Text(widget.existing != null ? 'Modifica Prerequisito' : 'Nuovo Prerequisito'),
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
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esempio: Se "Ecografia Mammaria" richiede "Mammografia" 20 min prima,\n'
                          '→ Prerequisito = Mammografia\n'
                          '→ Esame Principale = Ecografia Mammaria',
                          style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Esame prerequisito (PRIMA)
                Text('Esame Prerequisito (da fare PRIMA) *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPrerequisiteExam,
                  decoration: InputDecoration(
                    hintText: 'Es: Mammografia',
                    prefixIcon: Icon(Icons.schedule, color: Colors.purple),
                  ),
                  items: widget.allExams.map((exam) => DropdownMenuItem(value: exam.id, child: Text('${exam.name} (${exam.category.displayName})'))).toList(),
                  onChanged: (v) => setState(() => _selectedPrerequisiteExam = v),
                ),
                
                const SizedBox(height: 24),
                
                // Tempo prima
                TextFormField(
                  controller: _timeGapCtrl,
                  decoration: InputDecoration(
                    labelText: 'Minuti prima dell\'esame principale *',
                    hintText: 'Es: 20',
                    prefixIcon: Icon(Icons.timer, color: Colors.purple),
                    suffixText: 'minuti',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Inserisci un valore valido' : null,
                ),
                
                const SizedBox(height: 24),
                
                // Esame principale (POI)
                Text('Esame Principale (da prenotare POI) *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedExam,
                  decoration: InputDecoration(
                    hintText: 'Es: Ecografia Mammaria',
                    prefixIcon: Icon(Icons.flag, color: colorScheme.primary),
                  ),
                  items: widget.allExams.map((exam) => DropdownMenuItem(value: exam.id, child: Text('${exam.name} (${exam.category.displayName})'))).toList(),
                  onChanged: (v) => setState(() => _selectedExam = v),
                ),
                
                const SizedBox(height: 24),
                
                // Obbligatorio o consigliato
                SwitchListTile(
                  title: const Text('Prerequisito Obbligatorio'),
                  subtitle: Text(_isMandatory ? 'L\'utente non può prenotare senza questo esame' : 'Consigliato ma non bloccante'),
                  value: _isMandatory,
                  onChanged: (v) => setState(() => _isMandatory = v),
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Note', hintText: 'Note opzionali'), maxLines: 2),
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
