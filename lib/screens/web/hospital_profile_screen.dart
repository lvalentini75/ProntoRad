import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/models/organization.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';

/// Schermata profilo ospedale - visualizza e modifica informazioni anagrafiche
class HospitalProfileScreen extends StatefulWidget {
  const HospitalProfileScreen({super.key});

  @override
  State<HospitalProfileScreen> createState() => _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends State<HospitalProfileScreen> {
  final OrganizationService _orgService = OrganizationService();
  final _formKey = GlobalKey<FormState>();
  
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  Organization? _organization;
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _regionController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _vatNumberController;
  late TextEditingController _notesController;
  OrganizationType _selectedType = OrganizationType.hospital;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadOrganization();
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _provinceController = TextEditingController();
    _regionController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _vatNumberController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _regionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _vatNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    try {
      setState(() => _loading = true);
      
      final profile = SupabaseAuthManager.instance.cachedProfile;
      final organizationId = profile?.organizationId;
      
      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('[HospitalProfile] ⚠️ Utente senza organizzazione');
        if (mounted) setState(() => _loading = false);
        return;
      }
      
      final org = await _orgService.getOrganizationById(organizationId);
      
      if (org != null) {
        _organization = org;
        _populateForm(org);
      }
      
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[HospitalProfile] ❌ Errore: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento dati: $e')),
        );
      }
    }
  }

  void _populateForm(Organization org) {
    _nameController.text = org.name;
    _addressController.text = org.address;
    _cityController.text = org.city;
    _provinceController.text = org.province;
    _regionController.text = org.region;
    _phoneController.text = org.phone ?? '';
    _emailController.text = org.email ?? '';
    _websiteController.text = org.website ?? '';
    _vatNumberController.text = org.vatNumber ?? '';
    _notesController.text = org.notes ?? '';
    _selectedType = org.orgType;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      setState(() => _saving = true);
      
      final updated = _organization!.copyWith(
        name: _nameController.text.trim(),
        orgType: _selectedType,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        region: _regionController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        vatNumber: _vatNumberController.text.trim().isEmpty ? null : _vatNumberController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        updatedAt: DateTime.now().toUtc(),
      );
      
      final result = await _orgService.updateOrganization(updated);
      
      if (mounted) {
        setState(() {
          _organization = result;
          _editing = false;
          _saving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profilo aggiornato con successo'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        
        // Aggiorna cache organizzazione
        SupabaseAuthManager.instance.updateCachedOrganization(result.toJson());
      }
    } catch (e) {
      debugPrint('[HospitalProfile] ❌ Errore salvataggio: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio: $e')),
        );
      }
    }
  }

  void _cancelEdit() {
    if (_organization != null) {
      _populateForm(_organization!);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_organization == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_rounded, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Organizzazione non trovata',
                style: context.textStyles.headlineMedium?.bold,
              ),
              const SizedBox(height: 8),
              Text(
                'Il tuo profilo non è associato a nessuna organizzazione',
                style: context.textStyles.bodyLarge
                  ?.withColor(colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business_rounded, 
                            size: 32, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Profilo Ospedale',
                            style: context.textStyles.headlineLarge?.bold),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Gestisci le informazioni anagrafiche della tua struttura',
                        style: context.textStyles.bodyLarge
                          ?.withColor(colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (!_editing)
                  FilledButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modifica'),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // Form
            Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark 
                      ? const Color(0xFF2A3340) 
                      : const Color(0xFFE8EDF2),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informazioni generali
                    Text('📋 Informazioni Generali',
                      style: context.textStyles.titleLarge?.bold),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nome Struttura *',
                      enabled: _editing,
                      validator: (val) => val?.trim().isEmpty ?? true 
                        ? 'Campo obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDropdown(
                      label: 'Tipo Struttura *',
                      value: _selectedType,
                      enabled: _editing,
                      items: OrganizationType.values,
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _vatNumberController,
                      label: 'Partita IVA',
                      enabled: _editing,
                    ),

                    const Divider(height: 48),

                    // Indirizzo
                    Text('📍 Indirizzo',
                      style: context.textStyles.titleLarge?.bold),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _addressController,
                      label: 'Via e numero civico *',
                      enabled: _editing,
                      validator: (val) => val?.trim().isEmpty ?? true 
                        ? 'Campo obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'Città *',
                            enabled: _editing,
                            validator: (val) => val?.trim().isEmpty ?? true 
                              ? 'Campo obbligatorio' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _provinceController,
                            label: 'Provincia *',
                            enabled: _editing,
                            validator: (val) => val?.trim().isEmpty ?? true 
                              ? 'Campo obbligatorio' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _regionController,
                      label: 'Regione *',
                      enabled: _editing,
                      validator: (val) => val?.trim().isEmpty ?? true 
                        ? 'Campo obbligatorio' : null,
                    ),

                    const Divider(height: 48),

                    // Contatti
                    Text('📞 Contatti',
                      style: context.textStyles.titleLarge?.bold),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Telefono',
                      enabled: _editing,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      enabled: _editing,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Sito web',
                      enabled: _editing,
                      keyboardType: TextInputType.url,
                    ),

                    const Divider(height: 48),

                    // Note
                    Text('📝 Note',
                      style: context.textStyles.titleLarge?.bold),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      controller: _notesController,
                      label: 'Note e informazioni aggiuntive',
                      enabled: _editing,
                      maxLines: 4,
                    ),

                    // Action buttons
                    if (_editing) ...[
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : _cancelEdit,
                            child: const Text('Annulla'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _saving ? null : _saveChanges,
                            icon: _saving 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                            label: Text(_saving ? 'Salvataggio...' : 'Salva modifiche'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Info card
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le informazioni qui inserite saranno visibili ai pazienti durante il processo di prenotazione.',
                      style: context.textStyles.bodyMedium
                        ?.withColor(colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled 
          ? (isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC))
          : (isDark ? const Color(0xFF1A1F26) : const Color(0xFFE8EDF2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required OrganizationType value,
    required bool enabled,
    required List<OrganizationType> items,
    required void Function(OrganizationType?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DropdownButtonFormField<OrganizationType>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled 
          ? (isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC))
          : (isDark ? const Color(0xFF1A1F26) : const Color(0xFFE8EDF2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: items.map((type) => DropdownMenuItem(
        value: type,
        child: Text(type.displayName),
      )).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
