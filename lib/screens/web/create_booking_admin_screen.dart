import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/availability_slot.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/availability_service.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/debug_log_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/theme.dart';

/// Schermata per inserimento prenotazione manuale dalla dashboard
class CreateBookingAdminScreen extends StatefulWidget {
  const CreateBookingAdminScreen({super.key});

  @override
  State<CreateBookingAdminScreen> createState() => _CreateBookingAdminScreenState();
}

class _CreateBookingAdminScreenState extends State<CreateBookingAdminScreen> {
  final _availabilityService = AvailabilityService();
  final _examService = ExamService();
  final _bookingService = BookingService();
  final _userService = UserService();
  final _debugLog = DebugLogService();
  
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  
  List<ExamType> _exams = [];
  List<AvailabilitySlot> _allSlots = [];
  String? _selectedCategory; // RM, TAC, ECO, RX
  String? _selectedExamFilter;
  AvailabilitySlot? _selectedSlot;
  UrgencyLevel _urgency = UrgencyLevel.normal;
  
  bool _loading = true;
  String? _organizationName;
  int _currentYear = DateTime.now().year;
  
  @override
  void initState() {
    super.initState();
    _priceController.text = '10';
    _loadData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final org = SupabaseAuthManager.instance.cachedOrganization;
      
      if (profile == null || org == null) {
        _debugLog.error('CreateBookingAdmin', 'Profile o organization mancanti');
        return;
      }
      
      final orgId = org['id'] as String;
      final orgName = org['name'] as String? ?? 'Ospedale';
      final exams = await _examService.getAllExams();
      final slots = await _availabilityService.getAllSlotsForOrganization(orgId);
      
      _debugLog.info('CreateBookingAdmin', 'Caricati ${exams.length} esami e ${slots.length} slot');
      
      if (mounted) {
        setState(() {
          _exams = exams;
          _allSlots = slots;
          _organizationName = orgName;
        });
      }
    } catch (e) {
      _debugLog.error('CreateBookingAdmin', 'Error loading data', error: e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Map<DateTime, int> _getSlotCountsByDay() {
    final counts = <DateTime, int>{};
    for (final slot in _allSlots) {
      // Solo slot disponibili (non prenotati)
      if (slot.bookingId != null && slot.bookingId!.isNotEmpty) continue;
      
      // Accetta slot con examId OPPURE con solo examCategory
      final hasExamId = slot.examId != null && slot.examId!.isNotEmpty;
      final hasCategory = slot.examCategory != null && slot.examCategory!.isNotEmpty;
      
      if (!hasExamId && !hasCategory) continue;
      
      // Filtro per categoria
      if (_selectedCategory != null && !_matchesCategory(slot)) continue;
      
      // Filtro per esame specifico (solo se lo slot ha già un examId)
      if (_selectedExamFilter != null && hasExamId && slot.examId != _selectedExamFilter) continue;
      
      final day = DateTime(slot.startTime.year, slot.startTime.month, slot.startTime.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }
  
  bool _matchesCategory(AvailabilitySlot slot) {
    if (slot.examCategory != null) {
      return slot.examCategory!.toUpperCase() == _selectedCategory?.toUpperCase();
    }
    if (slot.examId != null && slot.examId!.isNotEmpty) {
      final exam = _exams.firstWhere((e) => e.id == slot.examId, orElse: () => _exams.first);
      final category = _getExamCategoryFromName(exam.name);
      return category.toUpperCase() == _selectedCategory?.toUpperCase();
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
  
  Future<void> _confirmBooking() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona uno slot dal calendario')),
      );
      return;
    }
    
    // Determina l'examId da usare per la prenotazione
    String? examId = _selectedSlot!.examId;
    
    // Se lo slot ha solo examCategory (e non examId), usa il filtro esame selezionato
    if ((examId == null || examId.isEmpty) && _selectedExamFilter != null && _selectedExamFilter!.isNotEmpty) {
      examId = _selectedExamFilter;
      _debugLog.info('CreateBookingAdmin', 'Slot con solo examCategory, uso filtro esame: $examId');
    }
    
    // Se ancora non abbiamo un examId, richiedi di selezionare un esame
    if (examId == null || examId.isEmpty) {
      _debugLog.error('CreateBookingAdmin', 'Slot senza examId e nessun filtro esame selezionato');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Per questo slot, seleziona prima un tipo esame specifico dal filtro'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty ||
        _emailController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila tutti i campi obbligatori')),
      );
      return;
    }
    
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final org = SupabaseAuthManager.instance.cachedOrganization;
      if (profile == null || org == null) return;
      
      final orgId = org['id'] as String;
      final price = double.tryParse(_priceController.text) ?? 10.0;
      
      // Crea o trova l'utente paziente
      final patientEmail = _emailController.text.trim();
      var patientId = await _userService.getUserIdByEmail(patientEmail);
      
      if (patientId == null) {
        // Crea nuovo utente paziente
        _debugLog.info('CreateBookingAdmin', 'Creazione nuovo paziente: $patientEmail');
        patientId = await _userService.createEndUser(
          email: patientEmail,
          firstName: _nameController.text.trim(),
          lastName: _surnameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
      }
      
      // Valida che patientId sia valido
      if (patientId.isEmpty) {
        _debugLog.error('CreateBookingAdmin', 'patientId è vuoto dopo la creazione/ricerca utente');
        throw Exception('Impossibile creare o trovare l\'utente paziente');
      }
      
      // examId già determinato dalla validazione sopra
      final slotId = _selectedSlot!.id;
      
      // Log dettagliato di tutti i parametri
      _debugLog.info('CreateBookingAdmin', '''
        ========== PARAMETRI PRENOTAZIONE ==========
        userId: $patientId (length: ${patientId.length})
        orgId: $orgId (length: ${orgId.length})
        examId: $examId (length: ${examId.length})
        slotId: $slotId (length: ${slotId.length})
        date: ${_selectedSlot!.startTime}
        price: $price
        urgency: ${_urgency.name}
        notes: ${_notesController.text.trim()}
        ============================================
      ''');
      
      // Validazione extra: verifica che nessun campo UUID sia una stringa vuota
      if (patientId.isEmpty) {
        throw Exception('❌ patientId è vuoto');
      }
      if (orgId.isEmpty) {
        throw Exception('❌ organizationId è vuoto');
      }
      if (examId.isEmpty) {
        throw Exception('❌ examTypeId è vuoto');
      }
      if (slotId.isEmpty) {
        throw Exception('❌ slotId è vuoto');
      }
      
      await _bookingService.createBookingWithLock(
        userId: patientId,
        organizationId: orgId,
        examTypeId: examId,
        bookingDate: DateTime(
          _selectedSlot!.startTime.year,
          _selectedSlot!.startTime.month,
          _selectedSlot!.startTime.day,
        ),
        bookingTime: _selectedSlot!.startTime,
        slotId: slotId,
        urgency: _urgency,
        price: price,
        notes: _notesController.text.trim(),
      );
      
      _debugLog.info('CreateBookingAdmin', '✅ Prenotazione creata con successo');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Prenotazione creata con successo')),
        );
        context.pop();
      }
    } catch (e) {
      _debugLog.error('CreateBookingAdmin', 'Error creating booking', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header blu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5B8FB9),
                  const Color(0xFF5B8FB9).withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_circle_outline, color: Color(0xFF5B8FB9), size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Inserisci Prenotazione',
                      style: context.textStyles.headlineSmall?.bold
                        .withColor(Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Ospedale/Istituto: $_organizationName',
                          style: context.textStyles.bodyMedium
                            ?.withColor(Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content area
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left panel - Calendario
                Expanded(
                  flex: 7,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategorySelector(),
                        const SizedBox(height: 20),
                        _buildExamFilter(),
                        const SizedBox(height: 24),
                        _buildCalendar(),
                      ],
                    ),
                  ),
                ),
                
                // Right panel - Dati paziente
                SizedBox(
                  width: 400,
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelectedSlotCard(),
                          const SizedBox(height: 24),
                          _buildPatientSearch(),
                          const SizedBox(height: 20),
                          _buildPatientForm(),
                          const SizedBox(height: 24),
                          _buildBookingDetails(),
                          const SizedBox(height: 32),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDebugLogs,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.bug_report, color: Colors.white),
        label: const Text('Log Prenotazioni', style: TextStyle(color: Colors.white)),
      ),
    );
  }
  
  void _showDebugLogs() {
    final bookingLogs = _debugLog.logs
        .where((log) => log.source == 'CreateBookingAdmin')
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
            const Text('Log Debug Prenotazioni'),
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
              tooltip: 'Cancella tutti i log',
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: bookingLogs.isEmpty
              ? const Center(
                  child: Text('Nessun log disponibile.\nI log appariranno qui durante le operazioni.'),
                )
              : ListView.separated(
                  itemCount: bookingLogs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = bookingLogs[index];
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(log.levelIcon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                log.formattedTimestamp,
                                style: context.textStyles.labelSmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  log.message,
                                  style: context.textStyles.bodySmall?.copyWith(
                                    fontWeight: log.level == LogLevel.error || log.level == LogLevel.critical
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (log.error != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, top: 4),
                              child: Text(
                                'Error: ${log.error}',
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: Colors.red.shade700,
                                  fontFamily: 'monospace',
                                ),
                              ),
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
  
  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.widgets_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Macro categoria esame',
                style: context.textStyles.titleMedium?.semiBold,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCategoryButton('RM', LightModeColors.rmColor),
              const SizedBox(width: 12),
              _buildCategoryButton('TAC', LightModeColors.tacColor),
              const SizedBox(width: 12),
              _buildCategoryButton('ECO', LightModeColors.ecoColor),
              const SizedBox(width: 12),
              _buildCategoryButton('RX', LightModeColors.rxColor),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryButton(String category, Color color) {
    final isSelected = _selectedCategory == category;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedCategory = isSelected ? null : category;
          _selectedExamFilter = null;
          _selectedSlot = null;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                const Icon(Icons.check, color: Colors.white, size: 18)
              else
                Icon(_getCategoryIcon(category), color: Colors.grey.shade600, size: 18),
              const SizedBox(width: 6),
              Text(
                category,
                style: context.textStyles.labelLarge?.semiBold
                  .withColor(isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'RM': return Icons.analytics;
      case 'TAC': return Icons.camera;
      case 'ECO': return Icons.graphic_eq;
      case 'RX': return Icons.view_in_ar;
      default: return Icons.medical_services;
    }
  }
  
  Widget _buildExamFilter() {
    final filteredExams = _selectedCategory != null
        ? _exams.where((e) => _getExamCategoryFromName(e.name) == _selectedCategory).toList()
        : _exams;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filtra per tipo esame (opzionale)',
                style: context.textStyles.bodyMedium?.medium
                  .withColor(Colors.grey.shade600),
              ),
              const Spacer(),
              if (_selectedExamFilter != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _selectedExamFilter = null;
                    _selectedSlot = null;
                  }),
                  tooltip: 'Rimuovi filtro',
                ),
            ],
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedExamFilter,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              hint: Text('Seleziona esame $_selectedCategory'),
              items: filteredExams.map((exam) {
                return DropdownMenuItem<String>(
                  value: exam.id,
                  child: Text(exam.name),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _selectedExamFilter = value;
                _selectedSlot = null;
              }),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 20),
              const SizedBox(width: 8),
              Text(
                'Calendario disponibilità (riga = mese)',
                style: context.textStyles.titleMedium?.semiBold,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _currentYear--),
              ),
              Text(
                _currentYear.toString(),
                style: context.textStyles.titleMedium?.bold,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _currentYear++),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMonthRows(),
        ],
      ),
    );
  }
  
  Widget _buildMonthRows() {
    final slotCounts = _getSlotCountsByDay();
    final months = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    ];
    
    return Column(
      children: List.generate(6, (monthIndex) {
        final month = monthIndex + 1;
        final daysInMonth = DateTime(_currentYear, month + 1, 0).day;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month label with days count
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF5B8FB9)),
                        const SizedBox(width: 4),
                        Text(
                          months[monthIndex],
                          style: context.textStyles.labelMedium?.semiBold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentYear.toString(),
                      style: context.textStyles.labelSmall
                        ?.withColor(Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8FB9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysInMonth gg',
                  style: context.textStyles.labelSmall?.bold
                    .withColor(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              
              // Days grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(daysInMonth, (dayIndex) {
                      final day = dayIndex + 1;
                      final date = DateTime(_currentYear, month, day);
                      final slotCount = slotCounts[date] ?? 0;
                      final weekday = date.weekday;
                      final isWeekend = weekday == 6 || weekday == 7;
                      final weekdayAbbr = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'][weekday - 1];
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: slotCount > 0 ? () => _showSlotsForDay(date) : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 40,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: slotCount > 0 
                                  ? const Color(0xFF5B8FB9).withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: slotCount > 0 
                                    ? const Color(0xFF5B8FB9)
                                    : Colors.grey.shade200,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  weekdayAbbr,
                                  style: context.textStyles.labelSmall
                                    ?.withColor(isWeekend ? Colors.red : Colors.grey.shade600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  day.toString(),
                                  style: context.textStyles.bodySmall?.semiBold
                                    .withColor(slotCount > 0 ? const Color(0xFF5B8FB9) : Colors.grey.shade700),
                                ),
                                if (slotCount > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    slotCount.toString(),
                                    style: context.textStyles.labelSmall?.bold
                                      .withColor(const Color(0xFF5B8FB9)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
  
  void _showSlotsForDay(DateTime date) {
    final daySlots = _allSlots.where((slot) {
      final slotDay = DateTime(slot.startTime.year, slot.startTime.month, slot.startTime.day);
      if (slotDay != date) return false;
      
      // Accetta slot con examId OPPURE con solo examCategory
      final hasExamId = slot.examId != null && slot.examId!.isNotEmpty;
      final hasCategory = slot.examCategory != null && slot.examCategory!.isNotEmpty;
      
      if (!hasExamId && !hasCategory) return false;
      
      if (_selectedCategory != null && !_matchesCategory(slot)) return false;
      if (_selectedExamFilter != null && hasExamId && slot.examId != _selectedExamFilter) return false;
      return true;
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) {
        final dateFormatter = DateFormat('dd/MM/yyyy', 'it');
        final timeFormatter = DateFormat('HH:mm', 'it');
        
        return AlertDialog(
          title: Text('Slot disponibili - ${dateFormatter.format(date)}'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: daySlots.length,
              itemBuilder: (context, index) {
                final slot = daySlots[index];
                final hasExamId = slot.examId != null && slot.examId!.isNotEmpty;
                
                // Determina il testo da mostrare
                String examText;
                if (hasExamId) {
                  final exam = _exams.firstWhere((e) => e.id == slot.examId, orElse: () => _exams.first);
                  examText = exam.name;
                } else if (slot.examCategory != null && slot.examCategory!.isNotEmpty) {
                  examText = 'Categoria: ${slot.examCategory}';
                } else {
                  examText = 'Generico';
                }
                
                final isBooked = slot.bookingId != null && slot.bookingId!.isNotEmpty;
                
                return ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('${timeFormatter.format(slot.startTime)} - ${timeFormatter.format(slot.endTime)}'),
                  subtitle: Text(examText),
                  trailing: isBooked
                      ? const Chip(label: Text('Prenotato'), backgroundColor: Colors.orange)
                      : const Chip(label: Text('Disponibile'), backgroundColor: Colors.green),
                  onTap: isBooked ? null : () {
                    setState(() => _selectedSlot = slot);
                    Navigator.pop(context);
                  },
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
  
  Widget _buildSelectedSlotCard() {
    if (_selectedSlot == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Seleziona uno slot dal calendario',
                style: context.textStyles.bodyMedium
                  ?.withColor(Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }
    
    final hasExamId = _selectedSlot!.examId != null && _selectedSlot!.examId!.isNotEmpty;
    
    String examText;
    if (hasExamId) {
      final exam = _exams.firstWhere((e) => e.id == _selectedSlot!.examId, orElse: () => _exams.first);
      examText = exam.name;
    } else if (_selectedSlot!.examCategory != null && _selectedSlot!.examCategory!.isNotEmpty) {
      examText = 'Categoria: ${_selectedSlot!.examCategory}';
    } else {
      examText = 'Generico';
    }
    
    final timeFormatter = DateFormat('HH:mm', 'it');
    final dateFormatter = DateFormat('dd/MM/yyyy', 'it');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF6EDDD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today, color: Color(0xFF4ECDC4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${timeFormatter.format(_selectedSlot!.startTime)} - ${timeFormatter.format(_selectedSlot!.endTime)}',
                  style: context.textStyles.titleMedium?.bold
                    .withColor(Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  examText,
                  style: context.textStyles.bodyMedium
                    ?.withColor(Colors.white.withValues(alpha: 0.9)),
                ),
                Text(
                  dateFormatter.format(_selectedSlot!.startTime),
                  style: context.textStyles.bodySmall
                    ?.withColor(Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _selectedSlot = null),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPatientSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_search, size: 20),
            const SizedBox(width: 8),
            Text(
              'Dati paziente e prenotazione',
              style: context.textStyles.titleMedium?.semiBold,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Cerca paziente in anagrafica',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onSubmitted: (query) async {
            // TODO: Implementa ricerca paziente
            _debugLog.info('CreateBookingAdmin', 'Ricerca paziente: $query');
          },
        ),
      ],
    );
  }
  
  Widget _buildPatientForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text('Nome *', style: context.textStyles.labelMedium?.semiBold),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      hintText: 'fff',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge, size: 16),
                      const SizedBox(width: 4),
                      Text('Cognome *', style: context.textStyles.labelMedium?.semiBold),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _surnameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      hintText: 'fff',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.email, size: 16),
                const SizedBox(width: 4),
                Text('Email *', style: context.textStyles.labelMedium?.semiBold),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: 'fff@fff.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone, size: 16),
                const SizedBox(width: 4),
                Text('Telefono *', style: context.textStyles.labelMedium?.semiBold),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: '345345',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildBookingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dettagli prenotazione',
          style: context.textStyles.titleMedium?.semiBold,
        ),
        const SizedBox(height: 16),
        
        // Urgenza
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Urgenza', style: context.textStyles.labelMedium?.medium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildUrgencyButton(UrgencyLevel.normal, 'Normale', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildUrgencyButton(UrgencyLevel.urgent, 'Urgente', Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildUrgencyButton(UrgencyLevel.veryUrgent, 'Molto Urgente', Colors.red),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Prezzo
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.euro, size: 16),
                const SizedBox(width: 4),
                Text('Prezzo (€)', style: context.textStyles.labelMedium?.semiBold),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Note
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note, size: 16),
                const SizedBox(width: 4),
                Text('Note (opzionale)', style: context.textStyles.labelMedium?.medium),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: 'rr',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildUrgencyButton(UrgencyLevel level, String label, Color color) {
    final isSelected = _urgency == level;
    
    return InkWell(
      onTap: () => setState(() => _urgency = level),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 16)
            else
              Icon(_getUrgencyIcon(level), color: Colors.grey.shade600, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: context.textStyles.labelSmall?.semiBold
                  .withColor(isSelected ? Colors.white : Colors.grey.shade700),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getUrgencyIcon(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.normal: return Icons.schedule;
      case UrgencyLevel.urgent: return Icons.warning_amber;
      case UrgencyLevel.veryUrgent: return Icons.priority_high;
    }
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cancel_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Annulla', style: context.textStyles.labelLarge?.semiBold),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _confirmBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 18),
                const SizedBox(width: 8),
                Text('Conferma', style: context.textStyles.labelLarge?.semiBold),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
