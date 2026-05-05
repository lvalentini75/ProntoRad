import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/nav.dart';

/// Shell wrapper for mobile pages with persistent bottom navigation
class MobileAppShell extends StatelessWidget {
  const MobileAppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final colorScheme = Theme.of(context).colorScheme;
    
    // Determine selected index based on current route
    int selectedIndex = 0;
    if (location.startsWith(AppRoutes.bookings) || location.contains('/booking')) {
      selectedIndex = 1;
    } else if (location.startsWith(AppRoutes.profile)) {
      selectedIndex = 2;
    } else if (location.startsWith(AppRoutes.support)) {
      selectedIndex = 3;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Material(
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: NavigationBar(
          elevation: 0,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go(AppRoutes.home);
                break;
              case 1:
                context.go(AppRoutes.bookings);
                break;
              case 2:
                context.go(AppRoutes.profile);
                break;
              case 3:
                context.go(AppRoutes.support);
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Prenotazioni',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profilo',
            ),
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined),
              selectedIcon: Icon(Icons.support_agent),
              label: 'Supporto',
            ),
          ],
        ),
      ),
    );
  }
}
