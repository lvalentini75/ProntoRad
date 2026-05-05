import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/services/audit_log_service.dart';
import 'package:xraynow/services/debug_log_service.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:web/web.dart' as web;

/// Desktop-optimized login screen for web dashboard
class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isSeedingDemoUsers = false;
  
  // Progress tracking
  bool _showProgress = false;
  double _loginProgress = 0.0;
  String _currentStep = '';
  final List<String> _logMessages = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _seedDemoUsers() async {
    setState(() {
      _isSeedingDemoUsers = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🌱 [WebLogin] Calling seed_demo_users edge function...');
      final response = await SupabaseConfig.client.functions
          .invoke('seed_demo_users', body: {'organization_name': 'Istituto Demo ProntoRad'});

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Errore durante la creazione degli utenti demo');
      }

      debugPrint('✅ [WebLogin] Utenti demo creati: \${response.data}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Utenti demo creati con successo!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      debugPrint('❌ [WebLogin] Errore seed demo users: \$e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore creazione utenti demo: \$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSeedingDemoUsers = false);
      }
    }
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logMessages.add('${DateTime.now().toLocal().toString().substring(11, 19)} $message');
      if (_logMessages.length > 8) {
        _logMessages.removeAt(0);
      }
    });
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci la tua email')),
      );
      return;
    }

    await SupabaseAuthManager.instance.resetPassword(
      email: _emailController.text.trim(),
      context: context,
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showProgress = true;
      _errorMessage = null;
      _loginProgress = 0.0;
      _currentStep = 'Inizializzazione…';
      _logMessages.clear();
    });

    try {
      // Usa il metodo centralizzato del SupabaseAuthManager con callback per progress
      final authManager = SupabaseAuthManager.instance;
      
      final user = await authManager.signInWithEmailAndLoadProfile(
        context,
        _emailController.text.trim(),
        _passwordController.text,
        onProgress: (progress, label) {
          if (!mounted) return;
          setState(() {
            _loginProgress = progress;
            _currentStep = label;
          });
          _addLog('$label');
        },
      );
      
      if (user == null) {
        throw Exception('Login fallito');
      }
      
      // Verifica localStorage (solo per debug log)
      if (kIsWeb) {
        try {
          final localStorage = web.window.localStorage;
          const sessionKey = 'sb-dgsgkynrahaexzmzxqvt-auth-token';
          final sessionValue = localStorage.getItem(sessionKey);
          
          if (sessionValue != null && sessionValue.isNotEmpty) {
            _addLog('✅ Sessione salvata in localStorage');
          } else {
            _addLog('⚠️ Sessione non trovata in localStorage');
          }
        } catch (e) {
          _addLog('⚠️ Errore verifica localStorage: $e');
        }
      }
      
      // Audit log
      try {
        await AuditLogService.logAuthEvent(
          'login',
          details: {'email': _emailController.text.trim()},
        );
        _addLog('📝 Audit log registrato');
      } catch (_) {
        _addLog('⚠️ Audit log fallito (non critico)');
      }
      
      if (!mounted) return;
      
      setState(() {
        _loginProgress = 1.0;
        _currentStep = 'Completato';
      });
      
      _addLog('🎉 Login completato con successo!');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final role = user.role ?? 'end_user';
      if (role == 'super_admin' || role == 'org_admin') {
        _addLog('🚀 Reindirizzamento a dashboard...');
        context.go('/dashboard');
      } else {
        _addLog('🚀 Reindirizzamento a home...');
        context.go('/home');
      }
      
    } catch (e, stackTrace) {
      _addLog('❌ ERRORE: $e');
      DebugLogService().error(
        'WebLoginScreen',
        'Errore imprevisto durante il login - Email: ${_emailController.text.trim()}',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('❌ [WebLogin] Error: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Credenziali non valide. Riprova.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Title
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.local_hospital_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'PRONTORAD',
                      style: context.textStyles.headlineLarge?.bold,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dashboard Amministrativa',
                      style: context.textStyles.bodyLarge
                          ?.withColor(colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A3340)
                          : const Color(0xFFE8EDF2),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Accedi',
                          style: context.textStyles.titleLarge?.bold,
                        ),
                        const SizedBox(height: 24),

                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E2430)
                                : const Color(0xFFF8FAFC),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci l\'email';
                            }
                            if (!value.contains('@')) {
                              return 'Email non valida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E2430)
                                : const Color(0xFFF8FAFC),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la password';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _handleLogin(),
                        ),
                        
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _handleForgotPassword,
                            child: const Text('Password dimenticata?'),
                          ),
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    size: 20, color: colorScheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: context.textStyles.bodySmall
                                        ?.withColor(colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Progress bar (visible during login)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: !_showProgress
                              ? const SizedBox.shrink()
                              : Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F1419)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.outline.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              value: _loginProgress >= 1 ? 1 : null,
                                              color: _loginProgress >= 1
                                                  ? Colors.green
                                                  : colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _currentStep,
                                              style: context.textStyles.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${(_loginProgress * 100).toInt()}%',
                                            style: context.textStyles.bodySmall
                                                ?.withColor(colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _loginProgress,
                                          minHeight: 6,
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _loginProgress >= 1
                                                ? Colors.green
                                                : colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Step indicators
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildStepIndicator('Credenziali', _loginProgress >= 0.20, colorScheme, isDark),
                                          _buildStepIndicator('Profilo', _loginProgress >= 0.50, colorScheme, isDark),
                                          _buildStepIndicator('Account', _loginProgress >= 0.65, colorScheme, isDark),
                                          _buildStepIndicator('Dati', _loginProgress >= 0.85, colorScheme, isDark),
                                          _buildStepIndicator('OK', _loginProgress >= 1.0, colorScheme, isDark),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        // Login button
                        FilledButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  'Accedi',
                                  style: context.textStyles.bodyLarge?.bold
                                      .withColor(colorScheme.onPrimary),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Demo credentials hint
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Credenziali Demo',
                            style: context.textStyles.labelMedium?.semiBold
                                .withColor(colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Super Admin: admin@prontorad.demo\nOrg Admin: ospedale@prontorad.demo\nPassword: password123',
                        style: context.textStyles.bodySmall
                            ?.withColor(colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isSeedingDemoUsers ? null : _seedDemoUsers,
                        icon: _isSeedingDemoUsers
                            ? SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            : Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _isSeedingDemoUsers ? 'Creazione...' : 'Crea Utenti Demo',
                          style: context.textStyles.labelSmall,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
          
          // Log popup in basso (visibile durante login)
          if (_isLoading && _logMessages.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colorScheme.primary, colorScheme.tertiary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.local_hospital_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ProntoRad Login',
                                  style: context.textStyles.titleSmall?.bold,
                                ),
                                Text(
                                  'Debug Log',
                                  style: context.textStyles.bodySmall
                                      ?.withColor(colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF0F1419) 
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _logMessages.map((msg) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                msg,
                                style: context.textStyles.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool completed, ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? Colors.green
                : (isDark ? const Color(0xFF1A1F26) : Colors.white),
            border: Border.all(
              color: completed
                  ? Colors.green
                  : colorScheme.outline.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: completed
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.textStyles.labelSmall?.copyWith(
            color: completed ? Colors.green : colorScheme.onSurfaceVariant,
            fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
