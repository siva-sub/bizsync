import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';
import '../database/crdt_database_service.dart';

/// Null safety validation result
class NullSafetyResult {
  final String id;
  final String checkName;
  final String tableName;
  final String? columnName;
  final bool isValid;
  final int? violationCount;
  final String? errorMessage;
  final Map<String, dynamic> details;
  final NullSafetySeverity severity;
  final DateTime timestamp;
  final String? suggestedFix;
  final List<String> sampleViolations;

  const NullSafetyResult({
    required this.id,
    required this.checkName,
    required this.tableName,
    this.columnName,
    required this.isValid,
    this.violationCount,
    this.errorMessage,
    required this.details,
    required this.severity,
    required this.timestamp,
    this.suggestedFix,
    this.sampleViolations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'check_name': checkName,
      'table_name': tableName,
      'column_name': columnName,
      'is_valid': isValid,
      'violation_count': violationCount,
      'error_message': errorMessage,
      'details': jsonEncode(details),
      'severity': severity.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'suggested_fix': suggestedFix,
      'sample_violations': jsonEncode(sampleViolations),
    };
  }

  factory NullSafetyResult.fromJson(Map<String, dynamic> json) {
    return NullSafetyResult(
      id: json['id'] as String,
      checkName: json['check_name'] as String,
      tableName: json['table_name'] as String,
      columnName: json['column_name'] as String?,
      isValid: json['is_valid'] as bool,
      violationCount: json['violation_count'] as int?,
      errorMessage: json['error_message'] as String?,
      details: jsonDecode(json['details'] as String) as Map<String, dynamic>,
      severity: NullSafetySeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      suggestedFix: json['suggested_fix'] as String?,
      sampleViolations: List<String>.from(
        jsonDecode(json['sample_violations'] as String) as List,
      ),
    );
  }
}

/// Null safety severity levels
enum NullSafetySeverity {
  info,
  warning,
  error,
  critical,
}

/// Types of null safety violations
enum NullViolationType {
  nullRequiredField,
  emptyRequiredField,
  nullForeignKey,
  nullPrimaryKey,
  nullUniqueField,
  inconsistentNullState,
  nullCalculatedField,
  nullTimestamp,
}

/// Null safety rule definition
class NullSafetyRule {
  final String id;
  final String name;
  final String tableName;
  final String? columnName;
  final NullViolationType violationType;
  final NullSafetySeverity expectedSeverity;
  final String description;
  final String validationQuery;
  final String? fixQuery;
  final bool isRequired;
  final Map<String, dynamic>? configuration;

  const NullSafetyRule({
    required this.id,
    required this.name,
    required this.tableName,
    this.columnName,
    required this.violationType,
    required this.expectedSeverity,
    required this.description,
    required this.validationQuery,
    this.fixQuery,
    this.isRequired = true,
    this.configuration,
  });
}

/// Data integrity patterns for null safety
class DataIntegrityPattern {
  final String name;
  final String description;
  final List<String> affectedTables;
  final List<String> requiredColumns;
  final String validationLogic;
  final String remediation;

  const DataIntegrityPattern({
    required this.name,
    required this.description,
    required this.affectedTables,
    required this.requiredColumns,
    required this.validationLogic,
    required this.remediation,
  });
}

/// Comprehensive null safety validator
class NullSafetyValidator {
  final CRDTDatabaseService _databaseService;
  final List<NullSafetyRule> _rules = [];
  final List<DataIntegrityPattern> _patterns = [];
  final List<NullSafetyResult> _recentResults = [];
  
  // Statistics tracking
  int _totalChecks = 0;
  int _totalViolations = 0;
  final Map<String, int> _violationsByTable = {};
  final Map<String, int> _violationsByType = {};
  
  // Configuration
  static const int maxSampleViolations = 10;
  static const int maxRecentResults = 500;

  NullSafetyValidator(this._databaseService);

  /// Initialize the null safety validator
  Future<void> initialize() async {
    await _createNullSafetyTables();
    await _registerBuiltInRules();
    await _registerDataIntegrityPatterns();
    
    if (kDebugMode) {
      print('NullSafetyValidator initialized with ${_rules.length} rules');
    }
  }

  /// Register a custom null safety rule
  void registerRule(NullSafetyRule rule) {
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
  }

  /// Run all null safety validations
  Future<List<NullSafetyResult>> validateNullSafety({
    String? tableName,
    NullViolationType? violationType,
    NullSafetySeverity? minSeverity,
  }) async {
    final results = <NullSafetyResult>[];

    // Filter rules
    var rulesToRun = _rules.where((rule) {
      if (tableName != null && rule.tableName != tableName) return false;
      if (violationType != null && rule.violationType != violationType) return false;
      if (minSeverity != null) {
        final ruleIndex = NullSafetySeverity.values.indexOf(rule.expectedSeverity);
        final minIndex = NullSafetySeverity.values.indexOf(minSeverity);
        if (ruleIndex < minIndex) return false;
      }
      return true;
    }).toList();

    // Run validations
    for (final rule in rulesToRun) {
      try {
        final result = await _runSingleValidation(rule);
        results.add(result);
        
        // Update statistics
        _totalChecks++;
        if (!result.isValid) {
          _totalViolations++;
          _violationsByTable[result.tableName] = 
              (_violationsByTable[result.tableName] ?? 0) + (result.violationCount ?? 1);
          _violationsByType[rule.violationType.name] = 
              (_violationsByType[rule.violationType.name] ?? 0) + (result.violationCount ?? 1);
        }
      } catch (e) {
        results.add(NullSafetyResult(
          id: UuidGenerator.generateId(),
          checkName: rule.name,
          tableName: rule.tableName,
          columnName: rule.columnName,
          isValid: false,
          errorMessage: 'Validation failed: ${e.toString()}',
          details: {'error': e.toString()},
          severity: NullSafetySeverity.error,
          timestamp: DateTime.now(),
        ));
      }
    }

    // Store results
    await _storeResults(results);
    
    // Keep recent results in memory
    _recentResults.addAll(results);
    if (_recentResults.length > maxRecentResults) {
      _recentResults.removeRange(0, _recentResults.length - maxRecentResults);
    }

    return results;
  }

  /// Validate specific table for null safety
  Future<List<NullSafetyResult>> validateTable(String tableName) async {
    return await validateNullSafety(tableName: tableName);
  }

  /// Validate before critical operations
  Future<bool> validateBeforeOperation(
    String operationName,
    Map<String, dynamic> operationData, {
    List<String>? specificRules,
  }) async {
    final rulesToCheck = specificRules != null
        ? _rules.where((r) => specificRules.contains(r.id))
        : _rules.where((r) => r.expectedSeverity == NullSafetySeverity.critical);

    final results = <NullSafetyResult>[];
    
    for (final rule in rulesToCheck) {
      // Create dynamic validation based on operation data
      final dynamicRule = _createDynamicRule(rule, operationData);
      final result = await _runSingleValidation(dynamicRule);
      results.add(result);
    }

    final hasViolations = results.any((r) => !r.isValid);
    
    if (hasViolations) {
      await _logOperationViolations(operationName, results, operationData);
    }

    return !hasViolations;
  }

  /// Get null safety statistics
  Map<String, dynamic> getNullSafetyStatistics() {
    final violationRate = _totalChecks > 0 
        ? (_totalViolations / _totalChecks * 100) 
        : 0.0;

    final recentViolations = _recentResults
        .where((r) => !r.isValid && 
               r.timestamp.isAfter(DateTime.now().subtract(const Duration(hours: 24))))
        .length;

    return {
      'total_checks': _totalChecks,
      'total_violations': _totalViolations,
      'violation_rate_percent': violationRate,
      'recent_violations_24h': recentViolations,
      'violations_by_table': Map.from(_violationsByTable),
      'violations_by_type': Map.from(_violationsByType),
      'most_problematic_table': _getMostProblematicTable(),
      'most_common_violation': _getMostCommonViolationType(),
      'last_check': _recentResults.isNotEmpty 
          ? _recentResults.last.timestamp.toIso8601String() 
          : null,
    };
  }

  /// Get null safety recommendations
  Future<List<Map<String, dynamic>>> getNullSafetyRecommendations() async {
    final recommendations = <Map<String, dynamic>>[];
    final recentResults = await validateNullSafety();
    
    // Group violations by type and table
    final violationGroups = <String, List<NullSafetyResult>>{};
    for (final result in recentResults.where((r) => !r.isValid)) {
      final key = '${result.tableName}_${result.violationType}';
      violationGroups.putIfAbsent(key, () => []);
      violationGroups[key]!.add(result);
    }

    // Generate recommendations based on patterns
    for (final group in violationGroups.entries) {
      final violations = group.value;
      final firstViolation = violations.first;
      final totalCount = violations.fold<int>(0, (sum, v) => sum + (v.violationCount ?? 1));
      
      recommendations.add({
        'type': 'null_safety_fix',
        'table_name': firstViolation.tableName,
        'column_name': firstViolation.columnName,
        'violation_type': firstViolation.violationType?.name,
        'severity': firstViolation.severity.name,
        'total_violations': totalCount,
        'title': 'Fix ${firstViolation.checkName}',
        'description': firstViolation.errorMessage,
        'suggested_fix': firstViolation.suggestedFix,
        'priority': _calculatePriority(firstViolation.severity, totalCount),
        'estimated_effort': _estimateEffort(firstViolation.violationType, totalCount),
      });
    }

    // Add pattern-based recommendations
    for (final pattern in _patterns) {
      final patternViolations = recentResults.where((r) => 
          pattern.affectedTables.contains(r.tableName) && !r.isValid).toList();
      
      if (patternViolations.isNotEmpty) {
        recommendations.add({
          'type': 'data_integrity_pattern',
          'pattern_name': pattern.name,
          'description': pattern.description,
          'affected_tables': pattern.affectedTables,
          'violation_count': patternViolations.length,
          'remediation': pattern.remediation,
          'priority': 'medium',
        });
      }
    }

    // Sort by priority
    recommendations.sort((a, b) => _comparePriority(a['priority'], b['priority']));

    return recommendations;
  }

  /// Auto-fix null safety violations
  Future<Map<String, dynamic>> autoFixViolations({
    String? tableName,
    NullViolationType? violationType,
    bool dryRun = true,
  }) async {
    final results = await validateNullSafety(
      tableName: tableName,
      violationType: violationType,
    );
    
    final fixableViolations = results.where((r) => 
        !r.isValid && _getFixQueryForRule(r.checkName) != null).toList();
    
    final fixResults = <String, dynamic>{
      'total_violations': results.where((r) => !r.isValid).length,
      'fixable_violations': fixableViolations.length,
      'fixes_applied': 0,
      'fixes_failed': 0,
      'dry_run': dryRun,
      'details': <Map<String, dynamic>>[],
    };

    if (!dryRun) {
      final db = await _databaseService.database;
      
      for (final violation in fixableViolations) {
        try {
          final fixQuery = _getFixQueryForRule(violation.checkName);
          if (fixQuery != null) {
            await db.execute(fixQuery);
            fixResults['fixes_applied'] = (fixResults['fixes_applied'] as int) + 1;
            
            fixResults['details'].add({
              'violation_id': violation.id,
              'fix_applied': true,
              'fix_query': fixQuery,
            });
          }
        } catch (e) {
          fixResults['fixes_failed'] = (fixResults['fixes_failed'] as int) + 1;
          
          fixResults['details'].add({
            'violation_id': violation.id,
            'fix_applied': false,
            'error': e.toString(),
          });
        }
      }
    } else {
      // Dry run - just show what would be fixed
      for (final violation in fixableViolations) {
        final fixQuery = _getFixQueryForRule(violation.checkName);
        fixResults['details'].add({
          'violation_id': violation.id,
          'would_fix': true,
          'fix_query': fixQuery,
        });
      }
    }

    return fixResults;
  }

  /// Export null safety report
  Future<Map<String, dynamic>> exportNullSafetyReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fromDate ??= DateTime.now().subtract(const Duration(days: 7));
    toDate ??= DateTime.now();

    final results = await validateNullSafety();
    final statistics = getNullSafetyStatistics();
    final recommendations = await getNullSafetyRecommendations();

    return {
      'period': {
        'from': fromDate.toIso8601String(),
        'to': toDate.toIso8601String(),
      },
      'statistics': statistics,
      'total_violations': results.where((r) => !r.isValid).length,
      'violations_by_severity': _groupBySeverity(results),
      'violations_by_table': _groupByTable(results),
      'top_violations': results
          .where((r) => !r.isValid)
          .take(20)
          .map((r) => {
            'check_name': r.checkName,
            'table_name': r.tableName,
            'column_name': r.columnName,
            'violation_count': r.violationCount,
            'severity': r.severity.name,
            'error_message': r.errorMessage,
          })
          .toList(),
      'recommendations': recommendations,
      'data_integrity_patterns': _patterns.map((p) => {
        'name': p.name,
        'description': p.description,
        'affected_tables': p.affectedTables,
      }).toList(),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // Private helper methods

  Future<void> _createNullSafetyTables() async {
    final db = await _databaseService.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS null_safety_results (
        id TEXT PRIMARY KEY,
        check_name TEXT NOT NULL,
        table_name TEXT NOT NULL,
        column_name TEXT,
        is_valid INTEGER NOT NULL,
        violation_count INTEGER,
        error_message TEXT,
        details TEXT NOT NULL,
        severity TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        suggested_fix TEXT,
        sample_violations TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_null_safety_table ON null_safety_results(table_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_null_safety_timestamp ON null_safety_results(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_null_safety_valid ON null_safety_results(is_valid)');
  }

  Future<void> _registerBuiltInRules() async {
    // Customer null safety rules
    _rules.addAll([
      const NullSafetyRule(
        id: 'customer_name_required',
        name: 'Customer Name Required',
        tableName: 'customers_crdt',
        columnName: 'name',
        violationType: NullViolationType.nullRequiredField,
        expectedSeverity: NullSafetySeverity.error,
        description: 'Customer name cannot be null or empty',
        validationQuery: '''
          SELECT id, name FROM customers_crdt 
          WHERE (name IS NULL OR TRIM(name) = '') AND is_deleted = 0
        ''',
        fixQuery: '''
          UPDATE customers_crdt 
          SET name = 'Unknown Customer ' || substr(id, 1, 8)
          WHERE (name IS NULL OR TRIM(name) = '') AND is_deleted = 0
        ''',
      ),

      const NullSafetyRule(
        id: 'customer_email_format',
        name: 'Customer Email Format',
        tableName: 'customers_crdt',
        columnName: 'email',
        violationType: NullViolationType.emptyRequiredField,
        expectedSeverity: NullSafetySeverity.warning,
        description: 'Customer email should be valid format when provided',
        validationQuery: '''
          SELECT id, email FROM customers_crdt 
          WHERE email IS NOT NULL AND email != '' 
            AND email NOT LIKE '%@%.%' AND is_deleted = 0
        ''',
      ),

      const NullSafetyRule(
        id: 'customer_timestamps',
        name: 'Customer Timestamps Required',
        tableName: 'customers_crdt',
        violationType: NullViolationType.nullTimestamp,
        expectedSeverity: NullSafetySeverity.critical,
        description: 'Customer created_at and updated_at timestamps are required',
        validationQuery: '''
          SELECT id, created_at, updated_at FROM customers_crdt 
          WHERE (created_at IS NULL OR updated_at IS NULL) AND is_deleted = 0
        ''',
        fixQuery: '''
          UPDATE customers_crdt 
          SET created_at = COALESCE(created_at, strftime('%s', 'now') * 1000),
              updated_at = COALESCE(updated_at, strftime('%s', 'now') * 1000)
          WHERE (created_at IS NULL OR updated_at IS NULL) AND is_deleted = 0
        ''',
      ),
    ]);

    // Invoice null safety rules
    _rules.addAll([
      const NullSafetyRule(
        id: 'invoice_number_required',
        name: 'Invoice Number Required',
        tableName: 'invoices_crdt',
        columnName: 'invoice_number',
        violationType: NullViolationType.nullRequiredField,
        expectedSeverity: NullSafetySeverity.error,
        description: 'Invoice number cannot be null or empty',
        validationQuery: '''
          SELECT id, invoice_number FROM invoices_crdt 
          WHERE (invoice_number IS NULL OR TRIM(invoice_number) = '') AND is_deleted = 0
        ''',
        fixQuery: '''
          UPDATE invoices_crdt 
          SET invoice_number = 'INV-' || strftime('%Y%m%d', 'now') || '-' || substr(id, 1, 6)
          WHERE (invoice_number IS NULL OR TRIM(invoice_number) = '') AND is_deleted = 0
        ''',
      ),

      const NullSafetyRule(
        id: 'invoice_customer_fk',
        name: 'Invoice Customer Foreign Key',
        tableName: 'invoices_crdt',
        columnName: 'customer_id',
        violationType: NullViolationType.nullForeignKey,
        expectedSeverity: NullSafetySeverity.critical,
        description: 'Invoice must have a valid customer reference',
        validationQuery: '''
          SELECT i.id, i.customer_id FROM invoices_crdt i
          LEFT JOIN customers_crdt c ON i.customer_id = c.id
          WHERE i.customer_id IS NOT NULL AND c.id IS NULL AND i.is_deleted = 0
        ''',
      ),

      const NullSafetyRule(
        id: 'invoice_amount_required',
        name: 'Invoice Amount Required',
        tableName: 'invoices_crdt',
        columnName: 'total_amount',
        violationType: NullViolationType.nullCalculatedField,
        expectedSeverity: NullSafetySeverity.error,
        description: 'Invoice total amount cannot be null',
        validationQuery: '''
          SELECT id, total_amount FROM invoices_crdt 
          WHERE total_amount IS NULL AND is_deleted = 0
        ''',
        fixQuery: '''
          UPDATE invoices_crdt 
          SET total_amount = 0.0
          WHERE total_amount IS NULL AND is_deleted = 0
        ''',
      ),
    ]);

    // Product null safety rules
    _rules.addAll([
      const NullSafetyRule(
        id: 'product_name_required',
        name: 'Product Name Required',
        tableName: 'products_crdt',
        columnName: 'name',
        violationType: NullViolationType.nullRequiredField,
        expectedSeverity: NullSafetySeverity.error,
        description: 'Product name cannot be null or empty',
        validationQuery: '''
          SELECT id, name FROM products_crdt 
          WHERE (name IS NULL OR TRIM(name) = '') AND is_deleted = 0
        ''',
        fixQuery: '''
          UPDATE products_crdt 
          SET name = 'Product ' || substr(id, 1, 8)
          WHERE (name IS NULL OR TRIM(name) = '') AND is_deleted = 0
        ''',
      ),

      const NullSafetyRule(
        id: 'product_price_required',
        name: 'Product Price Required',
        tableName: 'products_crdt',
        columnName: 'price',
        violationType: NullViolationType.nullCalculatedField,
        expectedSeverity: NullSafetySeverity.error,
        description: 'Product price cannot be null',
        validationQuery: '''
          SELECT id, price FROM products_crdt 
          WHERE price IS NULL AND is_deleted = 0
        ''',
        fixQuery: '''
          UPDATE products_crdt 
          SET price = 0.0
          WHERE price IS NULL AND is_deleted = 0
        ''',
      ),
    ]);
  }

  Future<void> _registerDataIntegrityPatterns() async {
    _patterns.addAll([
      const DataIntegrityPattern(
        name: 'Customer-Invoice Relationship Integrity',
        description: 'Ensures all invoices have valid customer references and customer data is complete',
        affectedTables: ['customers_crdt', 'invoices_crdt'],
        requiredColumns: ['customers_crdt.name', 'invoices_crdt.customer_id'],
        validationLogic: 'Check foreign key relationships and required customer fields',
        remediation: 'Fix orphaned invoices and complete customer profiles',
      ),

      const DataIntegrityPattern(
        name: 'Financial Data Completeness',
        description: 'Ensures all financial calculations have valid non-null values',
        affectedTables: ['invoices_crdt', 'products_crdt'],
        requiredColumns: ['invoices_crdt.total_amount', 'products_crdt.price'],
        validationLogic: 'Check that monetary amounts are not null and are valid numbers',
        remediation: 'Set default values for null financial fields and recalculate totals',
      ),

      const DataIntegrityPattern(
        name: 'Timestamp Consistency',
        description: 'Ensures all records have valid creation and modification timestamps',
        affectedTables: ['customers_crdt', 'invoices_crdt', 'products_crdt'],
        requiredColumns: ['created_at', 'updated_at'],
        validationLogic: 'Check that timestamps are not null and updated_at >= created_at',
        remediation: 'Set missing timestamps to current time and fix chronological order',
      ),
    ]);
  }

  Future<NullSafetyResult> _runSingleValidation(NullSafetyRule rule) async {
    final db = await _databaseService.database;
    final stopwatch = Stopwatch()..start();

    try {
      final violations = await db.rawQuery(rule.validationQuery);
      stopwatch.stop();

      final violationCount = violations.length;
      final isValid = violationCount == 0;
      
      // Get sample violations
      final sampleViolations = violations
          .take(maxSampleViolations)
          .map((v) => v.toString())
          .toList();

      return NullSafetyResult(
        id: UuidGenerator.generateId(),
        checkName: rule.name,
        tableName: rule.tableName,
        columnName: rule.columnName,
        isValid: isValid,
        violationCount: violationCount,
        errorMessage: isValid ? null : 
            '$violationCount ${rule.violationType.name} violations found in ${rule.tableName}${rule.columnName != null ? '.${rule.columnName}' : ''}',
        details: {
          'rule_id': rule.id,
          'violation_type': rule.violationType.name,
          'query_execution_time_ms': stopwatch.elapsedMilliseconds,
          'sample_records': violations.take(5).toList(),
        },
        severity: rule.expectedSeverity,
        timestamp: DateTime.now(),
        suggestedFix: rule.fixQuery != null ? 'Run auto-fix query' : 
            'Manually correct ${rule.tableName}.${rule.columnName ?? 'records'}',
        sampleViolations: sampleViolations,
      );
    } catch (e) {
      stopwatch.stop();
      
      return NullSafetyResult(
        id: UuidGenerator.generateId(),
        checkName: rule.name,
        tableName: rule.tableName,
        columnName: rule.columnName,
        isValid: false,
        errorMessage: 'Validation query failed: ${e.toString()}',
        details: {
          'rule_id': rule.id,
          'error': e.toString(),
          'query': rule.validationQuery,
        },
        severity: NullSafetySeverity.error,
        timestamp: DateTime.now(),
      );
    }
  }

  NullSafetyRule _createDynamicRule(NullSafetyRule baseRule, Map<String, dynamic> operationData) {
    // Create a dynamic rule based on operation data
    // This could modify the validation query to check specific records
    var dynamicQuery = baseRule.validationQuery;
    
    // Add operation-specific filters
    if (operationData.containsKey('id')) {
      dynamicQuery = dynamicQuery.replaceAll(
        'WHERE',
        'WHERE id = \'${operationData['id']}\' AND',
      );
    }

    return NullSafetyRule(
      id: '${baseRule.id}_dynamic',
      name: '${baseRule.name} (Dynamic)',
      tableName: baseRule.tableName,
      columnName: baseRule.columnName,
      violationType: baseRule.violationType,
      expectedSeverity: baseRule.expectedSeverity,
      description: baseRule.description,
      validationQuery: dynamicQuery,
      fixQuery: baseRule.fixQuery,
      isRequired: baseRule.isRequired,
      configuration: operationData,
    );
  }

  Future<void> _storeResults(List<NullSafetyResult> results) async {
    final db = await _databaseService.database;

    for (final result in results) {
      await db.insert(
        'null_safety_results',
        result.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _logOperationViolations(
    String operationName,
    List<NullSafetyResult> violations,
    Map<String, dynamic> operationData,
  ) async {
    if (kDebugMode) {
      print('Null safety violations detected for operation: $operationName');
      for (final violation in violations.where((v) => !v.isValid)) {
        print('  - ${violation.checkName}: ${violation.errorMessage}');
      }
    }
  }

  String? _getFixQueryForRule(String ruleName) {
    final rule = _rules.firstWhere(
      (r) => r.name == ruleName,
      orElse: () => throw ArgumentError('Rule not found: $ruleName'),
    );
    return rule.fixQuery;
  }

  String? _getMostProblematicTable() {
    if (_violationsByTable.isEmpty) return null;
    
    return _violationsByTable.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String? _getMostCommonViolationType() {
    if (_violationsByType.isEmpty) return null;
    
    return _violationsByType.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String _calculatePriority(NullSafetySeverity severity, int violationCount) {
    if (severity == NullSafetySeverity.critical || violationCount > 100) {
      return 'critical';
    } else if (severity == NullSafetySeverity.error || violationCount > 50) {
      return 'high';
    } else if (severity == NullSafetySeverity.warning || violationCount > 10) {
      return 'medium';
    } else {
      return 'low';
    }
  }

  String _estimateEffort(NullViolationType? violationType, int violationCount) {
    if (violationType == null) return 'unknown';
    
    switch (violationType) {
      case NullViolationType.nullRequiredField:
      case NullViolationType.emptyRequiredField:
        return violationCount > 100 ? 'high' : 'medium';
      case NullViolationType.nullForeignKey:
      case NullViolationType.nullPrimaryKey:
        return 'high';
      case NullViolationType.nullTimestamp:
      case NullViolationType.nullCalculatedField:
        return 'low';
      default:
        return 'medium';
    }
  }

  int _comparePriority(dynamic a, dynamic b) {
    const priorityOrder = ['critical', 'high', 'medium', 'low'];
    final aIndex = priorityOrder.indexOf(a.toString());
    final bIndex = priorityOrder.indexOf(b.toString());
    return aIndex.compareTo(bIndex);
  }

  Map<String, int> _groupBySeverity(List<NullSafetyResult> results) {
    final groups = <String, int>{};
    for (final result in results.where((r) => !r.isValid)) {
      groups[result.severity.name] = (groups[result.severity.name] ?? 0) + 1;
    }
    return groups;
  }

  Map<String, int> _groupByTable(List<NullSafetyResult> results) {
    final groups = <String, int>{};
    for (final result in results.where((r) => !r.isValid)) {
      groups[result.tableName] = (groups[result.tableName] ?? 0) + (result.violationCount ?? 1);
    }
    return groups;
  }
}