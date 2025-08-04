import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../widgets/chart_widgets.dart';
import '../providers/dashboard_providers.dart';

class RevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const RevenueAnalyticsScreen({super.key});

  @override
  ConsumerState<RevenueAnalyticsScreen> createState() =>
      _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends ConsumerState<RevenueAnalyticsScreen>
    with TickerProviderStateMixin {
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revenueAnalytics =
        ref.watch(revenueAnalyticsProvider(_selectedPeriod));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue Analytics'),
        actions: [
          _buildPeriodSelector(),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportData(),
            tooltip: 'Export Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Trends', icon: Icon(Icons.trending_up)),
            Tab(text: 'Breakdown', icon: Icon(Icons.pie_chart)),
            Tab(text: 'Forecasts', icon: Icon(Icons.insights)),
          ],
        ),
      ),
      body: revenueAnalytics.when(
        data: (data) =>
            data != null ? _buildContent(data) : _buildNoDataState(),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildContent(RevenueAnalytics data) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(data),
        _buildTrendsTab(data),
        _buildBreakdownTab(data),
        _buildForecastsTab(data),
      ],
    );
  }

  Widget _buildOverviewTab(RevenueAnalytics data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard(
                'Total Revenue',
                data.totalRevenue,
                'SGD',
                Icons.attach_money,
                Colors.green,
                data.growthRate,
              ),
              _buildMetricCard(
                'Recurring Revenue',
                data.recurringRevenue,
                'SGD',
                Icons.repeat,
                Colors.blue,
                null,
              ),
              _buildMetricCard(
                'Average Order Value',
                data.averageOrderValue,
                'SGD',
                Icons.shopping_cart,
                Colors.orange,
                null,
              ),
              _buildMetricCard(
                'Total Transactions',
                data.totalTransactions.toDouble(),
                'orders',
                Icons.receipt,
                Colors.purple,
                null,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Revenue trend chart
          InteractiveLineChart(
            data: data.revenueByDay,
            title: 'Daily Revenue Trend',
            subtitle: 'Revenue performance over time',
            lineColor: Colors.green,
            height: 350,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(RevenueAnalytics data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Revenue vs Recurring Revenue comparison
          InteractiveLineChart(
            data: [
              ...data.revenueByDay.map((dp) => DataPoint(
                    timestamp: dp.timestamp,
                    value: dp.value,
                    label: 'Total Revenue',
                  )),
            ],
            title: 'Revenue Trends Comparison',
            subtitle: 'Total vs Recurring Revenue',
            lineColor: Colors.green,
            height: 300,
          ),

          const SizedBox(height: 24),

          // Growth rate visualization
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth Analysis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGrowthIndicator(
                          'Revenue Growth',
                          data.growthRate,
                          '%',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGrowthIndicator(
                          'Transaction Growth',
                          15.2, // Mock data
                          '%',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTab(RevenueAnalytics data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Revenue by category pie chart
          InteractivePieChart(
            data: data.revenueByCategory.entries
                .map((entry) => DataPoint(
                      timestamp: DateTime.now(),
                      value: entry.value,
                      label: entry.key,
                    ))
                .toList(),
            title: 'Revenue by Category',
            height: 350,
          ),

          const SizedBox(height: 24),

          // Top customers by revenue
          InteractiveBarChart(
            data: data.revenueByCustomer.take(10).toList(),
            title: 'Top 10 Customers by Revenue',
            barColor: Colors.blue,
            height: 300,
          ),

          const SizedBox(height: 24),

          // Top products by revenue
          InteractiveBarChart(
            data: data.revenueByProduct.take(10).toList(),
            title: 'Top 10 Products by Revenue',
            barColor: Colors.orange,
            height: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildForecastsTab(RevenueAnalytics data) {
    // Mock forecast data for demonstration
    final forecastData = _generateMockForecastData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Revenue forecast chart
          InteractiveLineChart(
            data: [
              ...data.revenueByDay,
              ...forecastData,
            ],
            title: 'Revenue Forecast',
            subtitle: 'Historical data and 30-day forecast',
            lineColor: Colors.green,
            height: 350,
          ),

          const SizedBox(height: 24),

          // Forecast metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Forecast Insights',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildForecastMetric(
                    'Predicted Revenue (Next 30 days)',
                    forecastData.fold(0.0, (sum, dp) => sum + dp.value),
                    'SGD',
                  ),
                  const SizedBox(height: 8),
                  _buildForecastMetric(
                    'Confidence Level',
                    85.0,
                    '%',
                  ),
                  const SizedBox(height: 8),
                  _buildForecastMetric(
                    'Expected Growth',
                    12.5,
                    '%',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    double value,
    String unit,
    IconData icon,
    Color color,
    double? changePercent,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                if (changePercent != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changePercent >= 0 ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatValue(value, unit),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthIndicator(String label, double value, String unit) {
    final isPositive = value >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${isPositive ? '+' : ''}${value.toStringAsFixed(1)}$unit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastMetric(String label, double value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          _formatValue(value, unit),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
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
          Text('Loading revenue analytics...'),
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
            'Failed to load revenue analytics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(revenueAnalyticsProvider(_selectedPeriod));
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
            Icons.pie_chart_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Revenue Data Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Start creating invoices to see revenue analytics',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.today:
        return 'Today';
      case TimePeriod.yesterday:
        return 'Yesterday';
      case TimePeriod.thisWeek:
        return 'This Week';
      case TimePeriod.lastWeek:
        return 'Last Week';
      case TimePeriod.thisMonth:
        return 'This Month';
      case TimePeriod.lastMonth:
        return 'Last Month';
      case TimePeriod.thisQuarter:
        return 'This Quarter';
      case TimePeriod.lastQuarter:
        return 'Last Quarter';
      case TimePeriod.thisYear:
        return 'This Year';
      case TimePeriod.lastYear:
        return 'Last Year';
      case TimePeriod.custom:
        return 'Custom Range';
    }
  }

  String _formatValue(double value, String unit) {
    String formatted = '';

    if (unit == 'SGD') {
      formatted = '\$';
      if (value >= 1000000) {
        formatted += '${(value / 1000000).toStringAsFixed(1)}M';
      } else if (value >= 1000) {
        formatted += '${(value / 1000).toStringAsFixed(1)}K';
      } else {
        formatted += value.toStringAsFixed(0);
      }
    } else {
      formatted = value.toStringAsFixed(unit == '%' ? 1 : 0);
      if (unit != 'orders') formatted += ' $unit';
    }

    return formatted;
  }

  List<DataPoint> _generateMockForecastData() {
    final forecast = <DataPoint>[];
    final now = DateTime.now();

    for (int i = 1; i <= 30; i++) {
      forecast.add(DataPoint(
        timestamp: now.add(Duration(days: i)),
        value: 1500 + (i * 50) + (i % 7 * 200), // Mock forecast pattern
        label: 'Forecast',
      ));
    }

    return forecast;
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Revenue Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf),
              title: Text('Export as PDF'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            ListTile(
              leading: Icon(Icons.table_chart),
              title: Text('Export as Excel'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            ListTile(
              leading: Icon(Icons.file_copy),
              title: Text('Export as CSV'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
