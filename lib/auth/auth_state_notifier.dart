import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';

/// Notifier per cambiamenti stato autenticazione
/// 
/// Ascolta SupabaseConfig.auth.onAuthStateChange e notifica i listener
/// (principalmente GoRouter) quando lo stato auth cambia.
/// 
/// NOTA: Inizializzazione completata in main() prima della creazione del router,
/// quindi isInitializing è sempre false quando questo notifier viene creato.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    debugPrint('[AuthStateNotifier] 🚀 Inizializzazione auth notifier (init già completata in main)');
    
    _subscription = SupabaseConfig.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('[AuthStateNotifier] 🔔 Auth event: $event, user: ${data.session?.user.email ?? "null"}');
      
      // Notifica il router per rieseguire redirect logic
      notifyListeners();
    });
  }
  
  /// L'inizializzazione è completata in main() prima che il router venga creato,
  /// quindi questo è sempre false
  bool get isInitializing => false;
  
  StreamSubscription<AuthState>? _subscription;
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
