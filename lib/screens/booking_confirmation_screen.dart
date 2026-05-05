import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/facility.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/models/user.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/theme.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final ExamType exam;
  final String organizationId;
  final String organizationName;
  final DateTime date;
  final DateTime time;
  final UrgencyLevel urgency;
  final String? slotId;
  final double? price;

  const BookingConfirmationScreen({
    super.key,
    required this.exam,
    required this.organizationId,
    required this.organizationName,
    required this.date,
    required this.time,
    required this.urgency,
    this.slotId,
    this.price,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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

      debugPrint('[BookingConfirmation] 📋 Creazione prenotazione:');
      debugPrint('[BookingConfirmation]   - userId: ${user.id}');
      debugPrint('[BookingConfirmation]   - organizationId: ${widget.organizationId}');
      debugPrint('[BookingConfirmation]   - organizationName: ${widget.organizationName}');
      debugPrint('[BookingConfirmation]   - examTypeId: ${widget.exam.id}');
      debugPrint('[BookingConfirmation]   - examName: ${widget.exam.name}');
      debugPrint('[BookingConfirmation]   - slotId: ${widget.slotId ?? "N/A"}');
      
      final createdBooking = await bookingService.createBookingWithLock(
        userId: user.id,
        organizationId: widget.organizationId,
        examTypeId: widget.exam.id,
        bookingDate: widget.date,
        bookingTime: widget.time,
        slotId: widget.slotId,
        urgency: widget.urgency,
        price: widget.price ?? 80.0,
        notes: null,
      );
      
      debugPrint('[BookingConfirmation] ✅ Prenotazione creata con ID: ${createdBooking.id}');
      debugPrint('[BookingConfirmation] ✅ Organization ID salvato: ${createdBooking.organizationId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Prenotazione inserita con successo!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ));
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go('/booking-status/${createdBooking.id}');
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
                              '${widget.exam.category.displayName} - ${widget.exam.name}',
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
