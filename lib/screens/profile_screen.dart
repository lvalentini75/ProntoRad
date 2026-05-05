import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xraynow/models/user.dart';
import 'package:xraynow/services/user_service.dart';
import 'package:xraynow/services/notification_service.dart';
import 'package:xraynow/supabase/supabase_config.dart';
import 'package:xraynow/auth/supabase_auth_manager.dart';
import 'package:xraynow/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  User? _user;
  bool _isLoading = true;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    try {
      // Prima prova a usare il profilo già caricato dall'AuthManager
      User? user = SupabaseAuthManager.instance.cachedProfile;
      
      // Se non c'è cache, prova a ricaricare
      if (user == null) {
        debugPrint('[ProfileScreen] Cache vuota, provo a ricaricare profilo...');
        user = await _userService.getCurrentUser();
      }
      
      int unreadCount = 0;
      if (user != null) {
        debugPrint('[ProfileScreen] ✅ Profilo trovato: ${user.email}');
        unreadCount = await _notificationService.getUnreadCount(user.id);
      } else {
        debugPrint('[ProfileScreen] ❌ Nessun profilo trovato');
      }
      
      setState(() {
        _user = user;
        _unreadNotifications = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ProfileScreen] ❌ Errore: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseConfig.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showEditProfileDialog() {
    if (_user == null) return;

    final firstNameController = TextEditingController(text: _user!.firstName);
    final lastNameController = TextEditingController(text: _user!.lastName);
    final phoneController = TextEditingController(text: _user!.phoneNumber);
    final fiscalCodeController = TextEditingController(text: _user!.fiscalCode ?? '');
    DateTime? dateOfBirth = _user!.dateOfBirth;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifica Profilo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Cognome',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fiscalCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Codice Fiscale',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dateOfBirth ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('it', 'IT'),
                    );
                    if (picked != null) {
                      setDialogState(() => dateOfBirth = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data di Nascita',
                      prefixIcon: Icon(Icons.cake),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      dateOfBirth != null
                          ? DateFormat('dd/MM/yyyy').format(dateOfBirth!)
                          : 'Seleziona data',
                      style: TextStyle(
                        color: dateOfBirth != null ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedUser = _user!.copyWith(
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  fiscalCode: fiscalCodeController.text.trim().isEmpty 
                      ? null 
                      : fiscalCodeController.text.trim().toUpperCase(),
                  dateOfBirth: dateOfBirth,
                  updatedAt: DateTime.now(),
                );
                
                try {
                  await _userService.updateUser(updatedUser);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profilo aggiornato!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadUser();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = SupabaseConfig.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isAuthenticated && _user != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _logout,
              tooltip: 'Esci',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isAuthenticated
              ? _buildLoginPrompt()
              : _user == null
                  ? _buildNoProfileState()
                  : RefreshIndicator(
                      onRefresh: _loadUser,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.paddingLg,
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 24),
                            _buildProfileInfo(),
                            const SizedBox(height: 24),
                            _buildMenuSection(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.login,
              size: 50,
              color: LightModeColors.lightPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Accedi per vedere il tuo profilo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Effettua il login per gestire le tue prenotazioni e i tuoi dati personali.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login),
            label: const Text('Accedi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push('/signup'),
            child: const Text('Non hai un account? Registrati'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Nessun profilo trovato',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Prenota un esame per creare il tuo profilo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Prenota ora'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: LightModeColors.lightPrimaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            size: 50,
            color: LightModeColors.lightPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _user!.fullName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _user!.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showEditProfileDialog,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Modifica profilo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: LightModeColors.lightPrimary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Informazioni personali',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          _ProfileInfoRow(
            icon: Icons.email,
            label: 'Email',
            value: _user!.email,
          ),
          _ProfileInfoRow(
            icon: Icons.phone,
            label: 'Telefono',
            value: _user!.phoneNumber.isNotEmpty ? _user!.phoneNumber : 'Non specificato',
          ),
          _ProfileInfoRow(
            icon: Icons.badge,
            label: 'Codice Fiscale',
            value: _user!.fiscalCode ?? 'Non specificato',
          ),
          _ProfileInfoRow(
            icon: Icons.cake,
            label: 'Data di nascita',
            value: _user!.dateOfBirth != null
                ? DateFormat('dd/MM/yyyy').format(_user!.dateOfBirth!)
                : 'Non specificata',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _MenuButton(
          icon: Icons.notifications,
          label: 'Notifiche',
          badge: _unreadNotifications > 0 ? _unreadNotifications : null,
          onTap: () => context.push('/notifications'),
        ),
        _MenuButton(
          icon: Icons.calendar_today,
          label: 'Le mie prenotazioni',
          onTap: () => context.push('/bookings'),
        ),
        _MenuButton(
          icon: Icons.help_outline,
          label: 'Supporto',
          onTap: () => context.push('/support'),
        ),
        _MenuButton(
          icon: Icons.privacy_tip,
          label: 'Privacy e Termini',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy e Termini - In arrivo')),
            );
          },
        ),
        _MenuButton(
          icon: Icons.info,
          label: 'Informazioni app',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'ProntoRad',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.medical_services, size: 48),
              children: [
                const Text('App per la prenotazione di esami radiologici.'),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (SupabaseConfig.auth.currentUser != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Esci', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: LightModeColors.lightPrimary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 54),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LightModeColors.lightOutline),
          ),
          child: Row(
            children: [
              Icon(icon, color: LightModeColors.lightPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge! > 99 ? '99+' : badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
