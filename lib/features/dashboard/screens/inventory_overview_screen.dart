import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../widgets/chart_widgets.dart';
import '../providers/dashboard_providers.dart';

class InventoryOverviewScreen extends ConsumerWidget {
  const InventoryOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryOverview = ref.watch(inventoryOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inventoryOverviewProvider),
          ),
        ],
      ),
      body: inventoryOverview.when(
        data: (data) => data != null 
            ? _buildContent(context, data)
            : _buildNoDataState(),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(context, error, ref),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InventoryOverview data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inventory summary cards
          _buildSummaryCards(context, data),
          
          const SizedBox(height: 24),
          
          // Stock alerts section
          if (data.stockAlerts.isNotEmpty)
            _buildStockAlerts(context, data.stockAlerts),
          
          const SizedBox(height: 24),
          
          // Stock by category chart
          InteractivePieChart(
            data: data.stockByCategory.entries
                .map((entry) => DataPoint(
                      timestamp: DateTime.now(),
                      value: entry.value.toDouble(),
                      label: entry.key,
                    ))
                .toList(),
            title: 'Stock by Category',
            height: 350,
          ),
          
          const SizedBox(height: 24),
          
          // Inventory turnover chart
          InteractiveLineChart(
            data: data.inventoryTurnover,
            title: 'Inventory Turnover',
            subtitle: 'Turnover rate over time',
            lineColor: Colors.purple,
            height: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, InventoryOverview data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          context,
          'Total Products',
          data.totalProducts.toDouble(),
          '',
          Icons.inventory_2,
          Colors.blue,
        ),
        _buildSummaryCard(
          context,
          'Low Stock Items',
          data.lowStockProducts.toDouble(),
          '',
          Icons.warning,
          Colors.orange,
        ),
        _buildSummaryCard(
          context,
          'Out of Stock',
          data.outOfStockProducts.toDouble(),
          '',
          Icons.error,
          Colors.red,
        ),
        _buildSummaryCard(
          context,
          'Inventory Value',
          data.totalInventoryValue,
          'SGD',
          Icons.monetization_on,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatValue(value, unit),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlerts(BuildContext context, List<ProductStockAlert> alerts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Stock Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.take(5).map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getAlertColor(alert.severity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAlertColor(alert.severity).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getAlertIcon(alert.severity),
                          color: _getAlertColor(alert.severity),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.productName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Current: ${alert.currentStock} | Min: ${alert.minStock}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            alert.severity.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getAlertColor(alert.severity),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )),
            if (alerts.length > 5)
              TextButton(
                onPressed: () => _showAllAlerts(context, alerts),
                child: Text('View All ${alerts.length} Alerts'),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAlertColor(String severity) {
    switch (severity) {
      case 'out_of_stock':
        return Colors.red;
      case 'critical':
        return Colors.deepOrange;
      case 'low':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String severity) {
    switch (severity) {
      case 'out_of_stock':
        return Icons.error;
      case 'critical':
        return Icons.warning;
      case 'low':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading inventory data...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load inventory data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(inventoryOverviewProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Inventory Data Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatValue(double value, String unit) {
    if (unit == 'SGD') {
      return '\$${value.toStringAsFixed(0)}';
    } else {
      return value.toStringAsFixed(0) + (unit.isNotEmpty ? ' $unit' : '');
    }
  }

  void _showAllAlerts(BuildContext context, List<ProductStockAlert> alerts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Stock Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return ListTile(
                leading: Icon(
                  _getAlertIcon(alert.severity),
                  color: _getAlertColor(alert.severity),
                ),
                title: Text(alert.productName),
                subtitle: Text('Current: ${alert.currentStock} | Min: ${alert.minStock}'),
                trailing: Chip(
                  label: Text(alert.severity.toUpperCase()),
                  backgroundColor: _getAlertColor(alert.severity),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}