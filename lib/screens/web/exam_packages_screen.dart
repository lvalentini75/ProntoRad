import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/exam_package_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/theme.dart';

/// Schermata gestione pacchetti esami
class ExamPackagesScreen extends StatefulWidget {
  const ExamPackagesScreen({super.key});

  @override
  State<ExamPackagesScreen> createState() => _ExamPackagesScreenState();
}

class _ExamPackagesScreenState extends State<ExamPackagesScreen> {
  final _service = ExamPackageService();
  final _examService = ExamService();
  
  List<ExamPackage> _packages = [];
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
      
      final packages = await _service.getPackagesForOrganization(orgId);
      final exams = await _examService.getAllExams();
      
      setState(() {
        _packages = packages;
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

  String _getExamNames(List<String> examIds) {
    final names = examIds.map((id) {
      final exam = _allExams.firstWhere(
        (e) => e.id == id,
        orElse: () => ExamType(
          id: id,
          name: 'Esame sconosciuto',
          category: ExamCategory.rm,
          bodyDistrict: BodyDistrict.testa,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return exam.name;
    }).toList();
    return names.join(', ');
  }

  Future<void> _showPackageDialog([ExamPackage? existing]) async {
    final result = await showDialog<ExamPackage>(
      context: context,
      builder: (ctx) => ExamPackageDialog(
        existing: existing,
        allExams: _allExams,
        organizationId: SupabaseAuthManager.instance.cachedProfile?.organizationId ?? '',
      ),
    );
    
    if (result != null) {
      setState(() => _loading = true);
      try {
        if (existing != null) {
          await _service.updatePackage(result);
        } else {
          await _service.createPackage(result);
        }
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(existing != null ? 'Pacchetto aggiornato' : 'Pacchetto creato')),
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

  Future<void> _deletePackage(ExamPackage package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Eliminare il pacchetto "${package.name}"?'),
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
      final success = await _service.deletePackage(package.id);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pacchetto eliminato')),
          );
        }
      }
    }
  }

  Future<void> _exportPackages() async {
    try {
      final orgId = SupabaseAuthManager.instance.cachedProfile?.organizationId;
      if (orgId == null) return;
      
      final json = await _service.exportPackagesToJson(orgId);
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

  Future<void> _importPackages() async {
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
      
      final importResult = await _service.importPackagesFromJson(content, orgId);
      
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
                          Icon(Icons.inventory_2_rounded, color: colorScheme.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pacchetti Esami', style: context.textStyles.titleLarge?.bold),
                                Text(
                                  'Gestisci pacchetti di esami predefiniti per prenotazioni multiple',
                                  style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _importPackages,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Importa'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _packages.isEmpty ? null : _exportPackages,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Esporta'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _showPackageDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nuovo Pacchetto'),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: _packages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text('Nessun pacchetto configurato', style: context.textStyles.titleMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Crea pacchetti per combinare più esami in una singola prenotazione',
                                    style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: AppSpacing.paddingLg,
                              itemCount: _packages.length,
                              itemBuilder: (ctx, i) => _PackageCard(
                                package: _packages[i],
                                examNames: _getExamNames(_packages[i].examIds),
                                onEdit: () => _showPackageDialog(_packages[i]),
                                onDelete: () => _deletePackage(_packages[i]),
                                onToggleActive: () async {
                                  final updated = _packages[i].copyWith(isActive: !_packages[i].isActive);
                                  await _service.updatePackage(updated);
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

class _PackageCard extends StatelessWidget {
  final ExamPackage package;
  final String examNames;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _PackageCard({
    required this.package,
    required this.examNames,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(package.name, style: context.textStyles.titleMedium?.bold),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: package.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              package.isActive ? 'Attivo' : 'Inattivo',
                              style: context.textStyles.labelSmall?.withColor(
                                package.isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (package.description.isNotEmpty)
                        Text(
                          package.description,
                          style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(package.isActive ? Icons.toggle_on : Icons.toggle_off, 
                    size: 32, 
                    color: package.isActive ? colorScheme.primary : colorScheme.outline,
                  ),
                  onPressed: onToggleActive,
                  tooltip: package.isActive ? 'Disattiva' : 'Attiva',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Modifica',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: colorScheme.error,
                  onPressed: onDelete,
                  tooltip: 'Elimina',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.medical_services_outlined,
                  label: '${package.examIds.length} esami',
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: '${package.totalDurationMinutes} min',
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: package.isCumulative ? Icons.add : Icons.compare_arrows,
                  label: package.isCumulative ? 'Tempi sommati' : 'Slot singolo',
                  color: colorScheme.primary,
                ),
                if (package.packagePrice != null) ...[
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.euro,
                    label: '€${package.packagePrice!.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Esami: $examNames',
              style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Dialog per creare/modificare un pacchetto
class ExamPackageDialog extends StatefulWidget {
  final ExamPackage? existing;
  final List<ExamType> allExams;
  final String organizationId;

  const ExamPackageDialog({
    super.key,
    this.existing,
    required this.allExams,
    required this.organizationId,
  });

  @override
  State<ExamPackageDialog> createState() => _ExamPackageDialogState();
}

class _ExamPackageDialogState extends State<ExamPackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priceCtrl;
  
  List<String> _selectedExamIds = [];
  bool _isCumulative = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _durationCtrl = TextEditingController(text: widget.existing?.totalDurationMinutes.toString() ?? '30');
    _priceCtrl = TextEditingController(text: widget.existing?.packagePrice?.toString() ?? '');
    _selectedExamIds = List.from(widget.existing?.examIds ?? []);
    _isCumulative = widget.existing?.isCumulative ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExamIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un esame'), backgroundColor: Colors.orange),
      );
      return;
    }

    final package = ExamPackage(
      id: widget.existing?.id ?? '',
      organizationId: widget.organizationId,
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      examIds: _selectedExamIds,
      totalDurationMinutes: int.tryParse(_durationCtrl.text) ?? 30,
      isCumulative: _isCumulative,
      packagePrice: _priceCtrl.text.isNotEmpty ? double.tryParse(_priceCtrl.text) : null,
      isActive: widget.existing?.isActive ?? true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, package);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Raggruppa esami per categoria
    final examsByCategory = <ExamCategory, List<ExamType>>{};
    for (final exam in widget.allExams) {
      examsByCategory.putIfAbsent(exam.category, () => []).add(exam);
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(widget.existing != null ? 'Modifica Pacchetto' : 'Nuovo Pacchetto'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome pacchetto *',
                    hintText: 'Es: RM Colonna Completa',
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    hintText: 'Descrizione opzionale del pacchetto',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                // Selezione esami
                Text('Esami inclusi *', style: context.textStyles.titleSmall?.bold),
                const SizedBox(height: 8),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    children: examsByCategory.entries.map((entry) {
                      return ExpansionTile(
                        title: Text(entry.key.displayName),
                        initiallyExpanded: true,
                        children: entry.value.map((exam) {
                          final isSelected = _selectedExamIds.contains(exam.id);
                          return CheckboxListTile(
                            title: Text(exam.name),
                            subtitle: Text(exam.bodyDistrict.displayName, style: context.textStyles.bodySmall),
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedExamIds.add(exam.id);
                                } else {
                                  _selectedExamIds.remove(exam.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_selectedExamIds.length} esami selezionati',
                  style: context.textStyles.bodySmall?.withColor(colorScheme.primary),
                ),
                
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Durata totale (minuti) *',
                          hintText: '30',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Campo obbligatorio';
                          if (int.tryParse(v!) == null) return 'Numero non valido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prezzo pacchetto (€)',
                          hintText: 'Opzionale',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Tempi cumulativi'),
                  subtitle: Text(
                    _isCumulative 
                        ? 'I tempi degli esami vengono sommati' 
                        : 'Gli esami usano lo slot più lungo (es. TAC multi-distretto)',
                    style: context.textStyles.bodySmall,
                  ),
                  value: _isCumulative,
                  onChanged: (v) => setState(() => _isCumulative = v),
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
