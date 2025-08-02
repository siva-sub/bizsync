import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../widgets/chart_widgets.dart';
import '../providers/dashboard_providers.dart';

class TaxComplianceScreen extends ConsumerWidget {
  const TaxComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxComplianceStatus = ref.watch(taxComplianceStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Compliance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(taxComplianceStatusProvider),
          ),
        ],
      ),
      body: taxComplianceStatus.when(
        data: (data) => data != null 
            ? _buildContent(context, data)
            : _buildNoDataState(),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(context, error, ref),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TaxComplianceStatus data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compliance score gauge
          ProgressGauge(
            value: data.complianceScore,
            maxValue: 100,
            title: 'Compliance Score',
            subtitle: '${data.complianceScore.toStringAsFixed(1)}% compliant',
            color: _getComplianceColor(data.complianceScore),
            height: 250,
          ),
          
          const SizedBox(height: 24),
          
          // Tax overview cards
          _buildTaxOverviewCards(context, data),
          
          const SizedBox(height: 24),
          
          // Upcoming obligations
          if (data.upcomingObligations.isNotEmpty)
            _buildUpcomingObligations(context, data.upcomingObligations),
          
          const SizedBox(height: 24),
          
          // Tax alerts
          if (data.alerts.isNotEmpty)
            _buildTaxAlerts(context, data.alerts),
          
          const SizedBox(height: 24),
          
          // Tax breakdown chart
          if (data.taxLiabilities.isNotEmpty)
            InteractivePieChart(
              data: data.taxLiabilities.entries
                  .map((entry) => DataPoint(
                        timestamp: DateTime.now(),
                        value: entry.value,
                        label: entry.key,
                      ))
                  .toList(),
              title: 'Tax Liabilities Breakdown',
              height: 350,
            ),
        ],
      ),
    );
  }

  Widget _buildTaxOverviewCards(BuildContext context, TaxComplianceStatus data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildOverviewCard(
          context,
          'Total Tax Paid',
          data.totalTaxPaid,
          'SGD',
          Icons.payment,
          Colors.green,
        ),
        _buildOverviewCard(
          context,
          'Pending Taxes',
          data.pendingTaxes,
          'SGD',
          Icons.pending,
          Colors.orange,
        ),
        _buildOverviewCard(
          context,
          'Compliance Score',
          data.complianceScore,
          '%',
          Icons.verified,
          _getComplianceColor(data.complianceScore),
        ),
        _buildOverviewCard(
          context,
          'Obligations',
          data.upcomingObligations.length.toDouble(),
          'items',
          Icons.assignment,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
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

  Widget _buildUpcomingObligations(BuildContext context, List<TaxObligation> obligations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Obligations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...obligations.take(5).map((obligation) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getObligationColor(obligation.daysUntilDue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getObligationColor(obligation.daysUntilDue).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment,
                          color: _getObligationColor(obligation.daysUntilDue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                obligation.type,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                obligation.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Due: ${_formatDate(obligation.dueDate)} (${obligation.daysUntilDue} days)',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${obligation.estimatedAmount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getObligationColor(obligation.daysUntilDue),
                              ),
                        ),
                      ],
                    ),
                  ),
                )),
            if (obligations.length > 5)
              TextButton(
                onPressed: () => _showAllObligations(context, obligations),
                child: Text('View All ${obligations.length} Obligations'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxAlerts(BuildContext context, List<TaxAlert> alerts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notification_important, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Tax Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.where((alert) => !alert.isRead).take(3).map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getAlertSeverityColor(alert.severity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getAlertSeverityColor(alert.severity).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getAlertIcon(alert.severity),
                          color: _getAlertSeverityColor(alert.severity),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                alert.message,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            alert.severity.toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: _getAlertSeverityColor(alert.severity),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _getComplianceColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  Color _getObligationColor(int daysUntilDue) {
    if (daysUntilDue <= 7) return Colors.red;
    if (daysUntilDue <= 30) return Colors.orange;
    return Colors.blue;
  }

  Color _getAlertSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Icons.error;
      case 'medium':
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
          Text('Loading tax compliance data...'),
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
            'Failed to load tax compliance data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(taxComplianceStatusProvider),
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
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Tax Compliance Data Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatValue(double value, String unit) {
    if (unit == 'SGD') {
      return '\$${value.toStringAsFixed(0)}';
    } else if (unit == '%') {
      return '${value.toStringAsFixed(1)}%';
    } else if (unit == 'items') {
      return value.toStringAsFixed(0);
    } else {
      return value.toStringAsFixed(0) + (unit.isNotEmpty ? ' $unit' : '');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAllObligations(BuildContext context, List<TaxObligation> obligations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Tax Obligations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: obligations.length,
            itemBuilder: (context, index) {
              final obligation = obligations[index];
              return ListTile(
                leading: Icon(
                  Icons.assignment,
                  color: _getObligationColor(obligation.daysUntilDue),
                ),
                title: Text(obligation.type),
                subtitle: Text(
                  '${obligation.description}\nDue: ${_formatDate(obligation.dueDate)}',
                ),
                trailing: Text(
                  '\$${obligation.estimatedAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                isThreeLine: true,
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