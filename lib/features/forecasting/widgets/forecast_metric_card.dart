import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Card widget displaying a forecast metric with trend indicator
class ForecastMetricCard extends StatelessWidget {
  final String title;
  final double? value;
  final double? trend; // Percentage change
  final Color color;
  final VoidCallback? onTap;

  const ForecastMetricCard({
    super.key,
    required this.title,
    this.value,
    this.trend,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormatter =
        NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    _getIconForMetric(title),
                    color: color,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value != null ? numberFormatter.format(value!) : 'No data',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: value != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  if (trend != null) ...[
                    const SizedBox(height: 4),
                    _buildTrendIndicator(context),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    if (trend == null) return const SizedBox.shrink();

    final isPositive = trend! >= 0;
    final trendColor = isPositive ? Colors.green : Colors.red;
    final trendIcon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Row(
      children: [
        Icon(
          trendIcon,
          size: 16,
          color: trendColor,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${trend!.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: trendColor,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'vs last period',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  IconData _getIconForMetric(String title) {
    switch (title.toLowerCase()) {
      case 'revenue':
        return Icons.trending_up;
      case 'expenses':
        return Icons.trending_down;
      case 'cash flow':
        return Icons.account_balance;
      case 'inventory':
        return Icons.inventory;
      default:
        return Icons.analytics;
    }
  }
}
