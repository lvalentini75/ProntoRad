import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/models/organization.dart';
import 'package:xraynow/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/screens/web/widgets/data_table_card.dart';
import 'package:xraynow/data/locations.dart';
import 'package:xraynow/supabase/supabase_config.dart';

/// Organizations management screen for Super Admin
class OrganizationsManagementScreen extends StatefulWidget {
  const OrganizationsManagementScreen({super.key});

  @override
  State<OrganizationsManagementScreen> createState() => _OrganizationsManagementScreenState();
}

class _OrganizationsManagementScreenState extends State<OrganizationsManagementScreen> {
  bool _loading = true;
  List<Organization> _organizations = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    try {
      final service = OrganizationService();
      final orgs = await service.getAllOrganizations();
      if (mounted) {
        setState(() {
          _organizations = orgs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [OrganizationsManagement] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Organization> get _filteredOrgs => _organizations.where((org) {
    return org.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (org.city.toLowerCase().contains(_searchQuery.toLowerCase())) ||
        (org.province.toLowerCase().contains(_searchQuery.toLowerCase()));
  }).toList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              Text('Gestione Ospedali',
                                style: context.textStyles.headlineLarge?.bold),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${_filteredOrgs.length} strutture registrate',
                            style: context.textStyles.bodyLarge
                              ?.withColor(colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showAddOrgDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuova struttura'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome, città o provincia...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1F26) : Colors.white,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 24),

                // Organizations table
                DataTableCard(
                  columns: const [
                    'Nome Struttura',
                    'Città',
                    'Email',
                    'Telefono',
                    'Stato',
                    'Azioni',
                  ],
                  rows: _filteredOrgs.map((org) => [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.local_hospital_rounded, 
                            size: 20, color: colorScheme.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(org.name,
                                style: context.textStyles.bodyMedium?.semiBold,
                                overflow: TextOverflow.ellipsis),
                              Text(org.orgType.displayName,
                                style: context.textStyles.labelSmall
                                  ?.withColor(colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text('${org.city}, ${org.province}',
                      style: context.textStyles.bodyMedium),
                    Text(org.email ?? '-',
                      style: context.textStyles.bodyMedium),
                    Text(org.phone ?? '-',
                      style: context.textStyles.bodyMedium),
                    const _StatusBadge(isActive: true),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          onPressed: () => _showOrgDetails(org),
                          tooltip: 'Dettagli completi',
                          color: colorScheme.primary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          onPressed: () => _showEditOrgDialog(org),
                          tooltip: 'Modifica anagrafica',
                          color: Colors.orange,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          onPressed: () => _confirmDeleteOrg(org),
                          tooltip: 'Elimina',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ]).toList(),
                ),
              ],
            ),
          ),
    );
  }

  void _showAddOrgDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OrganizationFormDialog(
        title: 'Nuova Struttura Sanitaria',
        onSave: (org) async {
          try {
            await OrganizationService().createOrganization(org);
            if (mounted) {
              Navigator.pop(context);
              _loadOrganizations();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Struttura creata con successo'),
                  backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Errore: $e'),
                backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _showOrgDetails(Organization org) {
    showDialog(
      context: context,
      builder: (context) => _OrganizationDetailsDialog(organization: org),
    );
  }

  void _showEditOrgDialog(Organization org) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OrganizationFormDialog(
        title: 'Modifica: ${org.name}',
        organization: org,
        onSave: (updatedOrg) async {
          try {
            await OrganizationService().updateOrganization(updatedOrg);
            if (mounted) {
              Navigator.pop(context);
              _loadOrganizations();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Struttura aggiornata'),
                  backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Errore: $e'),
                backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteOrg(Organization org) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
        title: const Text('Conferma Eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare "${org.name}"?\n\n'
          'Questa azione è irreversibile e eliminerà tutti i dati associati '
          '(tariffari, disponibilità, prenotazioni).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await OrganizationService().deleteOrganization(org.id);
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadOrganizations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Struttura eliminata'),
                      backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Errore: $e'),
                    backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Attivo' : 'Inattivo',
            style: context.textStyles.labelSmall?.semiBold.withColor(color),
          ),
        ],
      ),
    );
  }
}

/// Dialog per visualizzare i dettagli completi dell'organizzazione
class _OrganizationDetailsDialog extends StatefulWidget {
  final Organization organization;

  const _OrganizationDetailsDialog({required this.organization});

  @override
  State<_OrganizationDetailsDialog> createState() => _OrganizationDetailsDialogState();
}

class _OrganizationDetailsDialogState extends State<_OrganizationDetailsDialog> {
  List<User> _orgAdmins = [];
  List<User> _allUsers = [];
  bool _loading = true;
  bool _showPasswords = false;

  @override
  void initState() {
    super.initState();
    _loadOrgData();
  }

  Future<void> _loadOrgData() async {
    try {
      final userService = UserService();
      final admins = await userService.getOrgAdmins(widget.organization.id);
      final users = await userService.getUsersByOrganization(widget.organization.id);
      if (mounted) {
        setState(() {
          _orgAdmins = admins;
          _allUsers = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading org data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_hospital_rounded, 
                      size: 32, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(org.name,
                          style: context.textStyles.headlineSmall?.bold),
                        Text(org.orgType.displayName,
                          style: context.textStyles.bodyMedium
                            ?.withColor(colorScheme.onPrimaryContainer)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Anagrafica section
                    _SectionHeader(title: 'Anagrafica Struttura', icon: Icons.business_rounded),
                    const SizedBox(height: 12),
                    _DetailCard(
                      children: [
                        _DetailRow(label: 'Nome', value: org.name),
                        _DetailRow(label: 'Tipo', value: org.orgType.displayName),
                        _DetailRow(label: 'Indirizzo', value: org.address),
                        _DetailRow(label: 'Città', value: '${org.city} (${org.province})'),
                        _DetailRow(label: org.country == 'Svizzera' ? 'Cantone' : 'Regione', value: org.region),
                        _DetailRow(label: 'Paese', value: '${org.country == 'Italia' ? '🇮🇹' : '🇨🇭'} ${org.country}'),
                        _DetailRow(label: 'Email', value: org.email ?? 'Non specificata'),
                        _DetailRow(label: 'Telefono', value: org.phone ?? 'Non specificato'),
                        _DetailRow(label: 'Sito web', value: org.website ?? 'Non specificato'),
                        _DetailRow(label: 'P.IVA', value: org.vatNumber ?? 'Non specificata'),
                        if (org.notes != null && org.notes!.isNotEmpty)
                          _DetailRow(label: 'Note', value: org.notes!),
                        _DetailRow(label: 'ID', value: org.id, 
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: org.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ID copiato')),
                              );
                            },
                            tooltip: 'Copia ID',
                          ),
                        ),
                        _DetailRow(label: 'Creato il', 
                          value: _formatDate(org.createdAt)),
                        _DetailRow(label: 'Aggiornato il', 
                          value: _formatDate(org.updatedAt)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Admin credentials section
                    _SectionHeader(
                      title: 'Credenziali Amministratore', 
                      icon: Icons.admin_panel_settings_rounded,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            icon: Icon(_showPasswords 
                              ? Icons.visibility_off 
                              : Icons.visibility),
                            label: Text(_showPasswords 
                              ? 'Nascondi' 
                              : 'Mostra credenziali'),
                            onPressed: () => setState(() => 
                              _showPasswords = !_showPasswords),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Aggiungi Admin'),
                            onPressed: () => _showAddAdminDialog(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _orgAdmins.isEmpty
                        ? _DetailCard(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, 
                                      size: 48, color: Colors.orange),
                                    const SizedBox(height: 8),
                                    Text('Nessun amministratore assegnato',
                                      style: context.textStyles.bodyLarge?.semiBold),
                                    const SizedBox(height: 4),
                                    Text('Clicca "Aggiungi Admin" per assegnare un amministratore',
                                      style: context.textStyles.bodyMedium
                                        ?.withColor(colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: _orgAdmins.map((admin) => 
                              _AdminCredentialCard(
                                admin: admin,
                                showPassword: _showPasswords,
                                onResetPassword: () => _resetAdminPassword(admin),
                                onRemoveAdmin: () => _removeAdmin(admin),
                              ),
                            ).toList(),
                          ),

                    const SizedBox(height: 24),

                    // Staff section
                    _SectionHeader(
                      title: 'Staff Associato (${_allUsers.length})', 
                      icon: Icons.people_rounded,
                    ),
                    const SizedBox(height: 12),
                    _DetailCard(
                      children: [
                        if (_allUsers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Nessuno staff associato',
                              style: context.textStyles.bodyMedium
                                ?.withColor(colorScheme.onSurfaceVariant)),
                          )
                        else
                          ...(_allUsers.take(10).map((user) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(user.role),
                              child: Text(
                                '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            title: Text(user.fullName),
                            subtitle: Text(user.email),
                            trailing: _RoleBadge(role: user.role ?? 'end_user'),
                            dense: true,
                          )).toList()),
                        if (_allUsers.length > 10)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('... e altri ${_allUsers.length - 10} utenti',
                              style: context.textStyles.bodySmall
                                ?.withColor(colorScheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F26) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chiudi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
           'alle ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'super_admin': return Colors.purple;
      case 'org_admin': return Colors.blue;
      default: return Colors.grey;
    }
  }

  void _showAddAdminDialog() {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aggiungi Amministratore'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Inserisci i dati del nuovo amministratore per "${widget.organization.name}"',
                style: context.textStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'admin@ospedale.it',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Cognome *',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final firstName = firstNameController.text.trim();
              final lastName = lastNameController.text.trim();
              final phone = phoneController.text.trim();

              if (email.isEmpty || firstName.isEmpty || lastName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Compila tutti i campi obbligatori'),
                    backgroundColor: Colors.orange),
                );
                return;
              }

              try {
                // Check if user already exists
                final userService = UserService();
                var user = await userService.getUserByEmail(email);
                
                if (user != null) {
                  // Update existing user to org_admin
                  final updated = user.copyWith(
                    role: 'org_admin',
                    organizationId: widget.organization.id,
                    updatedAt: DateTime.now(),
                  );
                  await userService.updateUser(updated);
                } else {
                  // Create new user as org_admin
                  final newUser = User(
                    id: '',
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    phoneNumber: phone,
                    role: 'org_admin',
                    organizationId: widget.organization.id,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await userService.createUser(newUser);
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadOrgData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Admin ${user != null ? 'aggiornato' : 'creato'}: $email'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Errore: $e'),
                    backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAdminPassword(User admin) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded, size: 48, color: Colors.orange),
        title: const Text('Reset Password'),
        content: Text(
          'Inviare un\'email di reset password a "${admin.email}"?\n\n'
          'L\'utente riceverà un link per impostare una nuova password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await SupabaseConfig.auth.resetPasswordForEmail(admin.email);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Email di reset inviata a ${admin.email}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Errore: $e'),
                    backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Invia Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAdmin(User admin) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_remove_rounded, size: 48, color: Colors.red),
        title: const Text('Rimuovi Amministratore'),
        content: Text(
          'Rimuovere "${admin.fullName}" come amministratore?\n\n'
          'L\'utente verrà convertito in utente normale (end_user).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final updated = admin.copyWith(
                  role: 'end_user',
                  updatedAt: DateTime.now(),
                );
                await UserService().updateUser(updated);
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadOrgData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Amministratore rimosso'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Errore: $e'),
                    backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }
}

/// Card per le credenziali admin
class _AdminCredentialCard extends StatelessWidget {
  final User admin;
  final bool showPassword;
  final VoidCallback onResetPassword;
  final VoidCallback onRemoveAdmin;

  const _AdminCredentialCard({
    required this.admin,
    required this.showPassword,
    required this.onResetPassword,
    required this.onRemoveAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  '${admin.firstName.isNotEmpty ? admin.firstName[0] : ''}${admin.lastName.isNotEmpty ? admin.lastName[0] : ''}'.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.fullName,
                      style: context.textStyles.bodyLarge?.semiBold),
                    Text('Amministratore',
                      style: context.textStyles.bodySmall
                        ?.withColor(colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'reset') onResetPassword();
                  if (value == 'remove') onRemoveAdmin();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, size: 18),
                        SizedBox(width: 8),
                        Text('Reset Password'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Rimuovi Admin', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Credentials
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EMAIL (LOGIN)',
                      style: context.textStyles.labelSmall
                        ?.withColor(colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(admin.email,
                            style: context.textStyles.bodyMedium?.semiBold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: admin.email));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email copiata')),
                            );
                          },
                          tooltip: 'Copia email',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PASSWORD',
                      style: context.textStyles.labelSmall
                        ?.withColor(colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            showPassword 
                              ? '(gestita da Supabase Auth)' 
                              : '••••••••',
                            style: context.textStyles.bodyMedium,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 16),
                          label: const Text('Reset'),
                          onPressed: onResetPassword,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (admin.phoneNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(admin.phoneNumber, style: context.textStyles.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: context.textStyles.titleMedium?.semiBold),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
              style: context.textStyles.bodySmall
                ?.withColor(colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: SelectableText(value,
              style: context.textStyles.bodyMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (role) {
      case 'super_admin':
        color = Colors.purple;
        label = 'Super Admin';
        break;
      case 'org_admin':
        color = Colors.blue;
        label = 'Admin';
        break;
      default:
        color = Colors.grey;
        label = 'Utente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Dialog form per creare/modificare organizzazione
class _OrganizationFormDialog extends StatefulWidget {
  final String title;
  final Organization? organization;
  final Future<void> Function(Organization) onSave;

  const _OrganizationFormDialog({
    required this.title,
    this.organization,
    required this.onSave,
  });

  @override
  State<_OrganizationFormDialog> createState() => _OrganizationFormDialogState();
}

class _OrganizationFormDialogState extends State<_OrganizationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _vatController;
  late TextEditingController _notesController;

  OrganizationType _orgType = OrganizationType.hospital;
  String _selectedCountry = 'Italia';
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _nameController = TextEditingController(text: org?.name ?? '');
    _addressController = TextEditingController(text: org?.address ?? '');
    _emailController = TextEditingController(text: org?.email ?? '');
    _phoneController = TextEditingController(text: org?.phone ?? '');
    _websiteController = TextEditingController(text: org?.website ?? '');
    _vatController = TextEditingController(text: org?.vatNumber ?? '');
    _notesController = TextEditingController(text: org?.notes ?? '');

    if (org != null) {
      _orgType = org.orgType;
      _selectedCountry = org.country;
      _selectedRegion = org.region;
      _selectedProvince = org.province;
      _selectedCity = org.city;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _vatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> get _availableRegions {
    return Locations.getRegionsByCountry(_selectedCountry);
  }

  List<String> get _availableProvinces {
    if (_selectedRegion == null) return [];
    return Locations.getProvincesByRegion(_selectedRegion, country: _selectedCountry);
  }

  List<String> get _availableCities {
    if (_selectedProvince == null) return [];
    return Locations.getCitiesByProvince(_selectedProvince, country: _selectedCountry);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.business_rounded, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                      style: context.textStyles.titleLarge?.semiBold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo struttura
                      Text('Tipo Struttura',
                        style: context.textStyles.labelLarge?.semiBold),
                      const SizedBox(height: 8),
                      SegmentedButton<OrganizationType>(
                        selected: {_orgType},
                        onSelectionChanged: (v) => 
                          setState(() => _orgType = v.first),
                        segments: const [
                          ButtonSegment(
                            value: OrganizationType.hospital,
                            label: Text('Ospedale'),
                            icon: Icon(Icons.local_hospital),
                          ),
                          ButtonSegment(
                            value: OrganizationType.institute,
                            label: Text('Istituto'),
                            icon: Icon(Icons.business),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Nome
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Struttura *',
                          hintText: 'es. Ospedale San Raffaele',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (v) => 
                          (v?.isEmpty ?? true) ? 'Obbligatorio' : null,
                      ),

                      const SizedBox(height: 16),

                      // Indirizzo
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo *',
                          hintText: 'Via Roma, 1',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (v) => 
                          (v?.isEmpty ?? true) ? 'Obbligatorio' : null,
                      ),

                      const SizedBox(height: 16),

                      // Paese dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Paese *',
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: Locations.countries
                          .map((c) => DropdownMenuItem(
                            value: c, 
                            child: Row(
                              children: [
                                Text(c == 'Italia' ? '🇮🇹' : '🇨🇭', style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(c),
                              ],
                            ),
                          ))
                          .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedCountry = v ?? 'Italia';
                            _selectedRegion = null;
                            _selectedProvince = null;
                            _selectedCity = null;
                          });
                        },
                        validator: (v) => v == null ? 'Obbligatorio' : null,
                      ),

                      const SizedBox(height: 16),

                      // Location dropdowns
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedRegion,
                              decoration: InputDecoration(
                                labelText: '${Locations.getRegionLabel(_selectedCountry)} *',
                                prefixIcon: const Icon(Icons.map),
                              ),
                              items: _availableRegions
                                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedRegion = v;
                                  _selectedProvince = null;
                                  _selectedCity = null;
                                });
                              },
                              validator: (v) => v == null ? 'Obbligatorio' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedProvince,
                              decoration: InputDecoration(
                                labelText: '${Locations.getProvinceLabel(_selectedCountry)} *',
                              ),
                              items: _availableProvinces
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedProvince = v;
                                  _selectedCity = null;
                                });
                              },
                              validator: (v) => v == null ? 'Obbligatorio' : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: const InputDecoration(
                          labelText: 'Città *',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        items: _availableCities
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                        onChanged: (v) => setState(() => _selectedCity = v),
                        validator: (v) => v == null ? 'Obbligatorio' : null,
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      Text('Contatti',
                        style: context.textStyles.labelLarge?.semiBold),
                      const SizedBox(height: 12),

                      // Email e Telefono
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'info@ospedale.it',
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Telefono',
                                hintText: '+39 02 1234567',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Website e P.IVA
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(
                                labelText: 'Sito Web',
                                hintText: 'www.ospedale.it',
                                prefixIcon: Icon(Icons.language),
                              ),
                              keyboardType: TextInputType.url,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _vatController,
                              decoration: const InputDecoration(
                                labelText: 'Partita IVA',
                                hintText: '12345678901',
                                prefixIcon: Icon(Icons.receipt_long),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Note
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          hintText: 'Note interne...',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving 
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                    label: Text(_saving ? 'Salvataggio...' : 'Salva'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final org = Organization(
      id: widget.organization?.id ?? '',
      name: _nameController.text.trim(),
      orgType: _orgType,
      address: _addressController.text.trim(),
      city: _selectedCity!,
      province: _selectedProvince!,
      region: _selectedRegion!,
      country: _selectedCountry,
      email: _emailController.text.trim().isNotEmpty 
        ? _emailController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty 
        ? _phoneController.text.trim() : null,
      website: _websiteController.text.trim().isNotEmpty 
        ? _websiteController.text.trim() : null,
      vatNumber: _vatController.text.trim().isNotEmpty 
        ? _vatController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty 
        ? _notesController.text.trim() : null,
      createdAt: widget.organization?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.onSave(org);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
