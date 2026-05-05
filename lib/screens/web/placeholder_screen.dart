import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';

/// Placeholder screen for features under development
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.description = 'Questa funzionalità sarà disponibile a breve.',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: context.textStyles.headlineMedium?.bold,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: context.textStyles.bodyLarge
                ?.withColor(colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {},
              icon: Icon(Icons.construction_rounded),
              label: Text('In Sviluppo'),
            ),
          ],
        ),
      ),
    );
  }
}
