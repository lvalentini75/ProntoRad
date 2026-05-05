import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/models/exam_type.dart';
import 'package:xraynow/services/exam_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authManager = SupabaseAuthManager();
  final _examService = ExamService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Role selection: end_user (default) or org_admin
  String _role = 'end_user';

  // Organization fields (visible when role == org_admin)
  final _orgNameController = TextEditingController();
  final _orgAddressController = TextEditingController();
  final _orgCityController = TextEditingController();
  final _orgProvinceController = TextEditingController();
  final _orgRegionController = TextEditingController();
  final _facilityNameController = TextEditingController();
  final _basePriceController = TextEditingController(text: '120');
  String _orgType = 'hospital'; // hospital | institute
  String _facilityType = 'public'; // public | private

  // Exams to choose for organization services
  List<ExamType> _exams = [];
  final Set<String> _selectedExamIds = <String>{};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _orgNameController.dispose();
    _orgAddressController.dispose();
    _orgCityController.dispose();
    _orgProvinceController.dispose();
    _orgRegionController.dispose();
    _facilityNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      final items = await _examService.getAllExams();
      if (!mounted) return;
      setState(() => _exams = items);
    } catch (e) {
      debugPrint('Failed to load exams for signup: $e');
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final width = MediaQuery.of(context).size.width;
      final isDesktopWeb = kIsWeb && width >= 1024;
      // Su mobile, forza sempre 'end_user'
      final effectiveRole = isDesktopWeb ? _role : 'end_user';
      
      final metadata = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'role': effectiveRole,
        if (effectiveRole == 'org_admin')
          'org': {
            'name': _orgNameController.text.trim(),
            'org_type': _orgType,
            'address': _orgAddressController.text.trim(),
            'city': _orgCityController.text.trim(),
            'province': _orgProvinceController.text.trim(),
            'region': _orgRegionController.text.trim(),
            'facility_name': _facilityNameController.text.trim().isEmpty ? _orgNameController.text.trim() : _facilityNameController.text.trim(),
            'facility_type': _facilityType,
            // Base price to initialize offerings and facility
            'base_price': double.tryParse(_basePriceController.text.replaceAll(',', '.')) ?? 120.0,
            'exam_ids': _selectedExamIds.toList(),
          },
      };

      // Determina l'URL di redirect in base all'ambiente
      String? redirectUrl;
      if (kIsWeb) {
        // Per web, usa l'URL corrente come base per il redirect
        final uri = Uri.base;
        redirectUrl = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/login';
      }
      
      await _authManager.createAccountWithEmail(
        context,
        _emailController.text.trim(),
        _passwordController.text,
        metadata: metadata,
        emailRedirectTo: redirectUrl,
      );

      if (!mounted) return;
      if (mounted) {
        // Navigate to login after informing the user to verify email
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Conferma email inviata'),
            content: Text('Abbiamo inviato un\'email a ${_emailController.text.trim()}. Conferma l\'indirizzo per completare la registrazione.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        ).then((_) => context.go('/login'));
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la registrazione')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isDesktopWeb = kIsWeb && width >= 1024;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crea Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inizia a prenotare i tuoi esami',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                // Role selection - solo su desktop web
                if (isDesktopWeb)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Utente Privato'),
                        selected: _role == 'end_user',
                        onSelected: (v) => setState(() => _role = 'end_user'),
                      ),
                      ChoiceChip(
                        label: const Text('Ospedale / Istituto'),
                        selected: _role == 'org_admin',
                        onSelected: (v) => setState(() => _role = 'org_admin'),
                      ),
                    ],
                  ),
                if (isDesktopWeb) const SizedBox(height: 24),
                // Messaggio informativo per mobile
                if (!isDesktopWeb)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Da app mobile puoi registrarti solo come utente. Per ospedali e istituti, usa la versione web.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci il tuo nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Cognome',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci il tuo cognome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci la tua email';
                    }
                    if (!value.contains('@')) {
                      return 'Inserisci un\'email valida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci il tuo numero di telefono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la password';
                    }
                    if (value.length < 6) {
                      return 'La password deve avere almeno 6 caratteri';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Conferma Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Conferma la password';
                    }
                    if (value != _passwordController.text) {
                      return 'Le password non corrispondono';
                    }
                    return null;
                  },
                ),
                // Organization extra section (solo su desktop web)
                if (isDesktopWeb && _role == 'org_admin') ...[
                  const SizedBox(height: 24),
                  Text('Dati Ospedale / Istituto', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _orgType,
                    items: const [
                      DropdownMenuItem(value: 'hospital', child: Text('Ospedale')),
                      DropdownMenuItem(value: 'institute', child: Text('Istituto')),
                    ],
                    onChanged: (v) => setState(() => _orgType = v ?? 'hospital'),
                    decoration: InputDecoration(
                      labelText: 'Tipo Ospedale',
                      prefixIcon: const Icon(Icons.local_hospital_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgNameController,
                    decoration: InputDecoration(
                      labelText: 'Nome struttura',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => _role == 'org_admin' && (v == null || v.trim().isEmpty) ? 'Inserisci il nome struttura' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgAddressController,
                    decoration: InputDecoration(
                      labelText: 'Indirizzo',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => _role == 'org_admin' && (v == null || v.trim().isEmpty) ? 'Inserisci l\'indirizzo' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orgCityController,
                        decoration: InputDecoration(
                          labelText: 'Città',
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => _role == 'org_admin' && (v == null || v.trim().isEmpty) ? 'Inserisci la città' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _orgProvinceController,
                        decoration: InputDecoration(
                          labelText: 'Provincia',
                          prefixIcon: const Icon(Icons.map_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => _role == 'org_admin' && (v == null || v.trim().isEmpty) ? 'Inserisci la provincia' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgRegionController,
                    decoration: InputDecoration(
                      labelText: 'Regione',
                      prefixIcon: const Icon(Icons.public_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => _role == 'org_admin' && (v == null || v.trim().isEmpty) ? 'Inserisci la regione' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _facilityType,
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('Convenzionato SSN')),
                      DropdownMenuItem(value: 'private', child: Text('Privato')),
                    ],
                    onChanged: (v) => setState(() => _facilityType = v ?? 'public'),
                    decoration: InputDecoration(
                      labelText: 'Tipo Centro',
                      prefixIcon: const Icon(Icons.local_activity_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _facilityNameController,
                    decoration: InputDecoration(
                      labelText: 'Nome centro (opzionale)',
                      prefixIcon: const Icon(Icons.apartment_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _basePriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Prezzo base indicativo (€)',
                      prefixIcon: const Icon(Icons.euro_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Servizi offerti', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: _exams.isEmpty
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _exams.map((e) {
                              final selected = _selectedExamIds.contains(e.id);
                              return FilterChip(
                                label: Text(e.name),
                                selected: selected,
                                onSelected: (v) {
                                  setState(() {
                                    if (v) {
                                      _selectedExamIds.add(e.id);
                                    } else {
                                      _selectedExamIds.remove(e.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrati', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hai già un account? ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () => context.pop(),
                      child: const Text('Accedi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
