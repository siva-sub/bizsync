import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/forecasting_models.dart';
import '../services/forecasting_service.dart';
import '../services/forecast_export_service.dart';

/// Comprehensive financial reports screen with forecasting insights
class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends ConsumerState<FinancialReportsScreen> {
  late ForecastingService _forecastingService;
  late ForecastExportService _exportService;

  final Map<String, List<TimeSeriesPoint>> _historicalData = {};
  final Map<String, List<ForecastResult>> _latestForecasts = {};
  bool _isLoading = true;
  String? _error;

  DateTimeRange? _selectedDateRange;
  String _selectedReportType = 'overview';

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 365)),
      end: DateTime.now(),
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _forecastingService = await ForecastingService.getInstance();
      _exportService = ForecastExportService.getInstance();
      await _loadReportData();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReportData() async {
    try {
      setState(() => _isLoading = true);

      final dataSources = ['revenue', 'expenses', 'cashflow'];
      
      // Load historical data
      for (final source in dataSources) {
        _historicalData[source] = await _forecastingService.getHistoricalData(
          source,
          startDate: _selectedDateRange!.start,
          endDate: _selectedDateRange!.end,
          aggregation: Periodicity.monthly,
        );
      }

      // Load latest forecasts
      for (final source in dataSources) {
        final sessions = await _forecastingService.getForecastSessionsByDataSource(source);
        if (sessions.isNotEmpty) {
          final latestSession = sessions.first;
          
          // Get best performing scenario's forecast
          double bestScore = -1;
          List<ForecastResult>? bestForecast;
          
          for (final scenario in latestSession.scenarios) {
            final accuracy = latestSession.accuracyMetrics[scenario.id];
            final results = latestSession.results[scenario.id];
            
            if (accuracy != null && results != null && results.isNotEmpty) {
              final score = accuracy.r2;
              if (score > bestScore) {
                bestScore = score;
                bestForecast = results;
              }
            }
          }
          
          if (bestForecast != null) {
            _latestForecasts[source] = bestForecast;
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load report data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildReportsContent(),
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
            'Error Loading Reports',
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
            onPressed: _loadReportData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsContent() {
    return Column(
      children: [
        _buildReportTypeSelector(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSelectedReport(),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTypeSelector() {
    final reportTypes = [
      {'key': 'overview', 'title': 'Overview', 'icon': Icons.dashboard},
      {'key': 'revenue', 'title': 'Revenue Analysis', 'icon': Icons.trending_up},
      {'key': 'expenses', 'title': 'Expense Analysis', 'icon': Icons.trending_down},
      {'key': 'cashflow', 'title': 'Cash Flow', 'icon': Icons.account_balance},
      {'key': 'forecast', 'title': 'Forecast Summary', 'icon': Icons.analytics},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: reportTypes.map((type) {
            final isSelected = _selectedReportType == type['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : null,
                    ),
                    const SizedBox(width: 4),
                    Text(type['title'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedReportType = type['key'] as String;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSelectedReport() {
    switch (_selectedReportType) {
      case 'overview':
        return _buildOverviewReport();
      case 'revenue':
        return _buildRevenueAnalysis();
      case 'expenses':
        return _buildExpenseAnalysis();
      case 'cashflow':
        return _buildCashFlowAnalysis();
      case 'forecast':
        return _buildForecastSummary();
      default:
        return _buildOverviewReport();
    }
  }

  Widget _buildOverviewReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFinancialSummaryCards(),
        const SizedBox(height: 24),
        _buildCombinedChart(),
        const SizedBox(height: 24),
        _buildKeyMetrics(),
        const SizedBox(height: 24),
        _buildTrendAnalysis(),
      ],
    );
  }

  Widget _buildFinancialSummaryCards() {
    final revenueData = _historicalData['revenue'] ?? [];
    final expenseData = _historicalData['expenses'] ?? [];
    final cashflowData = _historicalData['cashflow'] ?? [];

    final totalRevenue = revenueData.fold<double>(0, (sum, point) => sum + point.value);
    final totalExpenses = expenseData.fold<double>(0, (sum, point) => sum + point.value);
    final netCashFlow = cashflowData.fold<double>(0, (sum, point) => sum + point.value);
    final profit = totalRevenue - totalExpenses;

    final numberFormatter = NumberFormat.currency(symbol: '\$');

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          'Total Revenue',
          numberFormatter.format(totalRevenue),
          Icons.trending_up,
          Colors.green,
          _calculateGrowthRate(revenueData),
        ),
        _buildSummaryCard(
          'Total Expenses',
          numberFormatter.format(totalExpenses),
          Icons.trending_down,
          Colors.red,
          _calculateGrowthRate(expenseData),
        ),
        _buildSummaryCard(
          'Net Profit',
          numberFormatter.format(profit),
          profit >= 0 ? Icons.thumb_up : Icons.thumb_down,
          profit >= 0 ? Colors.green : Colors.red,
          null,
        ),
        _buildSummaryCard(
          'Cash Flow',
          numberFormatter.format(netCashFlow),
          Icons.account_balance,
          Colors.blue,
          _calculateGrowthRate(cashflowData),
        ),
      ],
    );
  }

  double? _calculateGrowthRate(List<TimeSeriesPoint> data) {
    if (data.length < 2) return null;
    
    final recent = data.length >= 2 ? data.skip(data.length - 2).toList() : data;
    if (recent.length < 2) return null;
    
    final change = recent.last.value - recent.first.value;
    return recent.first.value != 0 ? (change / recent.first.value) * 100 : 0;
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double? growthRate,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                if (growthRate != null) _buildGrowthIndicator(growthRate),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthIndicator(double growthRate) {
    final isPositive = growthRate >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${growthRate.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Overview',
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
                          final revenueData = _historicalData['revenue'] ?? [];
                          final index = value.toInt();
                          if (index >= 0 && index < revenueData.length) {
                            return Text(
                              DateFormat('MMM').format(revenueData[index].date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildCombinedChartLines(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  List<LineChartBarData> _buildCombinedChartLines() {
    final lines = <LineChartBarData>[];
    
    final colors = [Colors.green, Colors.red, Colors.blue];
    final sources = ['revenue', 'expenses', 'cashflow'];
    
    for (int i = 0; i < sources.length; i++) {
      final data = _historicalData[sources[i]];
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

  Widget _buildChartLegend() {
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

  Widget _buildKeyMetrics() {
    final revenueData = _historicalData['revenue'] ?? [];
    final expenseData = _historicalData['expenses'] ?? [];

    if (revenueData.isEmpty || expenseData.isEmpty) {
      return const SizedBox.shrink();
    }

    final avgRevenue = revenueData.map((d) => d.value).reduce((a, b) => a + b) / revenueData.length;
    final avgExpenses = expenseData.map((d) => d.value).reduce((a, b) => a + b) / expenseData.length;
    final profitMargin = avgRevenue > 0 ? ((avgRevenue - avgExpenses) / avgRevenue) * 100 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Performance Indicators',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildKPIItem(
                    'Average Monthly Revenue',
                    NumberFormat.currency(symbol: '\$').format(avgRevenue),
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildKPIItem(
                    'Average Monthly Expenses',
                    NumberFormat.currency(symbol: '\$').format(avgExpenses),
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildKPIItem(
                    'Profit Margin',
                    '${profitMargin.toStringAsFixed(1)}%',
                    Icons.percent,
                    profitMargin >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTrendAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trend Analysis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildTrendInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendInsights() {
    final insights = <Widget>[];

    // Revenue trend analysis
    final revenueData = _historicalData['revenue'] ?? [];
    if (revenueData.length >= 3) {
      final recentRevenue = revenueData.length >= 3 ? revenueData.skip(revenueData.length - 3).toList() : revenueData;
      final trend = _analyzeTrend(recentRevenue);
      insights.add(_buildTrendInsight(
        'Revenue Trend',
        trend,
        'Based on last 3 months',
        Colors.green,
      ));
    }

    // Expense trend analysis
    final expenseData = _historicalData['expenses'] ?? [];
    if (expenseData.length >= 3) {
      final recentExpenses = expenseData.length >= 3 ? expenseData.skip(expenseData.length - 3).toList() : expenseData;
      final trend = _analyzeTrend(recentExpenses);
      insights.add(_buildTrendInsight(
        'Expense Trend',
        trend,
        'Based on last 3 months',
        Colors.red,
      ));
    }

    return insights.isNotEmpty
        ? Column(children: insights)
        : const Text('Insufficient data for trend analysis');
  }

  String _analyzeTrend(List<TimeSeriesPoint> data) {
    if (data.length < 2) return 'Stable';

    final changes = <double>[];
    for (int i = 1; i < data.length; i++) {
      final change = data[i].value - data[i - 1].value;
      changes.add(change);
    }

    final avgChange = changes.reduce((a, b) => a + b) / changes.length;
    final threshold = data.first.value * 0.05; // 5% threshold

    if (avgChange > threshold) {
      return 'Increasing';
    } else if (avgChange < -threshold) {
      return 'Decreasing';
    } else {
      return 'Stable';
    }
  }

  Widget _buildTrendInsight(String title, String trend, String subtitle, Color color) {
    IconData icon;
    Color trendColor;

    switch (trend) {
      case 'Increasing':
        icon = Icons.trending_up;
        trendColor = Colors.green;
        break;
      case 'Decreasing':
        icon = Icons.trending_down;
        trendColor = Colors.red;
        break;
      default:
        icon = Icons.trending_flat;
        trendColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: trendColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '$trend - $subtitle',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Similar methods for other report types would go here...
  Widget _buildRevenueAnalysis() {
    return const Center(child: Text('Revenue Analysis - Coming Soon'));
  }

  Widget _buildExpenseAnalysis() {
    return const Center(child: Text('Expense Analysis - Coming Soon'));
  }

  Widget _buildCashFlowAnalysis() {
    return const Center(child: Text('Cash Flow Analysis - Coming Soon'));
  }

  Widget _buildForecastSummary() {
    return const Center(child: Text('Forecast Summary - Coming Soon'));
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      await _loadReportData();
    }
  }

  Future<void> _exportReport() async {
    // Implementation for exporting the current report
    _showSuccessSnackBar('Export functionality coming soon');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}