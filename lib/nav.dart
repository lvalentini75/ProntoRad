import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:go_router/go_router.dart';
import 'package:xraynow/screens/splash_screen.dart';
import 'package:xraynow/screens/login_screen.dart';
import 'package:xraynow/screens/signup_screen.dart';
import 'package:xraynow/screens/home_screen.dart';
import 'package:xraynow/screens/exam_selection_screen.dart';
import 'package:xraynow/screens/location_selection_screen.dart';
import 'package:xraynow/screens/facility_list_screen.dart';
import 'package:xraynow/screens/booking_confirmation_screen.dart';
import 'package:xraynow/screens/booking_status_screen.dart';
import 'package:xraynow/screens/bookings_screen.dart';
import 'package:xraynow/screens/profile_screen.dart';
import 'package:xraynow/screens/support_screen.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/models/booking.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/screens/mobile_app_shell.dart';
import 'package:xraynow/screens/web/app_shell.dart';
import 'package:xraynow/screens/web/super_admin_dashboard_screen.dart';
import 'package:xraynow/screens/web/users_management_screen.dart';
import 'package:xraynow/screens/web/organizations_management_screen.dart';
import 'package:xraynow/screens/web/bookings_admin_screen.dart';
import 'package:xraynow/screens/web/kpi_screen.dart';
import 'package:xraynow/screens/web/placeholder_screen.dart';
import 'package:xraynow/screens/web/web_login_screen.dart';
import 'package:xraynow/screens/web/exams_registry_screen.dart';
import 'package:xraynow/screens/web/hospital_profile_screen.dart';
import 'package:xraynow/screens/web/exam_offerings_screen.dart';
import 'package:xraynow/screens/web/tariffs_management_screen.dart';
import 'package:xraynow/screens/web/availability_management_screen.dart';
import 'package:xraynow/screens/web/create_booking_admin_screen.dart';
import 'package:xraynow/screens/logs_viewer_screen.dart';
import 'package:xraynow/screens/debug_auth_test_screen.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/auth/auth_state_notifier.dart';

class AppRouter {
  static final _authNotifier = AuthStateNotifier();
  
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isOnSplash = loc == AppRoutes.splash;
      final isAuthenticated = SupabaseConfig.auth.currentUser != null;
      final isOnAuthPage = loc == AppRoutes.login || loc == AppRoutes.signup;
      final isOnDashboard = loc.startsWith('/dashboard');
      final isOnHome = loc == AppRoutes.home;
      final profile = SupabaseAuthManager.instance.cachedProfile;
      
      debugPrint('[Router] 🔀 loc=$loc, auth=$isAuthenticated, profile=${profile?.email ?? "null"}');

      // Splash: lascia che SplashScreen gestisca la navigazione iniziale
      if (isOnSplash) {
        debugPrint('[Router] 🌅 Su splash, lascio gestire a SplashScreen');
        return null;
      }
      
      // Desktop web detection: redirect non-auth users to dashboard login
      if (kIsWeb && !isAuthenticated && (isOnHome || loc == '/')) {
        final view = View.maybeOf(context);
        if (view != null) {
          final screenWidth = view.physicalSize.width / view.devicePixelRatio;
          final isDesktopWeb = screenWidth >= 1024;
          debugPrint('[Router] 🖥️ Screen width: $screenWidth, isDesktopWeb: $isDesktopWeb');
          if (isDesktopWeb) {
            debugPrint('[Router] 🖥️ Desktop web detected, redirect a dashboard login1');
            return '/dashboard/login1';
          }
        }
      }

      // App mobile: se già autenticato e su /login, redirect appropriato
      if (loc == '/login' && isAuthenticated) {
        final profile = SupabaseAuthManager.instance.cachedProfile;
        final role = profile?.role ?? 'end_user';
        if (role == 'super_admin' || role == 'org_admin') {
          debugPrint('[Router] ✅ Admin già autenticato, vai a dashboard');
          return AppRoutes.dashboard;
        }
        debugPrint('[Router] ✅ Utente già autenticato, vai alla home');
        return AppRoutes.home;
      }

      // Web dashboard access control (solo per /dashboard/* che NON siano /dashboard/login o /dashboard/login1)
      if (kIsWeb && isOnDashboard && loc != '/dashboard/login' && loc != '/dashboard/login1') {
        if (!isAuthenticated || profile == null) {
          debugPrint('[Router] 🔒 Dashboard richiede auth, redirect a dashboard login1');
          return '/dashboard/login1';
        }
        
        final role = profile.role;
        if (role != 'super_admin' && role != 'org_admin') {
          debugPrint('[Router] 🚫 Non autorizzato per dashboard (role=$role)');
          return '/dashboard/login1';
        }
      }

      // Se autenticato e su pagina di login, reindirizza alla destinazione corretta
      if (isAuthenticated && profile != null && isOnAuthPage) {
        final role = profile.role;
        if (loc == '/dashboard/login' && (role == 'super_admin' || role == 'org_admin')) {
          debugPrint('[Router] ✅ Admin autenticato su login, vai a dashboard');
          return AppRoutes.dashboard;
        }
        debugPrint('[Router] ✅ Utente autenticato su login, vai a home');
        return AppRoutes.home;
      }

      debugPrint('[Router] ✓ Nessun redirect necessario');
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(
          child: kIsWeb ? const WebLoginScreen() : const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboardLogin,
        name: 'dashboard-login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: WebLoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboardLogin1,
        name: 'dashboard-login1',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: WebLoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SignupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.debugAuthTest,
        name: 'debug-auth-test',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: DebugAuthTestScreen(),
        ),
      ),
      // Mobile shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MobileAppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.bookings,
            name: 'bookings',
            pageBuilder: (context, state) => const NoTransitionPage(child: BookingsScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: AppRoutes.support,
            name: 'support',
            pageBuilder: (context, state) => const NoTransitionPage(child: SupportScreen()),
          ),
          GoRoute(
            path: AppRoutes.logs,
            name: 'logs',
            builder: (context, state) => const LogsViewerScreen(),
          ),
          // Booking flow pages with bottom navigation
          GoRoute(
            path: AppRoutes.examSelection,
            name: 'exam-selection',
            pageBuilder: (context, state) {
              final category = state.extra as ExamCategory;
              return NoTransitionPage(
                child: ExamSelectionScreen(category: category),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.locationSelection,
            name: 'location-selection',
            pageBuilder: (context, state) {
              final exam = state.extra as ExamType;
              return NoTransitionPage(
                child: LocationSelectionScreen(exam: exam),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.facilityList,
            name: 'facility-list',
            pageBuilder: (context, state) {
              final params = state.extra as Map<String, dynamic>;
              return NoTransitionPage(
                child: FacilityListScreen(
                  exam: params['exam'] as ExamType,
                  region: params['region'] as String,
                  province: params['province'] as String,
                  city: params['city'] as String,
                  userLat: params['userLat'] as double?,
                  userLon: params['userLon'] as double?,
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.bookingConfirmation,
            name: 'booking-confirmation',
            pageBuilder: (context, state) {
              final params = state.extra as Map<String, dynamic>;
              return NoTransitionPage(
                child: BookingConfirmationScreen(
                  exam: params['exam'] as ExamType,
                  organizationId: params['organizationId'] as String,
                  organizationName: params['organizationName'] as String,
                  date: params['date'] as DateTime,
                  time: params['time'] as DateTime,
                  urgency: params['urgency'] as UrgencyLevel,
                  slotId: params['slotId'] as String?,
                  price: params['price'] as double?,
                ),
              );
            },
          ),
          GoRoute(
            path: '${AppRoutes.bookingStatus}/:id',
            name: 'booking-status',
            pageBuilder: (context, state) {
              final bookingId = state.pathParameters['id']!;
              return NoTransitionPage(
                child: BookingStatusScreen(bookingId: bookingId),
              );
            },
          ),
        ],
      ),
      // Web dashboard shell with sidebar
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SuperAdminDashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardKPI,
            name: 'dashboard-kpi',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: KPIScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardUsers,
            name: 'dashboard-users',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UsersManagementScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardOrganizations,
            name: 'dashboard-organizations',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrganizationsManagementScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardBookings,
            name: 'dashboard-bookings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BookingsAdminScreen(key: ValueKey('bookings-all')),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardBookingsPending,
            name: 'dashboard-bookings-pending',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BookingsAdminScreen(
                key: ValueKey('bookings-pending'),
                initialFilter: 'requested',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardBookingsConfirmed,
            name: 'dashboard-bookings-confirmed',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BookingsAdminScreen(
                key: ValueKey('bookings-confirmed'),
                initialFilter: 'confirmed',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardBookingsCreate,
            name: 'dashboard-bookings-create',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CreateBookingAdminScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardExams,
            name: 'dashboard-exams',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExamsRegistryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardTariffs,
            name: 'dashboard-tariffs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TariffsManagementScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardAudit,
            name: 'dashboard-audit',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlaceholderScreen(
                title: 'Audit Log',
                icon: Icons.history_rounded,
                description: 'Cronologia delle azioni amministrative del sistema.',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardOfferingsManagement,
            name: 'dashboard-offerings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExamOfferingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardAvailability,
            name: 'dashboard-availability',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AvailabilityManagementScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboardSettings,
            name: 'dashboard-settings',
            pageBuilder: (context, state) {
              // Per org_admin mostra HospitalProfileScreen, per altri placeholder
              final profile = SupabaseAuthManager.instance.cachedProfile;
              final isOrgAdmin = profile?.role == 'org_admin';
              
              return NoTransitionPage(
                child: isOrgAdmin 
                  ? const HospitalProfileScreen()
                  : const PlaceholderScreen(
                      title: 'Impostazioni',
                      icon: Icons.settings_rounded,
                      description: 'Configura le impostazioni del sistema.',
                    ),
              );
            },
          ),
        ],
      ),
    ],
  );
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String examSelection = '/exam-selection';
  static const String locationSelection = '/location-selection';
  static const String facilityList = '/facility-list';
  static const String bookingConfirmation = '/booking-confirmation';
  static const String bookingStatus = '/booking-status';
  static const String bookings = '/bookings';
  static const String profile = '/profile';
  static const String support = '/support';
  
  // Web dashboard routes
  static const String dashboard = '/dashboard';
  static const String dashboardLogin = '/dashboard/login';
  static const String dashboardLogin1 = '/dashboard/login1';
  static const String dashboardKPI = '/dashboard/kpi';
  static const String dashboardUsers = '/dashboard/users';
  static const String dashboardOrganizations = '/dashboard/organizations';
  static const String dashboardExams = '/dashboard/exams';
  static const String dashboardTariffs = '/dashboard/tariffs';
  static const String dashboardOfferingsManagement = '/dashboard/offerings';
  static const String dashboardAvailability = '/dashboard/availability';
  static const String dashboardBookings = '/dashboard/bookings';
  static const String dashboardBookingsPending = '/dashboard/bookings/pending';
  static const String dashboardBookingsConfirmed = '/dashboard/bookings/confirmed';
  static const String dashboardBookingsCreate = '/dashboard/bookings/create';
  static const String dashboardAudit = '/dashboard/audit';
  static const String dashboardSettings = '/dashboard/settings';
  
  // Debug routes
  static const String logs = '/logs';
  static const String debugAuthTest = '/debug-auth-test';
}

/// Helper to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
