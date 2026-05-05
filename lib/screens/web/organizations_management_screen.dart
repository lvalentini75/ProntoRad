import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';
import 'package:xraynow/services/organization_service.dart';
import 'package:xraynow/models/organization.dart';
import 'package:flutter/foundation.dart';
import 'package:xraynow/screens/web/widgets/data_table_card.dart';

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
        (org.city?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
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
                      icon: Icon(Icons.add_rounded),
                      label: Text('Nuova struttura'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome o città...',
                    prefixIcon: Icon(Icons.search_rounded),
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
                          child: Text(org.name,
                            style: context.textStyles.bodyMedium?.semiBold,
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    Text('${org.city ?? '-'}, ${org.province ?? ''}',
                      style: context.textStyles.bodyMedium),
                    Text(org.email ?? '-',
                      style: context.textStyles.bodyMedium),
                    Text(org.phone ?? '-',
                      style: context.textStyles.bodyMedium),
                    _StatusBadge(isActive: true),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility_rounded, size: 18),
                          onPressed: () => _showOrgDetails(org),
                          tooltip: 'Dettagli',
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_rounded, size: 18),
                          onPressed: () => _showEditOrgDialog(org),
                          tooltip: 'Modifica',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzione in sviluppo: Aggiungi ospedale')),
    );
  }

  void _showOrgDetails(Organization org) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(org.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 ${org.address ?? 'N/A'}'),
            Text('🏙️ ${org.city}, ${org.province} (${org.region})'),
            const SizedBox(height: 8),
            Text('📧 ${org.email ?? 'N/A'}'),
            Text('📞 ${org.phone ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  void _showEditOrgDialog(Organization org) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Modifica: ${org.name}')),
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
