import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'nav.dart';

/// Main entry point for the application (v2 - session persistence fix)
///
/// This sets up:
/// - Supabase initialization with IndexedDB session backup
/// - go_router navigation
/// - Material 3 theming with light/dark modes
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('[Main] ========== AVVIO APP ==========');
  
  // Suppress harmless Flutter Inspector errors
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Id does not exist')) {
      debugPrint('[Inspector] Ignored stale selection error');
      return;
    }
    FlutterError.presentError(details);
  };
  
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final msg = error.toString();
    if (msg.contains('Id does not exist')) {
      debugPrint('[Inspector] Ignored stale selection async error');
      return true;
    }
    return false;
  };
  
  try {
    // 1. Inizializza Supabase (con persistenza sessione)
    await SupabaseConfig.initialize();
    debugPrint('[Main] ✅ Supabase inizializzato');
    
    // 2. Inizializza Auth Manager (carica profilo se sessione attiva)
    await SupabaseAuthManager.instance.initialize();
    debugPrint('[Main] ✅ Auth Manager inizializzato');
    
    // 3. Inizializza locale italiano
    await initializeDateFormatting('it_IT', null);
    debugPrint('[Main] ✅ Locale IT inizializzato');
    
    debugPrint('[Main] ========== INIZIALIZZAZIONE COMPLETATA ==========');
    debugPrint('[Main] Sessione: ${SupabaseConfig.auth.currentUser?.email ?? "NESSUNA"}');
    debugPrint('[Main] Profilo: ${SupabaseAuthManager.instance.cachedProfile?.email ?? "NESSUNO"}');
    debugPrint('[Main] Org: ${SupabaseAuthManager.instance.cachedOrganization?["name"] ?? "NESSUNA"}');
    
  } catch (e, stack) {
    debugPrint('[Main] ❌ ERRORE INIZIALIZZAZIONE: $e');
    debugPrint('[Main] Stack: $stack');
    // Continua comunque ad avviare l'app
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ProntoRad',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,

      // Force 24-hour time across the entire app
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },

      routerConfig: AppRouter.router,
    );
  }
}
