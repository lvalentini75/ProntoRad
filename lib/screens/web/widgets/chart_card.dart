import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';

/// Placeholder for chart visualization
class ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const ChartCard({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F26) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
            ? const Color(0xFF2A3340) 
            : const Color(0xFFE8EDF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: context.textStyles.titleMedium?.semiBold),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _SimpleBarChart(),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart visualization
class _SimpleBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Mock data for 7 days
    final data = [45, 62, 38, 71, 55, 49, 68];
    final max = data.reduce((a, b) => a > b ? a : b);
    final labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final value = data[index];
        final height = (value / max) * 180;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value.toString(),
                  style: context.textStyles.labelSmall?.semiBold
                    .withColor(colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary,
                        colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[index],
                  style: context.textStyles.labelSmall
                    ?.withColor(colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
