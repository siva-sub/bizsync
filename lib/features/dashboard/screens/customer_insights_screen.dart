import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../widgets/chart_widgets.dart';
import '../providers/dashboard_providers.dart';

class CustomerInsightsScreen extends ConsumerStatefulWidget {
  const CustomerInsightsScreen({super.key});

  @override
  ConsumerState<CustomerInsightsScreen> createState() =>
      _CustomerInsightsScreenState();
}

class _CustomerInsightsScreenState
    extends ConsumerState<CustomerInsightsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;

  @override
  Widget build(BuildContext context) {
    final customerInsights =
        ref.watch(customerInsightsProvider(_selectedPeriod));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Insights'),
        actions: [
          _buildPeriodSelector(),
        ],
      ),
      body: customerInsights.when(
        data: (data) =>
            data != null ? _buildContent(data) : _buildNoDataState(),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildContent(CustomerInsights data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer metrics cards
          _buildMetricsCards(data),

          const SizedBox(height: 24),

          // Customer growth chart
          InteractiveLineChart(
            data: data.customerGrowth,
            title: 'Customer Growth',
            subtitle: 'New customers over time',
            lineColor: Colors.blue,
            height: 300,
          ),

          const SizedBox(height: 24),

          // Customer segments
          _buildSegmentationCharts(data),

          const SizedBox(height: 24),

          // Behavior insights
          if (data.behaviorInsights.isNotEmpty)
            _buildBehaviorInsights(data.behaviorInsights),
        ],
      ),
    );
  }

  Widget _buildMetricsCards(CustomerInsights data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          'Total Customers',
          data.totalCustomers.toDouble(),
          '',
          Icons.people,
          Colors.blue,
        ),
        _buildMetricCard(
          'New Customers',
          data.newCustomers.toDouble(),
          '',
          Icons.person_add,
          Colors.green,
        ),
        _buildMetricCard(
          'Churn Rate',
          data.churnRate,
          '%',
          Icons.person_remove,
          Colors.red,
        ),
        _buildMetricCard(
          'Avg. Lifetime Value',
          data.averageLifetimeValue,
          'SGD',
          Icons.monetization_on,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, double value, String unit, IconData icon, Color color) {
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

  Widget _buildSegmentationCharts(CustomerInsights data) {
    return Row(
      children: [
        Expanded(
          child: InteractivePieChart(
            data: data.customersBySegment.entries
                .map((entry) => DataPoint(
                      timestamp: DateTime.now(),
                      value: entry.value,
                      label: entry.key,
                    ))
                .toList(),
            title: 'Customers by Segment',
            height: 300,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InteractivePieChart(
            data: data.revenueBySegment.entries
                .map((entry) => DataPoint(
                      timestamp: DateTime.now(),
                      value: entry.value,
                      label: entry.key,
                    ))
                .toList(),
            title: 'Revenue by Segment',
            height: 300,
          ),
        ),
      ],
    );
  }

  Widget _buildBehaviorInsights(List<CustomerBehaviorInsight> insights) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Behavior Insights',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight.insight,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Recommendation: ${insight.recommendation}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Impact: ${(insight.impact * 100).toStringAsFixed(0)}%',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
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

  Widget _buildPeriodSelector() {
    return PopupMenuButton<TimePeriod>(
      icon: const Icon(Icons.date_range),
      onSelected: (period) {
        setState(() {
          _selectedPeriod = period;
        });
      },
      itemBuilder: (context) => TimePeriod.values.map((period) {
        return PopupMenuItem<TimePeriod>(
          value: period,
          child: Text(_getPeriodLabel(period)),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading customer insights...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
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
            'Failed to load customer insights',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(customerInsightsProvider(_selectedPeriod));
            },
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
            Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Customer Data Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.thisMonth:
        return 'This Month';
      case TimePeriod.lastMonth:
        return 'Last Month';
      case TimePeriod.thisQuarter:
        return 'This Quarter';
      case TimePeriod.thisYear:
        return 'This Year';
      default:
        return period.name;
    }
  }

  String _formatValue(double value, String unit) {
    if (unit == 'SGD') {
      return '\$${value.toStringAsFixed(0)}';
    } else if (unit == '%') {
      return '${value.toStringAsFixed(1)}%';
    } else {
      return value.toStringAsFixed(0) + (unit.isNotEmpty ? ' $unit' : '');
    }
  }
}
