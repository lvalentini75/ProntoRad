import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/theme.dart';

/// Web dashboard shell with sidebar navigation
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final profile = SupabaseAuthManager.instance.cachedProfile;
    final role = profile?.role ?? 'end_user';
    
    return Scaffold(
      body: Row(
        children: [
          DashboardSidebar(currentRole: role),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Sidebar navigation component
class DashboardSidebar extends StatelessWidget {
  final String currentRole;

  const DashboardSidebar({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1419) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark 
              ? const Color(0xFF2A3340) 
              : const Color(0xFFE8EDF2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 72,
            padding: AppSpacing.horizontalLg,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark 
                    ? const Color(0xFF2A3340) 
                    : const Color(0xFFE8EDF2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_hospital_rounded, 
                    color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRONTORAD',
                        style: context.textStyles.titleMedium?.bold),
                      Text(_getRoleLabel(currentRole),
                        style: context.textStyles.labelSmall
                          ?.withColor(colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: _buildNavItems(context, currentPath),
            ),
          ),

          // User profile section
          _buildUserSection(context),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context, String currentPath) {
    if (currentRole == 'super_admin') {
      return [
        _NavGroup(title: 'Dashboard', children: [
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Panoramica',
            route: '/dashboard',
            isActive: currentPath == '/dashboard',
          ),
          _NavItem(
            icon: Icons.analytics_rounded,
            label: 'KPI & Report',
            route: '/dashboard/kpi',
            isActive: currentPath == '/dashboard/kpi',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Gestione', children: [
          _NavItem(
            icon: Icons.people_rounded,
            label: 'Utenti',
            route: '/dashboard/users',
            isActive: currentPath == '/dashboard/users',
          ),
          _NavItem(
            icon: Icons.business_rounded,
            label: 'Ospedali',
            route: '/dashboard/organizations',
            isActive: currentPath == '/dashboard/organizations',
          ),
          _NavItem(
            icon: Icons.medical_information_outlined,
            label: 'Anagrafiche',
            route: '/dashboard/exams',
            isActive: currentPath == '/dashboard/exams',
          ),
          _NavItem(
            icon: Icons.euro_rounded,
            label: 'Tariffari',
            route: '/dashboard/tariffs',
            isActive: currentPath == '/dashboard/tariffs',
          ),
          _NavItem(
            icon: Icons.access_time_rounded,
            label: 'Disponibilità',
            route: '/dashboard/availability',
            isActive: currentPath == '/dashboard/availability',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Esami Multipli', children: [
          _NavItem(
            icon: Icons.inventory_2_rounded,
            label: 'Esami Multipli',
            route: '/dashboard/exam-packages',
            isActive: currentPath == '/dashboard/exam-packages',
          ),
          _NavItem(
            icon: Icons.link_rounded,
            label: 'Esami in Relazione',
            route: '/dashboard/exam-compatibility',
            isActive: currentPath == '/dashboard/exam-compatibility',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Prenotazioni', children: [
          _NavItem(
            icon: Icons.add_circle_outline,
            label: 'Inserisci Prenotazione',
            route: '/dashboard/bookings/create',
            isActive: currentPath == '/dashboard/bookings/create',
          ),
          _NavItem(
            icon: Icons.calendar_today_rounded,
            label: 'Tutte',
            route: '/dashboard/bookings',
            isActive: currentPath == '/dashboard/bookings',
          ),
          _NavItem(
            icon: Icons.pending_actions_rounded,
            label: 'In attesa',
            route: '/dashboard/bookings/pending',
            isActive: currentPath == '/dashboard/bookings/pending',
          ),
          _NavItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Confermate',
            route: '/dashboard/bookings/confirmed',
            isActive: currentPath == '/dashboard/bookings/confirmed',
          ),
          _NavItem(
            icon: Icons.calendar_view_day_rounded,
            label: 'Planning Sale',
            route: '/dashboard/planning',
            isActive: currentPath == '/dashboard/planning',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Sistema', children: [
          _NavItem(
            icon: Icons.history_rounded,
            label: 'Audit Log',
            route: '/dashboard/audit',
            isActive: currentPath == '/dashboard/audit',
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Impostazioni',
            route: '/dashboard/settings',
            isActive: currentPath == '/dashboard/settings',
          ),
        ]),
      ];
    }
    
    if (currentRole == 'org_admin') {
      return [
        _NavGroup(title: 'Dashboard', children: [
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Panoramica',
            route: '/dashboard',
            isActive: currentPath == '/dashboard',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Prenotazioni', children: [
          _NavItem(
            icon: Icons.add_circle_outline,
            label: 'Inserisci Prenotazione',
            route: '/dashboard/bookings/create',
            isActive: currentPath == '/dashboard/bookings/create',
          ),
          _NavItem(
            icon: Icons.calendar_today_rounded,
            label: 'Tutte',
            route: '/dashboard/bookings',
            isActive: currentPath == '/dashboard/bookings',
          ),
          _NavItem(
            icon: Icons.pending_actions_rounded,
            label: 'In attesa',
            route: '/dashboard/bookings/pending',
            isActive: currentPath == '/dashboard/bookings/pending',
          ),
          _NavItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Confermate',
            route: '/dashboard/bookings/confirmed',
            isActive: currentPath == '/dashboard/bookings/confirmed',
          ),
          _NavItem(
            icon: Icons.calendar_view_day_rounded,
            label: 'Planning Sale',
            route: '/dashboard/planning',
            isActive: currentPath == '/dashboard/planning',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Gestione', children: [
          _NavItem(
            icon: Icons.medical_services_outlined,
            label: 'Offerte Esami',
            route: '/dashboard/offerings',
            isActive: currentPath == '/dashboard/offerings',
          ),
          _NavItem(
            icon: Icons.euro_rounded,
            label: 'Tariffari',
            route: '/dashboard/tariffs',
            isActive: currentPath == '/dashboard/tariffs',
          ),
          _NavItem(
            icon: Icons.access_time_rounded,
            label: 'Disponibilità',
            route: '/dashboard/availability',
            isActive: currentPath == '/dashboard/availability',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Esami Multipli', children: [
          _NavItem(
            icon: Icons.inventory_2_rounded,
            label: 'Esami Multipli',
            route: '/dashboard/exam-packages',
            isActive: currentPath == '/dashboard/exam-packages',
          ),
          _NavItem(
            icon: Icons.link_rounded,
            label: 'Esami in Relazione',
            route: '/dashboard/exam-compatibility',
            isActive: currentPath == '/dashboard/exam-compatibility',
          ),
        ]),
        const SizedBox(height: 8),
        _NavGroup(title: 'Impostazioni', children: [
          _NavItem(
            icon: Icons.business_rounded,
            label: 'Profilo Ospedale',
            route: '/dashboard/settings',
            isActive: currentPath == '/dashboard/settings',
          ),
        ]),
      ];
    }
    
    // end_user o altri ruoli
    return [];
  }

  Widget _buildUserSection(BuildContext context) {
    final profile = SupabaseAuthManager.instance.cachedProfile;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark 
              ? const Color(0xFF2A3340) 
              : const Color(0xFFE8EDF2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              (profile?.firstName?.isNotEmpty ?? false) 
                ? profile!.firstName![0].toUpperCase() 
                : '?',
              style: context.textStyles.titleMedium?.bold
                .withColor(colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${profile?.firstName ?? ''} ${profile?.lastName ?? ''}'.trim(),
                  style: context.textStyles.bodyMedium?.semiBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  profile?.email ?? '',
                  style: context.textStyles.labelSmall
                    ?.withColor(colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.go('/logs'),
            icon: Icon(Icons.bug_report, size: 20),
            tooltip: 'Log Debug',
          ),
          IconButton(
            onPressed: () async {
              await SupabaseAuthManager.instance.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Esci',
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'org_admin': return 'Amministratore';
      case 'end_user': return 'Utente';
      default: return role;
    }
  }
}

/// Navigation group with title
class _NavGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _NavGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
          child: Text(
            title.toUpperCase(),
            style: context.textStyles.labelSmall?.semiBold
              .withColor(colorScheme.onSurfaceVariant),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Single navigation item
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive 
                ? (isDark ? const Color(0xFF1E2430) : const Color(0xFFF8FAFC))
                : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive 
                    ? colorScheme.primary 
                    : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: (isActive 
                    ? context.textStyles.bodyMedium?.semiBold 
                    : context.textStyles.bodyMedium)
                    ?.withColor(
                      isActive 
                        ? colorScheme.primary 
                        : colorScheme.onSurface,
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
