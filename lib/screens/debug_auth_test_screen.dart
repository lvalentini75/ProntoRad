import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';

class DebugAuthTestScreen extends StatefulWidget {
  const DebugAuthTestScreen({super.key});

  @override
  State<DebugAuthTestScreen> createState() => _DebugAuthTestScreenState();
}

class _DebugAuthTestScreenState extends State<DebugAuthTestScreen> {
  final List<String> _logs = [];
  bool _loading = false;

  // Credenziali utente demo per test
  final String _demoEmail = 'test@example.com';
  final String _demoPassword = 'Test123456!';

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.insert(0, '[$timestamp] $message');
    });
    debugPrint('[DebugAuthTest] $message');
  }

  Future<void> _seedAdminUser() async {
    _addLog('🌱 Seed Admin User: Inizio...');
    try {
      // 1. Login per verificare che l'utente esista in auth.users
      _addLog('1️⃣ Verifico autenticazione in auth.users...');
      final authResponse = await SupabaseConfig.auth.signInWithPassword(
        email: 'admin@prontorad.demo',
        password: 'password123',
      );
      
      if (authResponse.user == null) {
        _addLog('❌ Utente non trovato in auth.users');
        return;
      }
      
      final authUserId = authResponse.user!.id;
      _addLog('✅ Utente trovato in auth.users (ID: $authUserId)');
      
      // 2. Usa RPC function SECURITY DEFINER per verificare/creare utente
      _addLog('2️⃣ Verifico/creo utente tramite RPC (bypassa RLS)...');
      try {
        // Usa la funzione admin_create_user_profile che bypassa completamente RLS
        final result = await SupabaseConfig.client.rpc(
          'admin_create_user_profile',
          params: {
            'p_auth_user_id': authUserId,
            'p_email': 'admin@prontorad.demo',
            'p_first_name': 'Admin',
            'p_last_name': 'ProntoRad',
            'p_role': 'super_admin',
            'p_phone_number': '+39 333 1234567',
            'p_fiscal_code': 'ADMPRN80A01H501Z',
          },
        );
        
        _addLog('✅ RPC admin_create_user_profile completata!');
        _addLog('   User ID restituito: $result');
        
      } catch (rpcError) {
        _addLog('⚠️ RPC admin_create_user_profile fallita: $rpcError');
        _addLog('   Provo metodo alternativo get_user_profile_by_auth_id...');
        
        // Prova a leggere il profilo con la funzione alternativa
        try {
          final profileResult = await SupabaseConfig.client.rpc(
            'get_user_profile_by_auth_id',
            params: {'p_auth_user_id': authUserId},
          );
          
          if (profileResult != null && profileResult.isNotEmpty) {
            final profile = profileResult[0];
            _addLog('✅ Profilo esistente trovato via RPC:');
            _addLog('   Nome: ${profile['first_name']} ${profile['last_name']}');
            _addLog('   Ruolo: ${profile['role']}');
          } else {
            _addLog('❌ Nessun profilo trovato. Applica la migrazione!');
          }
        } catch (e2) {
          _addLog('❌ Anche get_user_profile_by_auth_id fallita: $e2');
          _addLog('');
          _addLog('📋 AZIONE RICHIESTA:');
          _addLog('   1. Apri pannello Supabase (sidebar sinistra)');
          _addLog('   2. Vai su "Migrations"');
          _addLog('   3. Applica: 20260131_000000_definitive_users_rls_fix.sql');
        }
      }
      
      // 3. Attendi che l'auth listener carichi il profilo automaticamente
      _addLog('3️⃣ Attendo caricamento profilo...');
      await Future.delayed(const Duration(seconds: 2));
      
      final profile = SupabaseAuthManager.instance.cachedProfile;
      if (profile != null) {
        _addLog('✅ Profilo caricato correttamente!');
        _addLog('   Nome completo: ${profile.firstName} ${profile.lastName}');
        _addLog('   Ruolo: ${profile.role}');
      } else {
        _addLog('⚠️ Profilo non ancora caricato, riprova tra poco');
      }
      
    } catch (e) {
      _addLog('❌ ERRORE: $e');
    }
  }

  Future<void> _testLogin() async {
    _addLog('🔵 Test Login: Inizio...');
    try {
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: 'admin@prontorad.demo',
        password: 'password123',
      );
      
      if (response.user != null) {
        _addLog('✅ Login riuscito!');
        _addLog('  User ID: ${response.user!.id}');
        _addLog('  Email: ${response.user!.email}');
        
        final token = response.session?.accessToken;
        if (token != null) {
          final preview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
          _addLog('  Access Token: $preview');
          _addLog('  Expires: ${response.session?.expiresAt}');
        }
        
        // Attendi che l'auth listener carichi il profilo
        await Future.delayed(const Duration(seconds: 2));
        
        final profile = SupabaseAuthManager.instance.cachedProfile;
        if (profile != null) {
          _addLog('  Profilo caricato:');
          _addLog('    Nome: ${profile.firstName} ${profile.lastName}');
          _addLog('    Ruolo: ${profile.role}');
          _addLog('    Org: ${profile.organizationId ?? "Nessuna"}');
        } else {
          _addLog('⚠️ Profilo non trovato in tabella users');
        }
      } else {
        _addLog('❌ Login fallito: user è null');
      }
    } catch (e) {
      _addLog('❌ ERRORE: $e');
    }  

  }

  Future<void> _testLogout() async {
    setState(() => _loading = true);
    _addLog('🔵 Inizio test logout...');

    try {
      // Test 1: Verifica stato PRIMA del logout
      final userBefore = SupabaseConfig.auth.currentUser;
      _addLog('✓ User prima del logout: ${userBefore?.email ?? "null"}');

      // Test 2: Esegui logout
      _addLog('🔵 Chiamo SupabaseAuthManager.signOut()...');
      await SupabaseAuthManager.instance.signOut();
      _addLog('✅ Logout completato!');

      // Test 3: Verifica stato DOPO il logout
      await Future.delayed(const Duration(milliseconds: 500));
      final userAfter = SupabaseConfig.auth.currentUser;
      _addLog('✓ User dopo logout: ${userAfter?.email ?? "null"}');

      // Test 4: Verifica profilo rimosso
      final profile = SupabaseAuthManager.instance.cachedProfile;
      _addLog('✓ Profilo dopo logout: ${profile?.email ?? "null"}');

      // Test 5: Verifica session rimossa
      final session = SupabaseConfig.auth.currentSession;
      _addLog('✓ Session dopo logout: ${session?.accessToken ?? "null"}');

      _addLog('✅ ✅ ✅ TEST LOGOUT COMPLETATO CON SUCCESSO! ✅ ✅ ✅');
    } catch (e) {
      _addLog('❌ ERRORE LOGOUT: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testCheckSession() async {
    _addLog('🔵 Verifica stato sessione corrente...');

    try {
      // Test 1: currentUser
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        _addLog('✅ AUTENTICATO: ${user.email}');
        _addLog('✓ UID: ${user.id}');
        _addLog('✓ Email verificata: ${user.emailConfirmedAt != null}');
      } else {
        _addLog('❌ NON AUTENTICATO');
      }

      // Test 2: currentSession
      final session = SupabaseConfig.auth.currentSession;
      if (session != null) {
        _addLog('✓ Session attiva');
        // Safe substring (evita RangeError se token è troppo corto)
        final tokenPreview = session.accessToken.length > 20 
            ? '${session.accessToken.substring(0, 20)}...' 
            : session.accessToken;
        final refreshPreview = session.refreshToken != null && session.refreshToken!.length > 20
            ? '${session.refreshToken!.substring(0, 20)}...'
            : session.refreshToken ?? 'N/A';
        
        _addLog('✓ AccessToken: $tokenPreview');
        _addLog('✓ RefreshToken: $refreshPreview');
        _addLog('✓ ExpiresAt: ${session.expiresAt}');
        
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiresAt = session.expiresAt ?? 0;
        final remainingSeconds = expiresAt - now;
        _addLog('✓ Tempo rimanente: ${remainingSeconds}s (~${(remainingSeconds / 60).toStringAsFixed(1)}min)');
      } else {
        _addLog('❌ Nessuna session attiva');
      }

      // Test 3: cachedProfile
      final profile = SupabaseAuthManager.instance.cachedProfile;
      if (profile != null) {
        _addLog('✓ Profilo caricato: ${profile.email}');
        _addLog('✓ Ruolo: ${profile.role}');
        _addLog('✓ Nome: ${profile.firstName} ${profile.lastName}');
      } else {
        _addLog('❌ Nessun profilo caricato');
      }

      // Test 4: cachedOrganization
      final org = SupabaseAuthManager.instance.cachedOrganization;
      if (org != null) {
        _addLog('✓ Organizzazione: ${org['name']}');
      } else {
        _addLog('⚠️ Nessuna organizzazione caricata');
      }

      _addLog('✅ Verifica completata!');
    } catch (e) {
      _addLog('❌ ERRORE: $e');
    }
  }

  Future<void> _testRefreshToken() async {
    setState(() => _loading = true);
    _addLog('🔵 Test refresh token...');

    try {
      // Test 1: Stato PRIMA del refresh
      final sessionBefore = SupabaseConfig.auth.currentSession;
      if (sessionBefore == null) {
        _addLog('❌ Nessuna sessione da refreshare');
        return;
      }
      _addLog('✓ AccessToken PRIMA: ${sessionBefore.accessToken.substring(0, 20)}...');
      _addLog('✓ ExpiresAt PRIMA: ${sessionBefore.expiresAt}');

      // Test 2: Esegui refresh
      _addLog('🔵 Chiamo refreshSession()...');
      final response = await SupabaseConfig.auth.refreshSession();
      _addLog('✅ Refresh completato!');

      // Test 3: Stato DOPO il refresh
      final sessionAfter = response.session;
      if (sessionAfter != null) {
        _addLog('✓ AccessToken DOPO: ${sessionAfter.accessToken.substring(0, 20)}...');
        _addLog('✓ ExpiresAt DOPO: ${sessionAfter.expiresAt}');
        _addLog('✓ Token cambiato: ${sessionBefore.accessToken != sessionAfter.accessToken}');
      }

      _addLog('✅ ✅ ✅ TEST REFRESH COMPLETATO! ✅ ✅ ✅');
    } catch (e) {
      _addLog('❌ ERRORE REFRESH: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testSessionPersistence() async {
    _addLog('🔵 Test persistenza sessione...');

    try {
      // Test: Verifica se la sessione è persistente (localStorage)
      final session = SupabaseConfig.auth.currentSession;
      if (session == null) {
        _addLog('❌ Nessuna sessione attiva da testare');
        _addLog('ℹ️ Fai prima il login!');
        return;
      }

      _addLog('✓ Session attiva trovata');
      _addLog('ℹ️ ISTRUZIONI:');
      _addLog('ℹ️ 1. Ricarica la pagina (F5 o Cmd+R)');
      _addLog('ℹ️ 2. Torna qui su Debug Auth Test');
      _addLog('ℹ️ 3. Clicca "Verifica Sessione"');
      _addLog('ℹ️ 4. Se vedi user + session → PERSISTENZA OK ✅');
      _addLog('ℹ️ 5. Se vedi "NON AUTENTICATO" → PERSISTENZA KO ❌');
    } catch (e) {
      _addLog('❌ ERRORE: $e');
    }
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Debug Auth Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Pulisci log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Pulsanti test
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CREDENZIALI TEST',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Email: $_demoEmail\nPassword: $_demoPassword',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _seedAdminUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('🌱 Seed Admin User'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _testLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Test Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _testLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Test Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _testCheckSession,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Verifica Sessione'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _testRefreshToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Test Refresh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _testSessionPersistence,
                      icon: const Icon(Icons.storage),
                      label: const Text('Test Persistenza'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Log output
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'Nessun log ancora.\nClicca un pulsante per iniziare i test.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color? bgColor;
                      if (log.contains('❌')) {
                        bgColor = Colors.red.shade50;
                      } else if (log.contains('✅')) {
                        bgColor = Colors.green.shade50;
                      } else if (log.contains('🔵')) {
                        bgColor = Colors.blue.shade50;
                      } else if (log.contains('⚠️')) {
                        bgColor = Colors.orange.shade50;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor ?? Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          log,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Loading indicator
          if (_loading)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
