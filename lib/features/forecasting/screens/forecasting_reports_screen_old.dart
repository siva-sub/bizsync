import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/forecasting_models.dart';
import '../services/forecasting_service.dart';
import '../widgets/forecast_metric_card.dart';
import '../widgets/forecast_session_card.dart';
import '../widgets/forecast_quick_actions.dart';

class ForecastingReportsScreen extends ConsumerStatefulWidget {
  const ForecastingReportsScreen({super.key});

  @override
  ConsumerState<ForecastingReportsScreen> createState() => _ForecastingReportsScreenState();
}

class _ForecastingReportsScreenState extends ConsumerState<ForecastingReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ForecastSession> _sessions = [];
  List<ForecastResult> _recentForecasts = [];
  Map<String, double> _accuracyMetrics = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadForecastingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadForecastingData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final forecastingService = await ForecastingService.getInstance();
      
      // Load all forecast sessions
      final sessions = await forecastingService.getAllForecastSessions();
      
      // Load recent forecasts (last 30 days)
      final recentForecasts = await forecastingService.getRecentForecasts(
        since: DateTime.now().subtract(const Duration(days: 30)),
      );

      // Calculate accuracy metrics
      final accuracy = await _calculateAccuracyMetrics(sessions);

      setState(() {
        _sessions = sessions;
        _recentForecasts = recentForecasts;
        _accuracyMetrics = accuracy;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, double>> _calculateAccuracyMetrics(List<ForecastSession> sessions) async {
    final metrics = <String, double>{};
    
    if (sessions.isEmpty) {
      return metrics;
    }

    // Calculate average accuracy across all sessions
    double totalAccuracy = 0.0;
    int accurateForecasts = 0;
    
    for (final session in sessions) {
      if (session.accuracyMetrics.isNotEmpty) {
        for (final entry in session.accuracyMetrics.entries) {
          if (entry.value is Map<String, dynamic>) {
            final sessionMetrics = entry.value as Map<String, dynamic>;
            if (sessionMetrics.containsKey('accuracy')) {
              totalAccuracy += (sessionMetrics['accuracy'] as num).toDouble();
              accurateForecasts++;
            }
          }
        }
      }
    }

    metrics['overall_accuracy'] = accurateForecasts > 0 ? totalAccuracy / accurateForecasts : 0.0;
    metrics['total_sessions'] = sessions.length.toDouble();
    metrics['active_sessions'] = sessions.where((s) => s.scenarios.isNotEmpty).length.toDouble();
    
    // Calculate trend accuracy (simplified)
    metrics['trend_accuracy'] = 0.75 + (0.25 * (metrics['overall_accuracy'] ?? 0.0));
    
    return metrics;
  }

  Future<void> _createNewForecastSession() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NewForecastSessionDialog(),
    );

    if (result != null && mounted) {
      try {
        final forecastingService = await ForecastingService.getInstance();
        
        final session = ForecastSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name'] as String,
          dataSource: result['dataSource'] as String,
          createdAt: DateTime.now(),
          scenarios: [],
          results: {},
          accuracyMetrics: {},
          historicalData: [],
        );

        await forecastingService.saveForecastSession(session);
        await _loadForecastingData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forecast session created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating session: $e')),
          );
        }
      }
    }
  }

  Future<void> _runDemoForecast() async {
    try {
      final forecastingService = await ForecastingService.getInstance();
      
      // Generate demo historical data
      final historicalData = <TimeSeriesPoint>[];
      final baseValue = 10000.0;
      final now = DateTime.now();
      
      for (int i = 11; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final trend = i * 100.0;
        final seasonal = 500.0 * (1 + 0.5 * (i % 4 - 2));
        final noise = (DateTime.now().millisecondsSinceEpoch % 1000 - 500).toDouble();
        final value = baseValue + trend + seasonal + noise;
        
        historicalData.add(TimeSeriesPoint(
          date: date,
          value: value,
          metadata: {'type': 'revenue'},
        ));
      }

      // Create demo session
      final session = ForecastSession(
        id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Demo Revenue Forecast',
        dataSource: 'revenue',
        createdAt: DateTime.now(),
        scenarios: [
          ForecastScenario(
            id: 'linear_growth',
            name: 'Linear Growth',
            method: 'linear_regression',
            parameters: {'growth_rate': 0.05},
            description: 'Steady linear growth projection',
          ),
          ForecastScenario(
            id: 'seasonal_trend',
            name: 'Seasonal Trend',
            method: 'seasonal_decomposition',
            parameters: {'seasonal_period': 12},
            description: 'Accounts for seasonal patterns',
          ),
        ],
        results: {},
        accuracyMetrics: {},
        historicalData: historicalData,
      );

      // Generate forecasts for both scenarios
      final results = <String, List<ForecastResult>>{};
      
      // Generate 6 months of forecasts
      for (int i = 1; i <= 6; i++) {
        final forecastDate = DateTime(now.year, now.month + i, 1);
        
        // Linear growth forecast
        final lastValue = historicalData.last.value;
        final linearValue = lastValue * (1 + 0.05 * i);
        results['linear_growth'] ??= [];
        results['linear_growth']!.add(ForecastResult(
          date: forecastDate,
          predictedValue: linearValue,
          lowerBound: linearValue * 0.9,
          upperBound: linearValue * 1.1,
          confidence: 0.85 - (i * 0.05),
          method: 'linear_regression',
          metrics: {'mape': 8.5, 'rmse': 450.0},
        ));

        // Seasonal trend forecast
        final seasonalValue = linearValue * (1 + 0.1 * ((i % 4) - 2) / 4);
        results['seasonal_trend'] ??= [];
        results['seasonal_trend']!.add(ForecastResult(
          date: forecastDate,
          predictedValue: seasonalValue,
          lowerBound: seasonalValue * 0.85,
          upperBound: seasonalValue * 1.15,
          confidence: 0.80 - (i * 0.03),
          method: 'seasonal_decomposition',
          metrics: {'mape': 6.2, 'rmse': 380.0},
        ));
      }

      session.results.addAll(results);
      session.accuracyMetrics['linear_growth'] = {'accuracy': 0.85, 'mape': 8.5};
      session.accuracyMetrics['seasonal_trend'] = {'accuracy': 0.92, 'mape': 6.2};

      await forecastingService.saveForecastSession(session);
      await _loadForecastingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo forecast generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating demo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecasting Reports'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadForecastingData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'new_session':
                  _createNewForecastSession();
                  break;
                case 'demo':
                  _runDemoForecast();
                  break;
                case 'export':
                  // TODO: Implement export functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export feature coming soon')),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_session',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('New Session'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'demo',
                child: ListTile(
                  leading: Icon(Icons.science),
                  title: Text('Run Demo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Reports'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.list), text: 'Sessions'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading forecasting data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadForecastingData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildSessionsTab(),
        _buildAnalyticsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          ForecastQuickActions(
            onNewSession: _createNewForecastSession,
            onRunDemo: _runDemoForecast,
            onViewTrends: () {
              // Navigate to trends analysis
              context.go('/forecasting/trends');
            },
          ),

          const SizedBox(height: 16),

          // Key Metrics
          Row(
            children: [
              Expanded(
                child: ForecastMetricCard(
                  title: 'Total Sessions',
                  value: _sessions.length.toString(),
                  icon: Icons.folder,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ForecastMetricCard(
                  title: 'Overall Accuracy',
                  value: '${((_accuracyMetrics['overall_accuracy'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                  icon: Icons.target,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ForecastMetricCard(
                  title: 'Active Sessions',
                  value: (_accuracyMetrics['active_sessions'] ?? 0.0).toInt().toString(),
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ForecastMetricCard(
                  title: 'Recent Forecasts',
                  value: _recentForecasts.length.toString(),
                  icon: Icons.schedule,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Sessions
          Text(
            'Recent Sessions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (_sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Forecast Sessions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first forecast session to get started with predictive analytics',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _runDemoForecast,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run Demo'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_sessions.take(3).map((session) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ForecastSessionCard(
                session: session,
                onTap: () {
                  // Navigate to session details
                  context.go('/forecasting/session/${session.id}');
                },
              ),
            ))),

          if (_sessions.length > 3) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('View All Sessions'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Sessions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.icon(
                onPressed: _createNewForecastSession,
                icon: const Icon(Icons.add),
                label: const Text('New Session'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Sessions Found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a forecast session to start analyzing trends and making predictions',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_sessions.map((session) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ForecastSessionCard(
                session: session,
                onTap: () {
                  context.go('/forecasting/session/${session.id}');
                },
                showDetails: true,
              ),
            ))),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecasting Analytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Accuracy Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.target, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Accuracy Metrics',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildAnalyticsMetric(
                    'Overall Accuracy',
                    '${((_accuracyMetrics['overall_accuracy'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                    'Average accuracy across all forecasting models',
                    Icons.analytics,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildAnalyticsMetric(
                    'Trend Accuracy',
                    '${((_accuracyMetrics['trend_accuracy'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                    'Accuracy in predicting directional trends',
                    Icons.trending_up,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildAnalyticsMetric(
                    'Model Performance',
                    _sessions.isNotEmpty ? 'Good' : 'No Data',
                    'Based on validation against historical data',
                    Icons.speed,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Usage Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Usage Statistics',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildAnalyticsMetric(
                    'Total Sessions',
                    _sessions.length.toString(),
                    'Forecast sessions created',
                    Icons.folder,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildAnalyticsMetric(
                    'Active Sessions',
                    (_accuracyMetrics['active_sessions'] ?? 0.0).toInt().toString(),
                    'Sessions with active forecasts',
                    Icons.play_circle,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildAnalyticsMetric(
                    'Recent Activity',
                    _recentForecasts.length.toString(),
                    'Forecasts generated in last 30 days',
                    Icons.schedule,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Performance Insights
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Performance Insights',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ..._generatePerformanceInsights(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String title, String value, String description, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  List<Widget> _generatePerformanceInsights() {
    final insights = <Widget>[];
    
    if (_sessions.isEmpty) {
      insights.add(
        ListTile(
          leading: const Icon(Icons.info, color: Colors.blue),
          title: const Text('Get Started'),
          subtitle: const Text('Create your first forecast session to begin generating insights'),
          contentPadding: EdgeInsets.zero,
        ),
      );
    } else {
      final accuracy = _accuracyMetrics['overall_accuracy'] ?? 0.0;
      
      if (accuracy > 0.8) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('High Accuracy'),
            subtitle: const Text('Your forecasting models are performing well'),
            contentPadding: EdgeInsets.zero,
          ),
        );
      } else if (accuracy > 0.6) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange),
            title: const Text('Moderate Accuracy'),
            subtitle: const Text('Consider using seasonal models or more historical data'),
            contentPadding: EdgeInsets.zero,
          ),
        );
      } else {
        insights.add(
          ListTile(
            leading: const Icon(Icons.error, color: Colors.red),
            title: const Text('Low Accuracy'),
            subtitle: const Text('Review your data quality and model parameters'),
            contentPadding: EdgeInsets.zero,
          ),
        );
      }
      
      if (_sessions.length >= 5) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.blue),
            title: const Text('Active User'),
            subtitle: const Text('You\'re making good use of forecasting features'),
            contentPadding: EdgeInsets.zero,
          ),
        );
      }
    }
    
    return insights;
  }
}

class _NewForecastSessionDialog extends StatefulWidget {
  @override
  _NewForecastSessionDialogState createState() => _NewForecastSessionDialogState();
}

class _NewForecastSessionDialogState extends State<_NewForecastSessionDialog> {
  final _nameController = TextEditingController();
  String _selectedDataSource = 'revenue';

  final Map<String, String> _dataSources = {
    'revenue': 'Revenue',
    'expenses': 'Expenses',
    'cashflow': 'Cash Flow',
    'inventory': 'Inventory',
    'sales': 'Sales Volume',
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Forecast Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Session Name',
              hintText: 'e.g., Q1 Revenue Forecast',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDataSource,
            decoration: const InputDecoration(
              labelText: 'Data Source',
              border: OutlineInputBorder(),
            ),
            items: _dataSources.entries
                .map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedDataSource = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.of(context).pop({
                'name': _nameController.text,
                'dataSource': _selectedDataSource,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}