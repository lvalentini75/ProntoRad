import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/services/debug_log_service.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/config/role_policies.dart';
import 'package:xraynow/services/audit_log_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authManager = SupabaseAuthManager();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Progress state
  bool _showProgress = false;
  double _progress = 0;
  String _progressLabel = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateProgress(double progress, String label) {
    if (mounted) {
      setState(() {
        _progress = progress;
        _progressLabel = label;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showProgress = true;
      _progress = 0;
      _progressLabel = 'Inizializzazione…';
    });

    try {
      // Usa il nuovo metodo con callback per la barra di avanzamento reale
      final user = await _authManager.signInWithEmailAndLoadProfile(
        context,
        _emailController.text.trim(),
        _passwordController.text,
        onProgress: _updateProgress,
      );

      if (!mounted) return;

      if (user != null) {
        // Log audit del login
        try { 
          await AuditLogService.logAuthEvent('login', details: {'email': _emailController.text.trim()}); 
        } catch (_) {}

        debugPrint('');
        debugPrint('╔═══════════════════════════════════════════════════════════════');
        debugPrint('║ 🎉 LOGIN COMPLETATO CON SUCCESSO!');
        debugPrint('╠═══════════════════════════════════════════════════════════════');
        debugPrint('║ Profilo ID: ${user.id}');
        debugPrint('║ Email: ${user.email}');
        debugPrint('║ Nome: ${user.fullName}');
        debugPrint('║ Ruolo: ${user.role}');
        debugPrint('║ Org ID: ${user.organizationId ?? "NESSUNA"}');
        debugPrint('║ Org Nome: ${_authManager.cachedOrganization?['name'] ?? "NESSUNA"}');
        debugPrint('╚═══════════════════════════════════════════════════════════════');
        debugPrint('');

        // Naviga alla home
        debugPrint('[Login] Navigazione -> /home');
        context.go('/home');
      } else {
        // Login fallito - il messaggio è già stato mostrato dall'authManager
        debugPrint('[Login] Login fallito');
      }
    } catch (e, stackTrace) {
      DebugLogService().error(
        'LoginScreen',
        'Errore imprevisto durante il login - Email: ${_emailController.text.trim()}',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('[Login] Errore imprevisto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e - Controlla Debug Console'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci la tua email')),
      );
      return;
    }

    await _authManager.resetPassword(
      email: _emailController.text.trim(),
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.local_hospital_rounded, size: 42, color: colorScheme.onPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'ProntoRad',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Prenota il tuo esame radiografico',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Inserisci la tua email';
              if (!value.contains('@')) return 'Inserisci un\'email valida';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Inserisci la password';
              if (value.length < 6) return 'La password deve avere almeno 6 caratteri';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: const Text('Password dimenticata?'),
            ),
          ),
          const SizedBox(height: 20),
          
          // Barra di avanzamento - sempre visibile durante il caricamento
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !_showProgress
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
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
                                value: _progress >= 1 ? 1 : null,
                                color: _progress >= 1 ? Colors.green : colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _progressLabel,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _progress >= 1 ? Colors.green : colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Step indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStepIndicator('Credenziali', _progress >= 0.20),
                            _buildStepIndicator('Profilo', _progress >= 0.50),
                            _buildStepIndicator('Account', _progress >= 0.65),
                            _buildStepIndicator('Dati', _progress >= 0.85),
                            _buildStepIndicator('OK', _progress >= 1.0),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          
          FilledButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Accesso in corso…', style: TextStyle(fontSize: 16)),
                    ],
                  )
                : const Text('Accedi', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isLoading ? null : () => context.push('/signup'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Crea un account', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [const SizedBox(height: 40), form]),
              );
            }
            // Desktop: center card
            return Center(
              child: SingleChildScrollView(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: form,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool completed) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? Colors.green : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: completed ? Colors.green : colorScheme.outline.withValues(alpha: 0.3),
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: completed ? Colors.green : colorScheme.onSurfaceVariant,
            fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
