import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/screens/web/widgets/data_table_card.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/models/organization.dart';

/// Users management screen for Super Admin
class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  bool _loading = true;
  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<Organization> _organizations = [];
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      debugPrint('ℹ️ [UsersManagement] Starting to load users...');
      
      final userService = UserService();
      final orgService = OrganizationService();
      
      // Get current user info for debugging
      final currentUser = await userService.getCurrentUser();
      debugPrint('ℹ️ [UsersManagement] Current user: ${currentUser?.email} (role: ${currentUser?.role})');
      debugPrint('ℹ️ [UsersManagement] Current auth_user_id: ${currentUser?.authUserId}');
      
      final users = await userService.getAllUsers();
      debugPrint('✅ [UsersManagement] Loaded ${users.length} users');
      
      final orgs = await orgService.getAllOrganizations();
      debugPrint('✅ [UsersManagement] Loaded ${orgs.length} organizations');
      
      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _organizations = orgs;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ [UsersManagement] Error loading users: $e');
      debugPrint('❌ [UsersManagement] Stack trace: $stack');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (user.firstName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (user.lastName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        final matchesRole = _roleFilter == 'all' || user.role == _roleFilter;
        
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _users.isEmpty
          ? _buildEmptyState(context, colorScheme, isDark)
          : SingleChildScrollView(
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
                              Icon(Icons.people_rounded, 
                                size: 32, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Text('Gestione Utenti',
                                style: context.textStyles.headlineLarge?.bold),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${_filteredUsers.length} utenti registrati',
                            style: context.textStyles.bodyLarge
                              ?.withColor(colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Filters
                Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca per nome o email...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1A1F26) : Colors.white,
                        ),
                        onChanged: (value) {
                          _searchQuery = value;
                          _filterUsers();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Role filter
                    Container(
                      width: 200,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark 
                            ? const Color(0xFF2A3340) 
                            : const Color(0xFFE8EDF2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _roleFilter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tutti i ruoli')),
                            DropdownMenuItem(value: 'end_user', child: Text('Utenti')),
                            DropdownMenuItem(value: 'org_admin', child: Text('Admin Ospedali')),
                            DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                          ],
                          onChanged: (value) {
                            setState(() => _roleFilter = value ?? 'all');
                            _filterUsers();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Users table
                DataTableCard(
                  columns: const [
                    'Utente',
                    'Email',
                    'Ruolo',
                    'Organizzazione',
                    'Telefono',
                    'Registrato il',
                    'Azioni',
                  ],
                  rows: _filteredUsers.map((user) {
                    final org = _organizations.firstWhere(
                      (o) => o.id == user.organizationId,
                      orElse: () => Organization(
                        id: '',
                        name: '-',
                        orgType: OrganizationType.hospital,
                        address: '',
                        city: '',
                        province: '',
                        region: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                    return [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              user.firstName.isNotEmpty 
                                ? user.firstName[0].toUpperCase() 
                                : '?',
                              style: context.textStyles.labelSmall?.bold
                                .withColor(colorScheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${user.firstName} ${user.lastName}'.trim(),
                                style: context.textStyles.bodyMedium?.semiBold),
                              if (user.fiscalCode != null && user.fiscalCode!.isNotEmpty)
                                Text(user.fiscalCode!,
                                  style: context.textStyles.labelSmall
                                    ?.withColor(colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                      Text(user.email, style: context.textStyles.bodyMedium),
                      _RoleBadge(role: user.role ?? 'end_user'),
                      Text(org.name, style: context.textStyles.bodyMedium),
                      Text(user.phoneNumber, style: context.textStyles.bodyMedium),
                      Text(
                        '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                        style: context.textStyles.bodyMedium,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_rounded, size: 18),
                            onPressed: () => _showEditDialog(user),
                            tooltip: 'Modifica',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_rounded, size: 18,
                              color: colorScheme.error),
                            onPressed: () => _showDeleteDialog(user),
                            tooltip: 'Elimina',
                          ),
                        ],
                      ),
                    ];
                  }).toList(),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 120,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Nessun utente trovato',
              style: context.textStyles.headlineMedium?.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Per visualizzare gli utenti, assicurati di:',
              style: context.textStyles.bodyLarge
                ?.withColor(colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep('1', 'Applicare le migrations al database', context),
                  const SizedBox(height: 16),
                  _buildStep('2', 'Creare gli utenti demo (migration seed)', context),
                  const SizedBox(height: 16),
                  _buildStep('3', 'Accedere con account super_admin', context),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, 
                        color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Istruzioni',
                        style: context.textStyles.titleSmall?.bold
                          .withColor(colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Apri il pannello Supabase dalla sidebar\n'
                    '2. Vai alla sezione "Migrations"\n'
                    '3. Applica le migrations:\n'
                    '   • 20260127_000001_add_user_columns.sql\n'
                    '   • 20260127_000000_super_admin_select_all_users.sql\n'
                    '4. Verifica che il tuo utente abbia role="super_admin" e auth_user_id compilato',
                    style: context.textStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ricarica'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: context.textStyles.labelMedium?.bold
              .withColor(Theme.of(context).colorScheme.onPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.bodyMedium,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => _UserEditDialog(
        user: user,
        organizations: _organizations,
        onSave: (updatedUser) async {
          try {
            final service = UserService();
            await service.updateUser(updatedUser);
            await _loadUsers();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Utente aggiornato con successo')),
              );
            }
          } catch (e) {
            debugPrint('❌ [UsersManagement] Update error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Errore: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showDeleteDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sei sicuro di voler eliminare l\'utente:'),
            const SizedBox(height: 8),
            Text('${user.fullName}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(user.email,
              style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            const Text('Questa azione non può essere annullata.',
              style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final service = UserService();
                await service.deleteUser(user.id);
                await _loadUsers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Utente eliminato con successo')),
                  );
                }
              } catch (e) {
                debugPrint('❌ [UsersManagement] Delete error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Errore: $e')),
                  );
                }
              }
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

/// User edit dialog
class _UserEditDialog extends StatefulWidget {
  final User user;
  final List<Organization> organizations;
  final Future<void> Function(User) onSave;

  const _UserEditDialog({
    required this.user,
    required this.organizations,
    required this.onSave,
  });

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _fiscalCodeController;
  late String _selectedRole;
  String? _selectedOrgId;
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _fiscalCodeController = TextEditingController(text: widget.user.fiscalCode ?? '');
    _selectedRole = widget.user.role ?? 'end_user';
    _selectedOrgId = widget.user.organizationId;
    _dateOfBirth = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fiscalCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome, cognome ed email sono obbligatori')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = widget.user.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        fiscalCode: _fiscalCodeController.text.trim().isEmpty 
          ? null 
          : _fiscalCodeController.text.trim(),
        role: _selectedRole,
        organizationId: _selectedOrgId,
        dateOfBirth: _dateOfBirth,
        updatedAt: DateTime.now(),
      );
      await widget.onSave(updated);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text('Modifica Utente'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First name
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'Nome *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Last name
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Cognome *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              // Phone
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Fiscal code
              TextField(
                controller: _fiscalCodeController,
                decoration: InputDecoration(
                  labelText: 'Codice Fiscale',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Role
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Ruolo *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'end_user', child: Text('Utente')),
                  DropdownMenuItem(value: 'org_admin', child: Text('Admin Ospedale')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Organization
              DropdownButtonFormField<String?>(
                value: _selectedOrgId,
                decoration: InputDecoration(
                  labelText: 'Organizzazione',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nessuna')),
                  ...widget.organizations.map((org) => DropdownMenuItem(
                    value: org.id,
                    child: Text(org.name),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _selectedOrgId = value);
                },
              ),
              const SizedBox(height: 16),
              // Date of birth
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Data di nascita',
                  style: context.textStyles.labelLarge),
                subtitle: Text(
                  _dateOfBirth != null
                    ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                    : 'Non specificata',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dateOfBirth = picked);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Salva'),
        ),
      ],
    );
  }
}

/// Role badge widget
class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final config = _getRoleConfig(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: config['color'].withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        config['label'],
        style: context.textStyles.labelSmall?.semiBold
          .withColor(config['color']),
      ),
    );
  }

  Map<String, dynamic> _getRoleConfig(String role) {
    switch (role) {
      case 'super_admin':
        return {
          'label': 'Super Admin',
          'color': const Color(0xFF8B5CF6),
        };
      case 'org_admin':
        return {
          'label': 'Admin Ospedale',
          'color': const Color(0xFF06B6D4),
        };
      case 'end_user':
      default:
        return {
          'label': 'Utente',
          'color': const Color(0xFF6366F1),
        };
    }
  }
}
