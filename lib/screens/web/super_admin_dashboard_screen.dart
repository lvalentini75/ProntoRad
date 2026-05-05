import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/screens/web/widgets/stat_card.dart';
import 'package:xraynow/screens/web/widgets/recent_activity_card.dart';
import 'package:xraynow/screens/web/widgets/chart_card.dart';
import 'package:xraynow/services/booking_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/services/exam_service.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';

/// Dashboard - Panoramica generale del sistema (adattiva per super_admin e org_admin)
class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  bool _loading = true;
  
  // Stats
  int _totalUsers = 0;
  int _totalOrganizations = 0;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _todayBookings = 0;
  double _avgBookingsPerDay = 0;
  
  // Recent data
  List<Map<String, dynamic>> _recentBookings = [];
  List<Map<String, dynamic>> _topOrganizations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final role = profile?.role ?? 'end_user';
      final isOrgAdmin = role == 'org_admin';
      final organizationId = profile?.organizationId;

      final userService = UserService();
      final orgService = OrganizationService();
      final bookingService = BookingService();
      final examService = ExamService();

      // Load data based on role
      List users;
      List orgs;
      List bookings;

      if (isOrgAdmin && organizationId != null) {
        // Org admin sees only their organization's data
        final results = await Future.wait([
          Future.value([]), // org_admin doesn't need all users
          orgService.getOrganizationById(organizationId).then((org) => org != null ? [org] : []),
          bookingService.getBookingsForOrganization(organizationId),
        ]);
        users = results[0] as List;
        orgs = results[1] as List;
        bookings = results[2] as List;
      } else {
        // Super admin sees all data
        final results = await Future.wait([
          userService.getAllUsers(),
          orgService.getAllOrganizations(),
          bookingService.getAllBookings(),
        ]);
        users = results[0] as List;
        orgs = results[1] as List;
        bookings = results[2] as List;
      }

      // Calculate stats
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayBookings = bookings.where((b) {
        final date = b['created_at'] is DateTime 
          ? b['created_at'] as DateTime
          : DateTime.parse(b['created_at']);
        return date.isAfter(todayStart);
      }).length;

      final pending = bookings.where((b) => b['status'] == 'pending').length;

      // Calculate average bookings per day (last 30 days)
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      final recentBookings = bookings.where((b) {
        final date = b['created_at'] is DateTime 
          ? b['created_at'] as DateTime
          : DateTime.parse(b['created_at']);
        return date.isAfter(thirtyDaysAgo);
      }).length;
      final avgPerDay = recentBookings / 30;

      // Get recent bookings with full details
      final sortedBookings = List.from(bookings)
        ..sort((a, b) {
          final aDate = a['created_at'] is DateTime 
            ? a['created_at'] as DateTime
            : DateTime.parse(a['created_at']);
          final bDate = b['created_at'] is DateTime 
            ? b['created_at'] as DateTime
            : DateTime.parse(b['created_at']);
          return bDate.compareTo(aDate);
        });

      // Get top organizations by booking count
      final orgBookingCounts = <String, int>{};
      for (var booking in bookings) {
        final orgId = booking['organization_id'] as String?;
        if (orgId != null) {
          orgBookingCounts[orgId] = (orgBookingCounts[orgId] ?? 0) + 1;
        }
      }
      
      final topOrgIds = orgBookingCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topOrgs = <Map<String, dynamic>>[];
      for (var entry in topOrgIds.take(5)) {
        final org = orgs.firstWhere(
          (o) => o['id'] == entry.key,
          orElse: () => null,
        );
        if (org != null) {
          topOrgs.add({
            'name': org['name'],
            'bookings': entry.value,
          });
        }
      }

      if (mounted) {
        setState(() {
          _totalUsers = users.length;
          _totalOrganizations = orgs.length;
          _totalBookings = bookings.length;
          _pendingBookings = pending;
          _todayBookings = todayBookings;
          _avgBookingsPerDay = avgPerDay;
          _recentBookings = sortedBookings.take(8).toList().cast<Map<String, dynamic>>();
          _topOrganizations = topOrgs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [SuperAdminDashboard] Error loading data: $e');
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard',
                            style: context.textStyles.headlineLarge?.bold),
                          const SizedBox(height: 4),
                          Text('Benvenuto nella panoramica generale 👋',
                            style: context.textStyles.bodyLarge
                              ?.withColor(colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    _RefreshButton(onRefresh: _loadDashboardData),
                  ],
                ),
                const SizedBox(height: 32),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.people_rounded,
                        label: 'Utenti totali',
                        value: _totalUsers.toString(),
                        trend: '+12%',
                        trendUp: true,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.business_rounded,
                        label: 'Ospedali',
                        value: _totalOrganizations.toString(),
                        trend: '+3',
                        trendUp: true,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Prenotazioni totali',
                        value: _totalBookings.toString(),
                        trend: '+${_todayBookings} oggi',
                        trendUp: true,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        icon: Icons.pending_actions_rounded,
                        label: 'In attesa',
                        value: _pendingBookings.toString(),
                        trend: '${(_avgBookingsPerDay).toStringAsFixed(1)}/giorno',
                        trendUp: false,
                        color: const Color(0xFFF59E0B),
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
                      flex: 2,
                      child: ChartCard(
                        title: 'Prenotazioni ultimi 7 giorni',
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RecentActivityCard(
                        title: 'Top 5 Ospedali',
                        icon: Icons.stars_rounded,
                        activities: _topOrganizations.map((org) => 
                          '${org['name']} • ${org['bookings']} prenotazioni'
                        ).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent bookings
                RecentActivityCard(
                  title: 'Prenotazioni recenti',
                  icon: Icons.history_rounded,
                  activities: _recentBookings.map((booking) {
                    final status = booking['status'] ?? 'pending';
                    final emoji = status == 'confirmed' ? '✅' : 
                                  status == 'cancelled' ? '❌' : '⏳';
                    return '$emoji ${booking['patient_name']} • ${booking['exam_name']}';
                  }).toList(),
                ),
              ],
            ),
          ),
    );
  }
}

/// Refresh button component
class _RefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;

  const _RefreshButton({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E2430) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onRefresh,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark 
                ? const Color(0xFF2A3340) 
                : const Color(0xFFE8EDF2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 18, 
                color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Aggiorna',
                style: context.textStyles.bodyMedium?.semiBold
                  .withColor(colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
