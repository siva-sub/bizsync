import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forecasting_models.dart';

/// Card widget displaying forecast session information
class ForecastSessionCard extends StatelessWidget {
  final ForecastSession session;
  final VoidCallback? onTap;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  const ForecastSessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.onExport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('MMM dd, yyyy');

    // Get best performing scenario
    final bestScenario = _getBestPerformingScenario();

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildDataSourceChip(context),
                            const SizedBox(width: 8),
                            Text(
                              'Created ${dateFormatter.format(session.createdAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'export':
                          onExport?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.file_download),
                            SizedBox(width: 8),
                            Text('Export'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      context,
                      'Scenarios',
                      '${session.scenarios.length}',
                      Icons.analytics,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      context,
                      'Data Points',
                      '${session.historicalData.length}',
                      Icons.timeline,
                    ),
                  ),
                  if (bestScenario != null)
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        'Best R²',
                        '${(bestScenario['accuracy'].r2 * 100).toStringAsFixed(1)}%',
                        Icons.star,
                      ),
                    ),
                ],
              ),
              if (bestScenario != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Best: ${bestScenario['scenario'].name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataSourceChip(BuildContext context) {
    final colors = {
      'revenue': Colors.green,
      'expenses': Colors.red,
      'cashflow': Colors.blue,
      'inventory': Colors.orange,
    };

    final icons = {
      'revenue': Icons.trending_up,
      'expenses': Icons.trending_down,
      'cashflow': Icons.account_balance,
      'inventory': Icons.inventory,
    };

    final color = colors[session.dataSource] ?? Colors.grey;
    final icon = icons[session.dataSource] ?? Icons.analytics;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            session.dataSource.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _getBestPerformingScenario() {
    ForecastScenario? bestScenario;
    ForecastAccuracy? bestAccuracy;
    double bestScore = -1;

    for (final scenario in session.scenarios) {
      final accuracy = session.accuracyMetrics[scenario.id];
      if (accuracy != null) {
        final score = accuracy.r2;
        if (score > bestScore) {
          bestScore = score;
          bestScenario = scenario;
          bestAccuracy = accuracy;
        }
      }
    }

    if (bestScenario != null && bestAccuracy != null) {
      return {'scenario': bestScenario, 'accuracy': bestAccuracy};
    }
    return null;
  }
}
