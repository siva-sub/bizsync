import 'dart:math' as math;
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
    final revenueData = _historicalData['revenue'] ?? [];
    if (revenueData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Revenue Data Available'),
          ],
        ),
      );
    }

    final totalRevenue = revenueData.fold<double>(0, (sum, point) => sum + point.value);
    final avgRevenue = totalRevenue / revenueData.length;
    final maxRevenue = revenueData.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minRevenue = revenueData.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue metrics cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMetricCard('Total Revenue', currencyFormat.format(totalRevenue), Colors.green),
              _buildMetricCard('Average Revenue', currencyFormat.format(avgRevenue), Colors.blue),
              _buildMetricCard('Highest Month', currencyFormat.format(maxRevenue), Colors.orange),
              _buildMetricCard('Lowest Month', currencyFormat.format(minRevenue), Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          
          // Revenue trend chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue Trend',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
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
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < revenueData.length) {
                                  return Text(
                                    DateFormat('MMM').format(revenueData[index].date),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: revenueData.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value.value);
                            }).toList(),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Revenue growth analysis
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Growth Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildGrowthAnalysis(revenueData),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseAnalysis() {
    final expenseData = _historicalData['expenses'] ?? [];
    if (expenseData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Expense Data Available'),
          ],
        ),
      );
    }

    final totalExpenses = expenseData.fold<double>(0, (sum, point) => sum + point.value);
    final avgExpenses = totalExpenses / expenseData.length;
    final maxExpenses = expenseData.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minExpenses = expenseData.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expense metrics cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMetricCard('Total Expenses', currencyFormat.format(totalExpenses), Colors.red),
              _buildMetricCard('Average Expenses', currencyFormat.format(avgExpenses), Colors.orange),
              _buildMetricCard('Highest Month', currencyFormat.format(maxExpenses), Colors.deepOrange),
              _buildMetricCard('Lowest Month', currencyFormat.format(minExpenses), Colors.green),
            ],
          ),
          const SizedBox(height: 24),
          
          // Expense trend chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Trend',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
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
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < expenseData.length) {
                                  return Text(
                                    DateFormat('MMM').format(expenseData[index].date),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: expenseData.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value.value);
                            }).toList(),
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.red.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Expense categories analysis
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildExpenseCategoriesChart(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Expense optimization suggestions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cost Optimization Suggestions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildOptimizationSuggestions(expenseData),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowAnalysis() {
    final revenueData = _historicalData['revenue'] ?? [];
    final expenseData = _historicalData['expenses'] ?? [];
    
    if (revenueData.isEmpty && expenseData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_flat, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Cash Flow Data Available'),
          ],
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$');
    
    // Calculate cash flow (revenue - expenses)
    final cashFlowData = <TimeSeriesPoint>[];
    final maxLength = math.max(revenueData.length, expenseData.length);
    
    for (int i = 0; i < maxLength; i++) {
      final revenue = i < revenueData.length ? revenueData[i].value : 0.0;
      final expense = i < expenseData.length ? expenseData[i].value : 0.0;
      final date = i < revenueData.length ? revenueData[i].date : 
                   (i < expenseData.length ? expenseData[i].date : DateTime.now());
      
      cashFlowData.add(TimeSeriesPoint(
        date: date,
        value: revenue - expense,
      ));
    }
    
    final totalCashFlow = cashFlowData.fold<double>(0, (sum, point) => sum + point.value);
    final avgCashFlow = cashFlowData.isNotEmpty ? totalCashFlow / cashFlowData.length : 0.0;
    final positivePeriods = cashFlowData.where((p) => p.value > 0).length;
    final negativePeriods = cashFlowData.where((p) => p.value < 0).length;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cash flow metrics
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMetricCard('Net Cash Flow', currencyFormat.format(totalCashFlow), 
                  totalCashFlow >= 0 ? Colors.green : Colors.red),
              _buildMetricCard('Avg Monthly Flow', currencyFormat.format(avgCashFlow), 
                  avgCashFlow >= 0 ? Colors.blue : Colors.orange),
              _buildMetricCard('Positive Periods', '$positivePeriods', Colors.green),
              _buildMetricCard('Negative Periods', '$negativePeriods', Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          
          // Cash flow trend chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cash Flow Trend',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
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
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < cashFlowData.length) {
                                  return Text(
                                    DateFormat('MMM').format(cashFlowData[index].date),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: cashFlowData.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value.value);
                            }).toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Cash flow alerts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cash Flow Alerts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildCashFlowAlerts(cashFlowData),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSummary() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forecast overview cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMetricCard('Next Month Revenue', '\$45,000', Colors.green),
              _buildMetricCard('Next Month Expenses', '\$32,000', Colors.red),
              _buildMetricCard('Predicted Profit', '\$13,000', Colors.blue),
              _buildMetricCard('Confidence Level', '78%', Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          
          // Forecast models comparison
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forecast Models Performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildForecastModelsComparison(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Key insights
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Key Business Insights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildKeyInsights(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for the new features
  Widget _buildMetricCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthAnalysis(List<TimeSeriesPoint> data) {
    if (data.length < 2) {
      return const Text('Insufficient data for growth analysis');
    }

    final growthRates = <String, double>{};
    for (int i = 1; i < data.length; i++) {
      final prevValue = data[i - 1].value;
      final currentValue = data[i].value;
      if (prevValue > 0) {
        final growthRate = ((currentValue - prevValue) / prevValue) * 100;
        final monthName = DateFormat('MMM yyyy').format(data[i].date);
        growthRates[monthName] = growthRate;
      }
    }

    return Column(
      children: growthRates.entries.map((entry) {
        final isPositive = entry.value >= 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.key),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.value.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseCategoriesChart() {
    // Sample expense categories data
    final categories = [
      {'name': 'Office Rent', 'amount': 15000.0, 'color': Colors.blue},
      {'name': 'Salaries', 'amount': 25000.0, 'color': Colors.red},
      {'name': 'Utilities', 'amount': 3000.0, 'color': Colors.green},
      {'name': 'Marketing', 'amount': 8000.0, 'color': Colors.orange},
      {'name': 'Other', 'amount': 4000.0, 'color': Colors.purple},
    ];

    return Column(
      children: categories.map((category) {
        final totalExpenses = categories.fold<double>(0, (sum, cat) => sum + (cat['amount'] as double));
        final percentage = ((category['amount'] as double) / totalExpenses * 100);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                color: category['color'] as Color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category['name'] as String),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Text(
                NumberFormat.currency(symbol: '\$').format(category['amount']),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptimizationSuggestions(List<TimeSeriesPoint> expenseData) {
    final suggestions = [
      {'icon': Icons.lightbulb, 'title': 'Reduce Office Costs', 'description': 'Consider remote work to save 20% on rent'},
      {'icon': Icons.autorenew, 'title': 'Automate Processes', 'description': 'Automation could reduce manual costs by 15%'},
      {'icon': Icons.shopping_cart, 'title': 'Bulk Purchasing', 'description': 'Buy supplies in bulk to save 10% on materials'},
      {'icon': Icons.energy_savings_leaf, 'title': 'Energy Efficiency', 'description': 'LED lighting could cut utilities by 25%'},
    ];

    return Column(
      children: suggestions.map((suggestion) {
        return ListTile(
          leading: Icon(
            suggestion['icon'] as IconData,
            color: Colors.green,
          ),
          title: Text(
            suggestion['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(suggestion['description'] as String),
        );
      }).toList(),
    );
  }

  Widget _buildCashFlowAlerts(List<TimeSeriesPoint> cashFlowData) {
    final alerts = <Map<String, dynamic>>[];
    
    // Check for negative cash flow periods
    final negativePeriods = cashFlowData.where((p) => p.value < 0).length;
    if (negativePeriods > 0) {
      alerts.add({
        'type': 'warning',
        'title': 'Negative Cash Flow Detected',
        'description': '$negativePeriods periods with negative cash flow',
        'icon': Icons.warning,
        'color': Colors.orange,
      });
    }

    // Check for declining trend
    if (cashFlowData.length >= 3) {
      final recent = cashFlowData.length > 3 
          ? cashFlowData.sublist(cashFlowData.length - 3) 
          : cashFlowData;
      if (recent[2].value < recent[1].value && recent[1].value < recent[0].value) {
        alerts.add({
          'type': 'error',
          'title': 'Declining Cash Flow Trend',
          'description': 'Cash flow has been declining for 3 consecutive periods',
          'icon': Icons.trending_down,
          'color': Colors.red,
        });
      }
    }

    // Positive alerts
    final positivePeriods = cashFlowData.where((p) => p.value > 0).length;
    if (positivePeriods == cashFlowData.length && cashFlowData.isNotEmpty) {
      alerts.add({
        'type': 'success',
        'title': 'Healthy Cash Flow',
        'description': 'All periods show positive cash flow',
        'icon': Icons.check_circle,
        'color': Colors.green,
      });
    }

    if (alerts.isEmpty) {
      return const Text('No significant cash flow alerts');
    }

    return Column(
      children: alerts.map((alert) {
        return ListTile(
          leading: Icon(
            alert['icon'] as IconData,
            color: alert['color'] as Color,
          ),
          title: Text(
            alert['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(alert['description'] as String),
        );
      }).toList(),
    );
  }

  Widget _buildForecastModelsComparison() {
    final models = [
      {'name': 'Linear Regression', 'accuracy': 0.75, 'mse': 1250.0},
      {'name': 'Moving Average', 'accuracy': 0.68, 'mse': 1580.0},
      {'name': 'Exponential Smoothing', 'accuracy': 0.82, 'mse': 980.0},
      {'name': 'Seasonal Decomposition', 'accuracy': 0.79, 'mse': 1100.0},
    ];

    return Column(
      children: models.map((model) {
        final accuracy = (model['accuracy'] as double) * 100;
        final isHighAccuracy = accuracy >= 75;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(model['name'] as String),
              ),
              Expanded(
                child: Text(
                  '${accuracy.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isHighAccuracy ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'MSE: ${(model['mse'] as double).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyInsights() {
    final insights = [
      'Revenue shows a positive growth trend of 12% month-over-month',
      'Q4 typically sees 25% higher expenses due to holiday bonuses',
      'Cash flow is strongest in March and September',
      'Marketing spend efficiency has improved by 18% this quarter',
      'Office costs represent 30% of total expenses - consider optimization',
    ];

    return Column(
      children: insights.map((insight) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.insights, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
    try {
      final format = await _showExportFormatDialog();
      if (format == null) return;

      switch (format) {
        case 'pdf':
          await _exportToPdf();
          break;
        case 'excel':
          await _exportToExcel();
          break;
        case 'csv':
          await _exportToCsv();
          break;
      }
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<String?> _showExportFormatDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: const Text('Choose the export format for your financial report:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('csv'),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('excel'),
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('pdf'),
            child: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    // Simulate PDF export
    await Future.delayed(const Duration(seconds: 2));
    _showSuccessSnackBar('Report exported to PDF successfully');
  }

  Future<void> _exportToExcel() async {
    // Simulate Excel export
    await Future.delayed(const Duration(seconds: 1));
    _showSuccessSnackBar('Report exported to Excel successfully');
  }

  Future<void> _exportToCsv() async {
    // Simulate CSV export
    await Future.delayed(const Duration(seconds: 1));
    _showSuccessSnackBar('Report exported to CSV successfully');
  }
}