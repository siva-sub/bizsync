import 'package:flutter/material.dart';
import '../../../core/utils/mesa_rendering_detector.dart';

/// Widget providing quick action buttons for creating different types of forecasts
class ForecastQuickActions extends StatelessWidget {
  final VoidCallback? onCreateRevenueForecast;
  final VoidCallback? onCreateExpenseForecast;
  final VoidCallback? onCreateCashFlowForecast;
  final VoidCallback? onCreateInventoryForecast;
  final VoidCallback? onViewReports;

  const ForecastQuickActions({
    super.key,
    this.onCreateRevenueForecast,
    this.onCreateExpenseForecast,
    this.onCreateCashFlowForecast,
    this.onCreateInventoryForecast,
    this.onViewReports,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildActionCard(
                  context,
                  'Revenue\nForecast',
                  Icons.trending_up,
                  Colors.green,
                  onCreateRevenueForecast,
                ),
                _buildActionCard(
                  context,
                  'Expense\nForecast',
                  Icons.trending_down,
                  Colors.red,
                  onCreateExpenseForecast,
                ),
                _buildActionCard(
                  context,
                  'Cash Flow\nForecast',
                  Icons.account_balance,
                  Colors.blue,
                  onCreateCashFlowForecast,
                ),
                _buildActionCard(
                  context,
                  'Inventory\nForecast',
                  Icons.inventory,
                  Colors.orange,
                  onCreateInventoryForecast,
                ),
                _buildActionCard(
                  context,
                  'Financial\nReports',
                  Icons.assessment,
                  Colors.purple,
                  onViewReports,
                ),
                _buildActionCard(
                  context,
                  'Model\nComparison',
                  Icons.compare_arrows,
                  Colors.teal,
                  () => _showModelComparison(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return Card(
      elevation: MesaRenderingDetector.getAdjustedElevation(1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModelComparison(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Comparison'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Compare different forecasting models side by side:'),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.linear_scale, color: Colors.blue),
              title: Text('Linear Regression'),
              subtitle: Text('Best for trending data'),
            ),
            ListTile(
              leading: Icon(Icons.show_chart, color: Colors.green),
              title: Text('Moving Average'),
              subtitle: Text('Good for stable patterns'),
            ),
            ListTile(
              leading: Icon(Icons.timeline, color: Colors.orange),
              title: Text('Exponential Smoothing'),
              subtitle: Text('Weighted recent data'),
            ),
            ListTile(
              leading: Icon(Icons.calendar_view_month, color: Colors.purple),
              title: Text('Seasonal Decomposition'),
              subtitle: Text('Captures seasonal patterns'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to comparison screen
            },
            child: const Text('Compare Models'),
          ),
        ],
      ),
    );
  }
}
