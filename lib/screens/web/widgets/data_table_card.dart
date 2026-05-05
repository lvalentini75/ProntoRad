import 'package:flutter/material.dart';
import 'package:xraynow/theme.dart';

/// Reusable data table card component
class DataTableCard extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;

  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                ? const Color(0xFF1E2430) 
                : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: columns.map((col) => Expanded(
                child: Text(
                  col,
                  style: context.textStyles.labelMedium?.semiBold
                    .withColor(colorScheme.onSurfaceVariant),
                ),
              )).toList(),
            ),
          ),
          
          // Data rows
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nessun dato disponibile',
                  style: context.textStyles.bodyMedium
                    ?.withColor(colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final isLast = index == rows.length - 1;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(
                    bottom: BorderSide(
                      color: isDark 
                        ? const Color(0xFF2A3340) 
                        : const Color(0xFFE8EDF2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: row.map((widget) => Expanded(child: widget)).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }
}
