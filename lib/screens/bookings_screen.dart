import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/theme.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final UserService _userService = UserService();
  
  late TabController _tabController;
  List<Booking> _allBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        final bookings = await _bookingService.getUserBookings(user.id);
        bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _allBookings = bookings;
          _isLoading = false;
        });
      } else {
        setState(() {
          _allBookings = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Booking> get _upcomingBookings {
    final now = DateTime.now();
    return _allBookings.where((b) {
      final bookingDateTime = DateTime(
        b.bookingDate.year,
        b.bookingDate.month,
        b.bookingDate.day,
        b.bookingTime.hour,
        b.bookingTime.minute,
      );
      return bookingDateTime.isAfter(now) &&
          (b.status == BookingStatus.requested || b.status == BookingStatus.confirmed);
    }).toList()
      ..sort((a, b) => a.bookingDate.compareTo(b.bookingDate));
  }

  List<Booking> get _pastBookings {
    final now = DateTime.now();
    return _allBookings.where((b) {
      final bookingDateTime = DateTime(
        b.bookingDate.year,
        b.bookingDate.month,
        b.bookingDate.day,
        b.bookingTime.hour,
        b.bookingTime.minute,
      );
      return bookingDateTime.isBefore(now) || 
          b.status == BookingStatus.completed ||
          b.status == BookingStatus.cancelled ||
          b.status == BookingStatus.rejected;
    }).toList()
      ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = SupabaseConfig.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie prenotazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: isAuthenticated && _allBookings.isNotEmpty
            ? TabBar(
                controller: _tabController,
                labelColor: LightModeColors.lightPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: LightModeColors.lightPrimary,
                tabs: [
                  Tab(text: 'Tutte (${_allBookings.length})'),
                  Tab(text: 'Prossime (${_upcomingBookings.length})'),
                  Tab(text: 'Storico (${_pastBookings.length})'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isAuthenticated
              ? _buildLoginPrompt()
              : _allBookings.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBookingsList(_allBookings, 'Nessuna prenotazione'),
                          _buildBookingsList(_upcomingBookings, 'Nessuna prenotazione in programma'),
                          _buildBookingsList(_pastBookings, 'Nessuna prenotazione passata'),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.login,
              size: 50,
              color: LightModeColors.lightPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Accedi per vedere le tue prenotazioni',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Effettua il login per visualizzare e gestire le tue prenotazioni.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login),
            label: const Text('Accedi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push('/signup'),
            child: const Text('Non hai un account? Registrati'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Nessuna prenotazione',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Non hai ancora effettuato prenotazioni.\nPrenota il tuo primo esame!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.add),
            label: const Text('Prenota ora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> bookings, String emptyMessage) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingMd,
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return BookingCard(
          booking: booking,
          onTap: () => context.push('/booking-status/${booking.id}'),
        );
      },
    );
  }
}

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (booking.status) {
      case BookingStatus.requested:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.rejected:
        return Colors.redAccent;
      case BookingStatus.completed:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (booking.status) {
      case BookingStatus.requested:
        return Icons.pending;
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.rejected:
        return Icons.block;
      case BookingStatus.completed:
        return Icons.task_alt;
    }
  }

  bool get _isPast {
    final now = DateTime.now();
    final bookingDateTime = DateTime(
      booking.bookingDate.year,
      booking.bookingDate.month,
      booking.bookingDate.day,
      booking.bookingTime.hour,
      booking.bookingTime.minute,
    );
    return bookingDateTime.isBefore(now) ||
        booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _isPast ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isPast ? Colors.grey[300]! : LightModeColors.lightOutline,
        ),
        boxShadow: _isPast
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(), size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    booking.status.displayName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Creata ${_formatDateShort(booking.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getExamIcon(booking.examType?.category.name ?? ''),
                          color: LightModeColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.examType?.name ?? 'Esame',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _isPast ? Colors.grey[700] : null,
                              ),
                            ),
                            if (booking.organization != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                booking.organization!.name,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today,
                        label: DateFormat('dd MMM yyyy', 'it').format(booking.bookingDate),
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.access_time,
                        label: DateFormat('HH:mm').format(booking.bookingTime),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '€${booking.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: LightModeColors.lightPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Dettagli',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: LightModeColors.lightPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: LightModeColors.lightPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getExamIcon(String category) {
    switch (category.toLowerCase()) {
      case 'rm':
      case 'risonanza':
        return Icons.psychology;
      case 'tac':
      case 'tomografia':
        return Icons.scanner;
      case 'eco':
      case 'ecografia':
        return Icons.waves;
      case 'rx':
      case 'radiografia':
        return Icons.radio_button_checked;
      default:
        return Icons.medical_services;
    }
  }

  String _formatDateShort(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'oggi';
    } else if (difference.inDays == 1) {
      return 'ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
