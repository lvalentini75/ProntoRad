import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:xraynow/auth/auth_manager.dart';
import 'package:xraynow/models/user.dart' as app;
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/config/role_policies.dart';
import 'package:xraynow/utils/app_logger.dart';

/// Callback per progress bar durante login
typedef LoginProgressCallback = void Function(double progress, String label);

/// Auth Manager che usa la persistenza NATIVA di Supabase
/// 
/// Supabase SDK gestisce automaticamente:
/// - Persistenza sessione in localStorage (web) / shared_preferences (mobile)
/// - Refresh automatico del token
/// - Ripristino sessione al refresh della pagina
class SupabaseAuthManager extends AuthManager with EmailSignInManager {
  // Singleton
  static final SupabaseAuthManager _instance = SupabaseAuthManager._internal();
  static SupabaseAuthManager get instance => _instance;
  factory SupabaseAuthManager() => _instance;
  SupabaseAuthManager._internal();

  final UserService _userService = UserService();

  /// Cache del profilo utente (sincronizzata con DB)
  app.User? _cachedProfile;
  
  /// Cache dell'organizzazione (sincronizzata con DB)
  Map<String, dynamic>? _cachedOrganization;
  
  /// Flag di inizializzazione completata
  bool _initialized = false;
  
  /// Completer per garantire inizializzazione unica
  final Completer<void> _initCompleter = Completer<void>();
  
  /// Stream subscription per auth state changes
  StreamSubscription<sb.AuthState>? _authSubscription;
  
  /// Timer per rinnovare manualmente il token ogni 45 minuti
  Timer? _tokenRefreshTimer;

  /// Getter pubblici
  app.User? get cachedProfile => _cachedProfile;
  Map<String, dynamic>? get cachedOrganization => _cachedOrganization;
  bool get isInitialized => _initialized;
  Future<void> get initializationComplete => _initCompleter.future;

  /// Inizializza il sistema auth e ricostruisce la cache
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[Auth] Già inizializzato');
      return _initCompleter.future;
    }

    debugPrint('[Auth] ========== INIZIALIZZAZIONE AUTH MANAGER ==========');
    
    try {
      // Aspetta che Supabase sia pronto
      await SupabaseConfig.initialized;
      
      // 🚨 CRITICAL FIX: Aspetta ESPLICITAMENTE il primo evento auth
      // Questo garantisce che Supabase abbia completato il ripristino della sessione
      // da localStorage PRIMA che l'app proceda
      debugPrint('[Auth] ⏳ Aspetto primo evento auth da Supabase...');
      
      final firstAuthEventCompleter = Completer<void>();
      StreamSubscription<sb.AuthState>? tempSubscription;
      
      tempSubscription = SupabaseConfig.auth.onAuthStateChange.listen((data) {
        if (data.event == sb.AuthChangeEvent.initialSession) {
          debugPrint('[Auth] ✅ Ricevuto INITIAL_SESSION: ${data.session?.user.email ?? "nessuna sessione"}');
          tempSubscription?.cancel();
          firstAuthEventCompleter.complete();
        }
      });
      
      // Aspetta massimo 3 secondi per il primo evento
      await firstAuthEventCompleter.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[Auth] ⚠️ Timeout attesa INITIAL_SESSION, procedo comunque');
        },
      );
      
      // Ora setup del listener permanente
      _setupAuthStateListener();
      
      // Carica profilo se c'è una sessione attiva (ora siamo sicuri che sia stata ripristinata)
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser != null) {
        debugPrint('[Auth] ✅ Sessione attiva trovata: ${currentUser.email}');
        await _loadUserProfile(currentUser.id);
        _startTokenRefreshTimer(); // Avvia timer per rinnovo preventivo
      } else {
        debugPrint('[Auth] ℹ️ Nessuna sessione attiva');
      }
      
      _initialized = true;
      _initCompleter.complete();
      
      debugPrint('[Auth] ========== INIZIALIZZAZIONE COMPLETATA ==========');
      debugPrint('[Auth] Profilo: ${_cachedProfile?.email ?? "NESSUNO"}');
      debugPrint('[Auth] Ruolo: ${_cachedProfile?.role ?? "NESSUNO"}');
      debugPrint('[Auth] Organizzazione: ${_cachedOrganization?['name'] ?? "NESSUNA"}');
      
    } catch (e, stack) {
      debugPrint('[Auth] ❌ ERRORE INIZIALIZZAZIONE: $e');
      debugPrint('[Auth] Stack: $stack');
      _initCompleter.completeError(e, stack);
      rethrow;
    }
  }

  /// Setup listener per cambi stato autenticazione
  void _setupAuthStateListener() {
    _authSubscription?.cancel();
    
    _authSubscription = SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      
      debugPrint('[Auth] 🔔 State change: $event');
      
      switch (event) {
        case sb.AuthChangeEvent.signedIn:
          if (session?.user != null) {
            debugPrint('[Auth] ✅ Login riuscito: ${session!.user.email}');
            // 💾 Salva sessione in localStorage (web)
            if (kIsWeb) {
              SessionPersistence.saveSession(session);
            }
            await _loadUserProfile(session.user.id);
            _startTokenRefreshTimer(); // Avvia timer per rinnovo preventivo
          }
          break;
          
        case sb.AuthChangeEvent.tokenRefreshed:
          if (session?.user != null) {
            debugPrint('[Auth] 🔄 Token rinnovato automaticamente');
            if (session!.expiresAt != null) {
              final expiresDate = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
              debugPrint('[Auth]   - Nuova scadenza: ${expiresDate.toLocal()}');
            }
            // 💾 Aggiorna sessione salvata con nuovo token
            if (kIsWeb) {
              SessionPersistence.saveSession(session);
            }
            await _loadUserProfile(session.user.id);
          }
          break;
          
        case sb.AuthChangeEvent.userUpdated:
          if (session?.user != null) {
            debugPrint('[Auth] 📝 Profilo aggiornato per ${session!.user.email}');
            await _loadUserProfile(session.user.id);
          }
          break;
          
        case sb.AuthChangeEvent.signedOut:
          debugPrint('[Auth] 🚪 Logout: pulisco cache, timer e sessione salvata');
          _stopTokenRefreshTimer(); // Ferma timer
          // 🗑️ Cancella sessione salvata (web)
          if (kIsWeb) {
            SessionPersistence.clearSession();
          }
          _clearCache();
          break;
          
        default:
          break;
      }
    });
  }
  
  /// Avvia timer che rinnova il token ogni 45 minuti (prima della scadenza di 1 ora)
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer(); // Ferma timer esistente
    
    debugPrint('[Auth] 🕐 Avvio timer rinnovo token (ogni 45 minuti)');
    
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 45),
      (timer) async {
        try {
          final session = SupabaseConfig.auth.currentSession;
          if (session != null) {
            debugPrint('[Auth] ⏰ Timer scattato: rinnovo preventivo token...');
            
            // Rinnova il token manualmente
            await SupabaseConfig.auth.refreshSession();
            
            debugPrint('[Auth] ✅ Token rinnovato con successo (preventivo)');
          } else {
            debugPrint('[Auth] ⚠️ Timer scattato ma nessuna sessione attiva');
            timer.cancel();
          }
        } catch (e) {
          debugPrint('[Auth] ❌ Errore rinnovo preventivo token: $e');
        }
      },
    );
  }
  
  /// Ferma il timer di rinnovo token
  void _stopTokenRefreshTimer() {
    if (_tokenRefreshTimer != null) {
      debugPrint('[Auth] 🛑 Fermo timer rinnovo token');
      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = null;
    }
  }

  /// Carica il profilo utente dal database
  Future<void> _loadUserProfile(String authUserId) async {
    try {
      debugPrint('[Auth] Carico profilo per auth_user_id: $authUserId');
      
      // 1. Cerca per auth_user_id (metodo primario)
      var profile = await _userService.getUserByAuthId(authUserId);
      
      // 2. Se non trovato, cerca per email (fallback per utenti legacy)
      if (profile == null) {
        final authUser = SupabaseConfig.auth.currentUser;
        final email = authUser?.email;
        
        if (email != null && email.isNotEmpty) {
          debugPrint('[Auth] Profilo non trovato per auth_user_id, cerco per email: $email');
          profile = await _userService.getUserByEmail(email);
          
          // Collega auth_user_id se trovato per email
          if (profile != null) {
            debugPrint('[Auth] Profilo trovato per email, collego auth_user_id');
            try {
              profile = await _userService.ensureUserViaEdge(
                profile.copyWith(
                  authUserId: authUserId,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            } catch (e) {
              debugPrint('[Auth] Collegamento auth_user_id fallito (non bloccante): $e');
            }
          }
        }
      }
      
      // 3. Se non trovato, crea automaticamente un nuovo profilo
      if (profile == null) {
        final authUser = SupabaseConfig.auth.currentUser;
        if (authUser != null && authUser.email != null) {
          debugPrint('[Auth] 📝 Profilo non trovato, creo automaticamente per: ${authUser.email}');
          try {
            // Estrai nome e cognome dall'email se non disponibili nei metadati
            final metadata = authUser.userMetadata ?? {};
            final fullName = metadata['full_name'] as String? ?? '';
            final nameParts = fullName.split(' ');
            final firstName = metadata['first_name'] as String? ?? 
                              (nameParts.isNotEmpty ? nameParts.first : 'Utente');
            final lastName = metadata['last_name'] as String? ?? 
                             (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
            
            final newUser = app.User(
              id: '', // Generato dal DB
              email: authUser.email!,
              firstName: firstName,
              lastName: lastName,
              phoneNumber: authUser.phone ?? '',
              authUserId: authUserId,
              role: 'end_user',
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            );
            
            profile = await _userService.ensureUserViaEdge(newUser);
            debugPrint('[Auth] ✅ Profilo creato automaticamente: ${profile.email}');
          } catch (e) {
            debugPrint('[Auth] ❌ Creazione automatica profilo fallita: $e');
            _cachedProfile = null;
            _cachedOrganization = null;
            return;
          }
        } else {
          debugPrint('[Auth] ⚠️ Impossibile creare profilo: email mancante');
          _cachedProfile = null;
          _cachedOrganization = null;
          return;
        }
      }
      
      // Aggiorna cache profilo
      _cachedProfile = profile;
      debugPrint('[Auth] ✅ Profilo caricato: ${profile.email}');
      debugPrint('[Auth]   - ID: ${profile.id}');
      debugPrint('[Auth]   - Role: ${profile.role}');
      debugPrint('[Auth]   - Org ID: ${profile.organizationId ?? "NESSUNA"}');
      
      // Carica organizzazione se presente
      if (profile.organizationId != null && profile.organizationId!.isNotEmpty) {
        await _loadOrganization(profile.organizationId!);
      } else {
        _cachedOrganization = null;
      }
      
    } catch (e, stack) {
      debugPrint('[Auth] ❌ ERRORE caricamento profilo: $e');
      debugPrint('[Auth] Stack: $stack');
      _cachedProfile = null;
      _cachedOrganization = null;
    }
  }

  /// Carica l'organizzazione dal database
  Future<void> _loadOrganization(String organizationId) async {
    try {
      debugPrint('[Auth] Carico organizzazione: $organizationId');
      
      final orgData = await SupabaseConfig.client
          .from('organizations')
          .select('*')
          .eq('id', organizationId)
          .maybeSingle();
      
      if (orgData != null) {
        _cachedOrganization = Map<String, dynamic>.from(orgData as Map);
        debugPrint('[Auth] ✅ Organizzazione caricata: ${_cachedOrganization!['name']}');
      } else {
        debugPrint('[Auth] ⚠️ Organizzazione non trovata: $organizationId');
        _cachedOrganization = null;
      }
    } catch (e) {
      debugPrint('[Auth] ❌ ERRORE caricamento organizzazione: $e');
      _cachedOrganization = null;
    }
  }

  /// Pulisce la cache
  void _clearCache() {
    _cachedProfile = null;
    _cachedOrganization = null;
    debugPrint('[Auth] Cache pulita');
  }

  /// Aggiorna manualmente la cache del profilo
  void updateCachedProfile(app.User user) {
    _cachedProfile = user;
    debugPrint('[Auth] Cache profilo aggiornata: ${user.email}');
  }

  /// Aggiorna manualmente la cache dell'organizzazione
  void updateCachedOrganization(Map<String, dynamic>? org) {
    _cachedOrganization = org;
    debugPrint('[Auth] Cache organizzazione aggiornata: ${org?['name'] ?? "NESSUNA"}');
  }

  /// Ricarica profilo e organizzazione dal database
  Future<void> reloadProfile() async {
    final authUser = SupabaseConfig.auth.currentUser;
    if (authUser != null) {
      await _loadUserProfile(authUser.id);
    }
  }

  // ========== METODI DI AUTENTICAZIONE ==========

  /// Login con email e password + caricamento completo profilo
  Future<app.User?> signInWithEmailAndLoadProfile(
    BuildContext context,
    String email,
    String password, {
    LoginProgressCallback? onProgress,
  }) async {
    AppLogger.instance.auth('LOGIN_START', '========== INIZIO LOGIN ==========');
    AppLogger.instance.auth('LOGIN_START', 'Email: $email');
    
    _clearCache();

    try {
      // STEP 1: Autenticazione (0% -> 30%)
      AppLogger.instance.auth('LOGIN_STEP1', 'Chiamata signInWithPassword...');
      onProgress?.call(0.1, 'Verifica credenziali…');
      
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        AppLogger.instance.error('LOGIN_STEP1', 'Response user è NULL - credenziali invalide');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credenziali non valide')),
          );
        }
        return null;
      }

      final authUser = response.user!;
      final session = response.session;
      
      AppLogger.instance.success('LOGIN_STEP1', 'Autenticazione Supabase completata!');
      AppLogger.instance.auth('LOGIN_STEP1', 'User email: ${authUser.email}');
      AppLogger.instance.auth('LOGIN_STEP1', 'User ID: ${authUser.id}');
      AppLogger.instance.auth('LOGIN_STEP1', 'Session presente: ${session != null}');
      
      if (session != null) {
        final accessToken = session.accessToken;
        final refreshToken = session.refreshToken;
        
        AppLogger.instance.auth('LOGIN_STEP1', 'Access token: ${accessToken.length > 30 ? accessToken.substring(0, 30) : accessToken}...');
        if (refreshToken != null) {
          AppLogger.instance.auth('LOGIN_STEP1', 'Refresh token: ${refreshToken.length > 30 ? refreshToken.substring(0, 30) : refreshToken}...');
        }
        AppLogger.instance.auth('LOGIN_STEP1', 'Expires at: ${session.expiresAt}');
        
        if (session.expiresAt != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
          AppLogger.instance.auth('LOGIN_STEP1', 'Scadenza: ${expiryDate.toLocal()}');
        }
      }
      
      // 💾 SALVA SESSIONE IN LOCALSTORAGE (web)
      if (kIsWeb && session != null) {
        SessionPersistence.saveSession(session);
        AppLogger.instance.success('LOGIN_STEP1', '💾 Sessione salvata in localStorage');
      }
      
      // Attendi propagazione
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Verifica che la sessione sia stata salvata
      final verifySession = SupabaseConfig.auth.currentSession;
      if (verifySession != null) {
        AppLogger.instance.success('LOGIN_STEP1', '✅ Sessione verificata in memoria Supabase');
        // Verifica anche localStorage
        if (kIsWeb && SessionPersistence.hasStoredSession()) {
          AppLogger.instance.success('LOGIN_STEP1', '✅ Sessione verificata in localStorage');
        }
      } else {
        AppLogger.instance.error('LOGIN_STEP1', '❌ ATTENZIONE: sessione NON trovata dopo login!');
      }
      
      onProgress?.call(0.3, 'Autenticazione riuscita');

      // STEP 2: Caricamento profilo (30% -> 60%)
      debugPrint('██ STEP 2: Caricamento profilo utente...');
      onProgress?.call(0.4, 'Caricamento profilo…');
      
      var profile = await _userService.getUserByAuthId(authUser.id);
      
      // Se non esiste, cerca per email (utenti legacy)
      if (profile == null) {
        debugPrint('██ STEP 2: Profilo non trovato per auth_user_id, cerco per email');
        profile = await _userService.getUserByEmail(email);
        
        // Collega auth_user_id
        if (profile != null) {
          debugPrint('██ STEP 2: Profilo trovato per email, collego auth_user_id');
          try {
            profile = await _userService.ensureUserViaEdge(
              profile.copyWith(
                authUserId: authUser.id,
                updatedAt: DateTime.now().toUtc(),
              ),
            );
          } catch (e) {
            debugPrint('██ STEP 2: Collegamento auth_user_id fallito: $e');
          }
        }
      }
      
      // Se ancora non esiste, crea profilo
      if (profile == null) {
        debugPrint('██ STEP 2: Profilo non esiste, creo nuovo');
        profile = await _createProfileForAuthUser(authUser);
      }
      
      if (profile == null) {
        debugPrint('██ ❌ STEP 2 FALLITO: Impossibile creare/caricare profilo');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore caricamento profilo')),
          );
        }
        await SupabaseConfig.auth.signOut();
        return null;
      }
      
      _cachedProfile = profile;
      debugPrint('██ ✅ STEP 2 COMPLETATO: Profilo caricato!');
      debugPrint('██   ID: ${profile.id}');
      debugPrint('██   Nome: ${profile.fullName}');
      debugPrint('██   Role: ${profile.role}');
      onProgress?.call(0.6, 'Profilo caricato');

      // STEP 3: Caricamento organizzazione (60% -> 90%)
      debugPrint('██ STEP 3: Caricamento organizzazione...');
      onProgress?.call(0.7, 'Caricamento organizzazione…');
      
      if (profile.organizationId != null && profile.organizationId!.isNotEmpty) {
        await _loadOrganization(profile.organizationId!);
      }
      
      debugPrint('██ ✅ STEP 3 COMPLETATO');
      onProgress?.call(1.0, 'Login completato');
      
      debugPrint('');
      debugPrint('██████████████████████████████████████████████████████████████');
      debugPrint('██ 🎉 LOGIN COMPLETATO CON SUCCESSO!');
      debugPrint('██ Profilo: ${_cachedProfile?.email}');
      debugPrint('██ Ruolo: ${_cachedProfile?.role}');
      debugPrint('██████████████████████████████████████████████████████████████');
      debugPrint('');
      
      return _cachedProfile;

    } on sb.AuthException catch (e) {
      debugPrint('[Auth] ❌ AuthException: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return null;
    } catch (e, stack) {
      debugPrint('[Auth] ❌ Errore login: $e');
      debugPrint('[Auth] Stack: $stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il login: $e')),
        );
      }
      return null;
    }
  }

  /// Crea un profilo per un nuovo utente autenticato
  Future<app.User?> _createProfileForAuthUser(sb.User authUser) async {
    try {
      debugPrint('[Auth] Creazione profilo per ${authUser.email}');
      
      final metadata = <String, dynamic>{
        ...(authUser.appMetadata ?? {}),
        ...(authUser.userMetadata ?? {}),
      };
      
      // Estrai nome e cognome
      String firstName = (metadata['first_name'] ?? '').toString().trim();
      String lastName = (metadata['last_name'] ?? '').toString().trim();
      
      if (firstName.isEmpty || lastName.isEmpty) {
        // Fallback: usa email
        final emailPart = (authUser.email ?? '').split('@').first;
        final parts = emailPart.split(RegExp(r'[._-]'));
        if (firstName.isEmpty) firstName = parts.isNotEmpty ? _capitalize(parts[0]) : 'Utente';
        if (lastName.isEmpty) lastName = parts.length > 1 ? _capitalize(parts[1]) : 'ProntoRad';
      }

      // Determina il ruolo
      final policyRole = RolePolicies.roleForEmail(authUser.email);
      final metaRole = metadata['role']?.toString();
      final role = (policyRole ?? metaRole ?? 'end_user').toLowerCase();

      debugPrint('[Auth] Creo profilo: $firstName $lastName (role: $role)');

      final newUser = app.User(
        id: '',
        firstName: firstName,
        lastName: lastName,
        email: authUser.email ?? '',
        phoneNumber: '',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        authUserId: authUser.id,
        role: role,
        organizationId: null,
      );

      final created = await _userService.ensureUserViaEdge(newUser);
      debugPrint('[Auth] ✅ Profilo creato con ID: ${created.id}');
      return created;
      
    } catch (e, stack) {
      debugPrint('[Auth] ❌ Creazione profilo fallita: $e');
      debugPrint('[Auth] Stack: $stack');
      return null;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // ========== OVERRIDE METODI AUTH MANAGER ==========

  @override
  Future<app.User?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    return signInWithEmailAndLoadProfile(context, email, password);
  }

  @override
  Future<app.User?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password, {
    Map<String, dynamic>? metadata,
    String? emailRedirectTo,
  }) async {
    try {
      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
        data: metadata,
        emailRedirectTo: emailRedirectTo,
      );

      if (response.user != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registrazione effettuata. Controlla la tua email.'),
            ),
          );
        }
      }
      return null;
    } on sb.AuthException catch (e) {
      debugPrint('[Auth] Signup error: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return null;
    } catch (e) {
      debugPrint('[Auth] Signup error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la registrazione')),
        );
      }
      return null;
    }
  }

  @override
  Future signOut() async {
    debugPrint('[Auth] 🚪 Logout');
    _stopTokenRefreshTimer(); // Ferma timer prima di logout
    _clearCache();
    // 🗑️ Cancella sessione da localStorage (web)
    if (kIsWeb) {
      SessionPersistence.clearSession();
      debugPrint('[Auth] 🗑️ Sessione rimossa da localStorage');
    }
    try {
      await SupabaseConfig.auth.signOut();
      debugPrint('[Auth] ✅ Logout completato');
    } catch (e) {
      debugPrint('[Auth] ❌ Logout error: $e');
      rethrow;
    }
  }

  @override
  Future deleteUser(BuildContext context) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        await _userService.deleteUser(user.id);
      }
      _clearCache();
    } catch (e) {
      debugPrint('[Auth] Delete user error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore eliminazione account')),
        );
      }
      rethrow;
    }
  }

  @override
  Future updateEmail({required String email, required BuildContext context}) async {
    try {
      await SupabaseConfig.auth.updateUser(sb.UserAttributes(email: email));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email aggiornata')),
        );
      }
    } on sb.AuthException catch (e) {
      debugPrint('[Auth] Update email error: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      rethrow;
    }
  }

  @override
  Future resetPassword({required String email, required BuildContext context}) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email di recupero inviata')),
        );
      }
    } on sb.AuthException catch (e) {
      debugPrint('[Auth] Reset password error: ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      rethrow;
    }
  }

  app.User? getCurrentAuthUser() => _cachedProfile;
  bool get isAuthenticated => SupabaseConfig.auth.currentUser != null;
  String? get currentUserId => SupabaseConfig.auth.currentUser?.id;

  /// Cleanup
  void dispose() {
    _authSubscription?.cancel();
  }
}
