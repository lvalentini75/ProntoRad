import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/organization.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/models/tariff.dart';
import 'package:xraynow/models/availability_slot.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/services/tariff_service.dart';
import 'package:xraynow/services/availability_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/theme.dart';

/// Dati aggregati per mostrare un'organizzazione con prezzo e disponibilità
class OrganizationWithOffering {
  final Organization organization;
  final Tariff? tariff;
  final AvailabilitySlot? firstAvailableSlot;
  final DateTime? firstAvailableDate;
  double? distanceKm;

  OrganizationWithOffering({
    required this.organization,
    this.tariff,
    this.firstAvailableSlot,
    this.firstAvailableDate,
    this.distanceKm,
  });

  double get price => tariff?.price ?? 80.0;
}

class FacilityListScreen extends StatefulWidget {
  final ExamType? exam;
  final ExamPackage? examPackage;
  final String region;
  final String province;
  final String city;
  final double? userLat;
  final double? userLon;

  const FacilityListScreen({
    super.key,
    this.exam,
    this.examPackage,
    required this.region,
    required this.province,
    required this.city,
    this.userLat,
    this.userLon,
  }) : assert(exam != null || examPackage != null, 'Either exam or examPackage must be provided');
  
  /// Ottiene il nome da mostrare (esame o pacchetto)
  String get displayName => exam?.name ?? examPackage?.name ?? 'Esame';
  
  /// Ottiene la durata dell'appuntamento (30 min default per singolo esame)
  int get durationMinutes => examPackage?.totalDurationMinutes ?? 30;

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _FacilityListScreenState extends State<FacilityListScreen> {
  final OrganizationService _orgService = OrganizationService();
  final TariffService _tariffService = TariffService();
  final AvailabilityService _availabilityService = AvailabilityService();
  final ExamService _examService = ExamService();
  
  List<OrganizationWithOffering> _organizations = [];
  List<OrganizationWithOffering> _filteredOrganizations = [];
  bool _isLoading = true;
  
  String _selectedFilter = 'Distanza';
  final List<String> _filters = ['Distanza', 'Data/Ora', 'Prezzo'];
  UrgencyLevel _urgencyLevel = UrgencyLevel.normal;
  
  // Cache degli esami per derivare la categoria dagli slot con solo examId
  Map<String, String> _examIdToCategory = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    // Carica prima la mappa esami -> categoria
    try {
      final exams = await _examService.getAllExams();
      for (final exam in exams) {
        _examIdToCategory[exam.id] = exam.category.name.toUpperCase();
      }
      debugPrint('[FacilityList] 📚 Caricati ${_examIdToCategory.length} esami per mappa categoria');
    } catch (e) {
      debugPrint('[FacilityList] ⚠️ Errore caricamento esami: $e');
    }
    
    // Poi carica le organizzazioni
    await _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final examId = widget.exam?.id;
      final packageId = widget.examPackage?.id;
      final examCategory = widget.exam?.category.name.toUpperCase() ?? '';
      
      debugPrint('[FacilityList] 🔍 Searching facilities for:');
      debugPrint('   - Exam: ${widget.exam?.name ?? "N/A"} (id=$examId, category=$examCategory)');
      debugPrint('   - Package: ${widget.examPackage?.name ?? "N/A"} (id=$packageId)');
      debugPrint('   - Location: region=${widget.region}, province=${widget.province}, city=${widget.city}');
      
      // Cerca organizzazioni che offrono l'esame/pacchetto nella località specificata
      final orgs = await _orgService.searchOrganizations(
        examId: examId,
        packageId: packageId,
        region: widget.region,
        province: widget.province,
        city: widget.city,
      );
      
      debugPrint('[FacilityList] 📍 Found ${orgs.length} organizations matching criteria');

      // Carica tariffe e disponibilità per ogni organizzazione
      final List<OrganizationWithOffering> enrichedList = [];
      
      for (final org in orgs) {
        // Carica tariffa per l'esame (o prezzo del pacchetto se è un pacchetto)
        Tariff? tariff;
        if (widget.exam != null) {
          tariff = await _tariffService.getTariff(org.id, widget.exam!.id);
        }
        // Per i pacchetti, usiamo il prezzo del pacchetto se disponibile
        final packagePrice = widget.examPackage?.packagePrice;
        
        // Carica slot disponibili per questa organizzazione e esame/pacchetto
        AvailabilitySlot? firstSlot;
        DateTime? firstDate;
        
        try {
          final now = DateTime.now();
          final slots = await _availabilityService.getAllSlotsForOrganization(org.id);
          
          // Determina la categoria per il match
          final examCategoryUpper = widget.exam?.category.name.toUpperCase() ?? '';
          final examIds = widget.examPackage?.examIds ?? [];
          
          // Helper per verificare se uno slot è compatibile
          bool slotMatchesExamOrPackage(AvailabilitySlot s) {
            // Per singolo esame
            if (widget.exam != null) {
              // Match esatto per examId
              if (s.examId == widget.exam!.id) return true;
              
              // Match per examCategory (se valorizzata)
              if (s.examCategory != null && s.examCategory!.toUpperCase() == examCategoryUpper) {
                return true;
              }
              
              // Fallback: deriva la categoria dall'examId (per slot legacy senza examCategory)
              if (s.examCategory == null && s.examId != null && _examIdToCategory.containsKey(s.examId)) {
                final derivedCategory = _examIdToCategory[s.examId]!.toUpperCase();
                if (derivedCategory == examCategoryUpper) {
                  return true;
                }
              }
            }
            
            // Per pacchetto: verifica se lo slot copre almeno uno degli esami del pacchetto
            if (widget.examPackage != null && examIds.isNotEmpty) {
              if (s.examId != null && examIds.contains(s.examId)) return true;
            }
            
            return false;
          }
          
          final availableSlots = slots.where((s) => 
            slotMatchesExamOrPackage(s) &&
            s.isAvailable &&
            s.startTime.isAfter(now)
          ).toList();
          
          debugPrint('[FacilityList] Org ${org.name}: ${availableSlots.length} slot disponibili');
          
          // Ordina per data/ora e prendi il primo
          if (availableSlots.isNotEmpty) {
            availableSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
            firstSlot = availableSlots.first;
            firstDate = DateTime(
              firstSlot.startTime.year,
              firstSlot.startTime.month,
              firstSlot.startTime.day,
            );
            debugPrint('[FacilityList] Org ${org.name}: primo slot disponibile ${firstSlot.startTime}');
          } else {
            debugPrint('[FacilityList] Org ${org.name}: nessuno slot disponibile');
          }
        } catch (e) {
          debugPrint('[FacilityList] Error loading slots for org ${org.id}: $e');
        }

        // Calcola distanza se coordinate disponibili
        double? distance;
        if (widget.userLat != null && widget.userLon != null && 
            org.latitude != null && org.longitude != null) {
          distance = _orgService.calculateDistance(
            widget.userLat!, 
            widget.userLon!,
            org.latitude!, 
            org.longitude!,
          );
        }
        
        enrichedList.add(OrganizationWithOffering(
          organization: org,
          tariff: tariff,
          firstAvailableSlot: firstSlot,
          firstAvailableDate: firstDate,
          distanceKm: distance,
        ));
      }

      // Ordina per default (distanza se disponibile)
      _sortOrganizations(enrichedList);

      setState(() {
        _organizations = enrichedList;
        _filteredOrganizations = enrichedList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[FacilityList] Error loading organizations: $e');
      setState(() => _isLoading = false);
    }
  }

  // Rimosso - non più necessario con il nuovo schema availability

  void _sortOrganizations(List<OrganizationWithOffering> list) {
    switch (_selectedFilter) {
      case 'Distanza':
        if (widget.userLat != null && widget.userLon != null) {
          list.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
        }
        break;
      case 'Data/Ora':
        list.sort((a, b) {
          if (a.firstAvailableDate == null && b.firstAvailableDate == null) return 0;
          if (a.firstAvailableDate == null) return 1;
          if (b.firstAvailableDate == null) return -1;
          final dateCompare = a.firstAvailableDate!.compareTo(b.firstAvailableDate!);
          if (dateCompare != 0) return dateCompare;
          // Confronta gli orari usando startTime (DateTime)
          if (a.firstAvailableSlot == null && b.firstAvailableSlot == null) return 0;
          if (a.firstAvailableSlot == null) return 1;
          if (b.firstAvailableSlot == null) return -1;
          return a.firstAvailableSlot!.startTime.compareTo(b.firstAvailableSlot!.startTime);
        });
        break;
      case 'Prezzo':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
    }
  }

  void _applyFilter() {
    final sorted = [..._organizations];
    _sortOrganizations(sorted);
    setState(() => _filteredOrganizations = sorted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Icon(Icons.chevron_left, color: LightModeColors.lightPrimary, size: 32),
        ),
        title: const Text('Cerca Strutture', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.tune, color: LightModeColors.lightPrimary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                       onTap: () {
                         setState(() => _selectedFilter = filter);
                         _applyFilter();
                       },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Organization list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrganizations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('Nessuna struttura trovata', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Prova a modificare i filtri di ricerca',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredOrganizations.length,
                        itemBuilder: (context, index) {
                          final item = _filteredOrganizations[index];
                          return OrganizationSearchCard(
                            data: item,
                            exam: widget.exam,
                            examPackage: widget.examPackage,
                            onBook: () => _showTimeSlotSelection(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showTimeSlotSelection(OrganizationWithOffering item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimeSlotSheet(
        organization: item.organization,
        exam: widget.exam,
        examPackage: widget.examPackage,
        tariff: item.tariff,
        urgencyLevel: _urgencyLevel,
        onUrgencyChanged: (level) => setState(() => _urgencyLevel = level),
      ),
    );
  }
}

class OrganizationSearchCard extends StatelessWidget {
  final OrganizationWithOffering data;
  final ExamType? exam;
  final ExamPackage? examPackage;
  final VoidCallback onBook;

  const OrganizationSearchCard({
    super.key,
    required this.data,
    this.exam,
    this.examPackage,
    required this.onBook,
  });

  String _getDateTimeLabel() {
    if (data.firstAvailableDate == null || data.firstAvailableSlot == null) {
      return 'Nessuna disponibilità';
    }
    final date = data.firstAvailableDate!;
    final slot = data.firstAvailableSlot!;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    
    String dateStr;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      dateStr = 'Oggi';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      dateStr = 'Domani';
    } else {
      dateStr = DateFormat('EEE d MMM', 'it').format(date);
    }
    return '$dateStr, ${slot.startTimeFormatted}';
  }

  String _getPriceLabel() {
    return 'Privato: €${data.price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final org = data.organization;
    final hasAvailability = data.firstAvailableDate != null;
    final isHospital = org.orgType == OrganizationType.hospital;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with logo and info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: org.logoUrl != null && org.logoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(org.logoUrl!, fit: BoxFit.cover),
                          )
                        : Icon(
                            isHospital ? Icons.local_hospital : Icons.apartment,
                            color: LightModeColors.lightPrimary,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(org.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                        '${data.distanceKm != null ? '${data.distanceKm!.toStringAsFixed(1)} km • ' : ''}${org.city}, ${org.province}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Date/time slot
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasAvailability ? const Color(0xFFE8F4FC) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasAvailability ? Icons.access_time : Icons.event_busy,
                          size: 16,
                          color: hasAvailability ? LightModeColors.lightPrimary : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDateTimeLabel(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: hasAvailability ? LightModeColors.lightPrimary : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Price and book button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(_getPriceLabel(), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: hasAvailability ? onBook : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightModeColors.lightPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Prenota', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TimeSlotSheet extends StatefulWidget {
  final Organization organization;
  final ExamType? exam;
  final ExamPackage? examPackage;
  final Tariff? tariff;
  final UrgencyLevel urgencyLevel;
  final ValueChanged<UrgencyLevel> onUrgencyChanged;

  const TimeSlotSheet({
    super.key,
    required this.organization,
    this.exam,
    this.examPackage,
    this.tariff,
    required this.urgencyLevel,
    required this.onUrgencyChanged,
  }) : assert(exam != null || examPackage != null);
  
  String get displayName => exam?.name ?? examPackage?.name ?? 'Esame';

  @override
  State<TimeSlotSheet> createState() => _TimeSlotSheetState();
}

class _TimeSlotSheetState extends State<TimeSlotSheet> {
  final AvailabilityService _availabilityService = AvailabilityService();
  final ExamService _examService = ExamService();
  
  DateTime? _selectedDate;
  AvailabilitySlot? _selectedSlot;
  List<AvailabilitySlot> _availableSlots = [];
  Map<String, int> _slotBookingCounts = {};
  bool _loadingSlots = false;
  
  // Cache degli esami per derivare la categoria dagli slot con solo examId
  Map<String, String> _examIdToCategory = {};

  @override
  void initState() {
    super.initState();
    _loadExamCategories();
  }
  
  /// Carica tutti gli esami per creare una mappa examId -> category
  Future<void> _loadExamCategories() async {
    try {
      final exams = await _examService.getAllExams();
      final map = <String, String>{};
      for (final exam in exams) {
        map[exam.id] = exam.category.name.toUpperCase();
      }
      if (mounted) {
        setState(() {
          _examIdToCategory = map;
        });
      }
      debugPrint('[TimeSlotSheet] 📚 Caricati ${map.length} esami per mappa categoria');
    } catch (e) {
      debugPrint('[TimeSlotSheet] ⚠️ Errore caricamento esami: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.tariff?.price ?? 80.0;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Seleziona data e ora', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Prezzo: €${price.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text('Livello di urgenza', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: UrgencyLevel.values.map((level) => ChoiceChip(
                  label: Text(level.displayName),
                  selected: widget.urgencyLevel == level,
                  onSelected: (selected) {
                    if (selected) widget.onUrgencyChanged(level);
                  },
                )).toList(),
              ),
              const SizedBox(height: 24),
              Text('Seleziona la data', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(14, (index) {
                  final date = DateTime.now().add(Duration(days: index + 1));
                  final isSelected = _selectedDate?.day == date.day && 
                                     _selectedDate?.month == date.month &&
                                     _selectedDate?.year == date.year;
                  return GestureDetector(
                    onTap: () => _onDateSelected(date),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? LightModeColors.lightPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? LightModeColors.lightPrimary : LightModeColors.lightOutline),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEE', 'it').format(date),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isSelected ? Colors.white : Colors.grey),
                          ),
                          Text(
                            DateFormat('dd/MM').format(date),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isSelected ? Colors.white : LightModeColors.lightOnSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(height: 24),
                Text('Seleziona l\'orario', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_loadingSlots)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_availableSlots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_busy, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Text('Nessuno slot disponibile per questa data', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSlots.map((slot) {
                      final isSelected = _selectedSlot?.id == slot.id;
                      final remaining = slot.isAvailable ? 1 : 0; // TODO: aggiornare con logica corretta
                      return GestureDetector(
                        onTap: remaining > 0 ? () => setState(() => _selectedSlot = slot) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: remaining <= 0 
                                ? Colors.grey.shade200 
                                : isSelected 
                                    ? LightModeColors.lightPrimary 
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: remaining <= 0 
                                  ? Colors.grey.shade300 
                                  : isSelected 
                                      ? LightModeColors.lightPrimary 
                                      : LightModeColors.lightOutline,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                slot.startTimeFormatted,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: remaining <= 0 
                                      ? Colors.grey 
                                      : isSelected 
                                          ? Colors.white 
                                          : LightModeColors.lightOnSurface,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              Text(
                                remaining <= 0 ? 'Esaurito' : 'Disponibile',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: remaining <= 0 
                                      ? Colors.grey 
                                      : isSelected 
                                          ? Colors.white70 
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _selectedDate != null && _selectedSlot != null
                    ? () {
                        context.pop();
                        context.push(
                          '/booking-confirmation',
                          extra: {
                            if (widget.exam != null) 'exam': widget.exam,
                            if (widget.examPackage != null) 'examPackage': widget.examPackage,
                            'organizationId': widget.organization.id,
                            'organizationName': widget.organization.name,
                            'date': _selectedDate,
                            'time': _selectedSlot!.startTime,
                            'urgency': widget.urgencyLevel,
                            'slotId': _selectedSlot!.id,
                            'price': price,
                          },
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.lightPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Conferma orario'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
      _loadingSlots = true;
    });

    try {
      final examId = widget.exam?.id;
      final examName = widget.displayName;
      final examCategoryUpper = widget.exam?.category.name.toUpperCase() ?? '';
      final packageExamIds = widget.examPackage?.examIds ?? [];
      
      debugPrint('[TimeSlotSheet] 🔍 Carico slot per org=${widget.organization.id} (${widget.organization.name}), exam=$examName, date=${date.day}/${date.month}/${date.year}');
      
      // Carica tutti gli slot per questa organizzazione
      final allSlots = await _availabilityService.getAllSlotsForOrganization(widget.organization.id);
      
      debugPrint('[TimeSlotSheet] 📥 Ricevuti ${allSlots.length} slot totali dal DB');
      
      // Filtra per esame/pacchetto e data selezionata
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Helper per verificare se uno slot è compatibile con l'esame/pacchetto
      bool slotMatchesExamOrPackage(AvailabilitySlot s) {
        // Per singolo esame
        if (widget.exam != null) {
          // Match esatto per examId
          if (s.examId == examId) return true;
          
          // Match per examCategory (se valorizzata)
          if (s.examCategory != null && s.examCategory!.toUpperCase() == examCategoryUpper) {
            return true;
          }
          
          // Fallback: deriva la categoria dall'examId (per slot legacy)
          if (s.examCategory == null && s.examId != null && _examIdToCategory.containsKey(s.examId)) {
            final derivedCategory = _examIdToCategory[s.examId]!.toUpperCase();
            if (derivedCategory == examCategoryUpper) {
              return true;
            }
          }
        }
        
        // Per pacchetto: verifica se lo slot copre almeno uno degli esami del pacchetto
        if (widget.examPackage != null && packageExamIds.isNotEmpty) {
          if (s.examId != null && packageExamIds.contains(s.examId)) return true;
        }
        
        return false;
      }
      
      final slotsForExam = allSlots.where(slotMatchesExamOrPackage).toList();
      debugPrint('[TimeSlotSheet] 🔍 Slot per $examName: ${slotsForExam.length}');
      
      final availableSlots = slotsForExam.where((s) => s.isAvailable).toList();
      debugPrint('[TimeSlotSheet] 🔍 Slot disponibili (is_available=true): ${availableSlots.length}');
      
      final slots = availableSlots.where((s) =>
        s.startTime.isAfter(startOfDay) &&
        s.startTime.isBefore(endOfDay)
      ).toList();
      
      // Ordina per orario
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      debugPrint('[TimeSlotSheet] ✅ Slot finali per ${date.day}/${date.month}: ${slots.length}');
      if (slots.isEmpty && slotsForExam.isNotEmpty) {
        debugPrint('[TimeSlotSheet] ℹ️ Gli slot per questo esame esistono ma non per la data ${date.day}/${date.month}');
        // Log delle date disponibili
        final dates = slotsForExam.map((s) => '${s.startTime.day}/${s.startTime.month}').toSet();
        debugPrint('[TimeSlotSheet] 📅 Date con slot disponibili: ${dates.join(", ")}');
      }

      if (mounted) {
        setState(() {
          _availableSlots = slots;
          _slotBookingCounts = {};
          _loadingSlots = false;
        });
      }
    } catch (e) {
      debugPrint('[TimeSlotSheet] ❌ Error loading slots: $e');
      if (mounted) {
        setState(() {
          _availableSlots = [];
          _loadingSlots = false;
        });
      }
    }
  }
}
