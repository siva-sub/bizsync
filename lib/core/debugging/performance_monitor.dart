import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';
import '../database/crdt_database_service.dart';

/// Performance metric data point
class PerformanceMetric {
  final String id;
  final String metricName;
  final String category;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final Duration? duration;

  const PerformanceMetric({
    required this.id,
    required this.metricName,
    required this.category,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.context,
    this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'metric_name': metricName,
      'category': category,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'context': jsonEncode(context),
      'duration_ms': duration?.inMilliseconds,
    };
  }

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      id: json['id'] as String,
      metricName: json['metric_name'] as String,
      category: json['category'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      context: jsonDecode(json['context'] as String) as Map<String, dynamic>,
      duration: json['duration_ms'] != null
          ? Duration(milliseconds: json['duration_ms'] as int)
          : null,
    );
  }
}

/// Performance bottleneck detection result
class BottleneckResult {
  final String id;
  final String bottleneckType;
  final String description;
  final BottleneckSeverity severity;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> evidence;
  final DateTime detectedAt;
  final String? suggestedFix;
  final List<String> affectedOperations;

  const BottleneckResult({
    required this.id,
    required this.bottleneckType,
    required this.description,
    required this.severity,
    required this.metrics,
    required this.evidence,
    required this.detectedAt,
    this.suggestedFix,
    this.affectedOperations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bottleneck_type': bottleneckType,
      'description': description,
      'severity': severity.name,
      'metrics': jsonEncode(metrics),
      'evidence': jsonEncode(evidence),
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'suggested_fix': suggestedFix,
      'affected_operations': jsonEncode(affectedOperations),
    };
  }
}

/// Bottleneck severity levels
enum BottleneckSeverity {
  minor,
  moderate,
  severe,
  critical,
}

/// Performance categories
enum PerformanceCategory {
  database,
  ui,
  network,
  computation,
  memory,
  storage,
  rendering,
  animation,
}

/// Performance benchmark
class PerformanceBenchmark {
  final String name;
  final String category;
  final double expectedValue;
  final double warningThreshold;
  final double criticalThreshold;
  final String unit;
  final String description;

  const PerformanceBenchmark({
    required this.name,
    required this.category,
    required this.expectedValue,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.unit,
    required this.description,
  });
}

/// Operation timing tracker
class OperationTimer {
  final String operationName;
  final String category;
  final Stopwatch _stopwatch;
  final Map<String, dynamic> context;
  final DateTime startTime;

  OperationTimer._({
    required this.operationName,
    required this.category,
    required this.context,
  }) : _stopwatch = Stopwatch()..start(),
       startTime = DateTime.now();

  static OperationTimer start(
    String operationName, {
    String category = 'general',
    Map<String, dynamic>? context,
  }) {
    return OperationTimer._(
      operationName: operationName,
      category: category,
      context: context ?? {},
    );
  }

  PerformanceMetric stop() {
    _stopwatch.stop();
    
    return PerformanceMetric(
      id: UuidGenerator.generateId(),
      metricName: operationName,
      category: category,
      value: _stopwatch.elapsedMilliseconds.toDouble(),
      unit: 'ms',
      timestamp: startTime,
      context: context,
      duration: _stopwatch.elapsed,
    );
  }

  Duration get elapsed => _stopwatch.elapsed;
}

/// Comprehensive performance monitoring system
class PerformanceMonitor {
  final CRDTDatabaseService _databaseService;
  final List<PerformanceMetric> _metrics = [];
  final List<BottleneckResult> _detectedBottlenecks = [];
  final Map<String, List<double>> _metricHistory = {};
  final Map<String, PerformanceBenchmark> _benchmarks = {};
  final Map<String, Timer> _monitoringTimers = {};
  
  // Real-time tracking
  final Map<String, OperationTimer> _activeOperations = {};
  final List<double> _frameTimings = [];
  final List<double> _memoryUsage = [];
  
  // Configuration
  static const int maxMetricsHistory = 1000;
  static const int maxFrameTimings = 100;
  static const Duration monitoringInterval = Duration(seconds: 10);
  static const Duration benchmarkCheckInterval = Duration(minutes: 1);
  
  // Statistics
  int _totalOperationsTracked = 0;
  int _totalBottlenecksDetected = 0;
  final Map<String, int> _bottlenecksByType = {};
  final Map<String, double> _averageMetrics = {};

  PerformanceMonitor(this._databaseService);

  /// Initialize the performance monitor
  Future<void> initialize() async {
    await _createPerformanceTables();
    await _setupDefaultBenchmarks();
    await _startMonitoring();
    await _setupFrameCallbacks();

    if (kDebugMode) {
      print('PerformanceMonitor initialized');
    }
  }

  /// Start timing an operation
  OperationTimer startTimer(
    String operationName, {
    String category = 'general',
    Map<String, dynamic>? context,
  }) {
    final timer = OperationTimer.start(
      operationName,
      category: category,
      context: context,
    );
    
    _activeOperations[operationName] = timer;
    return timer;
  }

  /// Stop timing an operation and record the metric
  Future<PerformanceMetric> stopTimer(String operationName) async {
    final timer = _activeOperations.remove(operationName);
    if (timer == null) {
      throw ArgumentError('No active timer found for operation: $operationName');
    }
    
    final metric = timer.stop();
    await recordMetric(metric);
    
    _totalOperationsTracked++;
    
    return metric;
  }

  /// Record a custom performance metric
  Future<void> recordMetric(PerformanceMetric metric) async {
    _metrics.add(metric);
    
    // Keep metrics history bounded
    if (_metrics.length > maxMetricsHistory) {
      _metrics.removeAt(0);
    }

    // Update metric history for trend analysis
    _metricHistory.putIfAbsent(metric.metricName, () => []);
    _metricHistory[metric.metricName]!.add(metric.value);
    
    // Keep history bounded
    if (_metricHistory[metric.metricName]!.length > 100) {
      _metricHistory[metric.metricName]!.removeAt(0);
    }

    // Update averages
    _updateAverageMetrics();

    // Store in database
    await _storeMetric(metric);

    // Check for bottlenecks
    await _checkForBottlenecks(metric);
  }

  /// Record frame timing
  void recordFrameTiming(double frameTimeMs) {
    _frameTimings.add(frameTimeMs);
    
    if (_frameTimings.length > maxFrameTimings) {
      _frameTimings.removeAt(0);
    }

    // Record as metric periodically
    if (_frameTimings.length % 10 == 0) {
      final avgFrameTime = _frameTimings.reduce((a, b) => a + b) / _frameTimings.length;
      recordMetric(PerformanceMetric(
        id: UuidGenerator.generateId(),
        metricName: 'average_frame_time',
        category: 'ui',
        value: avgFrameTime,
        unit: 'ms',
        timestamp: DateTime.now(),
        context: {
          'sample_count': _frameTimings.length,
          'max_frame_time': _frameTimings.reduce(max),
          'min_frame_time': _frameTimings.reduce(min),
        },
      ));
    }
  }

  /// Record memory usage
  void recordMemoryUsage(double memoryMB) {
    _memoryUsage.add(memoryMB);
    
    if (_memoryUsage.length > 100) {
      _memoryUsage.removeAt(0);
    }
  }

  /// Get current performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    final activeOperations = _activeOperations.length;
    final avgFrameTime = _frameTimings.isNotEmpty 
        ? _frameTimings.reduce((a, b) => a + b) / _frameTimings.length 
        : 0.0;
    final currentMemory = _memoryUsage.isNotEmpty ? _memoryUsage.last : 0.0;
    
    return {
      'total_operations_tracked': _totalOperationsTracked,
      'active_operations': activeOperations,
      'total_metrics': _metrics.length,
      'bottlenecks_detected': _totalBottlenecksDetected,
      'bottlenecks_by_type': Map.from(_bottlenecksByType),
      'average_metrics': Map.from(_averageMetrics),
      'frame_performance': {
        'average_frame_time_ms': avgFrameTime,
        'frame_drop_rate': _calculateFrameDropRate(),
        'samples': _frameTimings.length,
      },
      'memory_performance': {
        'current_usage_mb': currentMemory,
        'peak_usage_mb': _memoryUsage.isNotEmpty ? _memoryUsage.reduce(max) : 0.0,
        'samples': _memoryUsage.length,
      },
      'last_metric': _metrics.isNotEmpty 
          ? _metrics.last.timestamp.toIso8601String()
          : null,
    };
  }

  /// Detect performance bottlenecks
  Future<List<BottleneckResult>> detectBottlenecks({
    PerformanceCategory? category,
    BottleneckSeverity? minSeverity,
  }) async {
    final bottlenecks = <BottleneckResult>[];

    // Database performance bottlenecks
    bottlenecks.addAll(await _detectDatabaseBottlenecks());
    
    // UI performance bottlenecks
    bottlenecks.addAll(await _detectUIBottlenecks());
    
    // Memory bottlenecks
    bottlenecks.addAll(await _detectMemoryBottlenecks());
    
    // Network bottlenecks
    bottlenecks.addAll(await _detectNetworkBottlenecks());
    
    // Computation bottlenecks
    bottlenecks.addAll(await _detectComputationBottlenecks());

    // Filter by category and severity
    var filteredBottlenecks = bottlenecks;
    
    if (category != null) {
      filteredBottlenecks = filteredBottlenecks
          .where((b) => b.bottleneckType.contains(category.name))
          .toList();
    }
    
    if (minSeverity != null) {
      final minIndex = BottleneckSeverity.values.indexOf(minSeverity);
      filteredBottlenecks = filteredBottlenecks
          .where((b) => BottleneckSeverity.values.indexOf(b.severity) >= minIndex)
          .toList();
    }

    // Store detected bottlenecks
    for (final bottleneck in filteredBottlenecks) {
      await _storeBottleneck(bottleneck);
    }

    _detectedBottlenecks.addAll(filteredBottlenecks);
    _totalBottlenecksDetected += filteredBottlenecks.length;

    return filteredBottlenecks;
  }

  /// Get performance trends analysis
  Map<String, dynamic> getPerformanceTrends({Duration? period}) {
    period ??= const Duration(hours: 24);
    final cutoff = DateTime.now().subtract(period);
    
    final recentMetrics = _metrics
        .where((m) => m.timestamp.isAfter(cutoff))
        .toList();

    final trends = <String, Map<String, dynamic>>{};
    
    // Group metrics by name
    final metricGroups = <String, List<PerformanceMetric>>{};
    for (final metric in recentMetrics) {
      metricGroups.putIfAbsent(metric.metricName, () => []);
      metricGroups[metric.metricName]!.add(metric);
    }

    // Calculate trends for each metric
    for (final entry in metricGroups.entries) {
      final metricName = entry.key;
      final metricValues = entry.value;
      
      if (metricValues.length >= 2) {
        metricValues.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        final firstHalf = metricValues.take(metricValues.length ~/ 2).toList();
        final secondHalf = metricValues.skip(metricValues.length ~/ 2).toList();
        
        final firstAvg = firstHalf.map((m) => m.value).reduce((a, b) => a + b) / firstHalf.length;
        final secondAvg = secondHalf.map((m) => m.value).reduce((a, b) => a + b) / secondHalf.length;
        
        final trend = secondAvg - firstAvg;
        final trendPercent = firstAvg != 0 ? (trend / firstAvg * 100) : 0.0;
        
        trends[metricName] = {
          'trend_value': trend,
          'trend_percent': trendPercent,
          'current_avg': secondAvg,
          'previous_avg': firstAvg,
          'sample_count': metricValues.length,
          'trend_direction': trend > 0 ? 'increasing' : trend < 0 ? 'decreasing' : 'stable',
        };
      }
    }

    return {
      'period_hours': period.inHours,
      'total_metrics': recentMetrics.length,
      'unique_metric_types': metricGroups.length,
      'trends': trends,
      'analysis_timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Export performance report
  Future<Map<String, dynamic>> exportPerformanceReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fromDate ??= DateTime.now().subtract(const Duration(days: 7));
    toDate ??= DateTime.now();

    final db = await _databaseService.database;
    
    // Get metrics for period
    final metricsResult = await db.query(
      'performance_metrics',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        fromDate.millisecondsSinceEpoch,
        toDate.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );

    final metrics = metricsResult.map((r) => PerformanceMetric.fromJson(r)).toList();

    // Get bottlenecks for period
    final bottlenecksResult = await db.query(
      'performance_bottlenecks',
      where: 'detected_at >= ? AND detected_at <= ?',
      whereArgs: [
        fromDate.millisecondsSinceEpoch,
        toDate.millisecondsSinceEpoch,
      ],
      orderBy: 'detected_at DESC',
    );

    final bottlenecks = bottlenecksResult.map((r) => BottleneckResult.fromJson(r)).toList();

    return {
      'period': {
        'from': fromDate.toIso8601String(),
        'to': toDate.toIso8601String(),
      },
      'summary': {
        'total_metrics': metrics.length,
        'total_bottlenecks': bottlenecks.length,
        'unique_operations': metrics.map((m) => m.metricName).toSet().length,
        'performance_categories': metrics.map((m) => m.category).toSet().toList(),
      },
      'metrics_analysis': _analyzeMetrics(metrics),
      'bottlenecks_analysis': _analyzeBottlenecks(bottlenecks),
      'performance_trends': getPerformanceTrends(period: toDate.difference(fromDate)),
      'top_slow_operations': _getTopSlowOperations(metrics),
      'benchmark_violations': await _getBenchmarkViolations(metrics),
      'recommendations': _generatePerformanceRecommendations(metrics, bottlenecks),
      'statistics': getPerformanceStatistics(),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // Private helper methods

  Future<void> _createPerformanceTables() async {
    final db = await _databaseService.database;

    // Performance metrics table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS performance_metrics (
        id TEXT PRIMARY KEY,
        metric_name TEXT NOT NULL,
        category TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        context TEXT NOT NULL,
        duration_ms INTEGER
      )
    ''');

    // Performance bottlenecks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS performance_bottlenecks (
        id TEXT PRIMARY KEY,
        bottleneck_type TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL,
        metrics TEXT NOT NULL,
        evidence TEXT NOT NULL,
        detected_at INTEGER NOT NULL,
        suggested_fix TEXT,
        affected_operations TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_perf_metrics_name ON performance_metrics(metric_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_perf_metrics_timestamp ON performance_metrics(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_perf_metrics_category ON performance_metrics(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_perf_bottlenecks_type ON performance_bottlenecks(bottleneck_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_perf_bottlenecks_detected ON performance_bottlenecks(detected_at)');
  }

  Future<void> _setupDefaultBenchmarks() async {
    _benchmarks.addAll({
      'database_query': const PerformanceBenchmark(
        name: 'database_query',
        category: 'database',
        expectedValue: 10.0,
        warningThreshold: 50.0,
        criticalThreshold: 200.0,
        unit: 'ms',
        description: 'Database query execution time',
      ),
      'ui_render': const PerformanceBenchmark(
        name: 'ui_render',
        category: 'ui',
        expectedValue: 16.67,
        warningThreshold: 33.33,
        criticalThreshold: 100.0,
        unit: 'ms',
        description: 'UI rendering time (60fps = 16.67ms)',
      ),
      'network_request': const PerformanceBenchmark(
        name: 'network_request',
        category: 'network',
        expectedValue: 100.0,
        warningThreshold: 1000.0,
        criticalThreshold: 5000.0,
        unit: 'ms',
        description: 'Network request completion time',
      ),
      'memory_usage': const PerformanceBenchmark(
        name: 'memory_usage',
        category: 'memory',
        expectedValue: 100.0,
        warningThreshold: 200.0,
        criticalThreshold: 500.0,
        unit: 'MB',
        description: 'Application memory usage',
      ),
    });
  }

  Future<void> _startMonitoring() async {
    // Start periodic performance monitoring
    _monitoringTimers['general'] = Timer.periodic(
      monitoringInterval,
      (_) => _performPeriodicMonitoring(),
    );

    // Start benchmark checking
    _monitoringTimers['benchmarks'] = Timer.periodic(
      benchmarkCheckInterval,
      (_) => _checkBenchmarks(),
    );
  }

  Future<void> _setupFrameCallbacks() async {
    if (kDebugMode) {
      WidgetsBinding.instance.addPersistentFrameCallback(_onFrameCallback);
    }
  }

  void _onFrameCallback(Duration timestamp) {
    final frameTimeMs = timestamp.inMicroseconds / 1000.0;
    recordFrameTiming(frameTimeMs);
  }

  Future<void> _performPeriodicMonitoring() async {
    try {
      // Record current memory usage
      final memoryUsage = await _getCurrentMemoryUsage();
      recordMemoryUsage(memoryUsage);

      // Check for new bottlenecks
      await detectBottlenecks();
    } catch (e) {
      if (kDebugMode) {
        print('Periodic monitoring failed: $e');
      }
    }
  }

  Future<void> _checkBenchmarks() async {
    for (final benchmark in _benchmarks.values) {
      final recentMetrics = _metricHistory[benchmark.name];
      if (recentMetrics != null && recentMetrics.isNotEmpty) {
        final currentValue = recentMetrics.last;
        
        if (currentValue > benchmark.criticalThreshold) {
          await _createBottleneck(
            '${benchmark.category}_critical_threshold',
            'Critical performance threshold exceeded for ${benchmark.name}',
            BottleneckSeverity.critical,
            {'benchmark': benchmark.name, 'value': currentValue, 'threshold': benchmark.criticalThreshold},
            {'current_value': currentValue, 'expected_value': benchmark.expectedValue},
            'Investigate and optimize ${benchmark.description}',
            [benchmark.name],
          );
        } else if (currentValue > benchmark.warningThreshold) {
          await _createBottleneck(
            '${benchmark.category}_warning_threshold',
            'Warning performance threshold exceeded for ${benchmark.name}',
            BottleneckSeverity.moderate,
            {'benchmark': benchmark.name, 'value': currentValue, 'threshold': benchmark.warningThreshold},
            {'current_value': currentValue, 'expected_value': benchmark.expectedValue},
            'Monitor and consider optimizing ${benchmark.description}',
            [benchmark.name],
          );
        }
      }
    }
  }

  Future<void> _storeMetric(PerformanceMetric metric) async {
    final db = await _databaseService.database;
    await db.insert('performance_metrics', metric.toJson());
  }

  Future<void> _storeBottleneck(BottleneckResult bottleneck) async {
    final db = await _databaseService.database;
    await db.insert('performance_bottlenecks', bottleneck.toJson());
  }

  Future<void> _checkForBottlenecks(PerformanceMetric metric) async {
    final benchmark = _benchmarks[metric.metricName];
    if (benchmark != null) {
      if (metric.value > benchmark.criticalThreshold) {
        await _createBottleneck(
          '${metric.category}_performance',
          'Critical performance issue detected for ${metric.metricName}',
          BottleneckSeverity.critical,
          {'metric_value': metric.value, 'threshold': benchmark.criticalThreshold},
          {'metric': metric.toJson()},
          'Immediate optimization required for ${metric.metricName}',
          [metric.metricName],
        );
      }
    }
  }

  Future<void> _createBottleneck(
    String type,
    String description,
    BottleneckSeverity severity,
    Map<String, dynamic> metrics,
    Map<String, dynamic> evidence,
    String suggestedFix,
    List<String> affectedOps,
  ) async {
    final bottleneck = BottleneckResult(
      id: UuidGenerator.generateId(),
      bottleneckType: type,
      description: description,
      severity: severity,
      metrics: metrics,
      evidence: evidence,
      detectedAt: DateTime.now(),
      suggestedFix: suggestedFix,
      affectedOperations: affectedOps,
    );

    await _storeBottleneck(bottleneck);
    _detectedBottlenecks.add(bottleneck);
    _totalBottlenecksDetected++;
    _bottlenecksByType[type] = (_bottlenecksByType[type] ?? 0) + 1;
  }

  void _updateAverageMetrics() {
    final metricGroups = <String, List<double>>{};
    
    for (final metric in _metrics) {
      metricGroups.putIfAbsent(metric.metricName, () => []);
      metricGroups[metric.metricName]!.add(metric.value);
    }
    
    for (final entry in metricGroups.entries) {
      final values = entry.value;
      _averageMetrics[entry.key] = values.reduce((a, b) => a + b) / values.length;
    }
  }

  double _calculateFrameDropRate() {
    if (_frameTimings.isEmpty) return 0.0;
    
    final droppedFrames = _frameTimings.where((t) => t > 16.67).length;
    return droppedFrames / _frameTimings.length;
  }

  Future<double> _getCurrentMemoryUsage() async {
    // Placeholder - would use platform-specific memory monitoring
    return 50.0; // MB
  }

  Future<List<BottleneckResult>> _detectDatabaseBottlenecks() async {
    final bottlenecks = <BottleneckResult>[];
    
    final dbMetrics = _metricHistory['database_query'] ?? [];
    if (dbMetrics.isNotEmpty) {
      final avgQueryTime = dbMetrics.reduce((a, b) => a + b) / dbMetrics.length;
      
      if (avgQueryTime > 100.0) { // 100ms threshold
        bottlenecks.add(BottleneckResult(
          id: UuidGenerator.generateId(),
          bottleneckType: 'database_slow_queries',
          description: 'Database queries are running slower than expected',
          severity: avgQueryTime > 500.0 ? BottleneckSeverity.severe : BottleneckSeverity.moderate,
          metrics: {'average_query_time': avgQueryTime, 'sample_count': dbMetrics.length},
          evidence: {'recent_query_times': dbMetrics.take(10).toList()},
          detectedAt: DateTime.now(),
          suggestedFix: 'Add database indexes, optimize queries, or consider query caching',
          affectedOperations: ['database_query'],
        ));
      }
    }
    
    return bottlenecks;
  }

  Future<List<BottleneckResult>> _detectUIBottlenecks() async {
    final bottlenecks = <BottleneckResult>[];
    
    final frameDropRate = _calculateFrameDropRate();
    if (frameDropRate > 0.1) { // 10% frame drop threshold
      bottlenecks.add(BottleneckResult(
        id: UuidGenerator.generateId(),
        bottleneckType: 'ui_frame_drops',
        description: 'High frame drop rate detected',
        severity: frameDropRate > 0.3 ? BottleneckSeverity.severe : BottleneckSeverity.moderate,
        metrics: {'frame_drop_rate': frameDropRate, 'sample_count': _frameTimings.length},
        evidence: {'recent_frame_times': _frameTimings.take(20).toList()},
        detectedAt: DateTime.now(),
        suggestedFix: 'Optimize UI rendering, reduce expensive operations in build methods',
        affectedOperations: ['ui_render'],
      ));
    }
    
    return bottlenecks;
  }

  Future<List<BottleneckResult>> _detectMemoryBottlenecks() async {
    final bottlenecks = <BottleneckResult>[];
    
    if (_memoryUsage.length >= 10) {
      final recent = _memoryUsage.sublist(_memoryUsage.length - 10);
      final older = _memoryUsage.sublist(0, min(10, _memoryUsage.length - 10));
      
      final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
      final olderAvg = older.reduce((a, b) => a + b) / older.length;
      final memoryIncrease = recentAvg - olderAvg;
      
      if (memoryIncrease > 50.0) { // 50MB increase threshold
        bottlenecks.add(BottleneckResult(
          id: UuidGenerator.generateId(),
          bottleneckType: 'memory_leak',
          description: 'Potential memory leak detected',
          severity: memoryIncrease > 200.0 ? BottleneckSeverity.critical : BottleneckSeverity.severe,
          metrics: {'memory_increase': memoryIncrease, 'current_usage': recentAvg},
          evidence: {'memory_trend': _memoryUsage.take(20).toList()},
          detectedAt: DateTime.now(),
          suggestedFix: 'Review object disposal, stream subscriptions, and widget lifecycle',
          affectedOperations: ['memory_allocation'],
        ));
      }
    }
    
    return bottlenecks;
  }

  Future<List<BottleneckResult>> _detectNetworkBottlenecks() async {
    final bottlenecks = <BottleneckResult>[];
    
    final networkMetrics = _metricHistory['network_request'] ?? [];
    if (networkMetrics.isNotEmpty) {
      final avgNetworkTime = networkMetrics.reduce((a, b) => a + b) / networkMetrics.length;
      
      if (avgNetworkTime > 2000.0) { // 2 second threshold
        bottlenecks.add(BottleneckResult(
          id: UuidGenerator.generateId(),
          bottleneckType: 'network_slow_requests',
          description: 'Network requests are slower than expected',
          severity: avgNetworkTime > 5000.0 ? BottleneckSeverity.severe : BottleneckSeverity.moderate,
          metrics: {'average_network_time': avgNetworkTime, 'sample_count': networkMetrics.length},
          evidence: {'recent_request_times': networkMetrics.take(10).toList()},
          detectedAt: DateTime.now(),
          suggestedFix: 'Optimize network requests, implement caching, or check network connectivity',
          affectedOperations: ['network_request'],
        ));
      }
    }
    
    return bottlenecks;
  }

  Future<List<BottleneckResult>> _detectComputationBottlenecks() async {
    final bottlenecks = <BottleneckResult>[];
    
    // Check for long-running operations
    final longOperations = _activeOperations.entries
        .where((entry) => entry.value.elapsed > const Duration(seconds: 5))
        .toList();
    
    if (longOperations.isNotEmpty) {
      bottlenecks.add(BottleneckResult(
        id: UuidGenerator.generateId(),
        bottleneckType: 'computation_blocking',
        description: '${longOperations.length} long-running operations detected',
        severity: longOperations.length > 5 ? BottleneckSeverity.severe : BottleneckSeverity.moderate,
        metrics: {'long_operations_count': longOperations.length},
        evidence: {
          'operations': longOperations.map((op) => {
            'name': op.key,
            'duration_ms': op.value.elapsed.inMilliseconds,
          }).toList(),
        },
        detectedAt: DateTime.now(),
        suggestedFix: 'Move heavy computations to isolates or optimize algorithms',
        affectedOperations: longOperations.map((op) => op.key).toList(),
      ));
    }
    
    return bottlenecks;
  }

  Map<String, dynamic> _analyzeMetrics(List<PerformanceMetric> metrics) {
    final categories = <String, List<double>>{};
    
    for (final metric in metrics) {
      categories.putIfAbsent(metric.category, () => []);
      categories[metric.category]!.add(metric.value);
    }
    
    final analysis = <String, dynamic>{};
    
    for (final entry in categories.entries) {
      final values = entry.value;
      values.sort();
      
      analysis[entry.key] = {
        'count': values.length,
        'average': values.reduce((a, b) => a + b) / values.length,
        'median': values[values.length ~/ 2],
        'min': values.first,
        'max': values.last,
        'p95': values[(values.length * 0.95).floor()],
        'p99': values[(values.length * 0.99).floor()],
      };
    }
    
    return analysis;
  }

  Map<String, dynamic> _analyzeBottlenecks(List<BottleneckResult> bottlenecks) {
    final bySeverity = <String, int>{};
    final byType = <String, int>{};
    
    for (final bottleneck in bottlenecks) {
      bySeverity[bottleneck.severity.name] = (bySeverity[bottleneck.severity.name] ?? 0) + 1;
      byType[bottleneck.bottleneckType] = (byType[bottleneck.bottleneckType] ?? 0) + 1;
    }
    
    return {
      'total_bottlenecks': bottlenecks.length,
      'by_severity': bySeverity,
      'by_type': byType,
      'critical_count': bottlenecks.where((b) => b.severity == BottleneckSeverity.critical).length,
      'most_common_type': byType.isNotEmpty 
          ? byType.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
    };
  }

  List<Map<String, dynamic>> _getTopSlowOperations(List<PerformanceMetric> metrics) {
    final operationTimes = <String, List<double>>{};
    
    for (final metric in metrics) {
      operationTimes.putIfAbsent(metric.metricName, () => []);
      operationTimes[metric.metricName]!.add(metric.value);
    }
    
    final averages = operationTimes.entries.map((entry) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return {
        'operation': entry.key,
        'average_time': avg,
        'max_time': entry.value.reduce(max),
        'sample_count': entry.value.length,
      };
    }).toList();
    
    averages.sort((a, b) => (b['average_time'] as double).compareTo(a['average_time'] as double));
    
    return averages.take(10).toList();
  }

  Future<List<Map<String, dynamic>>> _getBenchmarkViolations(List<PerformanceMetric> metrics) async {
    final violations = <Map<String, dynamic>>[];
    
    for (final metric in metrics) {
      final benchmark = _benchmarks[metric.metricName];
      if (benchmark != null && metric.value > benchmark.warningThreshold) {
        violations.add({
          'metric_name': metric.metricName,
          'value': metric.value,
          'threshold': benchmark.warningThreshold,
          'severity': metric.value > benchmark.criticalThreshold ? 'critical' : 'warning',
          'timestamp': metric.timestamp.toIso8601String(),
        });
      }
    }
    
    return violations;
  }

  List<Map<String, dynamic>> _generatePerformanceRecommendations(
    List<PerformanceMetric> metrics,
    List<BottleneckResult> bottlenecks,
  ) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Analyze bottleneck patterns
    final bottleneckTypes = <String, int>{};
    for (final bottleneck in bottlenecks) {
      bottleneckTypes[bottleneck.bottleneckType] = (bottleneckTypes[bottleneck.bottleneckType] ?? 0) + 1;
    }
    
    for (final entry in bottleneckTypes.entries) {
      if (entry.value >= 3) {
        recommendations.add({
          'type': 'bottleneck_optimization',
          'category': entry.key,
          'count': entry.value,
          'suggestion': _getBottleneckOptimizationSuggestion(entry.key),
          'priority': entry.value > 10 ? 'high' : 'medium',
        });
      }
    }
    
    return recommendations;
  }

  String _getBottleneckOptimizationSuggestion(String bottleneckType) {
    switch (bottleneckType) {
      case 'database_slow_queries':
        return 'Add database indexes, optimize query structure, implement query caching';
      case 'ui_frame_drops':
        return 'Optimize widget builds, reduce expensive operations, implement virtualization';
      case 'memory_leak':
        return 'Review object lifecycle, fix stream subscriptions, optimize widget disposal';
      case 'network_slow_requests':
        return 'Implement request caching, optimize payload size, check network implementation';
      case 'computation_blocking':
        return 'Move heavy computations to isolates, optimize algorithms, implement lazy loading';
      default:
        return 'Review and optimize the affected performance area';
    }
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _monitoringTimers.values) {
      timer.cancel();
    }
    _monitoringTimers.clear();
    
    if (kDebugMode) {
      WidgetsBinding.instance.removeFrameCallback(_onFrameCallback);
    }
  }
}

extension BottleneckResultFromJson on BottleneckResult {
  static BottleneckResult fromJson(Map<String, dynamic> json) {
    return BottleneckResult(
      id: json['id'] as String,
      bottleneckType: json['bottleneck_type'] as String,
      description: json['description'] as String,
      severity: BottleneckSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
      metrics: jsonDecode(json['metrics'] as String) as Map<String, dynamic>,
      evidence: jsonDecode(json['evidence'] as String) as Map<String, dynamic>,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(json['detected_at'] as int),
      suggestedFix: json['suggested_fix'] as String?,
      affectedOperations: List<String>.from(
        jsonDecode(json['affected_operations'] as String) as List,
      ),
    );
  }
}