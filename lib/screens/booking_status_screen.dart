import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/theme.dart';

class BookingStatusScreen extends StatefulWidget {
  final String bookingId;

  const BookingStatusScreen({super.key, required this.bookingId});

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  final BookingService _bookingService = BookingService();
  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[BookingStatus] Loading booking: ${widget.bookingId}');
      final booking = await _bookingService.getBookingById(widget.bookingId);
      
      if (booking == null) {
        debugPrint('[BookingStatus] Booking not found');
        setState(() {
          _errorMessage = 'Prenotazione non trovata';
          _isLoading = false;
        });
        return;
      }

      debugPrint('[BookingStatus] Booking loaded successfully');
      debugPrint('[BookingStatus] User: ${booking.user?.fullName}');
      debugPrint('[BookingStatus] Exam: ${booking.examType?.name}');
      debugPrint('[BookingStatus] Organization: ${booking.organization?.name}');

      setState(() {
        _booking = booking;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('[BookingStatus] Error loading booking: $e');
      debugPrint('[BookingStatus] Stack trace: $stack');
      setState(() {
        _errorMessage = 'Errore nel caricamento della prenotazione';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Stato prenotazione'),
        backgroundColor: Colors.white,
        foregroundColor: LightModeColors.lightOnSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null || _booking == null
              ? _buildErrorState()
              : _buildSuccessState(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'Prenotazione non trovata',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Si è verificato un problema nel caricamento della prenotazione',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadBooking,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Torna alla home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    final booking = _booking!;
    final isConfirmed = booking.status == BookingStatus.confirmed;

    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LightModeColors.lightPrimary,
                  LightModeColors.lightSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isConfirmed ? 'Prenotazione confermata!' : 'Richiesta inviata!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isConfirmed
                      ? 'La tua prenotazione è stata confermata'
                      : 'La tua richiesta è stata inviata alla struttura',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status timeline
          _BookingTimeline(status: booking.status),
          const SizedBox(height: 24),

          // Booking details card
          _BookingDetailsCard(booking: booking),
          const SizedBox(height: 16),

          // Patient details card
          _PatientDetailsCard(booking: booking),
          const SizedBox(height: 16),

          // Info banner
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: LightModeColors.lightPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConfirmed
                        ? 'Riceverai un promemoria via SMS prima dell\'appuntamento'
                        : 'Riceverai una conferma via email e SMS dalla struttura',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LightModeColors.lightPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text('Torna alla home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/bookings'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LightModeColors.lightPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: LightModeColors.lightPrimary, width: 2),
            ),
            child: const Text('Vedi tutte le prenotazioni', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BookingTimeline extends StatelessWidget {
  final BookingStatus status;

  const _BookingTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == BookingStatus.confirmed;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimelineStep(
              icon: Icons.send,
              label: 'Richiesta\nInviata',
              isCompleted: true,
              isActive: status == BookingStatus.requested,
            ),
          ),
          Container(
            width: 40,
            height: 2,
            color: isConfirmed ? LightModeColors.lightPrimary : Colors.grey.shade300,
          ),
          Expanded(
            child: _TimelineStep(
              icon: Icons.check_circle,
              label: 'Confermata',
              isCompleted: isConfirmed,
              isActive: isConfirmed,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCompleted;
  final bool isActive;

  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isCompleted ? LightModeColors.lightPrimary : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isCompleted ? Colors.white : Colors.grey.shade600,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isCompleted ? LightModeColors.lightPrimary : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _BookingDetailsCard extends StatelessWidget {
  final Booking booking;

  const _BookingDetailsCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services, color: LightModeColors.lightPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Dettagli prenotazione',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.science,
            label: 'Esame',
            value: booking.examType?.name ?? 'N/A',
          ),
          _DetailRow(
            icon: Icons.business,
            label: 'Struttura',
            value: booking.organization?.name ?? 'N/A',
          ),
          _DetailRow(
            icon: Icons.location_on,
            label: 'Indirizzo',
            value: booking.organization?.fullAddress ?? 'N/A',
          ),
          _DetailRow(
            icon: Icons.calendar_today,
            label: 'Data',
            value: DateFormat('EEEE dd MMMM yyyy', 'it').format(booking.bookingDate),
          ),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Orario',
            value: DateFormat('HH:mm').format(booking.bookingTime),
          ),
          _DetailRow(
            icon: Icons.euro,
            label: 'Prezzo',
            value: '€${booking.price.toStringAsFixed(2)}',
          ),
          if (booking.needsTransport)
            _DetailRow(
              icon: Icons.local_taxi,
              label: 'Trasporto',
              value: 'Richiesto',
            ),
          if (booking.isHomeService)
            _DetailRow(
              icon: Icons.home,
              label: 'Servizio',
              value: 'A domicilio',
            ),
        ],
      ),
    );
  }
}

class _PatientDetailsCard extends StatelessWidget {
  final Booking booking;

  const _PatientDetailsCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final user = booking.user;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: LightModeColors.lightPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Dati paziente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.badge,
            label: 'Nome completo',
            value: user?.fullName ?? 'N/A',
          ),
          _DetailRow(
            icon: Icons.email,
            label: 'Email',
            value: user?.email ?? 'N/A',
          ),
          _DetailRow(
            icon: Icons.phone,
            label: 'Telefono',
            value: user?.phoneNumber ?? 'N/A',
          ),
          if (user?.fiscalCode != null)
            _DetailRow(
              icon: Icons.credit_card,
              label: 'Codice fiscale',
              value: user!.fiscalCode!,
            ),
          if (user?.dateOfBirth != null)
            _DetailRow(
              icon: Icons.cake,
              label: 'Data di nascita',
              value: DateFormat('dd/MM/yyyy').format(user!.dateOfBirth!),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: LightModeColors.lightPrimary.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
