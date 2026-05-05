import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web show window, localStorage;
import 'package:xraynow/utils/app_logger.dart';

/// Chiave localStorage per la sessione (separata da PKCE)
const String _sessionStorageKey = 'prontorad_supabase_session';

/// Implementazione di GotrueAsyncStorage per web usando browser localStorage
class WebLocalStorage implements GotrueAsyncStorage {
  const WebLocalStorage();
  
  @override
  Future<String?> getItem({required String key}) async {
    if (!kIsWeb) return null;
    try {
      debugPrint('[WebLocalStorage] 📥 GET: $key');
      final value = web.window.localStorage.getItem(key);
      debugPrint('[WebLocalStorage] 📥 GET result: ${value != null ? "${value.length} chars" : "NULL"}');
      AppLogger.instance.storage('GET', key, value: value ?? 'NULL');
      return value;
    } catch (e) {
      debugPrint('[WebLocalStorage] ❌ GET ERROR: $e');
      AppLogger.instance.error('WebLocalStorage', 'Errore getItem($key): $e');
      return null;
    }
  }
  
  @override
  Future<void> setItem({required String key, required String value}) async {
    if (!kIsWeb) return;
    try {
      debugPrint('[WebLocalStorage] 💾 SET: $key (${value.length} chars)');
      web.window.localStorage.setItem(key, value);
      debugPrint('[WebLocalStorage] ✅ SET success');
      AppLogger.instance.storage('SET', key, value: '${value.length} chars');
    } catch (e) {
      debugPrint('[WebLocalStorage] ❌ SET ERROR: $e');
      AppLogger.instance.error('WebLocalStorage', 'Errore setItem($key): $e');
    }
  }
  
  @override
  Future<void> removeItem({required String key}) async {
    if (!kIsWeb) return;
    try {
      debugPrint('[WebLocalStorage] 🗑️ REMOVE: $key');
      web.window.localStorage.removeItem(key);
      debugPrint('[WebLocalStorage] ✅ REMOVE success');
      AppLogger.instance.storage('REMOVE', key);
    } catch (e) {
      debugPrint('[WebLocalStorage] ❌ REMOVE ERROR: $e');
      AppLogger.instance.error('WebLocalStorage', 'Errore removeItem($key): $e');
    }
  }
}

/// Helper per salvare/ripristinare sessione manualmente su web
class SessionPersistence {
  /// Salva sessione in localStorage
  static void saveSession(Session session) {
    if (!kIsWeb) return;
    try {
      final sessionJson = {
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'expires_at': session.expiresAt,
        'token_type': session.tokenType,
        'user': {
          'id': session.user.id,
          'email': session.user.email,
          'phone': session.user.phone,
          'created_at': session.user.createdAt,
          'app_metadata': session.user.appMetadata,
          'user_metadata': session.user.userMetadata,
          'aud': session.user.aud,
        },
      };
      final jsonStr = jsonEncode(sessionJson);
      web.window.localStorage.setItem(_sessionStorageKey, jsonStr);
      debugPrint('[SessionPersistence] 💾 Sessione salvata (${jsonStr.length} chars)');
      AppLogger.instance.storage('SAVE_SESSION', _sessionStorageKey, value: '${jsonStr.length} chars');
    } catch (e) {
      debugPrint('[SessionPersistence] ❌ Errore salvataggio sessione: $e');
      AppLogger.instance.error('SessionPersistence', 'Errore salvataggio: $e');
    }
  }
  
  /// Ripristina sessione da localStorage
  static Future<Session?> restoreSession() async {
    if (!kIsWeb) return null;
    try {
      final jsonStr = web.window.localStorage.getItem(_sessionStorageKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        debugPrint('[SessionPersistence] ℹ️ Nessuna sessione salvata');
        return null;
      }
      
      debugPrint('[SessionPersistence] 📥 Trovata sessione salvata (${jsonStr.length} chars)');
      
      final sessionJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Verifica se la sessione è scaduta
      final expiresAt = sessionJson['expires_at'] as int?;
      if (expiresAt != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final now = DateTime.now();
        if (expiryDate.isBefore(now)) {
          debugPrint('[SessionPersistence] ⚠️ Sessione scaduta il ${expiryDate.toLocal()}, sarà refreshata');
        } else {
          final remaining = expiryDate.difference(now);
          debugPrint('[SessionPersistence] ✅ Sessione valida, scade tra ${remaining.inMinutes} min');
        }
      }
      
      // Usa recoverSession() che gestisce anche il refresh del token se scaduto
      final refreshToken = sessionJson['refresh_token'] as String?;
      if (refreshToken != null) {
        debugPrint('[SessionPersistence] 🔄 Tentativo ripristino con refreshToken...');
        final response = await SupabaseConfig.auth.recoverSession(jsonStr);
        if (response.session != null) {
          debugPrint('[SessionPersistence] ✅ Sessione ripristinata: ${response.session!.user.email}');
          // Aggiorna il salvataggio con la sessione refreshata
          saveSession(response.session!);
          return response.session;
        }
      }
      
      debugPrint('[SessionPersistence] ❌ Ripristino fallito');
      clearSession();
      return null;
      
    } catch (e) {
      debugPrint('[SessionPersistence] ❌ Errore ripristino sessione: $e');
      AppLogger.instance.error('SessionPersistence', 'Errore ripristino: $e');
      clearSession();
      return null;
    }
  }
  
  /// Cancella sessione salvata
  static void clearSession() {
    if (!kIsWeb) return;
    try {
      web.window.localStorage.removeItem(_sessionStorageKey);
      debugPrint('[SessionPersistence] 🗑️ Sessione cancellata da localStorage');
      AppLogger.instance.storage('CLEAR_SESSION', _sessionStorageKey);
    } catch (e) {
      debugPrint('[SessionPersistence] ❌ Errore cancellazione sessione: $e');
    }
  }
  
  /// Verifica se esiste una sessione salvata
  static bool hasStoredSession() {
    if (!kIsWeb) return false;
    try {
      final jsonStr = web.window.localStorage.getItem(_sessionStorageKey);
      return jsonStr != null && jsonStr.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Helper per operazioni CRUD su Supabase
class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic>? filters,
    String columns = '*',
    String? orderBy,
    bool ascending = true,
  }) async {
    PostgrestFilterBuilder<PostgrestList> query = _client.from(table).select(columns);
    if (filters != null) {
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
    }
    PostgrestTransformBuilder<PostgrestList> finalQuery = query;
    if (orderBy != null) {
      finalQuery = query.order(orderBy, ascending: ascending);
    }
    final response = await finalQuery;
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    required Map<String, dynamic> filters,
    String columns = '*',
  }) async {
    var query = _client.from(table).select(columns);
    filters.forEach((key, value) {
      query = query.eq(key, value);
    });
    final response = await query.maybeSingle();
    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.from(table).insert(data).select();
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    final response = await _client.from(table).insert(data).select();
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> upsert(
    String table,
    Map<String, dynamic> data, {
    String? onConflict,
  }) async {
    final response = await _client
        .from(table)
        .upsert(data, onConflict: onConflict)
        .select();
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    var query = _client.from(table).update(data);
    filters.forEach((key, value) {
      query = query.eq(key, value);
    });
    final response = await query.select();
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    var query = _client.from(table).delete();
    filters.forEach((key, value) {
      query = query.eq(key, value);
    });
    await query;
  }
}

/// ============================================================================
/// CONFIGURAZIONE SUPABASE - PERSISTENZA ESPLICITA CON LocalStorage
/// 
/// PROBLEMA RISOLTO:
/// Supabase Flutter su web NON usa localStorage di default, ma HiveLocalStorage
/// che può fallire silenziosamente. Soluzione: implementiamo SessionPersistence
/// per salvare/ripristinare manualmente la sessione in localStorage.
/// 
/// RIFERIMENTO: https://supabase.com/docs/reference/dart/initializing#custom-localstorage
/// ============================================================================
class SupabaseConfig {
  static const String supabaseUrl = 'https://dgsgkynrahaexzmzxqvt.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnc2dreW5yYWhhZXh6bXp4cXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyMjQyMTgsImV4cCI6MjA4MzgwMDIxOH0.6nd-7dFs-2LWxuRrA53UFpqT7CsJXaccwUZYU9_Xl68';
  
  static final Completer<void> _initCompleter = Completer<void>();
  static Future<void> get initialized => _initCompleter.future;

  static Future<void> initialize() async {
    if (_initCompleter.isCompleted) {
      AppLogger.instance.debug('SupabaseConfig', 'Già inizializzato');
      return;
    }

    AppLogger.instance.init('SupabaseConfig', '========== INIZIO INIZIALIZZAZIONE ==========');
    AppLogger.instance.init('SupabaseConfig', 'Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
    
    try {
      // STEP 1: Inizializza Supabase SDK
      AppLogger.instance.init('SupabaseConfig', 'STEP 1: Configurazione Supabase.initialize()...');
      AppLogger.instance.init('SupabaseConfig', '  - URL: $supabaseUrl');
      AppLogger.instance.init('SupabaseConfig', '  - authFlowType: PKCE');
      AppLogger.instance.init('SupabaseConfig', '  - autoRefreshToken: true');
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: anonKey,
        debug: true, // ENABLE DEBUG per vedere log Supabase interni
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
          // PKCE storage per OAuth flows
          pkceAsyncStorage: kIsWeb ? const WebLocalStorage() : null,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 2,
        ),
      );
      AppLogger.instance.success('SupabaseConfig', 'Supabase SDK inizializzato');
      
      // STEP 2: Verifica se Supabase ha già una sessione
      AppLogger.instance.init('SupabaseConfig', 'STEP 2: Verifica sessione Supabase nativa...');
      
      Session? session = auth.currentSession;
      
      // STEP 3: Se non c'è sessione nativa, prova a ripristinare da localStorage (web)
      if (session == null && kIsWeb && SessionPersistence.hasStoredSession()) {
        AppLogger.instance.init('SupabaseConfig', 'STEP 3: 🔄 Sessione Supabase nulla, provo ripristino manuale...');
        session = await SessionPersistence.restoreSession();
      } else if (session == null) {
        AppLogger.instance.init('SupabaseConfig', 'STEP 3: Nessuna sessione salvata');
      }
      
      // STEP 4: Attendi il primo evento initialSession
      AppLogger.instance.init('SupabaseConfig', 'STEP 4: Attendo evento initialSession...');
      
      final initialEvent = await auth.onAuthStateChange
          .firstWhere(
            (event) => event.event == AuthChangeEvent.initialSession,
            orElse: () => throw TimeoutException('No initialSession event'),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              AppLogger.instance.warning('SupabaseConfig', 'Timeout evento initialSession (5s) - procedo comunque');
              return AuthState(AuthChangeEvent.initialSession, session);
            },
          );
      
      // Preferisci la sessione dal ripristino manuale se l'evento non ha sessione
      final finalSession = initialEvent.session ?? session;
      
      if (finalSession != null) {
        AppLogger.instance.auth('SESSION_RESTORED', '✅ Email: ${finalSession.user.email}');
        AppLogger.instance.auth('SESSION_RESTORED', '✅ User ID: ${finalSession.user.id}');
        
        final accessToken = finalSession.accessToken;
        final tokenPreview = accessToken.length > 20 ? accessToken.substring(0, 20) : accessToken;
        AppLogger.instance.auth('SESSION_RESTORED', '✅ Access Token: $tokenPreview...');
        
        final expiresAt = finalSession.expiresAt;
        if (expiresAt != null) {
          final expiresDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          AppLogger.instance.auth('SESSION_RESTORED', '✅ Scade: ${expiresDate.toLocal()}');
        }
      } else {
        AppLogger.instance.warning('SupabaseConfig', 'Nessuna sessione da ripristinare');
      }
      
      AppLogger.instance.success('SupabaseConfig', '========== INIZIALIZZAZIONE COMPLETATA ==========');
      _initCompleter.complete();
      
    } catch (e, stack) {
      AppLogger.instance.error('SupabaseConfig', 'ERRORE FATALE: $e');
      AppLogger.instance.error('SupabaseConfig', 'Stack: $stack');
      _initCompleter.completeError(e, stack);
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  
  /// Ottieni l'access token corrente
  static Future<String?> tryGetAccessToken() async {
    try {
      return auth.currentSession?.accessToken;
    } catch (e) {
      debugPrint('[SupabaseConfig] Errore get access token: $e');
      return null;
    }
  }
}
