import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/forecasting_models.dart';
import '../services/forecasting_service.dart';
import '../services/forecast_export_service.dart';
import '../widgets/forecast_session_card.dart';
import '../widgets/forecast_metric_card.dart';
import '../widgets/forecast_quick_actions.dart';

/// Main forecasting dashboard showing overview and navigation
class ForecastingDashboardScreen extends ConsumerStatefulWidget {
  const ForecastingDashboardScreen({super.key});

  @override
  ConsumerState<ForecastingDashboardScreen> createState() =>
      _ForecastingDashboardScreenState();
}

class _ForecastingDashboardScreenState
    extends ConsumerState<ForecastingDashboardScreen> {
  late ForecastingService _forecastingService;
  late ForecastExportService _exportService;

  List<ForecastSession> _recentSessions = [];
  bool _isLoading = true;
  String? _error;

  final Map<String, double> _lastForecasts = {};
  final Map<String, List<TimeSeriesPoint>> _historicalData = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _forecastingService = await ForecastingService.getInstance();
      _exportService = ForecastExportService.getInstance();
      await _loadDashboardData();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize forecasting service: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      // Load recent sessions
      _recentSessions = await _forecastingService.getAllForecastSessions();

      // Load latest forecasts for each data source
      await _loadLatestForecasts();

      // Load historical data for overview charts
      await _loadHistoricalOverview();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLatestForecasts() async {
    final dataSources = ['revenue', 'expenses', 'cashflow', 'inventory'];

    for (final source in dataSources) {
      final sessions =
          await _forecastingService.getForecastSessionsByDataSource(source);
      if (sessions.isNotEmpty) {
        final latestSession = sessions.first;

        // Get the best performing scenario's next forecast
        double? bestForecast;
        double bestScore = -1;

        for (final scenario in latestSession.scenarios) {
          final accuracy = latestSession.accuracyMetrics[scenario.id];
          final results = latestSession.results[scenario.id];

          if (accuracy != null && results != null && results.isNotEmpty) {
            final score = accuracy.r2;
            if (score > bestScore) {
              bestScore = score;
              bestForecast = results.first.predictedValue;
            }
          }
        }

        if (bestForecast != null) {
          _lastForecasts[source] = bestForecast;
        }
      }
    }
  }

  Future<void> _loadHistoricalOverview() async {
    final dataSources = ['revenue', 'expenses', 'cashflow'];

    for (final source in dataSources) {
      try {
        final data = await _forecastingService.getHistoricalData(
          source,
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          aggregation: Periodicity.monthly,
        );
        _historicalData[source] = data;
      } catch (e) {
        print('Failed to load historical data for $source: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecasting Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showForecastSettings(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: _buildDashboard(),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewForecastDialog(),
        icon: const Icon(Icons.analytics),
        label: const Text('New Forecast'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Dashboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDashboardData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildForecastOverview(),
          const SizedBox(height: 24),
          _buildHistoricalTrends(),
          const SizedBox(height: 24),
          _buildRecentSessions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return ForecastQuickActions(
      onCreateRevenueForecast: () => _navigateToForecast('revenue'),
      onCreateExpenseForecast: () => _navigateToForecast('expenses'),
      onCreateCashFlowForecast: () => _navigateToForecast('cashflow'),
      onCreateInventoryForecast: () => _navigateToForecast('inventory'),
      onViewReports: () => _navigateToReports(),
    );
  }

  Widget _buildForecastOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest Forecasts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                ForecastMetricCard(
                  title: 'Revenue',
                  value: _lastForecasts['revenue'],
                  trend: _calculateTrend('revenue'),
                  color: Colors.green,
                  onTap: () => _navigateToForecast('revenue'),
                ),
                ForecastMetricCard(
                  title: 'Expenses',
                  value: _lastForecasts['expenses'],
                  trend: _calculateTrend('expenses'),
                  color: Colors.red,
                  onTap: () => _navigateToForecast('expenses'),
                ),
                ForecastMetricCard(
                  title: 'Cash Flow',
                  value: _lastForecasts['cashflow'],
                  trend: _calculateTrend('cashflow'),
                  color: Colors.blue,
                  onTap: () => _navigateToForecast('cashflow'),
                ),
                ForecastMetricCard(
                  title: 'Inventory',
                  value: _lastForecasts['inventory'],
                  trend: _calculateTrend('inventory'),
                  color: Colors.orange,
                  onTap: () => _navigateToForecast('inventory'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _calculateTrend(String dataSource) {
    final data = _historicalData[dataSource];
    if (data == null || data.length < 2) return null;

    final recent =
        data.length >= 2 ? data.skip(data.length - 2).toList() : data;
    if (recent.length < 2) return null;

    final change = recent.last.value - recent.first.value;
    return recent.first.value != 0 ? (change / recent.first.value) * 100 : 0;
  }

  Widget _buildHistoricalTrends() {
    if (_historicalData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historical Trends (Last 12 Months)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (_historicalData['revenue']?.isNotEmpty == true) {
                            final data = _historicalData['revenue']!;
                            final index = value.toInt();
                            if (index >= 0 && index < data.length) {
                              return Text(
                                DateFormat('MMM').format(data[index].date),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildLineChartData(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineChartData() {
    final lines = <LineChartBarData>[];

    final colors = [Colors.green, Colors.red, Colors.blue];
    final dataSourceOrder = ['revenue', 'expenses', 'cashflow'];

    for (int i = 0; i < dataSourceOrder.length; i++) {
      final source = dataSourceOrder[i];
      final data = _historicalData[source];

      if (data != null && data.isNotEmpty) {
        lines.add(
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            color: colors[i],
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }

    return lines;
  }

  Widget _buildLegend() {
    final items = [
      {'name': 'Revenue', 'color': Colors.green},
      {'name': 'Expenses', 'color': Colors.red},
      {'name': 'Cash Flow', 'color': Colors.blue},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              color: item['color'] as Color,
            ),
            const SizedBox(width: 4),
            Text(
              item['name'] as String,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRecentSessions() {
    if (_recentSessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Forecast Sessions Yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first forecast to see it here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showNewForecastDialog(),
                child: const Text('Create Forecast'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Forecasts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => _navigateToAllSessions(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentSessions.take(5).length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = _recentSessions[index];
                return ForecastSessionCard(
                  session: session,
                  onTap: () => _navigateToSessionDetail(session.id),
                  onExport: () => _exportSession(session),
                  onDelete: () => _deleteSession(session),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToForecast(String dataSource) {
    context.push('/forecasting/$dataSource');
  }

  void _navigateToReports() {
    context.push('/forecasting/reports');
  }

  void _navigateToAllSessions() {
    context.push('/forecasting/sessions');
  }

  void _navigateToSessionDetail(String sessionId) {
    context.push('/forecasting/session/$sessionId');
  }

  void _showNewForecastDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Forecast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.green),
              title: const Text('Revenue Forecast'),
              subtitle: const Text('Predict future revenue trends'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToForecast('revenue');
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_down, color: Colors.red),
              title: const Text('Expense Forecast'),
              subtitle: const Text('Forecast future expenses'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToForecast('expenses');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.blue),
              title: const Text('Cash Flow Forecast'),
              subtitle: const Text('Predict cash flow patterns'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToForecast('cashflow');
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.orange),
              title: const Text('Inventory Forecast'),
              subtitle: const Text('Forecast inventory needs'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToForecast('inventory');
              },
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

  void _showForecastSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forecast Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Data Cache'),
              subtitle:
                  const Text('Update historical data from latest transactions'),
              onTap: () async {
                Navigator.of(context).pop();
                _showLoadingDialog('Refreshing data cache...');
                try {
                  await _forecastingService.refreshHistoricalDataCache();
                  await _loadDashboardData();
                  Navigator.of(context).pop();
                  _showSuccessSnackBar('Data cache refreshed successfully');
                } catch (e) {
                  Navigator.of(context).pop();
                  _showErrorSnackBar('Failed to refresh data cache: $e');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Model Performance'),
              subtitle: const Text('View detailed accuracy metrics'),
              onTap: () {
                Navigator.of(context).pop();
                _showModelPerformance();
              },
            ),
          ],
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

  void _showModelPerformance() {
    // Calculate average performance across all sessions
    final allAccuracies = <ForecastAccuracy>[];
    for (final session in _recentSessions) {
      allAccuracies.addAll(session.accuracyMetrics.values);
    }

    if (allAccuracies.isEmpty) {
      _showErrorSnackBar('No performance data available');
      return;
    }

    final avgR2 = allAccuracies.map((a) => a.r2).reduce((a, b) => a + b) /
        allAccuracies.length;
    final avgMape = allAccuracies.map((a) => a.mape).reduce((a, b) => a + b) /
        allAccuracies.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Performance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Average R² Score'),
              trailing: Text('${(avgR2 * 100).toStringAsFixed(1)}%'),
            ),
            ListTile(
              title: const Text('Average MAPE'),
              trailing: Text('${avgMape.toStringAsFixed(1)}%'),
            ),
            ListTile(
              title: const Text('Total Sessions'),
              trailing: Text('${_recentSessions.length}'),
            ),
            ListTile(
              title: const Text('Active Models'),
              trailing: Text('${allAccuracies.length}'),
            ),
          ],
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

  Future<void> _exportSession(ForecastSession session) async {
    try {
      _showLoadingDialog('Exporting forecast session...');

      final file = await _exportService.exportToPdf(session);
      Navigator.of(context).pop();

      await _exportService.shareFile(file, 'Forecast Report: ${session.name}');
      _showSuccessSnackBar('Forecast exported successfully');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Failed to export forecast: $e');
    }
  }

  Future<void> _deleteSession(ForecastSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forecast Session'),
        content: Text(
            'Are you sure you want to delete "${session.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _forecastingService.deleteForecastSession(session.id);
        await _loadDashboardData();
        _showSuccessSnackBar('Forecast session deleted');
      } catch (e) {
        _showErrorSnackBar('Failed to delete session: $e');
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
