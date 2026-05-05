# ProntoRad - AI Agent Guidelines

## Project Overview

**ProntoRad** is a cross-platform Flutter application for booking radiology exams (X-ray, MRI, CT, Ultrasound) in Italy. It features:
- **Mobile app**: End-user booking flow with bottom navigation
- **Web dashboard**: Role-based admin panels (super_admin, org_admin, end_user)
- **Backend**: Supabase (auth, database, edge functions, RLS policies)

**Package name**: `xraynow`  
**Language**: Italian UI, English code  
**Target platforms**: Android, iOS, Web

---

## Architecture

### Navigation
- **go_router** for all navigation
- Use `context.go()` for navigation, `context.push()` for stack, `context.pop()` to go back
- **Never use** `Navigator.push()` or `Navigator.pop()`
- Routes defined in `lib/nav.dart` with `AppRoutes` constants
- Two ShellRoutes:
  - `MobileAppShell`: Bottom navigation for mobile
  - `AppShell`: Sidebar for web dashboard

### Authentication
- Supabase Auth with PKCE flow
- `SupabaseAuthManager` singleton manages auth state and profile caching
- `auth_manager.dart` defines abstract interface with mixins for different auth providers
- Role-based access: `super_admin`, `org_admin`, `end_user`
- `RolePolicies` in `lib/config/role_policies.dart` enforces email-to-role mappings

### State Management
- Singleton services with direct Supabase calls
- `SupabaseAuthManager.instance.cachedProfile` for current user data
- `SupabaseAuthManager.instance.cachedOrganization` for org data
- Local state in StatefulWidgets, no global state management library

---

## Directory Structure

```
lib/
├── main.dart              # App entry point, Supabase init
├── nav.dart               # GoRouter configuration, AppRoutes
├── theme.dart             # Theme, colors, spacing, typography
├── auth/
│   ├── auth_manager.dart           # Abstract auth interface
│   └── supabase_auth_manager.dart  # Supabase implementation
├── config/
│   └── role_policies.dart  # Email-to-role enforcement
├── models/                 # Data classes with toJson/fromJson/copyWith
├── services/               # Business logic, Supabase CRUD operations
├── screens/
│   ├── mobile_app_shell.dart  # Bottom nav wrapper
│   ├── web/                   # Dashboard screens
│   │   ├── app_shell.dart     # Sidebar wrapper
│   │   └── widgets/           # Shared dashboard widgets
│   └── *.dart                 # Mobile screens
├── widgets/                # Reusable components
├── utils/                  # Utilities (PDF generation, etc.)
├── supabase/
│   └── supabase_config.dart  # Supabase client & SupabaseService
└── data/                   # Static data (Italian locations)

supabase/
├── migrations/             # SQL migrations for schema changes
└── functions/              # Edge functions (TypeScript)
```

---

## Code Conventions

### Imports
- **Always use absolute imports**: `package:xraynow/...`
- Import aliases for conflicts: `import 'package:xraynow/models/user.dart' as app;`

### Models
```dart
class ModelName {
  // Fields
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Constructor
  ModelName({required this.id, ...});
  
  // JSON conversion (snake_case keys)
  Map<String, dynamic> toJson() => {'id': id, ...};
  factory ModelName.fromJson(Map<String, dynamic> json) => ModelName(...);
  
  // Copy method
  ModelName copyWith({String? id, ...}) => ModelName(id: id ?? this.id, ...);
}
```

### Services
```dart
class ModelNameService {
  // Use SupabaseService helpers for CRUD
  Future<List<ModelName>> getAll() async {
    final data = await SupabaseService.select('table_name');
    return data.map((json) => ModelName.fromJson(json)).toList();
  }
  
  // Direct client access for complex queries
  Future<ModelName?> getById(String id) async {
    final data = await SupabaseConfig.client
        .from('table_name')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? ModelName.fromJson(data) : null;
  }
}
```

### Screens
```dart
class ScreenName extends StatefulWidget {
  const ScreenName({super.key});
  @override
  State<ScreenName> createState() => _ScreenNameState();
}

class _ScreenNameState extends State<ScreenName> {
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _load();
  }
  
  Future<void> _load() async {
    try {
      // Load data
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
```

### Theming
- Use theme colors: `Theme.of(context).colorScheme.primary`
- Spacing constants: `AppSpacing.md`, `AppSpacing.paddingLg`
- Text styles: `context.textStyles.bodyLarge?.bold`
- Custom colors in `LightModeColors`/`DarkModeColors`

### Debugging
- Use `debugPrint()` for logging (not `print()`)
- Log format: `debugPrint('[ClassName] message');`
- Emoji indicators: ✅ success, ❌ error, ℹ️ info

---

## Supabase Patterns

### Database Operations
```dart
// Via SupabaseService helpers
await SupabaseService.select('table', filters: {'column': value});
await SupabaseService.insert('table', data);
await SupabaseService.update('table', data, filters: {'id': id});
await SupabaseService.delete('table', filters: {'id': id});

// Direct client for complex queries
await SupabaseConfig.client.from('table').select('*, relation(*)').eq(...);
```

### RLS Policies
- All tables use Row Level Security
- Policies reference `auth.uid()` and helper functions like `get_user_organization_id()`
- Check `supabase/migrations/` for policy definitions

### Edge Functions
- Located in `supabase/functions/`
- TypeScript with Deno runtime
- Call via `SupabaseConfig.client.functions.invoke('function_name', body: {...})`

---

## Key Patterns

### Auth State Check
```dart
final isAuthenticated = SupabaseConfig.auth.currentUser != null;
final profile = SupabaseAuthManager.instance.cachedProfile;
final role = profile?.role ?? 'end_user';
```

### Role-Based Routing
```dart
if (role == 'super_admin') context.go(AppRoutes.adminDashboard);
else if (role == 'org_admin') context.go(AppRoutes.organizationDashboard);
else context.go(AppRoutes.dashboard);
```

### Loading States
```dart
if (_loading) return const Center(child: CircularProgressIndicator());
```

### Error Handling
```dart
try {
  // Operation
} catch (e) {
  debugPrint('[ClassName] Error: $e');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
    );
  }
}
```

---

## Important Constraints

1. **Cross-platform**: Must work on Android, iOS, and Web. Avoid `dart:io`.
2. **File uploads**: Use `file_picker` package, not platform-specific APIs.
3. **Session persistence**: Supabase handles session storage; `SupabaseAuthManager.initialize()` restores cache on app reload.
4. **Italian locale**: UI text in Italian, date formatting uses `it_IT`.
5. **24-hour time**: Enforced via `MediaQuery` in `main.dart`.
6. **Organization = Struttura**: In the domain, organizations represent healthcare facilities.

---

## Common Tasks

### Adding a New Screen
1. Create screen in `lib/screens/` (or `lib/screens/web/` for dashboard)
2. Add route constant in `AppRoutes` class
3. Add `GoRoute` in `nav.dart` under appropriate ShellRoute

### Adding a New Model
1. Create model class in `lib/models/` with `toJson`/`fromJson`/`copyWith`
2. Create service class in `lib/services/`
3. Create Supabase migration in `supabase/migrations/`

### Adding a New Service Method
1. Use `SupabaseService` helpers or direct `SupabaseConfig.client` calls
2. Handle errors with try/catch and `debugPrint`
3. Consider RLS policies when designing queries
