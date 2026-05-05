import 'package:flutter/material.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/facility_exam_offering.dart';
import 'package:xraynow/services/facility_exam_offering_service.dart';
import 'package:xraynow/services/profile_sync_service.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/theme.dart';

/// Schermata per gestire gli esami offerti dall'organizzazione
/// Ogni organizzazione ha automaticamente la sua struttura (facility) garantita dal database
class ExamOfferingsScreen extends StatefulWidget {
  const ExamOfferingsScreen({super.key});

  @override
  State<ExamOfferingsScreen> createState() => _ExamOfferingsScreenState();
}

class _ExamOfferingsScreenState extends State<ExamOfferingsScreen> {
  final _offeringService = FacilityExamOfferingService();
  final _profileSyncService = ProfileSyncService();

  bool _loading = true;
  String? _facilityId;
  List<ExamType> _allExams = [];
  Map<String, FacilityExamOffering> _offeringsMap = {};
  String _searchQuery = '';
  bool _processingToggle = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Caricamento semplificato: ogni organizzazione ha già la sua struttura
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[ExamOfferings] 🚀 Inizio caricamento...');

      // 1️⃣ Verifica autenticazione
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) {
        throw Exception('Sessione non valida. Effettua nuovamente il login.');
      }
      debugPrint('[ExamOfferings] ✅ User autenticato: ${user.email}');

      // 2️⃣ Sincronizza profilo
      final profile = await _profileSyncService.syncCurrentUser();
      if (profile == null) {
        throw Exception('Impossibile recuperare il profilo utente.\n\n'
            'Verifica i permessi o contatta il supporto.');
      }
      debugPrint('[ExamOfferings] ✅ Profilo: ${profile.email}, Ruolo: ${profile.role}');

      // 3️⃣ Verifica associazione organizzazione
      final orgId = profile.organizationId;
      if (orgId == null || orgId.isEmpty) {
        throw Exception('Questo utente non è associato a nessuna organizzazione.\n\n'
            'Contatta il supporto per configurare l\'account.');
      }

      // 4️⃣ Ottieni facility dell'organizzazione (garantita dal database)
      debugPrint('[ExamOfferings] 🔍 Recupero struttura per organizzazione $orgId...');
      final facilityData = await SupabaseConfig.client
          .from('facilities')
          .select('id')
          .eq('organization_id', orgId)
          .single();

      final facilityId = facilityData['id'] as String;
      debugPrint('[ExamOfferings] ✅ Struttura ID: $facilityId');

      // 5️⃣ Carica esami e offerte in parallelo
      final data = await _offeringService.getExamsWithOfferings(facilityId);
      final allExams = data['exams'] as List<ExamType>;
      final offeringsMap = data['offerings'] as Map<String, FacilityExamOffering>;

      debugPrint('[ExamOfferings] ✅ Caricati ${allExams.length} esami, ${offeringsMap.length} offerte attive');

      if (mounted) {
        setState(() {
          _facilityId = facilityId;
          _allExams = allExams;
          _offeringsMap = offeringsMap;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('[ExamOfferings] ❌ Errore: $e');
      debugPrint('[ExamOfferings] Stack: $stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  /// Toggle esame con aggiornamento ottimistico
  Future<void> _toggleExam(ExamType exam, bool selected) async {
    if (_facilityId == null || _processingToggle) return;

    final existingOffering = _offeringsMap[exam.id];
    
    // Aggiornamento ottimistico UI
    setState(() {
      _processingToggle = true;
      if (selected) {
        _offeringsMap[exam.id] = FacilityExamOffering(
          id: '',
          facilityId: _facilityId!,
          examTypeId: exam.id,
          price: 120.0,
          ssnPrice: 0,
          durationMinutes: 30,
          isAvailable: true,
          maxDailyBookings: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        _offeringsMap.remove(exam.id);
      }
    });

    try {
      if (selected) {
        final offering = FacilityExamOffering(
          id: '',
          facilityId: _facilityId!,
          examTypeId: exam.id,
          price: 120.0,
          ssnPrice: 0,
          durationMinutes: 30,
          isAvailable: true,
          maxDailyBookings: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        debugPrint('[ExamOfferings] ➕ Aggiunta esame ${exam.name} (facilityId=$_facilityId, examId=${exam.id})...');
        final created = await _offeringService.createOffering(offering);
        setState(() => _offeringsMap[exam.id] = created);
        debugPrint('[ExamOfferings] ✅ Esame aggiunto con ID: ${created.id}');
        _showSnackbar('✅ ${exam.name} aggiunto alle offerte', Colors.green);
      } else {
        if (existingOffering != null) {
          debugPrint('[ExamOfferings] ➖ Rimozione esame ${exam.name} (offeringId=${existingOffering.id})...');
          await _offeringService.deleteOffering(existingOffering.id);
          debugPrint('[ExamOfferings] ✅ Esame rimosso');
          _showSnackbar('🗑️ ${exam.name} rimosso dalle offerte', Colors.orange);
        }
      }
    } catch (e, stack) {
      debugPrint('[ExamOfferings] ❌ Errore toggle: $e');
      debugPrint('[ExamOfferings] Stack: $stack');
      
      // Rollback ottimistico
      setState(() {
        if (selected) {
          _offeringsMap.remove(exam.id);
        } else if (existingOffering != null) {
          _offeringsMap[exam.id] = existingOffering;
        }
      });
      
      // Estrai messaggio d'errore dettagliato
      String errorMessage = 'Errore durante l\'operazione';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('permission denied') || errorStr.contains('row-level security') || errorStr.contains('policy')) {
        errorMessage = '🔒 Permessi insufficienti. Verifica il tuo ruolo (richiesto: org_admin)';
      } else if (errorStr.contains('duplicate key') || errorStr.contains('unique constraint')) {
        errorMessage = '⚠️ Questo esame è già presente nelle offerte';
      } else if (errorStr.contains('foreign key')) {
        errorMessage = '⚠️ Errore di riferimento nel database';
      } else if (errorStr.contains('null value') || errorStr.contains('not-null constraint')) {
        errorMessage = '⚠️ Dati mancanti nell\'operazione';
      } else {
        // Mostra errore completo per debug
        final cleanMsg = e.toString().replaceAll('Exception: ', '').replaceAll('PostgrestException: ', '');
        errorMessage = cleanMsg.length < 150 ? cleanMsg : cleanMsg.substring(0, 147) + '...';
      }
      
      _showSnackbar('❌ $errorMessage', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _processingToggle = false);
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<ExamType> get _filteredExams {
    if (_searchQuery.isEmpty) return _allExams;
    final query = _searchQuery.toLowerCase();
    return _allExams.where((exam) {
      return exam.name.toLowerCase().contains(query) ||
          exam.description.toLowerCase().contains(query) ||
          exam.category.displayName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E13) : const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView(colorScheme)
              : _buildContent(colorScheme, isDark),
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: context.textStyles.bodyLarge?.withColor(colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: AppSpacing.paddingXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colorScheme),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildAvailableExamsCard(colorScheme, isDark)),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _buildSelectedExamsCard(colorScheme, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.medical_services_outlined, color: colorScheme.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gestione offerte esami', style: context.textStyles.headlineSmall?.bold),
              const SizedBox(height: 4),
              Text(
                'Seleziona gli esami che il tuo istituto offre ai pazienti',
                style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableExamsCard(ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1419) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Esami disponibili nel sistema', style: context.textStyles.titleMedium?.semiBold),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Cerca esame...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2027) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredExams.isEmpty
                ? Center(
                    child: Text(
                      'Nessun esame trovato',
                      style: context.textStyles.bodyMedium?.withColor(colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredExams.length,
                    itemBuilder: (context, index) {
                      final exam = _filteredExams[index];
                      final isSelected = _offeringsMap.containsKey(exam.id);
                      return _ExamListItem(
                        exam: exam,
                        isSelected: isSelected,
                        onToggle: (selected) => _toggleExam(exam, selected),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedExamsCard(ColorScheme colorScheme, bool isDark) {
    final selectedExams = _allExams.where((e) => _offeringsMap.containsKey(e.id)).toList();

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1419) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Esami attivi (${selectedExams.length})', style: context.textStyles.titleMedium?.semiBold),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: selectedExams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun esame selezionato.',
                          style: context.textStyles.bodyMedium?.semiBold?.withColor(colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Spunta gli esami a sinistra per abilitarli',
                          style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: selectedExams.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exam = selectedExams[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.check, size: 16, color: colorScheme.primary),
                        ),
                        title: Text(exam.name, style: context.textStyles.bodyMedium?.semiBold),
                        subtitle: Text(
                          '${exam.category.displayName} • ${exam.bodyDistrict.displayName}',
                          style: context.textStyles.labelSmall?.withColor(colorScheme.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExamListItem extends StatelessWidget {
  final ExamType exam;
  final bool isSelected;
  final ValueChanged<bool> onToggle;

  const _ExamListItem({
    required this.exam,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2027) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => onToggle(value ?? false),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(exam.name, style: context.textStyles.bodyMedium?.semiBold),
        subtitle: Text(
          '${exam.category.displayName} • ${exam.bodyDistrict.displayName}',
          style: context.textStyles.labelSmall?.withColor(colorScheme.onSurfaceVariant),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: colorScheme.primary,
      ),
    );
  }
}
