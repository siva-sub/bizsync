import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/forecasting_models.dart';
import '../services/forecasting_service.dart';
import '../services/forecast_export_service.dart';
import '../../../core/utils/uuid_generator.dart';

/// Revenue forecasting screen with model selection and configuration
class RevenueForecastingScreen extends ConsumerStatefulWidget {
  const RevenueForecastingScreen({super.key});

  @override
  ConsumerState<RevenueForecastingScreen> createState() => _RevenueForecastingScreenState();
}

class _RevenueForecastingScreenState extends ConsumerState<RevenueForecastingScreen> {
  late ForecastingService _forecastingService;
  late ForecastExportService _exportService;

  List<TimeSeriesPoint> _historicalData = [];
  ForecastSession? _currentSession;
  bool _isLoading = false;
  String? _error;

  // Configuration
  final _sessionNameController = TextEditingController();
  int _forecastHorizon = 12;
  Periodicity _periodicity = Periodicity.monthly;
  final List<ForecastScenario> _scenarios = [];

  // Chart key for export
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _sessionNameController.text = 'Revenue Forecast ${DateFormat('MMM yyyy').format(DateTime.now())}';
    _initializeServices();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      _forecastingService = await ForecastingService.getInstance();
      _exportService = ForecastExportService.getInstance();
      await _loadHistoricalData();
      _addDefaultScenarios();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _loadHistoricalData() async {
    try {
      setState(() => _isLoading = true);

      _historicalData = await _forecastingService.getHistoricalData(
        'revenue',
        startDate: DateTime.now().subtract(const Duration(days: 730)), // 2 years
        aggregation: _periodicity,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load historical data: $e';
        _isLoading = false;
      });
    }
  }

  void _addDefaultScenarios() {
    _scenarios.clear();
    
    // Linear regression scenario
    _scenarios.add(ForecastScenario(
      id: UuidGenerator.generateId(),
      name: 'Linear Trend',
      description: 'Simple linear trend analysis',
      method: ForecastingMethod.linearRegression,
      parameters: {},
      forecastHorizon: _forecastHorizon,
      periodicity: _periodicity,
    ));

    // Moving average scenario
    _scenarios.add(ForecastScenario(
      id: UuidGenerator.generateId(),
      name: 'Moving Average (3 months)',
      description: '3-month moving average',
      method: ForecastingMethod.movingAverage,
      parameters: {'window_size': 3},
      forecastHorizon: _forecastHorizon,
      periodicity: _periodicity,
    ));

    // Exponential smoothing scenario
    _scenarios.add(ForecastScenario(
      id: UuidGenerator.generateId(),
      name: 'Exponential Smoothing',
      description: 'Exponential smoothing with trend',
      method: ForecastingMethod.exponentialSmoothing,
      parameters: {'alpha': 0.3, 'beta': 0.3},
      forecastHorizon: _forecastHorizon,
      periodicity: _periodicity,
    ));

    // Seasonal decomposition scenario
    if (_historicalData.length >= 24) { // Need at least 2 years for seasonal
      _scenarios.add(ForecastScenario(
        id: UuidGenerator.generateId(),
        name: 'Seasonal Analysis',
        description: 'Seasonal decomposition forecasting',
        method: ForecastingMethod.seasonalDecomposition,
        parameters: {'seasonal_period': 12, 'multiplicative': false},
        forecastHorizon: _forecastHorizon,
        periodicity: _periodicity,
      ));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue Forecasting'),
        actions: [
          if (_currentSession != null) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportForecast,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
      floatingActionButton: _historicalData.isNotEmpty && _scenarios.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _currentSession == null ? _runForecast : _rerunForecast,
              icon: Icon(_currentSession == null ? Icons.play_arrow : Icons.refresh),
              label: Text(_currentSession == null ? 'Run Forecast' : 'Rerun'),
            )
          : null,
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
            'Error',
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
            onPressed: _initializeServices,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_historicalData.isEmpty) {
      return _buildNoDataState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigurationCard(),
          const SizedBox(height: 16),
          _buildHistoricalDataCard(),
          const SizedBox(height: 16),
          _buildScenariosCard(),
          if (_currentSession != null) ...[
            const SizedBox(height: 16),
            _buildResultsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Revenue Data Available',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'You need historical revenue data to create forecasts.\nCreate some invoices first.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forecast Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sessionNameController,
              decoration: const InputDecoration(
                labelText: 'Forecast Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Periodicity>(
                    value: _periodicity,
                    decoration: const InputDecoration(
                      labelText: 'Aggregation Period',
                      border: OutlineInputBorder(),
                    ),
                    items: Periodicity.values.map((period) {
                      return DropdownMenuItem(
                        value: period,
                        child: Text(period.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _periodicity = value;
                        });
                        _loadHistoricalData();
                        _addDefaultScenarios();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _forecastHorizon.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Forecast Periods',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final periods = int.tryParse(value);
                      if (periods != null && periods > 0 && periods <= 60) {
                        setState(() {
                          _forecastHorizon = periods;
                        });
                        _addDefaultScenarios();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalDataCard() {
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
                  'Historical Revenue Data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_historicalData.length} data points',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: RepaintBoundary(
                key: _chartKey,
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
                            final index = value.toInt();
                            if (index >= 0 && index < _historicalData.length) {
                              return Text(
                                DateFormat('MMM yy').format(_historicalData[index].date),
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: _historicalData.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value.value);
                        }).toList(),
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        dotData: FlDotData(show: _historicalData.length <= 24),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDataStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStatistics() {
    if (_historicalData.isEmpty) return const SizedBox.shrink();

    final values = _historicalData.map((d) => d.value).toList();
    final total = values.reduce((a, b) => a + b);
    final average = total / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    final numberFormatter = NumberFormat.currency(symbol: '\$');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Total', numberFormatter.format(total)),
        _buildStatItem('Average', numberFormatter.format(average)),
        _buildStatItem('Min', numberFormatter.format(min)),
        _buildStatItem('Max', numberFormatter.format(max)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildScenariosCard() {
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
                  'Forecasting Scenarios',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _addCustomScenario,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Custom'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _scenarios.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final scenario = _scenarios[index];
                return _buildScenarioTile(scenario, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioTile(ForecastScenario scenario, int index) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getScenarioColor(index),
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(scenario.name),
        subtitle: Text(scenario.description),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editScenario(scenario);
                break;
              case 'delete':
                _deleteScenario(scenario);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScenarioColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  Widget _buildResultsCard() {
    if (_currentSession == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forecast Results',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildForecastChart(),
            const SizedBox(height: 16),
            _buildAccuracyMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastChart() {
    if (_currentSession == null) return const SizedBox.shrink();

    return SizedBox(
      height: 400,
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
                  final index = value.toInt();
                  final totalHistorical = _historicalData.length;
                  
                  if (index < totalHistorical) {
                    return Text(
                      DateFormat('MMM yy').format(_historicalData[index].date),
                      style: const TextStyle(fontSize: 10),
                    );
                  } else {
                    // Forecast period
                    final forecastIndex = index - totalHistorical;
                    if (_currentSession!.results.values.isNotEmpty) {
                      final firstResults = _currentSession!.results.values.first;
                      if (forecastIndex < firstResults.length) {
                        return Text(
                          DateFormat('MMM yy').format(firstResults[forecastIndex].date),
                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                        );
                      }
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: _buildForecastChartData(),
        ),
      ),
    );
  }

  List<LineChartBarData> _buildForecastChartData() {
    final lines = <LineChartBarData>[];

    // Historical data line
    lines.add(
      LineChartBarData(
        spots: _historicalData.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value.value);
        }).toList(),
        isCurved: true,
        color: Colors.green,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    );

    // Forecast lines for each scenario
    for (int i = 0; i < _scenarios.length; i++) {
      final scenario = _scenarios[i];
      final results = _currentSession!.results[scenario.id];
      
      if (results != null && results.isNotEmpty) {
        final color = _getScenarioColor(i);
        final startIndex = _historicalData.length;
        
        lines.add(
          LineChartBarData(
            spots: results.asMap().entries.map((entry) {
              return FlSpot(
                (startIndex + entry.key).toDouble(),
                entry.value.predictedValue,
              );
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }

    return lines;
  }

  Widget _buildAccuracyMetrics() {
    if (_currentSession == null || _currentSession!.accuracyMetrics.isEmpty) {
      return const Text('No accuracy metrics available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Accuracy',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(),
          children: [
            const TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Model', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('R²', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('MAPE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('RMSE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ..._currentSession!.accuracyMetrics.entries.map((entry) {
              final scenario = _scenarios.firstWhere((s) => s.id == entry.key);
              final accuracy = entry.value;
              
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(scenario.name),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text((accuracy.r2 * 100).toStringAsFixed(1) + '%'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(accuracy.mape.toStringAsFixed(1) + '%'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(accuracy.rmse.toStringAsFixed(2)),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Future<void> _runForecast() async {
    if (_sessionNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a forecast name');
      return;
    }

    if (_scenarios.isEmpty) {
      _showErrorSnackBar('Please add at least one scenario');
      return;
    }

    try {
      setState(() => _isLoading = true);

      _currentSession = await _forecastingService.createForecastSession(
        name: _sessionNameController.text.trim(),
        dataSource: 'revenue',
        scenarios: _scenarios,
        aggregation: _periodicity,
      );

      setState(() => _isLoading = false);
      _showSuccessSnackBar('Forecast completed successfully');
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to run forecast: $e');
    }
  }

  Future<void> _rerunForecast() async {
    _currentSession = null;
    await _runForecast();
  }

  Future<void> _exportForecast() async {
    if (_currentSession == null) return;

    try {
      _showLoadingDialog('Exporting forecast...');
      
      // Capture chart image
      final chartImage = await _exportService.captureWidgetAsImage(_chartKey);
      
      final file = await _exportService.exportToPdf(
        _currentSession!,
        includeCharts: true,
        chartImages: [chartImage],
      );
      
      Navigator.of(context).pop();
      await _exportService.shareFile(file, 'Revenue Forecast: ${_currentSession!.name}');
      _showSuccessSnackBar('Forecast exported successfully');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Failed to export forecast: $e');
    }
  }

  void _addCustomScenario() {
    showDialog(
      context: context,
      builder: (context) => _CustomScenarioDialog(
        onScenarioCreated: (scenario) {
          setState(() {
            _scenarios.add(scenario);
          });
        },
        forecastHorizon: _forecastHorizon,
        periodicity: _periodicity,
      ),
    );
  }

  void _editScenario(ForecastScenario scenario) {
    showDialog(
      context: context,
      builder: (context) => _CustomScenarioDialog(
        scenario: scenario,
        onScenarioCreated: (updatedScenario) {
          setState(() {
            final index = _scenarios.indexOf(scenario);
            _scenarios[index] = updatedScenario;
          });
        },
        forecastHorizon: _forecastHorizon,
        periodicity: _periodicity,
      ),
    );
  }

  void _deleteScenario(ForecastScenario scenario) {
    setState(() {
      _scenarios.remove(scenario);
    });
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revenue Forecasting Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use Revenue Forecasting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Configure your forecast period and aggregation'),
              Text('2. Review your historical revenue data'),
              Text('3. Add or modify forecasting scenarios'),
              Text('4. Run the forecast to see predictions'),
              Text('5. Export results as PDF or Excel'),
              SizedBox(height: 16),
              Text(
                'Forecasting Methods:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Linear Regression: Best for trending data'),
              Text('• Moving Average: Good for stable patterns'),
              Text('• Exponential Smoothing: Emphasizes recent data'),
              Text('• Seasonal Decomposition: Captures seasonal patterns'),
            ],
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
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

/// Dialog for creating custom forecast scenarios
class _CustomScenarioDialog extends StatefulWidget {
  final ForecastScenario? scenario;
  final Function(ForecastScenario) onScenarioCreated;
  final int forecastHorizon;
  final Periodicity periodicity;

  const _CustomScenarioDialog({
    this.scenario,
    required this.onScenarioCreated,
    required this.forecastHorizon,
    required this.periodicity,
  });

  @override
  State<_CustomScenarioDialog> createState() => _CustomScenarioDialogState();
}

class _CustomScenarioDialogState extends State<_CustomScenarioDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ForecastingMethod _selectedMethod = ForecastingMethod.linearRegression;
  final Map<String, dynamic> _parameters = {};

  @override
  void initState() {
    super.initState();
    
    if (widget.scenario != null) {
      _nameController.text = widget.scenario!.name;
      _descriptionController.text = widget.scenario!.description;
      _selectedMethod = widget.scenario!.method;
      _parameters.addAll(widget.scenario!.parameters);
    } else {
      _setDefaultParameters();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _setDefaultParameters() {
    switch (_selectedMethod) {
      case ForecastingMethod.movingAverage:
        _parameters['window_size'] = 3;
        break;
      case ForecastingMethod.exponentialSmoothing:
        _parameters['alpha'] = 0.3;
        _parameters['beta'] = 0.3;
        break;
      case ForecastingMethod.seasonalDecomposition:
        _parameters['seasonal_period'] = 12;
        _parameters['multiplicative'] = false;
        break;
      default:
        _parameters.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.scenario != null ? 'Edit Scenario' : 'Create Custom Scenario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Scenario Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ForecastingMethod>(
              value: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Forecasting Method',
                border: OutlineInputBorder(),
              ),
              items: ForecastingMethod.values.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMethod = value;
                    _setDefaultParameters();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            _buildParametersSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveScenario,
          child: Text(widget.scenario != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildParametersSection() {
    switch (_selectedMethod) {
      case ForecastingMethod.movingAverage:
        return TextFormField(
          initialValue: _parameters['window_size']?.toString() ?? '3',
          decoration: const InputDecoration(
            labelText: 'Window Size',
            border: OutlineInputBorder(),
            helperText: 'Number of periods to average',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final windowSize = int.tryParse(value);
            if (windowSize != null && windowSize > 0) {
              _parameters['window_size'] = windowSize;
            }
          },
        );
      
      case ForecastingMethod.exponentialSmoothing:
        return Column(
          children: [
            TextFormField(
              initialValue: _parameters['alpha']?.toString() ?? '0.3',
              decoration: const InputDecoration(
                labelText: 'Alpha (Level Smoothing)',
                border: OutlineInputBorder(),
                helperText: 'Value between 0 and 1',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final alpha = double.tryParse(value);
                if (alpha != null && alpha > 0 && alpha <= 1) {
                  _parameters['alpha'] = alpha;
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _parameters['beta']?.toString() ?? '0.3',
              decoration: const InputDecoration(
                labelText: 'Beta (Trend Smoothing)',
                border: OutlineInputBorder(),
                helperText: 'Value between 0 and 1',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final beta = double.tryParse(value);
                if (beta != null && beta > 0 && beta <= 1) {
                  _parameters['beta'] = beta;
                }
              },
            ),
          ],
        );
      
      case ForecastingMethod.seasonalDecomposition:
        return Column(
          children: [
            TextFormField(
              initialValue: _parameters['seasonal_period']?.toString() ?? '12',
              decoration: const InputDecoration(
                labelText: 'Seasonal Period',
                border: OutlineInputBorder(),
                helperText: 'Number of periods in a season',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final period = int.tryParse(value);
                if (period != null && period > 1) {
                  _parameters['seasonal_period'] = period;
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Multiplicative Seasonality'),
              subtitle: const Text('Use multiplicative instead of additive'),
              value: _parameters['multiplicative'] ?? false,
              onChanged: (value) {
                setState(() {
                  _parameters['multiplicative'] = value;
                });
              },
            ),
          ],
        );
      
      default:
        return const Text('No parameters required for this method');
    }
  }

  void _saveScenario() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a scenario name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final scenario = ForecastScenario(
      id: widget.scenario?.id ?? UuidGenerator.generateId(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      method: _selectedMethod,
      parameters: Map.from(_parameters),
      forecastHorizon: widget.forecastHorizon,
      periodicity: widget.periodicity,
    );

    widget.onScenarioCreated(scenario);
    Navigator.of(context).pop();
  }
}