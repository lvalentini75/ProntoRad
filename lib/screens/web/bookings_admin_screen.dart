import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/models/organization.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/screens/web/widgets/data_table_card.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';

/// Bookings admin screen (adattiva per super_admin e org_admin)
class BookingsAdminScreen extends StatefulWidget {
  final String? initialFilter;
  
  const BookingsAdminScreen({super.key, this.initialFilter});

  @override
  State<BookingsAdminScreen> createState() => _BookingsAdminScreenState();
}

class _BookingsAdminScreenState extends State<BookingsAdminScreen> {
  bool _loading = true;
  List<Booking> _bookings = [];
  List<Organization> _organizations = [];
  String _statusFilter = 'all';
  String _organizationFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Imposta il filtro iniziale se fornito
    if (widget.initialFilter != null) {
      _statusFilter = widget.initialFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('ℹ️ [BookingsAdmin] ========== LOADING DATA ==========');
      final stopwatch = Stopwatch()..start();
      
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final role = profile?.role ?? 'end_user';
      final isOrgAdmin = role == 'org_admin';
      final organizationId = profile?.organizationId;
      
      debugPrint('[BookingsAdmin] User role: $role');
      debugPrint('[BookingsAdmin] User email: ${profile?.email}');
      debugPrint('[BookingsAdmin] Organization ID: $organizationId');
      debugPrint('[BookingsAdmin] Is org_admin: $isOrgAdmin');
      
      final service = BookingService();
      final orgService = OrganizationService();
      
      // Load data based on role
      List<Booking> bookings;
      List<Organization> organizations;
      
      if (isOrgAdmin && organizationId != null) {
        // Org admin sees only their organization's bookings
        debugPrint('[BookingsAdmin] 📋 Loading bookings for organization: $organizationId');
        final results = await Future.wait([
          service.getBookingsForOrganization(organizationId),
          orgService.getOrganizationById(organizationId).then((org) => org != null ? [org] : <Organization>[]),
        ]);
        bookings = results[0] as List<Booking>;
        organizations = results[1] as List<Organization>;
        debugPrint('[BookingsAdmin] ✅ Loaded ${bookings.length} bookings for org_admin');
        debugPrint('[BookingsAdmin] ✅ Organization: ${organizations.isNotEmpty ? organizations.first.name : 'NONE'}');
        // Log dettagliato di ogni prenotazione per debug
        for (final b in bookings) {
          debugPrint('[BookingsAdmin]   - Booking ${b.id.substring(0, 8)}: org=${b.organizationId}, exam=${b.examType?.name ?? b.examTypeId}, patient=${b.user?.fullName ?? "N/A"}, status=${b.status.name}');
        }
      } else {
        // Super admin sees all bookings
        debugPrint('[BookingsAdmin] 📋 Loading ALL bookings (super_admin)');
        final results = await Future.wait([
          service.getAllBookings(),
          orgService.getAllOrganizations(),
        ]);
        bookings = results[0] as List<Booking>;
        organizations = results[1] as List<Organization>;
        debugPrint('[BookingsAdmin] ✅ Loaded ${bookings.length} total bookings');
        debugPrint('[BookingsAdmin] ✅ Loaded ${organizations.length} total organizations');
      }
      
      stopwatch.stop();
      debugPrint('✅ [BookingsAdmin] Data loaded in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[BookingsAdmin] ========== DATA LOADING COMPLETE ==========');
      
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _organizations = organizations;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ [BookingsAdmin] Error: $e');
      debugPrint('❌ [BookingsAdmin] Stack: $stack');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Booking> get _filteredBookings {
    debugPrint('[BookingsAdmin] 🔍 Applicazione filtri:');
    debugPrint('  - Status filter: $_statusFilter');
    debugPrint('  - Org filter: $_organizationFilter');
    debugPrint('  - Search query: "$_searchQuery"');
    debugPrint('  - Total bookings: ${_bookings.length}');
    
    var filtered = _bookings.where((b) {
      final matchesStatus = _statusFilter == 'all' || b.status.name == _statusFilter;
      final matchesOrg = _organizationFilter == 'all' || b.organizationId == _organizationFilter;
      final patientName = _getPatientName(b);
      final examName = b.examType?.name ?? '';
      final orgName = b.organization?.name ?? '';
      final matchesSearch = _searchQuery.isEmpty ||
          patientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          examName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          orgName.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final passes = matchesStatus && matchesOrg && matchesSearch;
      
      if (!passes && kDebugMode) {
        debugPrint('  ❌ Booking ${b.id.substring(0, 8)} esclusa: status=${b.status.name}, matchesStatus=$matchesStatus, matchesOrg=$matchesOrg, matchesSearch=$matchesSearch');
      }
      
      return passes;
    }).toList();
    
    debugPrint('  ✅ Bookings filtrate: ${filtered.length}');
    
    // Ordine cronologico inverso (più recenti prima)
    filtered.sort((a, b) {
      final dateCompare = b.bookingDate.compareTo(a.bookingDate);
      if (dateCompare != 0) return dateCompare;
      return b.bookingTime.compareTo(a.bookingTime);
    });
    
    return filtered;
  }

  /// Helper per ottenere il nome completo del paziente, gestendo casi vuoti
  String _getPatientName(Booking booking) {
    if (booking.user == null) return 'Dati non disponibili';
    final firstName = booking.user!.firstName.trim();
    final lastName = booking.user!.lastName.trim();
    if (firstName.isEmpty && lastName.isEmpty) return 'Dati non disponibili';
    return '$firstName $lastName'.trim();
  }

  /// Helper per ottenere email del paziente
  String _getPatientEmail(Booking booking) {
    if (booking.user == null || booking.user!.email.trim().isEmpty) {
      return 'Non disponibile';
    }
    return booking.user!.email;
  }

  /// Helper per ottenere telefono del paziente
  String _getPatientPhone(Booking booking) {
    if (booking.user == null || booking.user!.phoneNumber.trim().isEmpty) {
      return 'Non disponibile';
    }
    return booking.user!.phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group by org for stats
    final byOrg = <String, int>{};
    for (var b in _bookings) {
      final orgId = b.organizationId ?? 'unknown';
      byOrg[orgId] = (byOrg[orgId] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, 
                                size: 32, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Text('Gestione Prenotazioni',
                                style: context.textStyles.headlineLarge?.bold),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${_filteredBookings.length} prenotazioni • ${byOrg.length} strutture',
                            style: context.textStyles.bodyLarge
                              ?.withColor(colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Filters
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca paziente, esame o struttura...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1A1F26) : Colors.white,
                        ),
                        onChanged: (value) {
                          debugPrint('[BookingsAdmin] 🔍 Cambio ricerca: "$value"');
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark 
                            ? const Color(0xFF2A3340) 
                            : const Color(0xFFE8EDF2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _organizationFilter,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Tutte le strutture')),
                            ..._organizations.map((org) => DropdownMenuItem(
                              value: org.id,
                              child: Text(org.name, overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (value) {
                            debugPrint('[BookingsAdmin] 🔄 Cambio filtro org da $_organizationFilter a $value');
                            setState(() => _organizationFilter = value ?? 'all');
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 180,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark 
                            ? const Color(0xFF2A3340) 
                            : const Color(0xFFE8EDF2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tutti gli stati')),
                            DropdownMenuItem(value: 'requested', child: Text('In attesa')),
                            DropdownMenuItem(value: 'confirmed', child: Text('Confermati')),
                            DropdownMenuItem(value: 'completed', child: Text('Completati')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Annullati')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rifiutati')),
                          ],
                          onChanged: (value) {
                            debugPrint('[BookingsAdmin] 🔄 Cambio filtro status da $_statusFilter a $value');
                            setState(() => _statusFilter = value ?? 'all');
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bookings table
                DataTableCard(
                  columns: const [
                    'ID',
                    'Paziente',
                    'Esame',
                    'Struttura',
                    'Data',
                    'Ora',
                    'Urgenza',
                    'Stato',
                    'GFR',
                    'Azioni',
                  ],
                  rows: _filteredBookings.map((booking) => [
                    Text('#${booking.id.substring(0, 8)}',
                      style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                    Text(_getPatientName(booking),
                      style: context.textStyles.bodyMedium?.semiBold),
                    Text(booking.examType?.name ?? '-',
                      style: context.textStyles.bodyMedium),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(booking.organization?.name ?? 'N/A',
                          style: context.textStyles.bodyMedium?.semiBold),
                        if (booking.organization?.city != null)
                          Text('${booking.organization?.city}',
                            style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    Text(
                      '${booking.bookingDate.day.toString().padLeft(2, '0')}/${booking.bookingDate.month.toString().padLeft(2, '0')}/${booking.bookingDate.year}',
                      style: context.textStyles.bodyMedium,
                    ),
                    Text(
                      '${booking.bookingTime.hour.toString().padLeft(2, '0')}:${booking.bookingTime.minute.toString().padLeft(2, '0')}',
                      style: context.textStyles.bodyMedium,
                    ),
                    _UrgencyBadge(urgency: booking.urgencyLevel),
                    _StatusBadge(status: booking.status.name),
                    _GfrIndicator(
                      gfrValue: booking.gfrValue,
                      warningThreshold: booking.organization?.gfrWarningThreshold ?? 60.0,
                      criticalThreshold: booking.organization?.gfrCriticalThreshold ?? 30.0,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility_rounded, size: 18),
                          onPressed: () => _showBookingDetails(booking),
                          tooltip: 'Dettagli',
                        ),
                        if (booking.status == BookingStatus.requested)
                          _ConfirmSwitch(
                            booking: booking,
                            onConfirm: () => _confirmBooking(booking),
                          ),
                      ],
                    ),
                  ]).toList(),
                ),
              ],
            ),
          ),
    );
  }

  void _showBookingDetails(Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F26) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dettaglio Prenotazione',
                            style: context.textStyles.titleLarge?.bold.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('#${booking.id.substring(0, 8)}',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontFamily: 'monospace',
                            )),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badges
                      Row(
                        children: [
                          _StatusBadge(status: booking.status.name),
                          const SizedBox(width: 12),
                          _UrgencyBadge(urgency: booking.urgencyLevel),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Paziente Section
                      _DetailSection(
                        icon: Icons.person_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: 'Paziente',
                        children: [
                          _DetailRow(
                            icon: Icons.badge_outlined,
                            label: 'Nome',
                            value: _getPatientName(booking),
                          ),
                          _DetailRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _getPatientEmail(booking),
                          ),
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Telefono',
                            value: _getPatientPhone(booking),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Struttura Section
                      _DetailSection(
                        icon: Icons.local_hospital_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Struttura',
                        children: [
                          _DetailRow(
                            icon: Icons.business_outlined,
                            label: 'Nome',
                            value: booking.organization?.name ?? 'N/A',
                          ),
                          if (booking.organization?.city != null)
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'Località',
                              value: '${booking.organization?.city}, ${booking.organization?.province ?? ''}',
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Esame Section
                      _DetailSection(
                        icon: Icons.medical_services_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Esame',
                        children: [
                          _DetailRow(
                            icon: Icons.description_outlined,
                            label: 'Tipo',
                            value: booking.examType?.name ?? 'N/A',
                          ),
                          _DetailRow(
                            icon: Icons.euro_outlined,
                            label: 'Prezzo',
                            value: '${booking.price.toStringAsFixed(2)} €',
                            valueStyle: context.textStyles.bodyLarge?.semiBold.withColor(const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Data e Ora Section
                      _DetailSection(
                        icon: Icons.calendar_month_rounded,
                        iconColor: const Color(0xFFEC4899),
                        title: 'Data e Ora',
                        children: [
                          _DetailRow(
                            icon: Icons.event_outlined,
                            label: 'Data',
                            value: '${booking.bookingDate.day.toString().padLeft(2, '0')}/${booking.bookingDate.month.toString().padLeft(2, '0')}/${booking.bookingDate.year}',
                          ),
                          _DetailRow(
                            icon: Icons.access_time_outlined,
                            label: 'Ora',
                            value: '${booking.bookingTime.hour.toString().padLeft(2, '0')}:${booking.bookingTime.minute.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                      
                      // Note paziente
                      if (booking.notes?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 20),
                        _DetailSection(
                          icon: Icons.note_alt_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Note Paziente',
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A3340) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3A4350) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(booking.notes!,
                                style: context.textStyles.bodyMedium),
                            ),
                          ],
                        ),
                      ],
                      
                      // Note operatore
                      if (booking.operatorNotes?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 20),
                        _DetailSection(
                          icon: Icons.support_agent_rounded,
                          iconColor: const Color(0xFF06B6D4),
                          title: 'Note Operatore',
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A3340) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3A4350) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(booking.operatorNotes!,
                                style: context.textStyles.bodyMedium),
                            ),
                          ],
                        ),
                      ],
                      
                      // GFR Section (if present)
                      if (booking.gfrValue != null) ...[
                        const SizedBox(height: 20),
                        _GfrDetailSection(
                          gfrValue: booking.gfrValue!,
                          warningThreshold: booking.organization?.gfrWarningThreshold ?? 60.0,
                          criticalThreshold: booking.organization?.gfrCriticalThreshold ?? 30.0,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151A21) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Chiudi'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBooking(Booking booking) async {
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      if (profile == null) {
        debugPrint('[BookingsAdmin] ❌ Cannot confirm: no profile');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore: profilo non disponibile')),
          );
        }
        return;
      }

      debugPrint('[BookingsAdmin] 🔄 Confirming booking ${booking.id}...');
      final service = BookingService();
      final confirmed = await service.confirmBooking(booking.id, profile.id);
      
      if (confirmed != null) {
        debugPrint('[BookingsAdmin] ✅ Booking confirmed successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Prenotazione confermata: ${_getPatientName(booking)}')),
          );
          // Ricarica i dati per aggiornare la UI
          _loadData();
        }
      } else {
        debugPrint('[BookingsAdmin] ❌ Failed to confirm booking');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Errore durante la conferma')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('[BookingsAdmin] ❌ Error confirming booking: $e');
      debugPrint('[BookingsAdmin] Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Errore: $e')),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config['color'].withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        config['label'],
        style: context.textStyles.labelSmall?.semiBold.withColor(config['color']),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'confirmed': return {'label': 'Confermato', 'color': const Color(0xFF10B981)};
      case 'completed': return {'label': 'Completato', 'color': const Color(0xFF6366F1)};
      case 'cancelled': return {'label': 'Annullato', 'color': const Color(0xFFEF4444)};
      case 'rejected': return {'label': 'Rifiutato', 'color': const Color(0xFFEF4444)};
      case 'requested':
      default: return {'label': 'In attesa', 'color': const Color(0xFFF59E0B)};
    }
  }
}

class _UrgencyBadge extends StatelessWidget {
  final UrgencyLevel urgency;

  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency != UrgencyLevel.normal;
    final color = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF6B7280);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        urgency.displayName,
        style: context.textStyles.labelSmall?.semiBold.withColor(color),
      ),
    );
  }
}

class _ConfirmSwitch extends StatefulWidget {
  final Booking booking;
  final VoidCallback onConfirm;

  const _ConfirmSwitch({required this.booking, required this.onConfirm});

  @override
  State<_ConfirmSwitch> createState() => _ConfirmSwitchState();
}

class _ConfirmSwitchState extends State<_ConfirmSwitch> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: _confirming,
        activeColor: const Color(0xFF10B981),
        inactiveTrackColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
        inactiveThumbColor: const Color(0xFFEF4444),
        onChanged: (value) async {
          setState(() => _confirming = value);
          if (value) {
            await Future.delayed(const Duration(milliseconds: 300));
            widget.onConfirm();
          }
        },
      ),
    );
  }
}

/// Sezione del dialog di dettaglio
class _DetailSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3340) : const Color(0xFFE8EDF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title,
                  style: context.textStyles.titleSmall?.semiBold.withColor(iconColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Riga di dettaglio con icona e valore
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
              style: context.textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
              style: valueStyle ?? context.textStyles.bodyMedium?.semiBold),
          ),
        ],
      ),
    );
  }
}

/// Widget indicatore GFR per la tabella
class _GfrIndicator extends StatelessWidget {
  final double? gfrValue;
  final double warningThreshold;
  final double criticalThreshold;

  const _GfrIndicator({
    required this.gfrValue,
    required this.warningThreshold,
    required this.criticalThreshold,
  });

  @override
  Widget build(BuildContext context) {
    if (gfrValue == null) {
      return Text('-', style: context.textStyles.bodyMedium?.withColor(Colors.grey));
    }

    final isCritical = gfrValue! < criticalThreshold;
    final isWarning = gfrValue! < warningThreshold && !isCritical;
    
    if (isCritical) {
      return Tooltip(
        message: 'GFR critico: ${gfrValue!.toStringAsFixed(1)} mL/min/1.73m²\nControindicazione per contrasto',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_rounded, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Text(
                gfrValue!.toStringAsFixed(1),
                style: context.textStyles.labelSmall?.semiBold.withColor(const Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
      );
    }
    
    if (isWarning) {
      return Tooltip(
        message: 'GFR basso: ${gfrValue!.toStringAsFixed(1)} mL/min/1.73m²\nRichiede attenzione',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                gfrValue!.toStringAsFixed(1),
                style: context.textStyles.labelSmall?.semiBold.withColor(const Color(0xFFF59E0B)),
              ),
            ],
          ),
        ),
      );
    }

    // GFR normale
    return Tooltip(
      message: 'GFR: ${gfrValue!.toStringAsFixed(1)} mL/min/1.73m²',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          gfrValue!.toStringAsFixed(1),
          style: context.textStyles.labelSmall?.semiBold.withColor(const Color(0xFF10B981)),
        ),
      ),
    );
  }
}

/// Sezione dettaglio GFR nel dialog
class _GfrDetailSection extends StatelessWidget {
  final double gfrValue;
  final double warningThreshold;
  final double criticalThreshold;

  const _GfrDetailSection({
    required this.gfrValue,
    required this.warningThreshold,
    required this.criticalThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCritical = gfrValue < criticalThreshold;
    final isWarning = gfrValue < warningThreshold && !isCritical;
    
    Color iconColor;
    Color bgColor;
    String title;
    String message;
    IconData icon;
    
    if (isCritical) {
      iconColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFEF4444);
      title = 'GFR Critico ⚠️';
      message = 'Attenzione: il valore GFR è sotto la soglia critica (${criticalThreshold.toStringAsFixed(0)} mL/min/1.73m²). L\'uso del mezzo di contrasto è controindicato. Consultare il medico.';
      icon = Icons.error_rounded;
    } else if (isWarning) {
      iconColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFF59E0B);
      title = 'GFR Basso ⚠️';
      message = 'Il valore GFR è sotto la soglia di warning (${warningThreshold.toStringAsFixed(0)} mL/min/1.73m²). Richiede attenzione e possibili precauzioni per l\'uso del contrasto.';
      icon = Icons.warning_amber_rounded;
    } else {
      iconColor = const Color(0xFF10B981);
      bgColor = const Color(0xFF10B981);
      title = 'GFR Normale ✓';
      message = 'Il valore GFR è nella norma. Nessuna controindicazione per l\'uso del mezzo di contrasto.';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242C) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bgColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title,
                  style: context.textStyles.titleSmall?.semiBold.withColor(iconColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.science_outlined, size: 18, color: iconColor),
                    const SizedBox(width: 12),
                    Text('Valore GFR',
                      style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Text(
                      '${gfrValue.toStringAsFixed(1)} mL/min/1.73m²',
                      style: context.textStyles.titleMedium?.bold.withColor(iconColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A3340) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(message, style: context.textStyles.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
