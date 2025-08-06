import 'dart:convert';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import '../../../core/storage/enhanced_database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../models/forecasting_models.dart';
import '../algorithms/linear_regression_model.dart';
import '../algorithms/moving_average_model.dart';
import '../algorithms/exponential_smoothing_model.dart';
import '../algorithms/seasonal_decomposition_model.dart';

/// Main forecasting service that coordinates all forecasting operations
class ForecastingService {
  static ForecastingService? _instance;
  EnhancedDatabaseService? _databaseService;

  ForecastingService._internal();

  static Future<ForecastingService> getInstance() async {
    if (_instance == null) {
      _instance = ForecastingService._internal();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    try {
      _databaseService = await EnhancedDatabaseService.getInstance();
      await _createForecastingTables();
    } catch (e) {
      print('Error initializing ForecastingService: $e');
      throw Exception('Failed to initialize ForecastingService: $e');
    }
  }

  /// Get the database service, initializing if needed
  Future<EnhancedDatabaseService> get databaseService async {
    if (_databaseService == null) {
      await _initialize();
    }
    return _databaseService!;
  }

  Future<void> _createForecastingTables() async {
    final dbService = await databaseService;
    final db = await dbService.database;

    // Create forecast sessions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS forecast_sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        data_source TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_modified INTEGER,
        scenarios TEXT, -- JSON array of scenarios
        results TEXT, -- JSON map of scenario_id -> results
        accuracy_metrics TEXT, -- JSON map of scenario_id -> accuracy
        historical_data TEXT, -- JSON array of historical data points
        metadata TEXT -- Additional metadata
      )
    ''');

    // Create forecast results table (denormalized for faster queries)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS forecast_results (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        scenario_id TEXT NOT NULL,
        forecast_date INTEGER NOT NULL,
        predicted_value REAL NOT NULL,
        lower_bound REAL NOT NULL,
        upper_bound REAL NOT NULL,
        confidence REAL NOT NULL,
        method TEXT NOT NULL,
        metrics TEXT, -- JSON
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES forecast_sessions (id)
      )
    ''');

    // Create historical data aggregation table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS forecast_historical_data (
        id TEXT PRIMARY KEY,
        data_source TEXT NOT NULL, -- 'revenue', 'expenses', 'cashflow', 'inventory'
        date INTEGER NOT NULL,
        value REAL NOT NULL,
        metadata TEXT, -- JSON with breakdown details
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_forecast_sessions_data_source ON forecast_sessions (data_source)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_forecast_results_session ON forecast_results (session_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_forecast_results_date ON forecast_results (forecast_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_historical_data_source_date ON forecast_historical_data (data_source, date)');
  }

  /// Get or create forecasting model based on method
  ForecastingModel _createModel(
      ForecastingMethod method, Map<String, dynamic>? parameters) {
    switch (method) {
      case ForecastingMethod.linearRegression:
        final model = LinearRegressionModel();
        if (parameters != null) model.setParameters(parameters);
        return model;

      case ForecastingMethod.movingAverage:
        final windowSize = parameters?['window_size'] ?? 3;
        final weights = parameters?['weights'] as List<double>?;
        if (weights != null) {
          return WeightedMovingAverageModel(weights: weights);
        } else {
          return MovingAverageModel(windowSize: windowSize);
        }

      case ForecastingMethod.exponentialSmoothing:
        final alpha = parameters?['alpha']?.toDouble() ?? 0.3;
        final beta = parameters?['beta']?.toDouble();
        if (beta != null) {
          return DoubleExponentialSmoothingModel(alpha: alpha, beta: beta);
        } else {
          return ExponentialSmoothingModel(alpha: alpha);
        }

      case ForecastingMethod.seasonalDecomposition:
        final seasonalPeriod = parameters?['seasonal_period'] ?? 12;
        final multiplicative = parameters?['multiplicative'] ?? false;
        return SeasonalDecompositionModel(
          seasonalPeriod: seasonalPeriod,
          multiplicative: multiplicative,
        );

      case ForecastingMethod.holtWinters:
        // For now, use double exponential smoothing as simplified Holt-Winters
        final alpha = parameters?['alpha']?.toDouble() ?? 0.3;
        final beta = parameters?['beta']?.toDouble() ?? 0.3;
        return DoubleExponentialSmoothingModel(alpha: alpha, beta: beta);

      case ForecastingMethod.ensemble:
        // Return linear regression as default for ensemble (would combine multiple models)
        return LinearRegressionModel();

      default:
        return LinearRegressionModel();
    }
  }

  /// Aggregate historical data from existing business data
  Future<List<TimeSeriesPoint>> getHistoricalData(
    String dataSource, {
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation = Periodicity.monthly,
  }) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    // Check if we have cached aggregated data
    final cached = await _getCachedHistoricalData(
        dataSource, startDate, endDate, aggregation);
    if (cached.isNotEmpty) {
      return cached;
    }

    // Generate fresh data from source tables
    List<TimeSeriesPoint> data = [];

    switch (dataSource) {
      case 'revenue':
        data = await _aggregateRevenueData(db, startDate, endDate, aggregation);
        break;
      case 'expenses':
        data = await _aggregateExpenseData(db, startDate, endDate, aggregation);
        break;
      case 'cashflow':
        data =
            await _aggregateCashFlowData(db, startDate, endDate, aggregation);
        break;
      case 'inventory':
        data =
            await _aggregateInventoryData(db, startDate, endDate, aggregation);
        break;
      default:
        throw ArgumentError('Unknown data source: $dataSource');
    }

    // Cache the aggregated data
    await _cacheHistoricalData(dataSource, data, aggregation);

    return data;
  }

  Future<List<TimeSeriesPoint>> _getCachedHistoricalData(
    String dataSource,
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation,
  ) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    String whereClause = 'data_source = ?';
    List<dynamic> args = [dataSource];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    final results = await db.query(
      'forecast_historical_data',
      where: whereClause,
      whereArgs: args,
      orderBy: 'date ASC',
    );

    return results
        .map((row) => TimeSeriesPoint(
              date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
              value: row['value'] as double,
              metadata: row['metadata'] != null
                  ? jsonDecode(row['metadata'] as String)
                  : null,
            ))
        .toList();
  }

  Future<void> _cacheHistoricalData(
    String dataSource,
    List<TimeSeriesPoint> data,
    Periodicity aggregation,
  ) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    // Clear existing cached data for this source
    await db.delete(
      'forecast_historical_data',
      where: 'data_source = ?',
      whereArgs: [dataSource],
    );

    // Insert new data
    for (final point in data) {
      await db.insert(
        'forecast_historical_data',
        {
          'id': UuidGenerator.generateId(),
          'data_source': dataSource,
          'date': point.date.millisecondsSinceEpoch,
          'value': point.value,
          'metadata':
              point.metadata != null ? jsonEncode(point.metadata) : null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }
  }

  Future<List<TimeSeriesPoint>> _aggregateRevenueData(
    Database db,
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation,
  ) async {
    // Query from enhanced invoices table
    String whereClause =
        "status IN ('paid', 'partially_paid') AND is_deleted = 0";
    List<dynamic> args = [];

    if (startDate != null) {
      whereClause += ' AND issue_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause += ' AND issue_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    final results = await db.query(
      'invoices_crdt',
      columns: ['issue_date', 'total_amount', 'currency'],
      where: whereClause,
      whereArgs: args,
      orderBy: 'issue_date ASC',
    );

    return _aggregateByPeriod(
      results
          .map((row) => {
                'date': DateTime.fromMillisecondsSinceEpoch(
                    row['issue_date'] as int),
                'value': row['total_amount'] as double,
                'metadata': {'currency': row['currency']},
              })
          .toList(),
      aggregation,
    );
  }

  Future<List<TimeSeriesPoint>> _aggregateExpenseData(
    Database db,
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation,
  ) async {
    // Query from transactions table (expense transactions)
    String whereClause = "debit_account LIKE '%expense%' AND is_deleted = 0";
    List<dynamic> args = [];

    if (startDate != null) {
      whereClause += ' AND transaction_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause += ' AND transaction_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    final results = await db.query(
      'transactions_crdt',
      columns: ['transaction_date', 'amount', 'currency'],
      where: whereClause,
      whereArgs: args,
      orderBy: 'transaction_date ASC',
    );

    return _aggregateByPeriod(
      results
          .map((row) => {
                'date': DateTime.fromMillisecondsSinceEpoch(
                    row['transaction_date'] as int),
                'value': row['amount'] as double,
                'metadata': {'currency': row['currency']},
              })
          .toList(),
      aggregation,
    );
  }

  Future<List<TimeSeriesPoint>> _aggregateCashFlowData(
    Database db,
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation,
  ) async {
    // Calculate net cash flow (revenue - expenses)
    final revenue =
        await _aggregateRevenueData(db, startDate, endDate, aggregation);
    final expenses =
        await _aggregateExpenseData(db, startDate, endDate, aggregation);

    // Merge and calculate net cash flow
    final Map<DateTime, double> revenueMap = {
      for (final point in revenue) point.date: point.value
    };
    final Map<DateTime, double> expenseMap = {
      for (final point in expenses) point.date: point.value
    };

    final allDates = {...revenueMap.keys, ...expenseMap.keys}.toList()..sort();

    return allDates.map((date) {
      final rev = revenueMap[date] ?? 0.0;
      final exp = expenseMap[date] ?? 0.0;
      return TimeSeriesPoint(
        date: date,
        value: rev - exp,
        metadata: {'revenue': rev, 'expenses': exp},
      );
    }).toList();
  }

  Future<List<TimeSeriesPoint>> _aggregateInventoryData(
    Database db,
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation,
  ) async {
    // For now, generate sample inventory data
    // In a real implementation, this would query inventory tables
    final data = <Map<String, dynamic>>[];

    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 365));
    final end = endDate ?? DateTime.now();

    for (var date = start;
        date.isBefore(end);
        date = date.add(Duration(days: aggregation.days))) {
      // Simulate inventory value fluctuations
      final baseValue = 100000.0;
      final variation =
          math.sin(date.millisecondsSinceEpoch / (1000 * 60 * 60 * 24 * 30)) *
              20000;
      final randomVariation = (math.Random().nextDouble() - 0.5) * 10000;

      data.add({
        'date': date,
        'value': baseValue + variation + randomVariation,
        'metadata': {'type': 'simulated'},
      });
    }

    return _aggregateByPeriod(data, aggregation);
  }

  List<TimeSeriesPoint> _aggregateByPeriod(
    List<Map<String, dynamic>> data,
    Periodicity aggregation,
  ) {
    if (data.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final item in data) {
      final date = item['date'] as DateTime;
      String key;

      switch (aggregation) {
        case Periodicity.daily:
          key =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          break;
        case Periodicity.weekly:
          final weekStart = date.subtract(Duration(days: date.weekday - 1));
          key = '${weekStart.year}-W${_weekOfYear(weekStart)}';
          break;
        case Periodicity.monthly:
          key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          break;
        case Periodicity.quarterly:
          final quarter = ((date.month - 1) ~/ 3) + 1;
          key = '${date.year}-Q$quarter';
          break;
        case Periodicity.yearly:
          key = '${date.year}';
          break;
      }

      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped.entries.map((entry) {
      final items = entry.value;
      final totalValue = items.fold<double>(
          0.0, (sum, item) => sum + (item['value'] as double));
      final avgValue = totalValue / items.length;

      // Use the first date in the period as representative
      final firstDate = items.first['date'] as DateTime;
      DateTime periodDate;

      switch (aggregation) {
        case Periodicity.daily:
          periodDate = firstDate;
          break;
        case Periodicity.weekly:
          periodDate =
              firstDate.subtract(Duration(days: firstDate.weekday - 1));
          break;
        case Periodicity.monthly:
          periodDate = DateTime(firstDate.year, firstDate.month, 1);
          break;
        case Periodicity.quarterly:
          final quarter = ((firstDate.month - 1) ~/ 3) + 1;
          periodDate = DateTime(firstDate.year, (quarter - 1) * 3 + 1, 1);
          break;
        case Periodicity.yearly:
          periodDate = DateTime(firstDate.year, 1, 1);
          break;
      }

      return TimeSeriesPoint(
        date: periodDate,
        value:
            totalValue, // Use total for most cases, could be average for some metrics
        metadata: {
          'count': items.length,
          'average': avgValue,
          'aggregation': aggregation.name,
        },
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  int _weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// Create and run a forecast session
  Future<ForecastSession> createForecastSession({
    required String name,
    required String dataSource,
    required List<ForecastScenario> scenarios,
    DateTime? startDate,
    DateTime? endDate,
    Periodicity aggregation = Periodicity.monthly,
  }) async {
    final sessionId = UuidGenerator.generateId();

    // Get historical data
    final historicalData = await getHistoricalData(
      dataSource,
      startDate: startDate,
      endDate: endDate,
      aggregation: aggregation,
    );

    if (historicalData.length < 3) {
      throw StateError(
          'Need at least 3 historical data points for forecasting');
    }

    // Run forecasts for each scenario
    final results = <String, List<ForecastResult>>{};
    final accuracyMetrics = <String, ForecastAccuracy>{};

    for (final scenario in scenarios) {
      try {
        final model = _createModel(scenario.method, scenario.parameters);

        // Split data for training and testing (80/20 split)
        final splitIndex = (historicalData.length * 0.8).round();
        final trainingData = historicalData.take(splitIndex).toList();
        final testData = historicalData.skip(splitIndex).toList();

        // Train model
        await model.train(trainingData);

        // Generate forecasts
        final forecasts = await model.forecast(scenario.forecastHorizon);
        results[scenario.id] = forecasts;

        // Calculate accuracy if we have test data
        if (testData.isNotEmpty) {
          final accuracy = await model.calculateAccuracy(testData);
          accuracyMetrics[scenario.id] = accuracy;
        }
      } catch (e) {
        // Log error and continue with other scenarios
        print('Error running scenario ${scenario.name}: $e');
        results[scenario.id] = [];
      }
    }

    // Create session
    final session = ForecastSession(
      id: sessionId,
      name: name,
      createdAt: DateTime.now(),
      scenarios: scenarios,
      results: results,
      accuracyMetrics: accuracyMetrics,
      historicalData: historicalData,
      dataSource: dataSource,
    );

    // Save to database
    await _saveForecastSession(session);

    return session;
  }

  /// Save a forecast session (public method)
  Future<void> saveForecastSession(ForecastSession session) async {
    await _saveForecastSession(session);
  }

  Future<void> _saveForecastSession(ForecastSession session) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    await db.insert(
      'forecast_sessions',
      {
        'id': session.id,
        'name': session.name,
        'data_source': session.dataSource,
        'created_at': session.createdAt.millisecondsSinceEpoch,
        'last_modified': session.lastModified?.millisecondsSinceEpoch,
        'scenarios':
            jsonEncode(session.scenarios.map((s) => s.toJson()).toList()),
        'results': jsonEncode(session.results.map((key, value) => MapEntry(
              key,
              value.map((r) => r.toJson()).toList(),
            ))),
        'accuracy_metrics':
            jsonEncode(session.accuracyMetrics.map((key, value) => MapEntry(
                  key,
                  value.toJson(),
                ))),
        'historical_data':
            jsonEncode(session.historicalData.map((d) => d.toJson()).toList()),
        'metadata': jsonEncode({}),
      },
    );

    // Save individual forecast results for better querying
    for (final scenarioEntry in session.results.entries) {
      final scenarioId = scenarioEntry.key;
      final forecasts = scenarioEntry.value;

      for (final forecast in forecasts) {
        await db.insert(
          'forecast_results',
          {
            'id': UuidGenerator.generateId(),
            'session_id': session.id,
            'scenario_id': scenarioId,
            'forecast_date': forecast.date.millisecondsSinceEpoch,
            'predicted_value': forecast.predictedValue,
            'lower_bound': forecast.lowerBound,
            'upper_bound': forecast.upperBound,
            'confidence': forecast.confidence,
            'method': forecast.method,
            'metrics': jsonEncode(forecast.metrics ?? {}),
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
    }
  }

  /// Get all forecast sessions
  Future<List<ForecastSession>> getAllForecastSessions() async {
    final dbService = await databaseService;
    final db = await dbService.database;

    final results = await db.query(
      'forecast_sessions',
      orderBy: 'created_at DESC',
    );

    return results.map((row) => _parseSessionFromRow(row)).toList();
  }

  /// Get forecast sessions by data source
  Future<List<ForecastSession>> getForecastSessionsByDataSource(
      String dataSource) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    final results = await db.query(
      'forecast_sessions',
      where: 'data_source = ?',
      whereArgs: [dataSource],
      orderBy: 'created_at DESC',
    );

    return results.map((row) => _parseSessionFromRow(row)).toList();
  }

  /// Get recent forecast sessions (limited number)
  Future<List<ForecastSession>> getRecentForecasts([int limit = 10]) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    final results = await db.query(
      'forecast_sessions',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return results.map((row) => _parseSessionFromRow(row)).toList();
  }

  /// Get specific forecast session
  Future<ForecastSession?> getForecastSession(String sessionId) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    final results = await db.query(
      'forecast_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    if (results.isEmpty) return null;

    return _parseSessionFromRow(results.first);
  }

  ForecastSession _parseSessionFromRow(Map<String, dynamic> row) {
    return ForecastSession(
      id: row['id'],
      name: row['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']),
      lastModified: row['last_modified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_modified'])
          : null,
      scenarios: (jsonDecode(row['scenarios']) as List)
          .map((s) => ForecastScenario.fromJson(s))
          .toList(),
      results: (jsonDecode(row['results']) as Map<String, dynamic>)
          .map((key, value) => MapEntry(
                key,
                (value as List).map((r) => ForecastResult.fromJson(r)).toList(),
              )),
      accuracyMetrics:
          (jsonDecode(row['accuracy_metrics']) as Map<String, dynamic>)
              .map((key, value) => MapEntry(
                    key,
                    ForecastAccuracy.fromJson(value),
                  )),
      historicalData: (jsonDecode(row['historical_data']) as List)
          .map((d) => TimeSeriesPoint.fromJson(d))
          .toList(),
      dataSource: row['data_source'],
    );
  }

  /// Delete forecast session
  Future<void> deleteForecastSession(String sessionId) async {
    final dbService = await databaseService;
    final db = await dbService.database;

    await db.transaction((txn) async {
      await txn.delete(
        'forecast_results',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      await txn.delete(
        'forecast_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  /// Refresh historical data cache
  Future<void> refreshHistoricalDataCache() async {
    final dbService = await databaseService;
    final db = await dbService.database;

    // Clear all cached data
    await db.delete('forecast_historical_data');

    // Regenerate for all data sources
    final dataSources = ['revenue', 'expenses', 'cashflow', 'inventory'];

    for (final source in dataSources) {
      try {
        await getHistoricalData(source);
      } catch (e) {
        print('Error refreshing cache for $source: $e');
      }
    }
  }
}
