import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../widgets/chart_widgets.dart';
import '../providers/dashboard_providers.dart';

class CashFlowScreen extends ConsumerStatefulWidget {
  const CashFlowScreen({super.key});

  @override
  ConsumerState<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends ConsumerState<CashFlowScreen> {
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;

  @override
  Widget build(BuildContext context) {
    final cashFlowData = ref.watch(cashFlowDataProvider(_selectedPeriod));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow Analysis'),
        actions: [
          _buildPeriodSelector(),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportData(),
          ),
        ],
      ),
      body: cashFlowData.when(
        data: (data) => data != null 
            ? _buildContent(data)
            : _buildNoDataState(),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildContent(CashFlowData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cash flow summary cards
          _buildSummaryCards(data),
          
          const SizedBox(height: 24),
          
          // Daily cash flow chart
          InteractiveLineChart(
            data: data.dailyCashFlow,
            title: 'Daily Cash Flow',
            subtitle: 'Net cash flow over time',
            lineColor: data.netCashFlow >= 0 ? Colors.green : Colors.red,
            height: 350,
          ),
          
          const SizedBox(height: 24),
          
          // Inflow vs Outflow comparison
          _buildInflowOutflowCharts(data),
          
          const SizedBox(height: 24),
          
          // Cash flow forecasts
          if (data.forecasts.isNotEmpty)
            _buildForecastSection(data.forecasts),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(CashFlowData data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          'Net Cash Flow',
          data.netCashFlow,
          data.netCashFlow >= 0 ? Icons.trending_up : Icons.trending_down,
          data.netCashFlow >= 0 ? Colors.green : Colors.red,
        ),
        _buildSummaryCard(
          'Total Inflow',
          data.totalInflow,
          Icons.arrow_downward,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Total Outflow',
          data.totalOutflow,
          Icons.arrow_upward,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Closing Balance',
          data.closingBalance,
          Icons.account_balance,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double value, IconData icon, Color color) {
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
              _formatCurrency(value),
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

  Widget _buildInflowOutflowCharts(CashFlowData data) {
    return Row(
      children: [
        Expanded(
          child: InteractivePieChart(
            data: data.inflowByCategory.entries
                .map((entry) => DataPoint(
                      timestamp: DateTime.now(),
                      value: entry.value,
                      label: entry.key,
                    ))
                .toList(),
            title: 'Inflow by Category',
            height: 300,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InteractivePieChart(
            data: data.outflowByCategory.entries
                .map((entry) => DataPoint(
                      timestamp: DateTime.now(),
                      value: entry.value,
                      label: entry.key,
                    ))
                .toList(),
            title: 'Outflow by Category',
            height: 300,
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSection(List<CashFlowForecast> forecasts) {
    final forecastData = forecasts.map((forecast) => DataPoint(
          timestamp: forecast.date,
          value: forecast.predictedBalance,
          label: 'Forecast',
        )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cash Flow Forecast',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        InteractiveLineChart(
          data: forecastData,
          title: 'Predicted Cash Balance',
          subtitle: '30-day forecast',
          lineColor: Colors.purple,
          height: 300,
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
          Text('Loading cash flow data...'),
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
            'Failed to load cash flow data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(cashFlowDataProvider(_selectedPeriod));
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
            Icons.account_balance_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Cash Flow Data Available',
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

  String _formatCurrency(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    
    String formatted = '\$';
    if (absValue >= 1000000) {
      formatted += '${(absValue / 1000000).toStringAsFixed(1)}M';
    } else if (absValue >= 1000) {
      formatted += '${(absValue / 1000).toStringAsFixed(1)}K';
    } else {
      formatted += absValue.toStringAsFixed(0);
    }
    
    return isNegative ? '-$formatted' : formatted;
  }

  void _exportData() {
    // Implementation for export functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Cash Flow Data'),
        content: const Text('Export functionality will be implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}