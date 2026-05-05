import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/config/role_policies.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    
    _controller.forward();
    
    _navigateAfterInit();
  }
  
  Future<void> _navigateAfterInit() async {
    debugPrint('[Splash] ========== INIZIO INIT ==========');
    
    try {
      // IMPORTANTE: Aspetta che TUTTA l'inizializzazione sia completata
      // incluso il recupero della sessione salvata
      debugPrint('[Splash] Attendo inizializzazione completa...');
      await SupabaseAuthManager.instance.initializationComplete;
      debugPrint('[Splash] ✅ Inizializzazione Auth Manager completata');
      
      // Aspetta un frame aggiuntivo per assicurarsi che tutti gli eventi auth siano processati
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Aspetta animazione minima (dopo l'init per evitare ritardi)
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Verifica stato
      final authManager = SupabaseAuthManager.instance;
      final currentUser = SupabaseConfig.auth.currentUser;
      final profile = authManager.cachedProfile;
      
      debugPrint('[Splash] ========== STATO FINALE ==========');
      debugPrint('[Splash]   - Auth User: ${currentUser?.email ?? "NESSUNO"}');
      debugPrint('[Splash]   - Profilo: ${profile?.email ?? "NESSUNO"}');
      debugPrint('[Splash]   - Ruolo: ${profile?.role ?? "NESSUNO"}');
      debugPrint('[Splash]   - Org: ${authManager.cachedOrganization?["name"] ?? "NESSUNA"}');
      
      if (!mounted) return;
      
      // Determina se siamo su desktop web (larghezza >= 1024px)
      final screenWidth = MediaQuery.of(context).size.width;
      final isDesktopWeb = kIsWeb && screenWidth >= 1024;
      debugPrint('[Splash] Screen width: $screenWidth, isDesktopWeb: $isDesktopWeb');
      
      // Naviga alla home (app mobile) o dashboard (web admin)
      if (currentUser != null && profile != null) {
        final role = profile.role;
        if (kIsWeb && (role == 'super_admin' || role == 'org_admin')) {
          debugPrint('[Splash] → Navigazione a Dashboard (admin web)');
          context.go('/dashboard');
        } else if (isDesktopWeb) {
          // Desktop web senza ruolo admin: mostra comunque dashboard login
          debugPrint('[Splash] → Navigazione a Dashboard Login (desktop web, end_user)');
          context.go('/dashboard/login');
        } else {
          debugPrint('[Splash] → Navigazione a Home');
          context.go('/home');
        }
      } else {
        // Utente non autenticato
        if (isDesktopWeb) {
          // Desktop web: vai al login dashboard
          debugPrint('[Splash] → Navigazione a Dashboard Login (desktop web)');
          context.go('/dashboard/login');
        } else {
          // Mobile: vai alla home (app mobile senza login)
          debugPrint('[Splash] → Navigazione a Home (no auth)');
          context.go('/home');
        }
      }
      
    } catch (e, stack) {
      debugPrint('[Splash] ❌ ERRORE: $e');
      debugPrint('[Splash] Stack: $stack');
      // Triggera comunque il refresh per mostrare schermata di errore
      if (mounted) {
        setState(() {});
      }
    }
    
    debugPrint('[Splash] ========== FINE INIT ==========');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.splashBackground,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_hospital_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PRONTORAD',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: BrandColors.brandNavy,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
