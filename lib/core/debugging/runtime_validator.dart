import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';
import '../database/crdt_database_service.dart';

/// Validation result for runtime checks
class ValidationResult {
  final String id;
  final String validationName;
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final Duration executionTime;
  final ValidationSeverity severity;

  const ValidationResult({
    required this.id,
    required this.validationName,
    required this.isValid,
    this.errorMessage,
    required this.context,
    required this.timestamp,
    required this.executionTime,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'validation_name': validationName,
      'is_valid': isValid,
      'error_message': errorMessage,
      'context': jsonEncode(context),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'execution_time_ms': executionTime.inMilliseconds,
      'severity': severity.name,
    };
  }

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      id: json['id'] as String,
      validationName: json['validation_name'] as String,
      isValid: json['is_valid'] as bool,
      errorMessage: json['error_message'] as String?,
      context: jsonDecode(json['context'] as String) as Map<String, dynamic>,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      executionTime: Duration(milliseconds: json['execution_time_ms'] as int),
      severity: ValidationSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
    );
  }
}

/// Severity levels for validation failures
enum ValidationSeverity {
  info,
  warning,
  error,
  critical,
}

/// Types of runtime validations
enum ValidationType {
  dataIntegrity,
  businessRule,
  schemaConsistency,
  nullSafety,
  performanceThreshold,
  securityConstraint,
  crdtConsistency,
  apiContract,
}

/// Runtime validation rule definition
class ValidationRule {
  final String id;
  final String name;
  final ValidationType type;
  final ValidationSeverity severity;
  final String description;
  final Future<ValidationResult> Function(Map<String, dynamic> context) validator;
  final bool isEnabled;
  final Duration? timeout;
  final Map<String, dynamic>? configuration;

  const ValidationRule({
    required this.id,
    required this.name,
    required this.type,
    required this.severity,
    required this.description,
    required this.validator,
    this.isEnabled = true,
    this.timeout,
    this.configuration,
  });
}

/// Comprehensive runtime validation system
class RuntimeValidator {
  final CRDTDatabaseService _databaseService;
  final List<ValidationRule> _rules = [];
  final List<ValidationResult> _recentResults = [];
  final Map<String, Timer> _scheduledValidations = {};
  
  // Performance tracking
  final Map<String, List<Duration>> _validationPerformance = {};
  
  // Validation statistics
  int _totalValidations = 0;
  int _failedValidations = 0;
  
  // Configuration
  static const int maxRecentResults = 1000;
  static const Duration defaultTimeout = Duration(seconds: 30);

  RuntimeValidator(this._databaseService);

  /// Initialize the runtime validator
  Future<void> initialize() async {
    await _createValidationTables();
    await _registerBuiltInRules();
    await _startScheduledValidations();
    
    if (kDebugMode) {
      print('RuntimeValidator initialized with ${_rules.length} rules');
    }
  }

  /// Register a custom validation rule
  void registerRule(ValidationRule rule) {
    // Remove existing rule with same ID
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
    
    if (kDebugMode) {
      print('Registered validation rule: ${rule.name}');
    }
  }

  /// Enable or disable a validation rule
  void toggleRule(String ruleId, bool enabled) {
    final ruleIndex = _rules.indexWhere((r) => r.id == ruleId);
    if (ruleIndex != -1) {
      final rule = _rules[ruleIndex];
      _rules[ruleIndex] = ValidationRule(
        id: rule.id,
        name: rule.name,
        type: rule.type,
        severity: rule.severity,
        description: rule.description,
        validator: rule.validator,
        isEnabled: enabled,
        timeout: rule.timeout,
        configuration: rule.configuration,
      );
    }
  }

  /// Run all enabled validation rules
  Future<List<ValidationResult>> runAllValidations({
    Map<String, dynamic>? context,
    ValidationType? filterType,
    ValidationSeverity? minSeverity,
  }) async {
    final results = <ValidationResult>[];
    final validationContext = context ?? {};
    
    // Filter rules
    final rulesToRun = _rules.where((rule) {
      if (!rule.isEnabled) return false;
      if (filterType != null && rule.type != filterType) return false;
      if (minSeverity != null) {
        final ruleIndex = ValidationSeverity.values.indexOf(rule.severity);
        final minIndex = ValidationSeverity.values.indexOf(minSeverity);
        if (ruleIndex < minIndex) return false;
      }
      return true;
    }).toList();

    // Run validations concurrently
    final futures = rulesToRun.map((rule) => _runSingleValidation(rule, validationContext));
    final validationResults = await Future.wait(futures);
    
    results.addAll(validationResults);
    
    // Store results
    await _storeValidationResults(results);
    
    // Update statistics
    _totalValidations += results.length;
    _failedValidations += results.where((r) => !r.isValid).length;
    
    // Keep recent results in memory
    _recentResults.addAll(results);
    if (_recentResults.length > maxRecentResults) {
      _recentResults.removeRange(0, _recentResults.length - maxRecentResults);
    }

    return results;
  }

  /// Run a specific validation rule
  Future<ValidationResult> runValidation(
    String ruleId, {
    Map<String, dynamic>? context,
  }) async {
    final rule = _rules.firstWhere(
      (r) => r.id == ruleId,
      orElse: () => throw ValidationException('Validation rule not found: $ruleId'),
    );

    return await _runSingleValidation(rule, context ?? {});
  }

  /// Validate critical operation before execution
  Future<bool> validateCriticalOperation(
    String operationName,
    Map<String, dynamic> operationContext, {
    List<String>? specificRules,
  }) async {
    final rulesToRun = specificRules != null
        ? _rules.where((r) => specificRules.contains(r.id) && r.isEnabled)
        : _rules.where((r) => r.isEnabled && 
            (r.severity == ValidationSeverity.critical || 
             r.severity == ValidationSeverity.error));

    final results = await Future.wait(
      rulesToRun.map((rule) => _runSingleValidation(rule, operationContext)),
    );

    final hasFailures = results.any((r) => !r.isValid);
    
    if (hasFailures) {
      final failures = results.where((r) => !r.isValid).toList();
      await _logCriticalOperationFailure(operationName, failures, operationContext);
    }

    return !hasFailures;
  }

  /// Get validation statistics
  Map<String, dynamic> getStatistics() {
    final failureRate = _totalValidations > 0 
        ? (_failedValidations / _totalValidations * 100) 
        : 0.0;

    final recentFailures = _recentResults
        .where((r) => !r.isValid && 
               r.timestamp.isAfter(DateTime.now().subtract(const Duration(hours: 1))))
        .length;

    return {
      'total_validations': _totalValidations,
      'failed_validations': _failedValidations,
      'failure_rate_percent': failureRate,
      'recent_failures_1h': recentFailures,
      'active_rules': _rules.where((r) => r.isEnabled).length,
      'total_rules': _rules.length,
      'average_performance': _calculateAveragePerformance(),
      'last_validation': _recentResults.isNotEmpty 
          ? _recentResults.last.timestamp.toIso8601String()
          : null,
    };
  }

  /// Get recent validation failures
  List<ValidationResult> getRecentFailures({
    Duration? since,
    ValidationSeverity? minSeverity,
    int? limit,
  }) {
    final cutoff = since != null 
        ? DateTime.now().subtract(since)
        : DateTime.now().subtract(const Duration(days: 1));

    var failures = _recentResults
        .where((r) => !r.isValid && r.timestamp.isAfter(cutoff))
        .toList();

    if (minSeverity != null) {
      final minIndex = ValidationSeverity.values.indexOf(minSeverity);
      failures = failures
          .where((r) => ValidationSeverity.values.indexOf(r.severity) >= minIndex)
          .toList();
    }

    // Sort by timestamp (most recent first)
    failures.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && failures.length > limit) {
      failures = failures.take(limit).toList();
    }

    return failures;
  }

  /// Export validation report
  Future<Map<String, dynamic>> exportValidationReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fromDate ??= DateTime.now().subtract(const Duration(days: 7));
    toDate ??= DateTime.now();

    final db = await _databaseService.database;
    
    // Get validation results for period
    final results = await db.query(
      'validation_results',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        fromDate.millisecondsSinceEpoch,
        toDate.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );

    final validationResults = results
        .map((r) => ValidationResult.fromJson(r))
        .toList();

    // Analyze results
    final totalCount = validationResults.length;
    final failureCount = validationResults.where((r) => !r.isValid).length;
    final successRate = totalCount > 0 ? ((totalCount - failureCount) / totalCount * 100) : 100.0;

    // Group by validation type
    final byType = <String, Map<String, int>>{};
    for (final result in validationResults) {
      byType.putIfAbsent(result.validationName, () => {'total': 0, 'failures': 0});
      byType[result.validationName]!['total'] = byType[result.validationName]!['total']! + 1;
      if (!result.isValid) {
        byType[result.validationName]!['failures'] = byType[result.validationName]!['failures']! + 1;
      }
    }

    // Group by severity
    final bySeverity = <String, int>{};
    for (final result in validationResults.where((r) => !r.isValid)) {
      bySeverity[result.severity.name] = (bySeverity[result.severity.name] ?? 0) + 1;
    }

    return {
      'period': {
        'from': fromDate.toIso8601String(),
        'to': toDate.toIso8601String(),
      },
      'summary': {
        'total_validations': totalCount,
        'total_failures': failureCount,
        'success_rate_percent': successRate,
      },
      'by_validation_type': byType,
      'by_severity': bySeverity,
      'recent_critical_failures': validationResults
          .where((r) => !r.isValid && r.severity == ValidationSeverity.critical)
          .take(10)
          .map((r) => {
            'validation_name': r.validationName,
            'error_message': r.errorMessage,
            'timestamp': r.timestamp.toIso8601String(),
            'context': r.context,
          })
          .toList(),
      'performance_metrics': _getPerformanceMetrics(),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // Private helper methods

  Future<void> _createValidationTables() async {
    final db = await _databaseService.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS validation_results (
        id TEXT PRIMARY KEY,
        validation_name TEXT NOT NULL,
        is_valid INTEGER NOT NULL,
        error_message TEXT,
        context TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        execution_time_ms INTEGER NOT NULL,
        severity TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS validation_rules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        description TEXT NOT NULL,
        is_enabled INTEGER DEFAULT 1,
        timeout_ms INTEGER,
        configuration TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_validation_results_timestamp ON validation_results(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_validation_results_name ON validation_results(validation_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_validation_results_valid ON validation_results(is_valid)');
  }

  Future<void> _registerBuiltInRules() async {
    // Data integrity rules
    registerRule(ValidationRule(
      id: 'customer_name_not_null',
      name: 'Customer Name Not Null',
      type: ValidationType.nullSafety,
      severity: ValidationSeverity.error,
      description: 'Ensures customer names are not null or empty',
      validator: _validateCustomerNamesNotNull,
      timeout: const Duration(seconds: 10),
    ));

    registerRule(ValidationRule(
      id: 'invoice_amount_positive',
      name: 'Invoice Amount Positive',
      type: ValidationType.businessRule,
      severity: ValidationSeverity.error,
      description: 'Ensures invoice amounts are positive',
      validator: _validateInvoiceAmountsPositive,
      timeout: const Duration(seconds: 15),
    ));

    registerRule(ValidationRule(
      id: 'foreign_key_integrity',
      name: 'Foreign Key Integrity',
      type: ValidationType.dataIntegrity,
      severity: ValidationSeverity.critical,
      description: 'Validates all foreign key relationships',
      validator: _validateForeignKeyIntegrity,
      timeout: const Duration(seconds: 30),
    ));

    registerRule(ValidationRule(
      id: 'transaction_balance',
      name: 'Transaction Balance',
      type: ValidationType.businessRule,
      severity: ValidationSeverity.critical,
      description: 'Ensures accounting transactions are balanced',
      validator: _validateTransactionBalance,
      timeout: const Duration(seconds: 20),
    ));

    registerRule(ValidationRule(
      id: 'crdt_timestamp_consistency',
      name: 'CRDT Timestamp Consistency',
      type: ValidationType.crdtConsistency,
      severity: ValidationSeverity.warning,
      description: 'Validates CRDT timestamp consistency',
      validator: _validateCRDTTimestamps,
      timeout: const Duration(seconds: 25),
    ));

    registerRule(ValidationRule(
      id: 'database_schema_version',
      name: 'Database Schema Version',
      type: ValidationType.schemaConsistency,
      severity: ValidationSeverity.critical,
      description: 'Validates database schema version matches expected',
      validator: _validateDatabaseSchemaVersion,
      timeout: const Duration(seconds: 5),
    ));

    registerRule(ValidationRule(
      id: 'query_performance_threshold',
      name: 'Query Performance Threshold',
      type: ValidationType.performanceThreshold,
      severity: ValidationSeverity.warning,
      description: 'Validates query execution times are within thresholds',
      validator: _validateQueryPerformance,
      timeout: const Duration(seconds: 60),
    ));
  }

  Future<void> _startScheduledValidations() async {
    // Schedule critical validations to run every 5 minutes
    _scheduledValidations['critical'] = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _runScheduledValidations(ValidationSeverity.critical),
    );

    // Schedule error-level validations to run every 15 minutes
    _scheduledValidations['error'] = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _runScheduledValidations(ValidationSeverity.error),
    );

    // Schedule warning-level validations to run every hour
    _scheduledValidations['warning'] = Timer.periodic(
      const Duration(hours: 1),
      (_) => _runScheduledValidations(ValidationSeverity.warning),
    );
  }

  Future<void> _runScheduledValidations(ValidationSeverity minSeverity) async {
    try {
      final results = await runAllValidations(minSeverity: minSeverity);
      final failures = results.where((r) => !r.isValid).toList();
      
      if (failures.isNotEmpty && kDebugMode) {
        print('Scheduled validation found ${failures.length} failures');
        for (final failure in failures) {
          print('  - ${failure.validationName}: ${failure.errorMessage}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Scheduled validation failed: $e');
      }
    }
  }

  Future<ValidationResult> _runSingleValidation(
    ValidationRule rule,
    Map<String, dynamic> context,
  ) async {
    final stopwatch = Stopwatch()..start();
    final resultId = UuidGenerator.generateId();
    
    try {
      // Run validation with timeout
      final timeout = rule.timeout ?? defaultTimeout;
      final result = await rule.validator(context).timeout(timeout);
      
      stopwatch.stop();
      
      // Track performance
      _validationPerformance.putIfAbsent(rule.id, () => []);
      _validationPerformance[rule.id]!.add(stopwatch.elapsed);
      
      // Keep only recent performance data
      if (_validationPerformance[rule.id]!.length > 100) {
        _validationPerformance[rule.id]!.removeAt(0);
      }
      
      return ValidationResult(
        id: resultId,
        validationName: rule.name,
        isValid: result.isValid,
        errorMessage: result.errorMessage,
        context: {...context, ...result.context},
        timestamp: DateTime.now(),
        executionTime: stopwatch.elapsed,
        severity: rule.severity,
      );
    } catch (e) {
      stopwatch.stop();
      
      return ValidationResult(
        id: resultId,
        validationName: rule.name,
        isValid: false,
        errorMessage: 'Validation failed: ${e.toString()}',
        context: context,
        timestamp: DateTime.now(),
        executionTime: stopwatch.elapsed,
        severity: rule.severity,
      );
    }
  }

  Future<void> _storeValidationResults(List<ValidationResult> results) async {
    final db = await _databaseService.database;
    
    for (final result in results) {
      await db.insert(
        'validation_results',
        result.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _logCriticalOperationFailure(
    String operationName,
    List<ValidationResult> failures,
    Map<String, dynamic> context,
  ) async {
    if (kDebugMode) {
      print('Critical operation validation failed: $operationName');
      for (final failure in failures) {
        print('  - ${failure.validationName}: ${failure.errorMessage}');
      }
    }

    // Could trigger alerts, logging, or automatic remediation here
  }

  Map<String, dynamic> _calculateAveragePerformance() {
    final performance = <String, double>{};
    
    for (final entry in _validationPerformance.entries) {
      final durations = entry.value;
      if (durations.isNotEmpty) {
        final averageMs = durations
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a + b) / durations.length;
        performance[entry.key] = averageMs;
      }
    }
    
    return performance;
  }

  Map<String, dynamic> _getPerformanceMetrics() {
    final metrics = <String, dynamic>{};
    
    for (final entry in _validationPerformance.entries) {
      final durations = entry.value.map((d) => d.inMilliseconds).toList();
      if (durations.isNotEmpty) {
        durations.sort();
        final len = durations.length;
        
        metrics[entry.key] = {
          'count': len,
          'average_ms': durations.reduce((a, b) => a + b) / len,
          'median_ms': len % 2 == 0 
              ? (durations[len ~/ 2 - 1] + durations[len ~/ 2]) / 2
              : durations[len ~/ 2],
          'min_ms': durations.first,
          'max_ms': durations.last,
          'p95_ms': durations[(len * 0.95).floor()],
        };
      }
    }
    
    return metrics;
  }

  // Built-in validation rule implementations

  Future<ValidationResult> _validateCustomerNamesNotNull(Map<String, dynamic> context) async {
    final db = await _databaseService.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM customers_crdt 
      WHERE (name IS NULL OR name = '') AND is_deleted = 0
    ''');
    
    final nullCount = result.first['count'] as int;
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'Customer Name Not Null',
      isValid: nullCount == 0,
      errorMessage: nullCount > 0 ? '$nullCount customers have null/empty names' : null,
      context: {'null_count': nullCount},
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0), // Will be overridden
      severity: ValidationSeverity.error,
    );
  }

  Future<ValidationResult> _validateInvoiceAmountsPositive(Map<String, dynamic> context) async {
    final db = await _databaseService.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM invoices_crdt 
      WHERE total_amount < 0 AND is_deleted = 0
    ''');
    
    final negativeCount = result.first['count'] as int;
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'Invoice Amount Positive',
      isValid: negativeCount == 0,
      errorMessage: negativeCount > 0 ? '$negativeCount invoices have negative amounts' : null,
      context: {'negative_count': negativeCount},
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0),
      severity: ValidationSeverity.error,
    );
  }

  Future<ValidationResult> _validateForeignKeyIntegrity(Map<String, dynamic> context) async {
    final db = await _databaseService.database;
    
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'Foreign Key Integrity',
      isValid: violations.isEmpty,
      errorMessage: violations.isNotEmpty ? '${violations.length} foreign key violations found' : null,
      context: {'violations': violations},
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0),
      severity: ValidationSeverity.critical,
    );
  }

  Future<ValidationResult> _validateTransactionBalance(Map<String, dynamic> context) async {
    final db = await _databaseService.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM transactions_crdt 
      WHERE ABS(total_debit - total_credit) > 0.01 
        AND status = 'posted' 
        AND is_deleted = 0
    ''');
    
    final unbalancedCount = result.first['count'] as int;
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'Transaction Balance',
      isValid: unbalancedCount == 0,
      errorMessage: unbalancedCount > 0 ? '$unbalancedCount unbalanced transactions found' : null,
      context: {'unbalanced_count': unbalancedCount},
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0),
      severity: ValidationSeverity.critical,
    );
  }

  Future<ValidationResult> _validateCRDTTimestamps(Map<String, dynamic> context) async {
    final db = await _databaseService.database;
    
    final futureTimestamps = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM invoices_crdt 
      WHERE created_at > ? OR updated_at > ?
    ''', [
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    ]);
    
    final futureCount = futureTimestamps.first['count'] as int;
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'CRDT Timestamp Consistency',
      isValid: futureCount == 0,
      errorMessage: futureCount > 0 ? '$futureCount records have future timestamps' : null,
      context: {'future_timestamp_count': futureCount},
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0),
      severity: ValidationSeverity.warning,
    );
  }

  Future<ValidationResult> _validateDatabaseSchemaVersion(Map<String, dynamic> context) async {
    // This would check actual schema version against expected
    const expectedVersion = 1;
    const currentVersion = 1; // This would be fetched from database
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'Database Schema Version',
      isValid: currentVersion == expectedVersion,
      errorMessage: currentVersion != expectedVersion 
          ? 'Schema version mismatch: expected $expectedVersion, got $currentVersion' 
          : null,
      context: {
        'expected_version': expectedVersion,
        'current_version': currentVersion,
      },
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0),
      severity: ValidationSeverity.critical,
    );
  }

  Future<ValidationResult> _validateQueryPerformance(Map<String, dynamic> context) async {
    // This would analyze recent query performance
    final slowQueries = <String>[]; // This would be populated from actual monitoring
    
    return ValidationResult(
      id: UuidGenerator.generateId(),
      validationName: 'Query Performance Threshold',
      isValid: slowQueries.isEmpty,
      errorMessage: slowQueries.isNotEmpty 
          ? '${slowQueries.length} slow queries detected' 
          : null,
      context: {'slow_queries': slowQueries},
      timestamp: DateTime.now(),
      executionTime: const Duration(milliseconds: 0),
      severity: ValidationSeverity.warning,
    );
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _scheduledValidations.values) {
      timer.cancel();
    }
    _scheduledValidations.clear();
  }
}