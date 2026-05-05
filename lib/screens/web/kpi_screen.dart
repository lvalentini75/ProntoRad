import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/screens/web/widgets/stat_card.dart';
import 'package:xraynow/screens/web/widgets/chart_card.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/models/booking.dart';
import 'package:flutter/foundation.dart';

/// KPI & Analytics screen for Super Admin
class KPIScreen extends StatefulWidget {
  const KPIScreen({super.key});

  @override
  State<KPIScreen> createState() => _KPIScreenState();
}

class _KPIScreenState extends State<KPIScreen> {
  bool _loading = true;
  
  // KPIs
  double _conversionRate = 0;
  double _avgRevenuePerBooking = 0;
  int _activeUsers = 0;
  int _newUsersThisMonth = 0;
  Map<String, int> _examTypeDistribution = {};
  Map<String, int> _regionDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadKPIs();
  }

  Future<void> _loadKPIs() async {
    try {
      final bookingService = BookingService();
      final userService = UserService();

      final bookings = await bookingService.getAllBookings();
      final users = await userService.getAllUsers();

      // Calculate conversion rate (confirmed / total)
      final confirmed = bookings.where((b) => b.status == BookingStatus.confirmed).length;
      final conversionRate = bookings.isNotEmpty ? (confirmed / bookings.length) * 100 : 0.0;

      // Calculate average revenue (mock data for now)
      final avgRevenue = bookings.isNotEmpty ? 85.0 : 0.0;

      // Active users (users who made at least one booking)
      final activeUserIds = bookings.map((b) => b.userId).toSet();
      final activeUsers = activeUserIds.length;

      // New users this month
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final newUsers = users.where((u) => u.createdAt.isAfter(thisMonthStart)).length;

      // Exam type distribution
      final examDist = <String, int>{};
      for (var booking in bookings) {
        final examName = booking.examType?.name ?? 'Altro';
        examDist[examName] = (examDist[examName] ?? 0) + 1;
      }

      // Region distribution (mock)
      final regionDist = {
        'Lombardia': 45,
        'Lazio': 32,
        'Campania': 28,
        'Veneto': 25,
        'Emilia-Romagna': 22,
      };

      if (mounted) {
        setState(() {
          _conversionRate = conversionRate;
          _avgRevenuePerBooking = avgRevenue;
          _activeUsers = activeUsers;
          _newUsersThisMonth = newUsers;
          _examTypeDistribution = examDist;
          _regionDistribution = regionDist;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [KPIScreen] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.analytics_rounded, 
                      size: 32, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text('KPI & Report',
                      style: context.textStyles.headlineLarge?.bold),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Dashboard analitica e metriche di business 📊',
                  style: context.textStyles.bodyLarge
                    ?.withColor(colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),

                // Primary KPIs
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Tasso di conversione',
                        value: '${_conversionRate.toStringAsFixed(1)}%',
                        trend: '+2.3%',
                        trendUp: true,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.euro_rounded,
                        label: 'Revenue media',
                        value: '€${_avgRevenuePerBooking.toStringAsFixed(0)}',
                        trend: '+€8',
                        trendUp: true,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.group_rounded,
                        label: 'Utenti attivi',
                        value: _activeUsers.toString(),
                        trend: '${_newUsersThisMonth} questo mese',
                        trendUp: true,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Charts row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ChartCard(
                        title: 'Trend prenotazioni mensili',
                        icon: Icons.show_chart_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DistributionCard(
                        title: 'Distribuzione per esame',
                        icon: Icons.pie_chart_rounded,
                        data: _examTypeDistribution,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Regional distribution
                _DistributionCard(
                  title: 'Distribuzione geografica',
                  icon: Icons.map_rounded,
                  data: _regionDistribution,
                ),
              ],
            ),
          ),
    );
  }
}

/// Distribution card with horizontal bars
class _DistributionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> data;

  const _DistributionCard({
    required this.title,
    required this.icon,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
            ? const Color(0xFF2A3340) 
            : const Color(0xFFE8EDF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: context.textStyles.titleMedium?.semiBold),
            ],
          ),
          const SizedBox(height: 20),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Nessun dato disponibile',
                  style: context.textStyles.bodyMedium
                    ?.withColor(colorScheme.onSurfaceVariant)),
              ),
            )
          else
            ...sorted.take(5).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                          style: context.textStyles.bodySmall?.semiBold),
                      ),
                      Text('${entry.value}',
                        style: context.textStyles.bodySmall?.semiBold
                          .withColor(colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / maxValue,
                      minHeight: 6,
                      backgroundColor: isDark 
                        ? const Color(0xFF2A3340) 
                        : const Color(0xFFE8EDF2),
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
