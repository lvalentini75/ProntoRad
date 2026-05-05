import 'package:flutter/material.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/standard_tariff.dart';
import 'package:xraynow/models/tariff.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/services/standard_tariff_service.dart';
import 'package:xraynow/services/tariff_service.dart';
import 'package:xraynow/theme.dart';
import 'package:flutter/foundation.dart';

/// Schermata di gestione tariffe
/// - Super Admin: gestisce tariffe standard di sistema
/// - Org Admin: gestisce tariffe personalizzate della propria organizzazione
class TariffsManagementScreen extends StatefulWidget {
  const TariffsManagementScreen({super.key});

  @override
  State<TariffsManagementScreen> createState() => _TariffsManagementScreenState();
}

class _TariffsManagementScreenState extends State<TariffsManagementScreen> {
  final _examService = ExamService();
  final _standardTariffService = StandardTariffService();
  final _tariffService = TariffService();

  bool _loading = true;
  List<ExamType> _exams = [];
  Map<String, StandardTariff> _standardTariffs = {};
  Map<String, Tariff> _customTariffs = {};
  ExamCategory? _selectedCategory;
  String _searchQuery = '';

  bool get _isSuperAdmin => SupabaseAuthManager.instance.cachedProfile?.role == 'super_admin';
  String? get _organizationId => SupabaseAuthManager.instance.cachedProfile?.organizationId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      
      // Carica esami
      final exams = await _examService.getAllExams();
      
      // Carica tariffe in base al ruolo
      if (_isSuperAdmin) {
        final stdTariffs = await _standardTariffService.getAllAsMap();
        if (mounted) {
          setState(() {
            _exams = exams;
            _standardTariffs = stdTariffs;
            _loading = false;
          });
        }
      } else {
        if (_organizationId == null) {
          debugPrint('[TariffsManagement] ❌ No organization ID for org_admin');
          if (mounted) setState(() => _loading = false);
          return;
        }
        
        final orgTariffs = await _tariffService.getTariffsForOrganization(_organizationId!);
        final orgTariffsMap = {for (var t in orgTariffs) t.examTypeId: t};
        
        // Carica anche tariffe standard per mostrare i default
        final stdTariffs = await _standardTariffService.getAllAsMap();
        
        if (mounted) {
          setState(() {
            _exams = exams;
            _customTariffs = orgTariffsMap;
            _standardTariffs = stdTariffs;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[TariffsManagement] ❌ Error loading data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ExamType> get _filteredExams {
    var filtered = _exams;
    
    if (_selectedCategory != null) {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) => 
        e.name.toLowerCase().contains(query) ||
        e.description.toLowerCase().contains(query)
      ).toList();
    }
    
    return filtered;
  }

  Future<void> _editTariff(ExamType exam, double? currentPrice) async {
    final controller = TextEditingController(
      text: currentPrice?.toStringAsFixed(2) ?? ''
    );
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => _TariffEditDialog(
        exam: exam,
        controller: controller,
        isSuperAdmin: _isSuperAdmin,
      ),
    );
    
    if (result != null) {
      await _saveTariff(exam.id, result);
    }
  }

  Future<void> _saveTariff(String examTypeId, double price) async {
    try {
      if (_isSuperAdmin) {
        await _standardTariffService.upsert(
          examTypeId: examTypeId,
          price: price,
        );
      } else {
        if (_organizationId == null) return;
        await _tariffService.upsertTariff(
          organizationId: _organizationId!,
          examTypeId: examTypeId,
          price: price,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tariffa salvata con successo')),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('[TariffsManagement] ❌ Error saving tariff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
      }
    }
  }

  Future<void> _deleteTariff(String examTypeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text('Sei sicuro di voler eliminare questa tariffa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      if (_isSuperAdmin) {
        await _standardTariffService.deleteByExamTypeId(examTypeId);
      } else {
        final tariff = _customTariffs[examTypeId];
        if (tariff != null) {
          await _tariffService.deleteTariff(tariff.id);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tariffa eliminata')),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('[TariffsManagement] ❌ Error deleting tariff: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        children: [
          // Header
          Container(
            padding: AppSpacing.paddingLg,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8EDF2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.euro_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSuperAdmin ? 'Tariffari Standard' : 'Tariffari Personalizzati',
                            style: context.textStyles.headlineSmall?.bold,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSuperAdmin 
                              ? 'Gestisci le tariffe di sistema per tutti gli esami'
                              : 'Personalizza i prezzi degli esami per la tua struttura',
                            style: context.textStyles.bodyMedium?.withColor(Colors.grey[600]!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Filtri
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca esame...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<ExamCategory>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE8EDF2)),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tutte')),
                          ...ExamCategory.values.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(_getCategoryLabel(cat)),
                          )),
                        ],
                        onChanged: (value) => setState(() => _selectedCategory = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredExams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun esame trovato',
                          style: context.textStyles.titleMedium?.withColor(Colors.grey[600]!),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: AppSpacing.paddingLg,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8EDF2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text('Esame', style: context.textStyles.labelLarge?.bold),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Categoria', style: context.textStyles.labelLarge?.bold),
                                ),
                                if (!_isSuperAdmin) ...[
                                  Expanded(
                                    child: Text('Std', style: context.textStyles.labelLarge?.bold, textAlign: TextAlign.right),
                                  ),
                                ],
                                Expanded(
                                  child: Text('Prezzo', style: context.textStyles.labelLarge?.bold, textAlign: TextAlign.right),
                                ),
                                const SizedBox(width: 100),
                              ],
                            ),
                          ),
                          // Table rows
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredExams.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final exam = _filteredExams[index];
                              final stdTariff = _standardTariffs[exam.id];
                              final customTariff = _customTariffs[exam.id];
                              
                              final currentPrice = _isSuperAdmin 
                                ? stdTariff?.price 
                                : customTariff?.price;
                              
                              return _TariffRow(
                                exam: exam,
                                standardPrice: stdTariff?.price,
                                currentPrice: currentPrice,
                                isSuperAdmin: _isSuperAdmin,
                                onEdit: () => _editTariff(exam, currentPrice),
                                onDelete: currentPrice != null 
                                  ? () => _deleteTariff(exam.id) 
                                  : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(ExamCategory category) {
    switch (category) {
      case ExamCategory.rx: return 'Radiografia';
      case ExamCategory.tac: return 'TAC';
      case ExamCategory.rm: return 'Risonanza Magnetica';
      case ExamCategory.eco: return 'Ecografia';
    }
  }
}

class _TariffRow extends StatelessWidget {
  final ExamType exam;
  final double? standardPrice;
  final double? currentPrice;
  final bool isSuperAdmin;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _TariffRow({
    required this.exam,
    this.standardPrice,
    this.currentPrice,
    required this.isSuperAdmin,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomPrice = !isSuperAdmin && currentPrice != null;
    final displayPrice = currentPrice ?? standardPrice;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Nome esame
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.name, style: context.textStyles.bodyLarge?.medium),
                if (exam.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exam.description,
                    style: context.textStyles.bodySmall?.withColor(Colors.grey[600]!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          
          // Categoria
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getCategoryColor(exam.category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getCategoryLabel(exam.category),
                style: context.textStyles.labelMedium?.withColor(_getCategoryColor(exam.category)),
              ),
            ),
          ),
          
          // Prezzo standard (solo per org_admin)
          if (!isSuperAdmin) ...[
            Expanded(
              child: Text(
                standardPrice != null ? '€${standardPrice!.toStringAsFixed(2)}' : '-',
                style: context.textStyles.bodyMedium?.withColor(Colors.grey[500]!),
                textAlign: TextAlign.right,
              ),
            ),
          ],
          
          // Prezzo corrente/personalizzato
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasCustomPrice)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Custom',
                      style: context.textStyles.labelSmall?.withColor(
                        Theme.of(context).colorScheme.primary
                      ),
                    ),
                  ),
                Text(
                  displayPrice != null ? '€${displayPrice.toStringAsFixed(2)}' : '-',
                  style: context.textStyles.titleMedium?.bold,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          
          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(currentPrice != null ? Icons.edit_rounded : Icons.add_rounded),
                  onPressed: onEdit,
                  tooltip: currentPrice != null ? 'Modifica' : 'Aggiungi',
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: onDelete,
                    tooltip: 'Elimina',
                    color: Colors.red,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(ExamCategory category) {
    switch (category) {
      case ExamCategory.rx: return 'RX';
      case ExamCategory.tac: return 'TAC';
      case ExamCategory.rm: return 'RM';
      case ExamCategory.eco: return 'ECO';
    }
  }

  Color _getCategoryColor(ExamCategory category) {
    switch (category) {
      case ExamCategory.rx: return Colors.blue;
      case ExamCategory.tac: return Colors.purple;
      case ExamCategory.rm: return Colors.indigo;
      case ExamCategory.eco: return Colors.teal;
    }
  }
}

class _TariffEditDialog extends StatelessWidget {
  final ExamType exam;
  final TextEditingController controller;
  final bool isSuperAdmin;

  const _TariffEditDialog({
    required this.exam,
    required this.controller,
    required this.isSuperAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isSuperAdmin ? 'Tariffa Standard' : 'Tariffa Personalizzata'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exam.name, style: context.textStyles.titleMedium?.bold),
          const SizedBox(height: 8),
          Text(
            exam.description,
            style: context.textStyles.bodySmall?.withColor(Colors.grey[600]!),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Prezzo (€)',
              prefixIcon: const Icon(Icons.euro_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final price = double.tryParse(controller.text);
            if (price != null && price >= 0) {
              Navigator.pop(context, price);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inserisci un prezzo valido')),
              );
            }
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
