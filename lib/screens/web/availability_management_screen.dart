import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/availability_slot.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/availability_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/services/debug_log_service.dart';
import 'package:xraynow/theme.dart';

/// Gestione disponibilità temporali - RISCRITTA DA ZERO per risolvere i problemi di loading
class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() => _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState extends State<AvailabilityManagementScreen> {
  final _availabilityService = AvailabilityService();
  final _examService = ExamService();
  final _debugLog = DebugLogService();
  
  // State management
  LoadingState _loadingState = LoadingState.idle;
  List<ExamType> _exams = [];
  List<AvailabilitySlot> _allSlots = [];
  String? _errorMessage;
  
  // UI state
  bool _isSingleMode = false; // false = Ricorrente, true = Singolo
  String? _selectedExamCategory; // RM, TAC, ECO, RX
  int _calendarYear = DateTime.now().year;
  
  @override
  void initState() {
    super.initState();
    _debugLog.info('AvailabilityManagement', '🔄 initState chiamato');
    _loadInitialData();
  }
  
  /// Carica i dati iniziali - chiamato solo all'avvio
  Future<void> _loadInitialData() async {
    await _loadData();
  }
  
  /// Ricarica i dati - può essere chiamato dopo operazioni CRUD
  Future<void> _reloadData() async {
    _debugLog.info('AvailabilityManagement', '🔄 Reload richiesto');
    await _loadData();
  }
  
  /// Metodo principale di caricamento dati
  Future<void> _loadData() async {
    if (!mounted) {
      _debugLog.warning('AvailabilityManagement', '⚠️ Widget non mounted, skip loading');
      return;
    }
    
    // Previeni caricamenti multipli simultanei
    if (_loadingState == LoadingState.loading) {
      _debugLog.warning('AvailabilityManagement', '⚠️ Caricamento già in corso, skip');
      return;
    }
    
    _debugLog.info('AvailabilityManagement', '📋 Inizio caricamento dati (anno: $_calendarYear)');
    setState(() {
      _loadingState = LoadingState.loading;
      _errorMessage = null;
    });
    
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final org = SupabaseAuthManager.instance.cachedOrganization;
      
      if (profile == null || org == null) {
        throw Exception('Profilo o organizzazione mancanti');
      }
      
      final orgId = org['id'] as String;
      
      // Carica esami
      final exams = await _examService.getAllExams();
      _debugLog.info('AvailabilityManagement', '✅ Caricati ${exams.length} esami');
      
      // Carica slot dell'anno corrente (ottimizzato)
      final yearStart = DateTime(_calendarYear, 1, 1);
      final yearEnd = DateTime(_calendarYear, 12, 31, 23, 59, 59);
      
      final slots = await _availabilityService.getAllSlotsForOrganization(
        orgId,
        staffUserId: profile.id,
        startDate: yearStart,
        endDate: yearEnd,
      );
      _debugLog.info('AvailabilityManagement', '✅ Caricati ${slots.length} slot');
      
      if (mounted) {
        setState(() {
          _exams = exams;
          _allSlots = slots;
          _loadingState = LoadingState.success;
        });
        _debugLog.info('AvailabilityManagement', '✅ State aggiornato con successo');
      }
    } catch (e, stack) {
      _debugLog.error('AvailabilityManagement', '❌ Errore caricamento', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  /// Cambia anno e ricarica
  void _changeYear(int delta) {
    if (_loadingState == LoadingState.loading) return;
    
    setState(() {
      _calendarYear += delta;
    });
    // Piccolo delay per feedback visivo
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _loadData();
    });
  }
  
  /// Chiamato quando viene creato un nuovo slot (singolo o batch)
  void _onSlotCreated() {
    _debugLog.info('AvailabilityManagement', '🆕 Slot creato, triggering reload...');
    _reloadData();
  }
  
  Map<DateTime, int> _getSlotCountsByDay() {
    final counts = <DateTime, int>{};
    for (final slot in _allSlots) {
      if (_selectedExamCategory != null && !_matchesCategory(slot)) continue;
      final day = DateTime(slot.startTime.year, slot.startTime.month, slot.startTime.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }
  
  bool _matchesCategory(AvailabilitySlot slot) {
    if (slot.examCategory != null) {
      return slot.examCategory!.toUpperCase() == _selectedExamCategory?.toUpperCase();
    }
    if (slot.examId != null && slot.examId!.isNotEmpty) {
      final exam = _exams.firstWhere((e) => e.id == slot.examId, orElse: () => _exams.first);
      final category = _getExamCategoryFromName(exam.name);
      return category.toUpperCase() == _selectedExamCategory?.toUpperCase();
    }
    return false;
  }
  
  String _getExamCategoryFromName(String examName) {
    if (examName.contains('RM') || examName.contains('Risonanza')) return 'RM';
    if (examName.contains('TAC') || examName.contains('TC')) return 'TAC';
    if (examName.contains('ECO') || examName.contains('Eco')) return 'ECO';
    if (examName.contains('RX') || examName.contains('Radiografia')) return 'RX';
    return 'RX';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Disponibilità', style: context.textStyles.titleLarge?.bold),
                Builder(
                  builder: (context) {
                    final org = SupabaseAuthManager.instance.cachedOrganization;
                    final orgName = org != null ? (org['name'] as String?) ?? 'Organizzazione sconosciuta' : 'NESSUNA ORGANIZZAZIONE';
                    final hasOrg = org != null;
                    return Text(
                      orgName, 
                      style: context.textStyles.labelSmall?.copyWith(
                        color: hasOrg ? Colors.grey.shade600 : Colors.red,
                        fontWeight: hasOrg ? FontWeight.normal : FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDebugLogs,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.bug_report, color: Colors.white),
        label: const Text('Log Debug', style: TextStyle(color: Colors.white)),
      ),
    );
  }
  
  Widget _buildBody() {
    switch (_loadingState) {
      case LoadingState.idle:
      case LoadingState.loading:
        return const Center(child: CircularProgressIndicator());
      
      case LoadingState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Errore caricamento', style: context.textStyles.titleMedium?.bold),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'Errore sconosciuto'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _reloadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        );
      
      case LoadingState.success:
        final profile = SupabaseAuthManager.instance.cachedProfile;
        final org = SupabaseAuthManager.instance.cachedOrganization;
        final hasValidPermissions = profile != null && 
                                    org != null && 
                                    (profile.role == 'org_admin' || profile.role == 'super_admin') &&
                                    (profile.organizationId == (org['id'] as String?) || profile.role == 'super_admin');
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning banner se l'utente non ha permessi corretti
              if (!hasValidPermissions) ...[
                Container(
                  margin: AppSpacing.paddingMd,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ PERMESSI INSUFFICIENTI',
                              style: context.textStyles.titleSmall?.bold.withColor(Colors.red.shade900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile == null 
                                ? 'Profilo utente non caricato.' 
                                : org == null 
                                  ? 'Nessuna organizzazione associata al tuo account.'
                                  : profile.role == 'end_user'
                                    ? 'Il tuo ruolo (${profile.role}) non ha permessi per creare slot. Contatta un amministratore.'
                                    : 'L\'organizzazione del tuo profilo non coincide con quella selezionata.',
                              style: context.textStyles.bodySmall?.withColor(Colors.red.shade800),
                            ),
                            if (profile != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Email: ${profile.email} | Ruolo: ${profile.role} | Org ID: ${profile.organizationId ?? "NESSUNA"}',
                                style: context.textStyles.labelSmall?.withColor(Colors.red.shade700),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildCreationSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildCalendarSection(),
            ],
          ),
        );
    }
  }
  
  Widget _buildCreationSection() {
    return Container(
      margin: AppSpacing.paddingMd,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Crea disponibilità', style: context.textStyles.titleMedium?.bold),
          const SizedBox(height: AppSpacing.md),
          
          // Tab: Singolo / Ricorrente
          Row(
            children: [
              _buildModeTab('Singolo', true, Icons.event),
              const SizedBox(width: AppSpacing.sm),
              _buildModeTab('Ricorrente', false, Icons.event_repeat),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Form
          if (!_isSingleMode) 
            RecurringAvailabilityCreator(
              exams: _exams,
              onSuccess: _onSlotCreated,
            )
          else 
            SingleAvailabilityCreator(
              exams: _exams,
              onSuccess: _onSlotCreated,
            ),
        ],
      ),
    );
  }
  
  Widget _buildModeTab(String label, bool isSingle, IconData icon) {
    final isActive = _isSingleMode == isSingle;
    return InkWell(
      onTap: () => setState(() => _isSingleMode = isSingle),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? LightModeColors.lightPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.textStyles.labelLarge?.copyWith(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalendarSection() {
    return Container(
      margin: AppSpacing.paddingMd,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Macro calendario per categoria', style: context.textStyles.titleMedium?.bold),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          _buildCategoryFilters(),
          const SizedBox(height: AppSpacing.lg),
          
          _buildMultiMonthCalendar(),
        ],
      ),
    );
  }
  
  Widget _buildCategoryFilters() {
    // Calcola conteggi per categoria
    final categoryCounts = <String, int>{};
    for (final slot in _allSlots) {
      if (slot.startTime.year != _calendarYear) continue;
      String? cat = slot.examCategory?.toUpperCase();
      if (cat == null && slot.examId != null) {
        final exam = _exams.firstWhere((e) => e.id == slot.examId, orElse: () => _exams.first);
        cat = _getExamCategoryFromName(exam.name);
      }
      if (cat != null) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildCategoryPillWithCount('RM', LightModeColors.rmColor, categoryCounts['RM'] ?? 0),
            const SizedBox(width: 6),
            _buildCategoryPillWithCount('TAC', LightModeColors.tacColor, categoryCounts['TAC'] ?? 0),
            const SizedBox(width: 6),
            _buildCategoryPillWithCount('ECO', LightModeColors.ecoColor, categoryCounts['ECO'] ?? 0),
            const SizedBox(width: 6),
            _buildCategoryPillWithCount('RX', LightModeColors.rxColor, categoryCounts['RX'] ?? 0),
          ],
        ),
        if (categoryCounts.values.every((c) => c == 0)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nessuno slot creato per il $_calendarYear. Usa il form sopra per creare disponibilità.',
                    style: context.textStyles.bodySmall?.copyWith(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildCategoryPillWithCount(String category, Color color, int count) {
    final isSelected = _selectedExamCategory == category;
    return InkWell(
      onTap: () => setState(() => _selectedExamCategory = isSelected ? null : category),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 14, color: Colors.white),
              ),
            Text(
              category,
              style: context.textStyles.labelMedium?.copyWith(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.3) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: context.textStyles.labelSmall?.copyWith(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMultiMonthCalendar() {
    final slotCounts = _getSlotCountsByDay();
    final slotsInYear = _allSlots.where((s) => s.startTime.year == _calendarYear).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text('Calendario (riga = mese)', style: context.textStyles.labelSmall?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(width: 12),
            Text(
              '($slotsInYear slot in $_calendarYear)',
              style: context.textStyles.labelSmall?.copyWith(
                color: slotsInYear > 0 ? LightModeColors.lightPrimary : Colors.grey.shade500,
                fontWeight: slotsInYear > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              onPressed: () => _changeYear(-1),
              tooltip: 'Anno precedente',
            ),
            const SizedBox(width: 8),
            Text('$_calendarYear', style: context.textStyles.titleMedium?.bold),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: () => _changeYear(1),
              tooltip: 'Anno successivo',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        for (int month = 1; month <= 12; month++)
          _buildMonthRow(DateTime(_calendarYear, month, 1), slotCounts),
      ],
    );
  }
  
  Widget _buildMonthRow(DateTime month, Map<DateTime, int> slotCounts) {
    final monthName = DateFormat('MMMM', 'it_IT').format(month);
    final year = month.year;
    final daysInMonth = DateTime(year, month.month + 1, 0).day;
    
    final totalSlots = List.generate(daysInMonth, (i) {
      final day = DateTime(year, month.month, i + 1);
      return slotCounts[day] ?? 0;
    }).fold<int>(0, (sum, count) => sum + count);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      monthName.substring(0, 1).toUpperCase() + monthName.substring(1),
                      style: context.textStyles.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalSlots gg',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            Icon(Icons.chevron_left, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildMonthGrid(year, month.month, daysInMonth, slotCounts),
              ),
            ),
            
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMonthGrid(int year, int month, int daysInMonth, Map<DateTime, int> slotCounts) {
    final days = <Widget>[];
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final slotCount = slotCounts[date] ?? 0;
      final weekday = date.weekday;
      final isWeekend = weekday == 6 || weekday == 7;
      
      final dayNames = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
      final dayName = dayNames[weekday - 1];
      
      days.add(_buildDayCell(day, dayName, slotCount, isWeekend, date));
      if (day < daysInMonth) days.add(const SizedBox(width: 2));
    }
    
    return Row(children: days);
  }
  
  Widget _buildDayCell(int day, String dayName, int slotCount, bool isWeekend, DateTime date) {
    return InkWell(
      onTap: slotCount > 0 ? () => _showSlotsForDay(date) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 35,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: slotCount > 0 
              ? LightModeColors.lightPrimaryContainer.withValues(alpha: 0.3)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: slotCount > 0 
                ? LightModeColors.lightPrimary.withValues(alpha: 0.2) 
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayName,
              style: context.textStyles.labelSmall?.copyWith(
                fontSize: 8,
                color: isWeekend ? Colors.red : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$day',
              style: context.textStyles.labelMedium?.copyWith(
                color: isWeekend ? Colors.red : Colors.grey.shade900,
                fontWeight: slotCount > 0 ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (slotCount > 0) ...[
              const SizedBox(height: 1),
              Text(
                '$slotCount',
                style: context.textStyles.labelSmall?.copyWith(
                  fontSize: 9,
                  color: LightModeColors.lightPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else
              const SizedBox(height: 1),
          ],
        ),
      ),
    );
  }
  
  void _showSlotsForDay(DateTime date) {
    final daySlots = _allSlots.where((slot) {
      final slotDay = DateTime(slot.startTime.year, slot.startTime.month, slot.startTime.day);
      if (slotDay != date) return false;
      if (_selectedExamCategory != null && !_matchesCategory(slot)) return false;
      return true;
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) {
        final dateFormatter = DateFormat('dd/MM/yyyy', 'it');
        final timeFormatter = DateFormat('HH:mm', 'it');
        
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Text('Slot disponibili - ${dateFormatter.format(date)}'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: daySlots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nessuno slot disponibile per questo giorno'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: daySlots.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final slot = daySlots[index];
                      final exam = slot.examId != null
                          ? _exams.firstWhere((e) => e.id == slot.examId, orElse: () => _exams.first)
                          : null;
                      final isBooked = slot.bookingId != null && slot.bookingId!.isNotEmpty;
                      
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isBooked ? Colors.orange.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.access_time,
                            color: isBooked ? Colors.orange : Colors.green,
                          ),
                        ),
                        title: Text(
                          '${timeFormatter.format(slot.startTime)} - ${timeFormatter.format(slot.endTime)}',
                          style: context.textStyles.titleSmall?.semiBold,
                        ),
                        subtitle: Text(
                          exam?.name ?? 'Categoria: ${slot.examCategory ?? "N/A"}',
                          style: context.textStyles.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isBooked ? Colors.orange : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isBooked ? 'Prenotato' : 'Disponibile',
                                style: context.textStyles.labelSmall?.bold.withColor(Colors.white),
                              ),
                            ),
                            if (!isBooked) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () => _deleteSlot(slot.id, context),
                                tooltip: 'Elimina slot',
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _deleteSlot(String slotId, BuildContext dialogContext) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Conferma eliminazione'),
          ],
        ),
        content: const Text('Sei sicuro di voler eliminare questo slot?\n\nQuesta azione non può essere annullata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _availabilityService.deleteSlot(slotId);
      _debugLog.info('AvailabilityManagement', '✅ Slot eliminato: $slotId');
      
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot eliminato'), backgroundColor: Colors.green),
        );
        _reloadData();
      }
    } catch (e) {
      _debugLog.error('AvailabilityManagement', '❌ Errore eliminazione', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _showDebugLogs() {
    final logs = _debugLog.logs
        .where((log) => log.source == 'AvailabilityManagement' || log.source == 'AvailabilityService')
        .toList()
        .reversed
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bug_report, size: 24, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('Log Debug'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                _debugLog.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log cancellati')),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: logs.isEmpty
              ? const Center(child: Text('Nessun log disponibile'))
              : ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    Color bgColor = Colors.white;
                    if (log.level == LogLevel.error || log.level == LogLevel.critical) {
                      bgColor = Colors.red.shade50;
                    } else if (log.level == LogLevel.warning) {
                      bgColor = Colors.orange.shade50;
                    } else if (log.level == LogLevel.info) {
                      bgColor = Colors.blue.shade50;
                    }
                    
                    return Container(
                      color: bgColor,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(log.levelIcon),
                              const SizedBox(width: 8),
                              Text(log.formattedTimestamp, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                              const SizedBox(width: 12),
                              Expanded(child: Text(log.message)),
                            ],
                          ),
                          if (log.error != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, top: 4),
                              child: Text('Error: ${log.error}', style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 11)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

/// Enum per lo stato di caricamento
enum LoadingState {
  idle,      // Stato iniziale
  loading,   // Caricamento in corso
  success,   // Dati caricati
  error,     // Errore
}

// =============================================================================
// CREATORE DISPONIBILITÀ RICORRENTI - RISCRITTA DA ZERO
// =============================================================================

class RecurringAvailabilityCreator extends StatefulWidget {
  final List<ExamType> exams;
  final VoidCallback onSuccess;
  
  const RecurringAvailabilityCreator({
    super.key,
    required this.exams,
    required this.onSuccess,
  });
  
  @override
  State<RecurringAvailabilityCreator> createState() => _RecurringAvailabilityCreatorState();
}

class _RecurringAvailabilityCreatorState extends State<RecurringAvailabilityCreator> {
  final _debugLog = DebugLogService();
  final _availabilityService = AvailabilityService();
  
  // Form state
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Lun-Ven default
  String? _selectedExamId;
  String? _selectedCategory;
  bool _useCategoryInsteadOfExam = false;
  DateTime _startDate = DateTime.now();
  int _weeks = 4;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);
  bool _divideIntoSlots = true;
  int _slotDuration = 30;
  
  // Creation state
  CreationState _creationState = CreationState.idle;
  double _progress = 0.0;
  String _statusMessage = '';
  int _totalCreated = 0;
  
  @override
  Widget build(BuildContext context) {
    // Log stato organizzazione per debug
    final org = SupabaseAuthManager.instance.cachedOrganization;
    final profile = SupabaseAuthManager.instance.cachedProfile;
    _debugLog.debug('RecurringCreator', '🏥 Org: ${org?['name'] ?? "NESSUNA"}, Profile: ${profile?.email ?? "NO"}');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Debug banner se manca organizzazione
        if (org == null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ Nessuna organizzazione associata al profilo. Impossibile creare slot.',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        
        _buildWeekdaySelector(),
        const SizedBox(height: AppSpacing.md),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildExamDropdown()),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildStartDatePicker()),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildWeeksPicker()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTimePicker('Inizio', _startTime, (t) => setState(() => _startTime = t))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildTimePicker('Fine', _endTime, (t) => setState(() => _endTime = t))),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildDivideToggle()),
            const SizedBox(width: AppSpacing.md),
            SizedBox(width: 140, child: _buildCreateButton()),
          ],
        ),
        
        // Progress indicator (se in creazione)
        if (_creationState == CreationState.creating) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildProgressIndicator(),
        ],
      ],
    );
  }
  
  Widget _buildWeekdaySelector() {
    const days = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return Wrap(
      spacing: AppSpacing.sm,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final isSelected = _selectedDays.contains(dayNum);
        return FilterChip(
          selected: isSelected,
          label: Text(days[i]),
          labelStyle: context.textStyles.labelMedium?.copyWith(
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          backgroundColor: Colors.grey.shade100,
          selectedColor: LightModeColors.lightPrimary,
          checkmarkColor: Colors.white,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedDays.add(dayNum);
              } else {
                _selectedDays.remove(dayNum);
              }
            });
          },
        );
      }),
    );
  }
  
  Widget _buildExamDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medical_services, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text('Tipo esame', style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Checkbox(
              value: _useCategoryInsteadOfExam,
              onChanged: (value) {
                setState(() {
                  _useCategoryInsteadOfExam = value ?? false;
                  if (_useCategoryInsteadOfExam) {
                    _selectedExamId = null;
                  } else {
                    _selectedCategory = null;
                  }
                });
              },
            ),
            Text('Solo macrocategoria', style: context.textStyles.labelSmall?.copyWith(color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_useCategoryInsteadOfExam)
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              hintText: 'Seleziona categoria',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: 'RM', child: Text('RM (Risonanza Magnetica)')),
              DropdownMenuItem(value: 'TAC', child: Text('TAC (Tomografia)')),
              DropdownMenuItem(value: 'ECO', child: Text('ECO (Ecografia)')),
              DropdownMenuItem(value: 'RX', child: Text('RX (Radiografia)')),
            ],
            onChanged: (value) => setState(() => _selectedCategory = value),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedExamId,
            decoration: InputDecoration(
              hintText: 'Seleziona esame...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: widget.exams.map((e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.name, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (value) {
              _debugLog.info('RecurringCreator', '📋 Esame selezionato: $value');
              setState(() => _selectedExamId = value);
            },
          ),
      ],
    );
  }
  
  Widget _buildStartDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text('Inizio da', style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) setState(() => _startDate = date);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWeeksPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_repeat, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text('Settimane', style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<int>(
          value: _weeks,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [1, 2, 3, 4, 6, 8, 12].map((w) => DropdownMenuItem(value: w, child: Text('$w'))).toList(),
          onChanged: (value) => setState(() => _weeks = value!),
        ),
      ],
    );
  }
  
  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) onChanged(t);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(time.format(context)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDivideToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: _divideIntoSlots,
              onChanged: (value) => setState(() => _divideIntoSlots = value),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('Dividi in slot', style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        if (_divideIntoSlots) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.timer, size: 16, color: Colors.grey),
              const SizedBox(width: AppSpacing.xs),
              Text('Durata (min)', style: context.textStyles.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<int>(
            value: _slotDuration,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            items: [15, 30, 45, 60].map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
            onChanged: (value) => setState(() => _slotDuration = value!),
          ),
        ],
      ],
    );
  }
  
  Widget _buildCreateButton() {
    final canCreate = _creationState == CreationState.idle && 
                      _selectedDays.isNotEmpty && 
                      (_useCategoryInsteadOfExam ? _selectedCategory != null : _selectedExamId != null);
    
    // Debug: mostra perché il pulsante potrebbe essere disabilitato
    _debugLog.debug('RecurringCreator', 'canCreate=$canCreate, state=$_creationState, days=${_selectedDays.length}, useCat=$_useCategoryInsteadOfExam, examId=$_selectedExamId, category=$_selectedCategory');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        FilledButton(
          onPressed: canCreate ? _createSlots : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: LightModeColors.lightPrimary,
          ),
          child: _creationState == CreationState.creating 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Crea'),
        ),
        // Debug info
        if (!canCreate) ...[
          const SizedBox(height: 8),
          Text(
            _useCategoryInsteadOfExam 
                ? (_selectedCategory == null ? '⚠️ Seleziona una categoria' : '')
                : (_selectedExamId == null ? '⚠️ Seleziona un esame' : ''),
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      ],
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(LightModeColors.lightPrimary),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}%',
            style: context.textStyles.labelSmall?.copyWith(
              color: LightModeColors.lightPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createSlots() async {
    if (!mounted) return;
    
    _debugLog.info('RecurringCreator', '🚀 Inizio creazione slot ricorrenti');
    
    setState(() {
      _creationState = CreationState.creating;
      _progress = 0.0;
      _statusMessage = 'Preparazione...';
      _totalCreated = 0;
    });
    
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final org = SupabaseAuthManager.instance.cachedOrganization;
      
      // Log dettagliato per debug
      _debugLog.info('RecurringCreator', '👤 Profilo: ${profile?.email ?? "NESSUNO"}');
      _debugLog.info('RecurringCreator', '👤 Profilo ID: ${profile?.id ?? "NESSUNO"}');
      _debugLog.info('RecurringCreator', '👤 Ruolo: ${profile?.role ?? "NESSUNO"}');
      _debugLog.info('RecurringCreator', '👤 Organization ID nel profilo: ${profile?.organizationId ?? "NESSUNO"}');
      _debugLog.info('RecurringCreator', '🏥 Org cachedOrganization: ${org?['name'] ?? "NESSUNA"}');
      _debugLog.info('RecurringCreator', '🏥 Org ID: ${org?['id'] ?? "NESSUNO"}');
      
      if (profile == null || org == null) {
        throw Exception('Profilo o organizzazione mancanti (profile: ${profile != null}, org: ${org != null})');
      }
      
      // Verifica ruolo
      if (profile.role != 'org_admin' && profile.role != 'super_admin') {
        _debugLog.warning('RecurringCreator', '⚠️ Ruolo utente: ${profile.role} - potrebbe non avere permessi INSERT');
      }
      
      final orgId = org['id'] as String;
      
      // Genera lista di slot
      final slots = _generateSlotsList(orgId, profile.id);
      _debugLog.info('RecurringCreator', '📋 Generati ${slots.length} slot da creare');
      
      if (slots.isEmpty) {
        throw Exception('Nessuno slot da creare con i parametri selezionati');
      }
      
      // Salva in batch
      final batchSize = 20; // Batch ridotti per evitare timeout
      int totalSaved = 0;
      
      for (int i = 0; i < slots.length; i += batchSize) {
        final end = (i + batchSize < slots.length) ? i + batchSize : slots.length;
        final batch = slots.sublist(i, end);
        
        if (mounted) {
          setState(() {
            _statusMessage = 'Creazione slot ${i + 1}-$end di ${slots.length}...';
            _progress = i / slots.length;
          });
        }
        
        _debugLog.info('RecurringCreator', '📤 Batch ${i + 1}-$end...');
        
        final created = await _availabilityService.createSlotsBatch(batch);
        totalSaved += created.length;
        _totalCreated = totalSaved;
        
        _debugLog.info('RecurringCreator', '✅ Batch: ${created.length}/${batch.length} creati');
        
        // Se il batch non ha creato nulla, segnala il problema
        if (created.isEmpty && batch.isNotEmpty) {
          _debugLog.warning('RecurringCreator', '⚠️ Batch vuoto! Possibile problema RLS policy');
        }
        
        // Piccolo delay per non sovraccaricare il DB
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Completamento
      _debugLog.info('RecurringCreator', '✅ TOTALE: $totalSaved/${slots.length} slot creati');
      
      if (mounted) {
        // Controlla se sono stati creati slot
        final success = totalSaved > 0;
        
        setState(() {
          if (success) {
            _statusMessage = '✅ Creazione completata! ($totalSaved slot)';
          } else {
            _statusMessage = '❌ Nessuno slot creato - verifica permessi RLS';
          }
          _progress = 1.0;
        });
        
        // Attendi prima di resettare UI
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          setState(() {
            _creationState = success ? CreationState.success : CreationState.error;
          });
          
          // Mostra feedback
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Creati $totalSaved slot'),
                backgroundColor: totalSaved == slots.length ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            // Mostra dialog con istruzioni dettagliate
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Errore Creazione Slot'),
                    ],
                  ),
                  content: const SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gli slot non sono stati salvati nel database.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        Text('Possibili cause:'),
                        SizedBox(height: 8),
                        Text('1. L\'utente non ha ruolo "org_admin" o "super_admin"'),
                        Text('2. L\'organization_id dell\'utente non coincide'),
                        Text('3. Le RLS policy non sono configurate correttamente'),
                        SizedBox(height: 16),
                        Text(
                          'Soluzione:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('1. Vai nel pannello Supabase (sidebar sinistra)'),
                        Text('2. Applica la migrazione più recente'),
                        Text('3. Fai LOGOUT e poi LOGIN di nuovo'),
                        Text('4. Riprova a creare gli slot'),
                        SizedBox(height: 12),
                        Text(
                          'Controlla anche i Log Debug per maggiori dettagli.',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          }
          
          // Chiama callback per reload DOPO che l'UI è stabile
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            widget.onSuccess();
          }
          
          // Reset form dopo un delay
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            setState(() {
              _creationState = CreationState.idle;
              _progress = 0.0;
              _statusMessage = '';
            });
          }
        }
      }
    } catch (e, stack) {
      _debugLog.error('RecurringCreator', '❌ Errore creazione', error: e, stackTrace: stack);
      
      if (mounted) {
        setState(() {
          _creationState = CreationState.error;
          _statusMessage = 'Errore: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e'), backgroundColor: Colors.red),
        );
        
        // Reset dopo errore
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _creationState = CreationState.idle;
          });
        }
      }
    }
  }
  
  List<AvailabilitySlot> _generateSlotsList(String orgId, String staffUserId) {
    final slots = <AvailabilitySlot>[];
    
    // Deriva la categoria dall'esame selezionato se non si usa la macrocategoria
    String? categoryToUse = _selectedCategory;
    if (!_useCategoryInsteadOfExam && _selectedExamId != null) {
      final selectedExam = widget.exams.firstWhere(
        (e) => e.id == _selectedExamId,
        orElse: () => widget.exams.first,
      );
      categoryToUse = selectedExam.category.name.toUpperCase();
      _debugLog.info('RecurringCreator', '📋 Categoria derivata da esame: $categoryToUse');
    }
    
    for (int week = 0; week < _weeks; week++) {
      final weekStart = _startDate.add(Duration(days: 7 * week));
      
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final date = weekStart.add(Duration(days: dayOffset));
        if (!_selectedDays.contains(date.weekday)) continue;
        
        final startDateTime = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
        final endDateTime = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);
        
        if (_divideIntoSlots) {
          var cursor = startDateTime;
          while (cursor.add(Duration(minutes: _slotDuration)).isBefore(endDateTime) ||
                 cursor.add(Duration(minutes: _slotDuration)).isAtSameMomentAs(endDateTime)) {
            slots.add(AvailabilitySlot(
              id: '',
              organizationId: orgId,
              examId: _useCategoryInsteadOfExam ? null : _selectedExamId,
              examCategory: categoryToUse, // Sempre valorizzata!
              staffUserId: staffUserId,
              startTime: cursor,
              endTime: cursor.add(Duration(minutes: _slotDuration)),
              isAvailable: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
            cursor = cursor.add(Duration(minutes: _slotDuration));
          }
        } else {
          slots.add(AvailabilitySlot(
            id: '',
            organizationId: orgId,
            examId: _useCategoryInsteadOfExam ? null : _selectedExamId,
            examCategory: categoryToUse, // Sempre valorizzata!
            staffUserId: staffUserId,
            startTime: startDateTime,
            endTime: endDateTime,
            isAvailable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }
    }
    
    return slots;
  }
}

enum CreationState {
  idle,
  creating,
  success,
  error,
}

// =============================================================================
// CREATORE DISPONIBILITÀ SINGOLA
// =============================================================================

class SingleAvailabilityCreator extends StatefulWidget {
  final List<ExamType> exams;
  final VoidCallback onSuccess;
  
  const SingleAvailabilityCreator({
    super.key,
    required this.exams,
    required this.onSuccess,
  });
  
  @override
  State<SingleAvailabilityCreator> createState() => _SingleAvailabilityCreatorState();
}

class _SingleAvailabilityCreatorState extends State<SingleAvailabilityCreator> {
  String? _selectedExamId;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  bool _creating = false;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildExamDropdown()),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildDatePicker()),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildTimePicker('Inizio', _startTime, (t) => setState(() => _startTime = t))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildTimePicker('Fine', _endTime, (t) => setState(() => _endTime = t))),
        const SizedBox(width: AppSpacing.md),
        SizedBox(width: 140, child: _buildCreateButton()),
      ],
    );
  }
  
  Widget _buildExamDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medical_services, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text('Tipo esame', style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: _selectedExamId,
          decoration: InputDecoration(
            hintText: 'RM Cervello',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: widget.exams.map((e) => DropdownMenuItem(
            value: e.id,
            child: Text(e.name, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) => setState(() => _selectedExamId = value),
        ),
      ],
    );
  }
  
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text('Data', style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) setState(() => _date = date);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(DateFormat('dd/MM/yyyy').format(_date)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: context.textStyles.labelMedium?.semiBold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) onChanged(t);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(time.format(context)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCreateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _creating || _selectedExamId == null ? null : _createSlot,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: LightModeColors.lightPrimary,
          ),
          child: _creating 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Crea'),
        ),
      ],
    );
  }
  
  Future<void> _createSlot() async {
    setState(() => _creating = true);
    
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final org = SupabaseAuthManager.instance.cachedOrganization;
      
      if (profile == null || org == null) throw Exception('Profilo o org mancanti');
      
      final orgId = org['id'] as String;
      final startDateTime = DateTime(_date.year, _date.month, _date.day, _startTime.hour, _startTime.minute);
      final endDateTime = DateTime(_date.year, _date.month, _date.day, _endTime.hour, _endTime.minute);
      
      // Deriva la categoria dall'esame selezionato
      final selectedExam = widget.exams.firstWhere(
        (e) => e.id == _selectedExamId,
        orElse: () => widget.exams.first,
      );
      final examCategory = selectedExam.category.name.toUpperCase();
      DebugLogService().info('SingleCreator', '📋 Categoria derivata: $examCategory');
      
      final slot = AvailabilitySlot(
        id: '',
        organizationId: orgId,
        examId: _selectedExamId!,
        examCategory: examCategory, // Sempre valorizzata!
        staffUserId: profile.id,
        startTime: startDateTime,
        endTime: endDateTime,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final created = await AvailabilityService().createSlot(slot);
      
      if (mounted && created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Slot creato'), backgroundColor: Colors.green),
        );
        widget.onSuccess();
      }
    } catch (e) {
      DebugLogService().error('SingleCreator', '❌ Errore', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
