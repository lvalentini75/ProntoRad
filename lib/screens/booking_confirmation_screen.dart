import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/exam_package.dart';
import 'package:xraynow/models/facility.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/models/user.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/theme.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final ExamType? exam;
  final ExamPackage? examPackage;
  final String organizationId;
  final String organizationName;
  final DateTime date;
  final DateTime time;
  final UrgencyLevel urgency;
  final String? slotId;
  final double? price;

  const BookingConfirmationScreen({
    super.key,
    this.exam,
    this.examPackage,
    required this.organizationId,
    required this.organizationName,
    required this.date,
    required this.time,
    required this.urgency,
    this.slotId,
    this.price,
  }) : assert(exam != null || examPackage != null);
  
  /// Ottiene il nome da mostrare
  String get displayName => exam?.name ?? examPackage?.name ?? 'Esame';
  
  /// Ottiene la categoria dell'esame (per il colore)
  String get categoryLabel {
    if (exam != null) {
      return exam!.category.name.toUpperCase();
    }
    return 'PACCHETTO';
  }

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gfrController = TextEditingController();
  
  bool _isLoading = false;
  bool _packageContainsTac = false;
  
  /// Returns true if this exam requires GFR value (TAC exams)
  bool get _requiresGfr => widget.exam?.category == ExamCategory.tac || _packageContainsTac;
  
  @override
  void initState() {
    super.initState();
    _checkPackageForTac();
  }
  
  /// Check if the exam package contains any TAC exams
  Future<void> _checkPackageForTac() async {
    if (widget.examPackage == null) return;
    
    try {
      final examService = ExamService();
      for (final examId in widget.examPackage!.examIds) {
        final exam = await examService.getExamById(examId);
        if (exam?.category == ExamCategory.tac) {
          if (mounted) {
            setState(() => _packageContainsTac = true);
          }
          debugPrint('[BookingConfirmation] 📋 Package contains TAC exam: ${exam?.name}');
          return;
        }
      }
    } catch (e) {
      debugPrint('[BookingConfirmation] Error checking package for TAC: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _gfrController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      // Fornisci un feedback visibile quando i campi sono incompleti
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compila tutti i campi obbligatori')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bookingService = BookingService();
      final userService = UserService();

      // Ensure we have a user record (also for anon users) using email as key
      final email = _emailController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();
      final now = DateTime.now();

      User? existing = await userService.getUserByEmail(email);
      User user;
      if (existing == null) {
        user = await userService.createUser(User(
          id: '', // will be generated server-side
          firstName: firstName,
          lastName: lastName,
          email: email,
          phoneNumber: phone,
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        // Optionally keep user data fresh
        final updated = existing.copyWith(
          firstName: firstName.isNotEmpty ? firstName : existing.firstName,
          lastName: lastName.isNotEmpty ? lastName : existing.lastName,
          phoneNumber: phone.isNotEmpty ? phone : existing.phoneNumber,
          updatedAt: now,
        );
        user = await userService.updateUser(updated);
      }

      final examId = widget.exam?.id;
      final examName = widget.displayName;
      final packageId = widget.examPackage?.id;
      
      debugPrint('[BookingConfirmation] 📋 Creazione prenotazione:');
      debugPrint('[BookingConfirmation]   - userId: ${user.id}');
      debugPrint('[BookingConfirmation]   - organizationId: ${widget.organizationId}');
      debugPrint('[BookingConfirmation]   - organizationName: ${widget.organizationName}');
      debugPrint('[BookingConfirmation]   - examTypeId: $examId');
      debugPrint('[BookingConfirmation]   - packageId: $packageId');
      debugPrint('[BookingConfirmation]   - examName: $examName');
      debugPrint('[BookingConfirmation]   - slotId: ${widget.slotId ?? "N/A"}');
      
      late final String bookingIdToShow;
      
      // If booking a package, create multiple bookings (one per exam)
      if (packageId != null && packageId.isNotEmpty) {
        debugPrint('[BookingConfirmation] 📦 Creazione prenotazioni multiple per pacchetto...');
        final gfrValue = _requiresGfr ? double.tryParse(_gfrController.text.trim()) : null;
        final createdBookings = await bookingService.createPackageBookings(
          userId: user.id,
          organizationId: widget.organizationId,
          packageId: packageId,
          bookingDate: widget.date,
          bookingTime: widget.time,
          slotId: widget.slotId,
          urgency: widget.urgency,
          totalPrice: widget.price ?? 80.0,
          notes: null,
          gfrValue: gfrValue,
        );
        
        debugPrint('[BookingConfirmation] ✅ Create ${createdBookings.length} prenotazioni per il pacchetto');
        // Show the parent booking (first one)
        bookingIdToShow = createdBookings.first.id;
      } else {
        // Single exam booking
        final gfrValue = _requiresGfr ? double.tryParse(_gfrController.text.trim()) : null;
        final createdBooking = await bookingService.createBookingWithLock(
          userId: user.id,
          organizationId: widget.organizationId,
          examTypeId: examId,
          bookingDate: widget.date,
          bookingTime: widget.time,
          slotId: widget.slotId,
          urgency: widget.urgency,
          price: widget.price ?? 80.0,
          notes: null,
          gfrValue: gfrValue,
        );
        
        debugPrint('[BookingConfirmation] ✅ Prenotazione creata con ID: ${createdBooking.id}');
        debugPrint('[BookingConfirmation] ✅ Organization ID salvato: ${createdBooking.organizationId}');
        bookingIdToShow = createdBooking.id;
      }

      if (mounted) {
        final isPackage = packageId != null && packageId.isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isPackage 
            ? '✅ Prenotazioni del pacchetto create con successo!' 
            : '✅ Prenotazione inserita con successo!'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 800),
        ));
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go('/booking-status/$bookingIdToShow');
      }
    } catch (e) {
      debugPrint('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante la prenotazione: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final months = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    final timeStr = '${widget.time.hour.toString().padLeft(2, '0')}:${widget.time.minute.toString().padLeft(2, '0')}';
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, color: LightModeColors.lightPrimary, size: 28),
              Text(
                'Indietro',
                style: TextStyle(
                  color: LightModeColors.lightPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 120,
        title: const Text(
          'Conferma Prenotazione',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exam summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.categoryLabel} - ${widget.displayName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.organizationName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(widget.date),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: LightModeColors.lightPrimary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Patient data section
                const Text(
                  'Dati Paziente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nome
                const Text(
                  'Nome',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _firstNameController,
                  decoration: _inputDecoration('Mario'),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Inserisci il nome' : null,
                ),
                const SizedBox(height: 16),
                
                // Cognome
                const Text(
                  'Cognome',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _lastNameController,
                  decoration: _inputDecoration('Rossi'),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Inserisci il cognome' : null,
                ),
                const SizedBox(height: 16),
                
                // Email
                const Text(
                  'Email',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  decoration: _inputDecoration('mario.rossi@email.com'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) return 'Inserisci l\'email';
                    if (!value!.contains('@')) return 'Email non valida';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Cellulare
                const Text(
                  'Cellulare',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  decoration: _inputDecoration('+39 333 1234567'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Inserisci il numero' : null,
                ),
                
                // GFR field - only for TAC exams
                if (_requiresGfr) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Per gli esami TAC con mezzo di contrasto è necessario indicare il valore GFR.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Valore GFR (mL/min/1.73m²)',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _gfrController,
                    decoration: _inputDecoration('Es: 90').copyWith(
                      suffixText: 'mL/min/1.73m²',
                      suffixStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!_requiresGfr) return null;
                      if (value?.trim().isEmpty ?? true) return 'Inserisci il valore GFR';
                      final gfr = double.tryParse(value!.trim());
                      if (gfr == null) return 'Inserisci un valore numerico valido';
                      if (gfr < 0 || gfr > 200) return 'Il valore deve essere tra 0 e 200';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Valori normali: > 90 mL/min/1.73m². Valori bassi possono indicare insufficienza renale.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.lightPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Conferma Prenotazione',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: LightModeColors.lightPrimary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
