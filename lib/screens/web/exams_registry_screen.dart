import 'package:flutter/material.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/standard_tariff.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/services/standard_tariff_service.dart';
import 'package:xraynow/theme.dart';

/// Anagrafiche screen with tabs for Esami, Clienti, Istituti
class ExamsRegistryScreen extends StatefulWidget {
  const ExamsRegistryScreen({super.key});

  @override
  State<ExamsRegistryScreen> createState() => _ExamsRegistryScreenState();
}

class _ExamsRegistryScreenState extends State<ExamsRegistryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Row(
              children: [
                Icon(Icons.medical_information_outlined,
                    size: 28, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text('Anagrafiche',
                    style: context.textStyles.headlineMedium?.bold),
              ],
            ),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A3340)
                      : const Color(0xFFE8EDF2),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: context.textStyles.titleSmall?.semiBold,
              unselectedLabelStyle: context.textStyles.titleSmall,
              tabs: const [
                Tab(text: 'Esami'),
                Tab(text: 'Tariffario'),
                Tab(text: 'Clienti'),
                Tab(text: 'Istituti'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ExamsTabContent(),
                TariffTabContent(),
                _PlaceholderTab(
                  title: 'Clienti',
                  description: 'Gestione anagrafica clienti in arrivo...',
                  icon: Icons.people_rounded,
                ),
                _PlaceholderTab(
                  title: 'Istituti',
                  description: 'Gestione anagrafica istituti in arrivo...',
                  icon: Icons.business_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exams tab content with CRUD operations
class ExamsTabContent extends StatefulWidget {
  const ExamsTabContent({super.key});

  @override
  State<ExamsTabContent> createState() => _ExamsTabContentState();
}

class _ExamsTabContentState extends State<ExamsTabContent> {
  final ExamService _examService = ExamService();
  final TextEditingController _searchController = TextEditingController();

  List<ExamType> _exams = [];
  List<ExamType> _filteredExams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
    _searchController.addListener(_filterExams);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exams = await _examService.getAllExams();
      if (mounted) {
        setState(() {
          _exams = exams;
          _filteredExams = exams;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore nel caricamento degli esami: $e';
          _loading = false;
        });
      }
    }
  }

  void _filterExams() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredExams = _exams;
      } else {
        _filteredExams = _exams.where((exam) {
          return exam.name.toLowerCase().contains(query) ||
              exam.category.displayName.toLowerCase().contains(query) ||
              exam.bodyDistrict.displayName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _showExamDialog({ExamType? exam}) async {
    final result = await showDialog<ExamType>(
      context: context,
      builder: (context) => ExamFormDialog(exam: exam),
    );

    if (result != null) {
      try {
        if (exam == null) {
          await _examService.createExam(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Esame creato con successo')),
            );
          }
        } else {
          await _examService.updateExam(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Esame aggiornato con successo')),
            );
          }
        }
        _loadExams();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nel salvataggio esame: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteExam(ExamType exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Vuoi eliminare l\'esame "${exam.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _examService.deleteExam(exam.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Esame eliminato con successo')),
          );
        }
        _loadExams();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nell\'eliminazione: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Top bar with count, search, and actions
          Row(
            children: [
              Icon(Icons.format_list_bulleted_rounded,
                  size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Esami (${_filteredExams.length})',
                style: context.textStyles.titleMedium?.semiBold,
              ),
              const Spacer(),

              // Search field
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca esami...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF2A3340)
                            : const Color(0xFFE8EDF2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF2A3340)
                            : const Color(0xFFE8EDF2),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // New exam button
              FilledButton.icon(
                onPressed: () => _showExamDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuovo esame'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),

              // Refresh button
              OutlinedButton.icon(
                onPressed: _loadExams,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Aggiorna'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Exams list
          Expanded(
            child: _buildContent(isDark, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadExams,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_filteredExams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined,
                size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Nessun esame presente'
                  : 'Nessun esame trovato',
              style: context.textStyles.titleMedium
                  ?.withColor(colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'Crea il primo esame per iniziare'
                  : 'Prova con altri termini di ricerca',
              style: context.textStyles.bodyMedium
                  ?.withColor(colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          itemCount: _filteredExams.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
          ),
          itemBuilder: (context, index) {
            final exam = _filteredExams[index];
            return ExamListTile(
              exam: exam,
              onEdit: () => _showExamDialog(exam: exam),
              onDelete: () => _deleteExam(exam),
            );
          },
        ),
      ),
    );
  }
}

/// Single exam list tile
class ExamListTile extends StatelessWidget {
  final ExamType exam;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExamListTile({
    super.key,
    required this.exam,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _getCategoryIcon(ExamCategory category) {
    switch (category) {
      case ExamCategory.rm:
        return Icons.blur_circular;
      case ExamCategory.tac:
        return Icons.donut_large;
      case ExamCategory.eco:
        return Icons.waves;
      case ExamCategory.rx:
        return Icons.image;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr =
        '${exam.updatedAt.year}-${exam.updatedAt.month.toString().padLeft(2, '0')}-${exam.updatedAt.day.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getCategoryIcon(exam.category),
          color: colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        exam.name,
        style: context.textStyles.bodyLarge?.semiBold,
      ),
      subtitle: Text(
        '${exam.category.displayName} · ${exam.bodyDistrict.displayName}',
        style: context.textStyles.bodySmall
            ?.withColor(colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateStr,
            style: context.textStyles.bodySmall
                ?.withColor(colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined,
                size: 20, color: colorScheme.onSurfaceVariant),
            tooltip: 'Modifica',
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline,
                size: 20, color: colorScheme.error),
            tooltip: 'Elimina',
          ),
        ],
      ),
    );
  }
}

/// Form dialog for creating/editing exams
class ExamFormDialog extends StatefulWidget {
  final ExamType? exam;

  const ExamFormDialog({super.key, this.exam});

  @override
  State<ExamFormDialog> createState() => _ExamFormDialogState();
}

class _ExamFormDialogState extends State<ExamFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late ExamCategory _selectedCategory;
  late BodyDistrict _selectedBodyDistrict;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exam?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.exam?.description ?? '');
    _selectedCategory = widget.exam?.category ?? ExamCategory.rx;
    _selectedBodyDistrict = widget.exam?.bodyDistrict ?? BodyDistrict.torace;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final exam = ExamType(
        id: widget.exam?.id ?? '',
        name: _nameController.text.trim(),
        category: _selectedCategory,
        bodyDistrict: _selectedBodyDistrict,
        description: _descriptionController.text.trim(),
        createdAt: widget.exam?.createdAt ?? now,
        updatedAt: now,
      );
      Navigator.pop(context, exam);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exam != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifica Esame' : 'Nuovo Esame'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome esame *',
                  hintText: 'es. RM Cervello',
                ),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Campo obbligatorio' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // Category dropdown
              DropdownButtonFormField<ExamCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Macro categoria *',
                ),
                items: ExamCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Body district dropdown
              DropdownButtonFormField<BodyDistrict>(
                value: _selectedBodyDistrict,
                decoration: const InputDecoration(
                  labelText: 'Distretto corporeo *',
                ),
                items: BodyDistrict.values
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedBodyDistrict = value);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  hintText: 'Descrizione opzionale dell\'esame',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Salva' : 'Crea'),
        ),
      ],
    );
  }
}

/// Tariff tab content for managing standard prices
class TariffTabContent extends StatefulWidget {
  const TariffTabContent({super.key});

  @override
  State<TariffTabContent> createState() => _TariffTabContentState();
}

class _TariffTabContentState extends State<TariffTabContent> {
  final ExamService _examService = ExamService();
  final StandardTariffService _tariffService = StandardTariffService();
  final TextEditingController _searchController = TextEditingController();

  List<ExamType> _exams = [];
  List<ExamType> _filteredExams = [];
  Map<String, StandardTariff> _tariffMap = {};
  bool _loading = true;
  String? _error;
  ExamCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterExams);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _examService.getAllExams(),
        _tariffService.getAllAsMap(),
      ]);
      
      if (mounted) {
        setState(() {
          _exams = results[0] as List<ExamType>;
          _filteredExams = _exams;
          _tariffMap = results[1] as Map<String, StandardTariff>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore nel caricamento: $e';
          _loading = false;
        });
      }
    }
  }

  void _filterExams() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExams = _exams.where((exam) {
        final matchesQuery = query.isEmpty ||
            exam.name.toLowerCase().contains(query) ||
            exam.category.displayName.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == null || 
            exam.category == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  Future<void> _showTariffDialog(ExamType exam) async {
    final currentTariff = _tariffMap[exam.id];
    final result = await showDialog<double>(
      context: context,
      builder: (context) => TariffFormDialog(
        exam: exam,
        currentPrice: currentTariff?.price,
      ),
    );

    if (result != null) {
      try {
        await _tariffService.upsert(
          examTypeId: exam.id,
          price: result,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tariffa aggiornata con successo')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nel salvataggio: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTariff(ExamType exam) async {
    final tariff = _tariffMap[exam.id];
    if (tariff == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Vuoi rimuovere la tariffa standard per "${exam.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tariffService.delete(tariff.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tariffa eliminata con successo')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nell\'eliminazione: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Top bar with filters and actions
          Row(
            children: [
              Icon(Icons.euro_rounded,
                  size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Tariffario Standard',
                style: context.textStyles.titleMedium?.semiBold,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_tariffMap.length} prezzi definiti',
                  style: context.textStyles.labelSmall?.withColor(colorScheme.onPrimaryContainer),
                ),
              ),
              const Spacer(),

              // Category filter
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<ExamCategory?>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    hintText: 'Categoria',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutte')),
                    ...ExamCategory.values.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.displayName),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                    _filterExams();
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Search field
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca esami...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Refresh button
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Aggiorna'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Queste sono le tariffe standard di sistema. Ogni ospedale potrà personalizzare i propri prezzi.',
                    style: context.textStyles.bodySmall?.withColor(colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tariff list
          Expanded(
            child: _buildContent(isDark, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_filteredExams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.euro_outlined,
                size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Nessun esame trovato',
              style: context.textStyles.titleMedium?.withColor(colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Prima crea gli esami nella tab "Esami"',
              style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Group exams by category
    final groupedExams = <ExamCategory, List<ExamType>>{};
    for (final exam in _filteredExams) {
      groupedExams.putIfAbsent(exam.category, () => []).add(exam);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          itemCount: groupedExams.length,
          itemBuilder: (context, index) {
            final category = groupedExams.keys.elementAt(index);
            final exams = groupedExams[category]!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(category), size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        category.displayName,
                        style: context.textStyles.titleSmall?.semiBold.withColor(colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${exams.length})',
                        style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Exam items
                ...exams.map((exam) => TariffListTile(
                  exam: exam,
                  tariff: _tariffMap[exam.id],
                  onEdit: () => _showTariffDialog(exam),
                  onDelete: _tariffMap[exam.id] != null ? () => _deleteTariff(exam) : null,
                )),
                if (index < groupedExams.length - 1)
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ExamCategory category) {
    switch (category) {
      case ExamCategory.rm:
        return Icons.blur_circular;
      case ExamCategory.tac:
        return Icons.donut_large;
      case ExamCategory.eco:
        return Icons.waves;
      case ExamCategory.rx:
        return Icons.image;
    }
  }
}

/// Single tariff list tile
class TariffListTile extends StatelessWidget {
  final ExamType exam;
  final StandardTariff? tariff;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const TariffListTile({
    super.key,
    required this.exam,
    this.tariff,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPrice = tariff != null && tariff!.price > 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        title: Text(
          exam.name,
          style: context.textStyles.bodyMedium?.semiBold,
        ),
        subtitle: Text(
          exam.bodyDistrict.displayName,
          style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price display
            Container(
              constraints: const BoxConstraints(minWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: hasPrice
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasPrice
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                hasPrice ? '€ ${tariff!.price.toStringAsFixed(2)}' : 'Non definito',
                style: context.textStyles.bodyMedium?.semiBold.withColor(
                  hasPrice ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            
            // Edit button
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                hasPrice ? Icons.edit_outlined : Icons.add_circle_outline,
                size: 20,
                color: hasPrice ? colorScheme.onSurfaceVariant : colorScheme.primary,
              ),
              tooltip: hasPrice ? 'Modifica prezzo' : 'Imposta prezzo',
            ),
            
            // Delete button (only if has price)
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                tooltip: 'Rimuovi prezzo',
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for setting/editing a tariff price
class TariffFormDialog extends StatefulWidget {
  final ExamType exam;
  final double? currentPrice;

  const TariffFormDialog({
    super.key,
    required this.exam,
    this.currentPrice,
  });

  @override
  State<TariffFormDialog> createState() => _TariffFormDialogState();
}

class _TariffFormDialogState extends State<TariffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.currentPrice?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
      Navigator.pop(context, price);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.currentPrice != null;

    return AlertDialog(
      title: Text(isEditing ? 'Modifica Tariffa' : 'Imposta Tariffa'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exam.name,
                            style: context.textStyles.bodyLarge?.semiBold,
                          ),
                          Text(
                            '${widget.exam.category.displayName} · ${widget.exam.bodyDistrict.displayName}',
                            style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Price input
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prezzo standard *',
                  hintText: '0.00',
                  prefixText: '€ ',
                  suffixText: 'EUR',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci un prezzo';
                  }
                  final price = double.tryParse(value.replaceAll(',', '.'));
                  if (price == null || price < 0) {
                    return 'Prezzo non valido';
                  }
                  return null;
                },
                autofocus: true,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),

              // Info text
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Questo sarà il prezzo base. Gli ospedali potranno personalizzarlo.',
                      style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Salva' : 'Imposta'),
        ),
      ],
    );
  }
}

/// Placeholder tab for features not yet implemented
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.textStyles.titleLarge?.semiBold
                .withColor(colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: context.textStyles.bodyMedium
                ?.withColor(colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
