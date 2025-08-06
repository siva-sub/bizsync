import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';
import '../database/crdt_database_service.dart';
import '../crdt/vector_clock.dart';
import '../crdt/hybrid_logical_clock.dart';

/// CRDT operation monitoring result
class CRDTMonitorResult {
  final String id;
  final String monitorName;
  final String tableName;
  final String? recordId;
  final CRDTIssueType issueType;
  final bool hasIssue;
  final String? description;
  final Map<String, dynamic> conflictDetails;
  final CRDTSeverity severity;
  final DateTime timestamp;
  final String? suggestedResolution;
  final List<String> affectedDevices;

  const CRDTMonitorResult({
    required this.id,
    required this.monitorName,
    required this.tableName,
    this.recordId,
    required this.issueType,
    required this.hasIssue,
    this.description,
    required this.conflictDetails,
    required this.severity,
    required this.timestamp,
    this.suggestedResolution,
    this.affectedDevices = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'monitor_name': monitorName,
      'table_name': tableName,
      'record_id': recordId,
      'issue_type': issueType.name,
      'has_issue': hasIssue,
      'description': description,
      'conflict_details': jsonEncode(conflictDetails),
      'severity': severity.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'suggested_resolution': suggestedResolution,
      'affected_devices': jsonEncode(affectedDevices),
    };
  }

  factory CRDTMonitorResult.fromJson(Map<String, dynamic> json) {
    return CRDTMonitorResult(
      id: json['id'] as String,
      monitorName: json['monitor_name'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String?,
      issueType: CRDTIssueType.values.firstWhere(
        (e) => e.name == json['issue_type'],
      ),
      hasIssue: json['has_issue'] as bool,
      description: json['description'] as String?,
      conflictDetails: jsonDecode(json['conflict_details'] as String) as Map<String, dynamic>,
      severity: CRDTSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      suggestedResolution: json['suggested_resolution'] as String?,
      affectedDevices: List<String>.from(
        jsonDecode(json['affected_devices'] as String) as List,
      ),
    );
  }
}

/// CRDT conflict severity levels
enum CRDTSeverity {
  info,
  warning,
  error,
  critical,
}

/// Types of CRDT issues
enum CRDTIssueType {
  conflictingUpdates,
  clockSkew,
  duplicateOperations,
  missingOperations,
  invalidVectorClock,
  staleData,
  syncPartition,
  concurrentDeletes,
  causalityViolation,
  mergeFailure,
}

/// CRDT operation metadata
class CRDTOperation {
  final String id;
  final String tableName;
  final String recordId;
  final String operationType; // insert, update, delete
  final Map<String, dynamic> operationData;
  final VectorClock vectorClock;
  final DateTime timestamp;
  final String deviceId;
  final String? causedBy; // ID of operation that caused this one

  const CRDTOperation({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operationType,
    required this.operationData,
    required this.vectorClock,
    required this.timestamp,
    required this.deviceId,
    this.causedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_name': tableName,
      'record_id': recordId,
      'operation_type': operationType,
      'operation_data': jsonEncode(operationData),
      'vector_clock': vectorClock.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'device_id': deviceId,
      'caused_by': causedBy,
    };
  }

  factory CRDTOperation.fromJson(Map<String, dynamic> json) {
    final deviceId = json['device_id'] as String;
    return CRDTOperation(
      id: json['id'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      operationType: json['operation_type'] as String,
      operationData: jsonDecode(json['operation_data'] as String) as Map<String, dynamic>,
      vectorClock: VectorClock.fromJson(
        jsonDecode(json['vector_clock'] as String) as Map<String, dynamic>, 
        deviceId
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      deviceId: deviceId,
      causedBy: json['caused_by'] as String?,
    );
  }
}

/// CRDT conflict resolution strategy
enum ConflictResolutionStrategy {
  lastWriterWins,
  firstWriterWins,
  highestValue,
  lowestValue,
  merge,
  userChoice,
  customLogic,
}

/// CRDT synchronization state
class SyncState {
  final String deviceId;
  final Map<String, VectorClock> lastSyncClocks;
  final DateTime lastSyncTime;
  final bool isOnline;
  final int pendingOperations;

  const SyncState({
    required this.deviceId,
    required this.lastSyncClocks,
    required this.lastSyncTime,
    required this.isOnline,
    required this.pendingOperations,
  });
}

/// Comprehensive CRDT operations monitor
class CRDTMonitor {
  final CRDTDatabaseService _databaseService;
  final String _deviceId;
  final List<CRDTMonitorResult> _recentResults = [];
  final Map<String, List<CRDTOperation>> _operationHistory = {};
  final Map<String, SyncState> _deviceStates = {};
  
  // Monitoring configuration
  static const int maxOperationHistory = 1000;
  static const int maxRecentResults = 500;
  static const Duration clockSkewThreshold = Duration(minutes: 5);
  static const Duration staleDataThreshold = Duration(hours: 24);
  
  // Statistics
  int _totalOperations = 0;
  int _conflictsDetected = 0;
  int _conflictsResolved = 0;
  final Map<String, int> _conflictsByType = {};

  CRDTMonitor(this._databaseService, this._deviceId);

  /// Initialize the CRDT monitor
  Future<void> initialize() async {
    await _createMonitoringTables();
    await _loadOperationHistory();
    await _startPeriodicMonitoring();
    
    if (kDebugMode) {
      print('CRDTMonitor initialized for device: $_deviceId');
    }
  }

  /// Monitor a CRDT operation
  Future<CRDTMonitorResult> monitorOperation(CRDTOperation operation) async {
    // Store operation
    await _storeOperation(operation);
    
    // Add to history
    _operationHistory.putIfAbsent(operation.tableName, () => []);
    _operationHistory[operation.tableName]!.add(operation);
    
    // Trim history if needed
    if (_operationHistory[operation.tableName]!.length > maxOperationHistory) {
      _operationHistory[operation.tableName]!.removeAt(0);
    }
    
    _totalOperations++;

    // Check for conflicts and issues
    final result = await _analyzeOperation(operation);
    
    // Store monitoring result
    await _storeMonitorResult(result);
    
    // Keep recent results
    _recentResults.add(result);
    if (_recentResults.length > maxRecentResults) {
      _recentResults.removeAt(0);
    }

    // Update statistics
    if (result.hasIssue) {
      _conflictsDetected++;
      _conflictsByType[result.issueType.name] = 
          (_conflictsByType[result.issueType.name] ?? 0) + 1;
    }

    return result;
  }

  /// Detect conflicts for a specific record
  Future<List<CRDTMonitorResult>> detectConflicts(
    String tableName,
    String recordId, {
    Duration? timeWindow,
  }) async {
    final conflicts = <CRDTMonitorResult>[];
    
    timeWindow ??= const Duration(hours: 1);
    final cutoff = DateTime.now().subtract(timeWindow);
    
    // Get recent operations for this record
    final operations = _operationHistory[tableName]
        ?.where((op) => op.recordId == recordId && op.timestamp.isAfter(cutoff))
        .toList() ?? [];
    
    if (operations.length < 2) return conflicts;

    // Check for concurrent operations
    final concurrentOps = _findConcurrentOperations(operations);
    
    for (final conflictPair in concurrentOps) {
      final conflict = await _analyzeConflict(conflictPair[0], conflictPair[1]);
      if (conflict.hasIssue) {
        conflicts.add(conflict);
      }
    }

    return conflicts;
  }

  /// Resolve conflicts using specified strategy
  Future<Map<String, dynamic>> resolveConflicts(
    List<CRDTMonitorResult> conflicts,
    ConflictResolutionStrategy strategy, {
    bool dryRun = true,
  }) async {
    final resolutionResults = <String, dynamic>{
      'total_conflicts': conflicts.length,
      'resolved_conflicts': 0,
      'failed_resolutions': 0,
      'dry_run': dryRun,
      'strategy': strategy.name,
      'details': <Map<String, dynamic>>[],
    };

    for (final conflict in conflicts) {
      try {
        final resolution = await _resolveConflict(conflict, strategy, dryRun);
        
        resolutionResults['details'].add({
          'conflict_id': conflict.id,
          'resolved': resolution['success'],
          'resolution_method': resolution['method'],
          'result_data': resolution['result'],
        });
        
        if (resolution['success']) {
          resolutionResults['resolved_conflicts'] = 
              (resolutionResults['resolved_conflicts'] as int) + 1;
          
          if (!dryRun) {
            _conflictsResolved++;
          }
        } else {
          resolutionResults['failed_resolutions'] = 
              (resolutionResults['failed_resolutions'] as int) + 1;
        }
      } catch (e) {
        resolutionResults['failed_resolutions'] = 
            (resolutionResults['failed_resolutions'] as int) + 1;
        
        resolutionResults['details'].add({
          'conflict_id': conflict.id,
          'resolved': false,
          'error': e.toString(),
        });
      }
    }

    return resolutionResults;
  }

  /// Get synchronization health status
  Future<Map<String, dynamic>> getSyncHealthStatus() async {
    final db = await _databaseService.database;
    
    // Check for recent operations
    final recentOpsResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM crdt_operations 
      WHERE timestamp > ?
    ''', [DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch]);
    
    final recentOpsCount = recentOpsResult.first['count'] as int;
    
    // Check for unresolved conflicts
    final conflictsResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM crdt_monitor_results 
      WHERE has_issue = 1 AND timestamp > ?
    ''', [DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch]);
    
    final unresolvedConflicts = conflictsResult.first['count'] as int;
    
    // Check clock synchronization
    final clockHealth = await _checkClockSynchronization();
    
    // Calculate health score
    final healthScore = _calculateSyncHealthScore(
      recentOpsCount,
      unresolvedConflicts,
      clockHealth,
    );

    return {
      'health_score': healthScore,
      'recent_operations': recentOpsCount,
      'unresolved_conflicts': unresolvedConflicts,
      'clock_synchronization': clockHealth,
      'device_states': _deviceStates.map((k, v) => MapEntry(k, {
        'last_sync': v.lastSyncTime.toIso8601String(),
        'is_online': v.isOnline,
        'pending_operations': v.pendingOperations,
      })),
      'total_operations': _totalOperations,
      'conflicts_detected': _conflictsDetected,
      'conflicts_resolved': _conflictsResolved,
      'conflict_rate': _totalOperations > 0 ? (_conflictsDetected / _totalOperations * 100) : 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get CRDT statistics
  Map<String, dynamic> getCRDTStatistics() {
    final conflictRate = _totalOperations > 0 
        ? (_conflictsDetected / _totalOperations * 100) 
        : 0.0;
    
    final resolutionRate = _conflictsDetected > 0 
        ? (_conflictsResolved / _conflictsDetected * 100) 
        : 0.0;

    return {
      'total_operations': _totalOperations,
      'conflicts_detected': _conflictsDetected,
      'conflicts_resolved': _conflictsResolved,
      'conflict_rate_percent': conflictRate,
      'resolution_rate_percent': resolutionRate,
      'conflicts_by_type': Map.from(_conflictsByType),
      'active_devices': _deviceStates.length,
      'online_devices': _deviceStates.values.where((s) => s.isOnline).length,
      'pending_operations_total': _deviceStates.values
          .fold<int>(0, (sum, state) => sum + state.pendingOperations),
      'last_operation': _recentResults.isNotEmpty 
          ? _recentResults.last.timestamp.toIso8601String() 
          : null,
    };
  }

  /// Export CRDT monitoring report
  Future<Map<String, dynamic>> exportCRDTReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fromDate ??= DateTime.now().subtract(const Duration(days: 7));
    toDate ??= DateTime.now();

    final db = await _databaseService.database;
    
    // Get operations for period
    final operations = await db.query(
      'crdt_operations',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        fromDate.millisecondsSinceEpoch,
        toDate.millisecondsSinceEpoch,
      ],
    );

    // Get monitoring results for period
    final monitorResults = await db.query(
      'crdt_monitor_results',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        fromDate.millisecondsSinceEpoch,
        toDate.millisecondsSinceEpoch,
      ],
    );

    final syncHealth = await getSyncHealthStatus();
    final statistics = getCRDTStatistics();

    return {
      'period': {
        'from': fromDate.toIso8601String(),
        'to': toDate.toIso8601String(),
      },
      'summary': {
        'total_operations': operations.length,
        'total_conflicts': monitorResults.where((r) => r['has_issue'] == 1).length,
        'conflict_types': _groupConflictsByType(monitorResults),
        'operations_by_table': _groupOperationsByTable(operations),
        'operations_by_device': _groupOperationsByDevice(operations),
      },
      'sync_health': syncHealth,
      'statistics': statistics,
      'top_conflicts': monitorResults
          .where((r) => r['has_issue'] == 1)
          .take(20)
          .map((r) => {
            'id': r['id'],
            'monitor_name': r['monitor_name'],
            'table_name': r['table_name'],
            'issue_type': r['issue_type'],
            'severity': r['severity'],
            'description': r['description'],
            'timestamp': DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int).toIso8601String(),
          })
          .toList(),
      'recommendations': await _generateRecommendations(monitorResults),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // Private helper methods

  Future<void> _createMonitoringTables() async {
    final db = await _databaseService.database;

    // CRDT operations table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS crdt_operations (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        operation_data TEXT NOT NULL,
        vector_clock TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        caused_by TEXT
      )
    ''');

    // CRDT monitor results table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS crdt_monitor_results (
        id TEXT PRIMARY KEY,
        monitor_name TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT,
        issue_type TEXT NOT NULL,
        has_issue INTEGER NOT NULL,
        description TEXT,
        conflict_details TEXT NOT NULL,
        severity TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        suggested_resolution TEXT,
        affected_devices TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_crdt_ops_table_record ON crdt_operations(table_name, record_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_crdt_ops_timestamp ON crdt_operations(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_crdt_ops_device ON crdt_operations(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_crdt_monitor_timestamp ON crdt_monitor_results(timestamp)');
  }

  Future<void> _loadOperationHistory() async {
    final db = await _databaseService.database;
    
    // Load recent operations
    final recentOps = await db.query(
      'crdt_operations',
      where: 'timestamp > ?',
      whereArgs: [DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
      limit: maxOperationHistory,
    );

    for (final opData in recentOps) {
      final operation = CRDTOperation.fromJson(opData);
      _operationHistory.putIfAbsent(operation.tableName, () => []);
      _operationHistory[operation.tableName]!.add(operation);
    }
  }

  Future<void> _startPeriodicMonitoring() async {
    // Run periodic health checks
    Timer.periodic(const Duration(minutes: 10), (_) => _performHealthCheck());
    
    // Run conflict detection
    Timer.periodic(const Duration(minutes: 5), (_) => _performConflictScan());
    
    // Clean up old data
    Timer.periodic(const Duration(hours: 6), (_) => _cleanupOldData());
  }

  Future<void> _storeOperation(CRDTOperation operation) async {
    final db = await _databaseService.database;
    await db.insert('crdt_operations', operation.toJson());
  }

  Future<void> _storeMonitorResult(CRDTMonitorResult result) async {
    final db = await _databaseService.database;
    await db.insert('crdt_monitor_results', result.toJson());
  }

  Future<CRDTMonitorResult> _analyzeOperation(CRDTOperation operation) async {
    // Check for various CRDT issues
    
    // Check for conflicting updates
    final conflictingOps = await _findConflictingOperations(operation);
    if (conflictingOps.isNotEmpty) {
      return CRDTMonitorResult(
        id: UuidGenerator.generateId(),
        monitorName: 'Conflicting Updates Detection',
        tableName: operation.tableName,
        recordId: operation.recordId,
        issueType: CRDTIssueType.conflictingUpdates,
        hasIssue: true,
        description: 'Found ${conflictingOps.length} conflicting operations',
        conflictDetails: {
          'operation_id': operation.id,
          'conflicting_operations': conflictingOps.map((op) => op.id).toList(),
          'conflict_count': conflictingOps.length,
        },
        severity: CRDTSeverity.error,
        timestamp: DateTime.now(),
        suggestedResolution: 'Apply conflict resolution strategy',
        affectedDevices: conflictingOps.map((op) => op.deviceId).toSet().toList(),
      );
    }

    // Check for clock skew
    final clockSkew = _detectClockSkew(operation);
    if (clockSkew > clockSkewThreshold) {
      return CRDTMonitorResult(
        id: UuidGenerator.generateId(),
        monitorName: 'Clock Skew Detection',
        tableName: operation.tableName,
        recordId: operation.recordId,
        issueType: CRDTIssueType.clockSkew,
        hasIssue: true,
        description: 'Clock skew detected: ${clockSkew.inMinutes} minutes',
        conflictDetails: {
          'operation_id': operation.id,
          'device_id': operation.deviceId,
          'skew_minutes': clockSkew.inMinutes,
          'operation_timestamp': operation.timestamp.toIso8601String(),
        },
        severity: clockSkew > const Duration(hours: 1) 
            ? CRDTSeverity.critical 
            : CRDTSeverity.warning,
        timestamp: DateTime.now(),
        suggestedResolution: 'Synchronize device clocks',
        affectedDevices: [operation.deviceId],
      );
    }

    // Check for causality violations
    final causalityViolation = await _detectCausalityViolation(operation);
    if (causalityViolation != null) {
      return causalityViolation;
    }

    // No issues detected
    return CRDTMonitorResult(
      id: UuidGenerator.generateId(),
      monitorName: 'Operation Analysis',
      tableName: operation.tableName,
      recordId: operation.recordId,
      issueType: CRDTIssueType.conflictingUpdates, // Default type
      hasIssue: false,
      conflictDetails: {
        'operation_id': operation.id,
        'status': 'healthy',
      },
      severity: CRDTSeverity.info,
      timestamp: DateTime.now(),
    );
  }

  Future<List<CRDTOperation>> _findConflictingOperations(CRDTOperation operation) async {
    final conflicting = <CRDTOperation>[];
    
    final recentOps = _operationHistory[operation.tableName]
        ?.where((op) => 
            op.recordId == operation.recordId &&
            op.id != operation.id &&
            op.timestamp.isAfter(DateTime.now().subtract(const Duration(minutes: 30))))
        .toList() ?? [];

    for (final otherOp in recentOps) {
      if (_areOperationsConflicting(operation, otherOp)) {
        conflicting.add(otherOp);
      }
    }

    return conflicting;
  }

  bool _areOperationsConflicting(CRDTOperation op1, CRDTOperation op2) {
    // Check if operations are concurrent and modify the same fields
    final areConcurrent = !op1.vectorClock.happensBefore(op2.vectorClock) &&
                         !op2.vectorClock.happensBefore(op1.vectorClock);
    
    if (!areConcurrent) return false;

    // Check if they modify the same fields
    final op1Fields = op1.operationData.keys.toSet();
    final op2Fields = op2.operationData.keys.toSet();
    
    return op1Fields.intersection(op2Fields).isNotEmpty;
  }

  Duration _detectClockSkew(CRDTOperation operation) {
    final now = DateTime.now();
    final opTime = operation.timestamp;
    
    if (opTime.isAfter(now)) {
      return opTime.difference(now);
    } else {
      return now.difference(opTime);
    }
  }

  Future<CRDTMonitorResult?> _detectCausalityViolation(CRDTOperation operation) async {
    // Check if this operation claims to happen before a causally dependent operation
    if (operation.causedBy != null) {
      final causingOp = await _findOperationById(operation.causedBy!);
      if (causingOp != null) {
        if (operation.vectorClock.happensBefore(causingOp.vectorClock)) {
          return CRDTMonitorResult(
            id: UuidGenerator.generateId(),
            monitorName: 'Causality Violation Detection',
            tableName: operation.tableName,
            recordId: operation.recordId,
            issueType: CRDTIssueType.causalityViolation,
            hasIssue: true,
            description: 'Operation happens before its cause',
            conflictDetails: {
              'operation_id': operation.id,
              'causing_operation_id': operation.causedBy,
              'operation_clock': operation.vectorClock.toJson(),
              'causing_clock': causingOp.vectorClock.toJson(),
            },
            severity: CRDTSeverity.critical,
            timestamp: DateTime.now(),
            suggestedResolution: 'Fix vector clock ordering',
            affectedDevices: [operation.deviceId, causingOp.deviceId],
          );
        }
      }
    }
    
    return null;
  }

  Future<CRDTOperation?> _findOperationById(String operationId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'crdt_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
    
    if (result.isNotEmpty) {
      return CRDTOperation.fromJson(result.first);
    }
    
    return null;
  }

  List<List<CRDTOperation>> _findConcurrentOperations(List<CRDTOperation> operations) {
    final concurrent = <List<CRDTOperation>>[];
    
    for (int i = 0; i < operations.length; i++) {
      for (int j = i + 1; j < operations.length; j++) {
        final op1 = operations[i];
        final op2 = operations[j];
        
        if (_areOperationsConflicting(op1, op2)) {
          concurrent.add([op1, op2]);
        }
      }
    }
    
    return concurrent;
  }

  Future<CRDTMonitorResult> _analyzeConflict(CRDTOperation op1, CRDTOperation op2) async {
    return CRDTMonitorResult(
      id: UuidGenerator.generateId(),
      monitorName: 'Conflict Analysis',
      tableName: op1.tableName,
      recordId: op1.recordId,
      issueType: CRDTIssueType.conflictingUpdates,
      hasIssue: true,
      description: 'Concurrent operations detected',
      conflictDetails: {
        'operation_1': op1.id,
        'operation_2': op2.id,
        'device_1': op1.deviceId,
        'device_2': op2.deviceId,
        'timestamp_diff_ms': (op1.timestamp.millisecondsSinceEpoch - op2.timestamp.millisecondsSinceEpoch).abs(),
      },
      severity: CRDTSeverity.error,
      timestamp: DateTime.now(),
      suggestedResolution: 'Apply conflict resolution strategy',
      affectedDevices: [op1.deviceId, op2.deviceId],
    );
  }

  Future<Map<String, dynamic>> _resolveConflict(
    CRDTMonitorResult conflict,
    ConflictResolutionStrategy strategy,
    bool dryRun,
  ) async {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriterWins:
        return await _resolveWithLastWriterWins(conflict, dryRun);
      case ConflictResolutionStrategy.firstWriterWins:
        return await _resolveWithFirstWriterWins(conflict, dryRun);
      case ConflictResolutionStrategy.merge:
        return await _resolveWithMerge(conflict, dryRun);
      default:
        return {
          'success': false,
          'method': strategy.name,
          'error': 'Resolution strategy not implemented',
        };
    }
  }

  Future<Map<String, dynamic>> _resolveWithLastWriterWins(
    CRDTMonitorResult conflict,
    bool dryRun,
  ) async {
    // Get the conflicting operations
    final op1Id = conflict.conflictDetails['operation_1'] as String?;
    final op2Id = conflict.conflictDetails['operation_2'] as String?;
    
    if (op1Id == null || op2Id == null) {
      return {'success': false, 'method': 'last_writer_wins', 'error': 'Missing operation IDs'};
    }

    final op1 = await _findOperationById(op1Id);
    final op2 = await _findOperationById(op2Id);
    
    if (op1 == null || op2 == null) {
      return {'success': false, 'method': 'last_writer_wins', 'error': 'Operations not found'};
    }

    // Choose the later operation
    final winningOp = op1.timestamp.isAfter(op2.timestamp) ? op1 : op2;
    
    if (!dryRun) {
      // Apply the winning operation's data
      await _applyOperation(winningOp);
    }

    return {
      'success': true,
      'method': 'last_writer_wins',
      'winning_operation': winningOp.id,
      'winning_timestamp': winningOp.timestamp.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _resolveWithFirstWriterWins(
    CRDTMonitorResult conflict,
    bool dryRun,
  ) async {
    // Similar to last writer wins but choose the earlier operation
    final op1Id = conflict.conflictDetails['operation_1'] as String?;
    final op2Id = conflict.conflictDetails['operation_2'] as String?;
    
    if (op1Id == null || op2Id == null) {
      return {'success': false, 'method': 'first_writer_wins', 'error': 'Missing operation IDs'};
    }

    final op1 = await _findOperationById(op1Id);
    final op2 = await _findOperationById(op2Id);
    
    if (op1 == null || op2 == null) {
      return {'success': false, 'method': 'first_writer_wins', 'error': 'Operations not found'};
    }

    // Choose the earlier operation
    final winningOp = op1.timestamp.isBefore(op2.timestamp) ? op1 : op2;
    
    if (!dryRun) {
      await _applyOperation(winningOp);
    }

    return {
      'success': true,
      'method': 'first_writer_wins',
      'winning_operation': winningOp.id,
      'winning_timestamp': winningOp.timestamp.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _resolveWithMerge(
    CRDTMonitorResult conflict,
    bool dryRun,
  ) async {
    // Implement semantic merge of conflicting operations
    return {
      'success': false,
      'method': 'merge',
      'error': 'Merge resolution not yet implemented',
    };
  }

  Future<void> _applyOperation(CRDTOperation operation) async {
    final db = await _databaseService.database;
    
    switch (operation.operationType) {
      case 'insert':
        await db.insert(operation.tableName, operation.operationData);
        break;
      case 'update':
        await db.update(
          operation.tableName,
          operation.operationData,
          where: 'id = ?',
          whereArgs: [operation.recordId],
        );
        break;
      case 'delete':
        await db.delete(
          operation.tableName,
          where: 'id = ?',
          whereArgs: [operation.recordId],
        );
        break;
    }
  }

  Future<Map<String, dynamic>> _checkClockSynchronization() async {
    // Check clock synchronization across devices
    final deviceClocks = <String, DateTime>{};
    
    for (final tableOps in _operationHistory.values) {
      for (final op in tableOps) {
        if (!deviceClocks.containsKey(op.deviceId) || 
            op.timestamp.isAfter(deviceClocks[op.deviceId]!)) {
          deviceClocks[op.deviceId] = op.timestamp;
        }
      }
    }

    final now = DateTime.now();
    final clockSkews = <String, int>{};
    var maxSkew = 0;
    
    for (final entry in deviceClocks.entries) {
      final skewMs = (now.millisecondsSinceEpoch - entry.value.millisecondsSinceEpoch).abs();
      clockSkews[entry.key] = skewMs;
      if (skewMs > maxSkew) maxSkew = skewMs;
    }

    return {
      'max_skew_ms': maxSkew,
      'device_skews': clockSkews,
      'is_synchronized': maxSkew < clockSkewThreshold.inMilliseconds,
      'synchronized_devices': clockSkews.values.where((skew) => skew < clockSkewThreshold.inMilliseconds).length,
      'total_devices': clockSkews.length,
    };
  }

  double _calculateSyncHealthScore(
    int recentOps,
    int unresolvedConflicts,
    Map<String, dynamic> clockHealth,
  ) {
    var score = 100.0;
    
    // Penalize for unresolved conflicts
    if (unresolvedConflicts > 0) {
      score -= min(unresolvedConflicts * 5, 30);
    }
    
    // Penalize for clock synchronization issues
    final isSynchronized = clockHealth['is_synchronized'] as bool;
    if (!isSynchronized) {
      score -= 20;
    }
    
    // Boost for recent activity (shows healthy sync)
    if (recentOps > 0) {
      score += min(recentOps * 0.1, 10);
    }
    
    return max(0, min(100, score));
  }

  Future<void> _performHealthCheck() async {
    // Implement periodic health checks
    try {
      final health = await getSyncHealthStatus();
      
      if ((health['health_score'] as double) < 70) {
        if (kDebugMode) {
          print('CRDT health warning: score ${health['health_score']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Health check failed: $e');
      }
    }
  }

  Future<void> _performConflictScan() async {
    // Scan for new conflicts
    try {
      for (final tableName in _operationHistory.keys) {
        final recentOps = _operationHistory[tableName]!
            .where((op) => op.timestamp.isAfter(DateTime.now().subtract(const Duration(minutes: 10))))
            .toList();
        
        for (final op in recentOps) {
          await _analyzeOperation(op);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Conflict scan failed: $e');
      }
    }
  }

  Future<void> _cleanupOldData() async {
    final db = await _databaseService.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    
    // Clean up old operations
    await db.delete(
      'crdt_operations',
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    
    // Clean up old monitor results
    await db.delete(
      'crdt_monitor_results',
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Map<String, int> _groupConflictsByType(List<Map<String, dynamic>> results) {
    final groups = <String, int>{};
    for (final result in results.where((r) => r['has_issue'] == 1)) {
      final type = result['issue_type'] as String;
      groups[type] = (groups[type] ?? 0) + 1;
    }
    return groups;
  }

  Map<String, int> _groupOperationsByTable(List<Map<String, dynamic>> operations) {
    final groups = <String, int>{};
    for (final op in operations) {
      final table = op['table_name'] as String;
      groups[table] = (groups[table] ?? 0) + 1;
    }
    return groups;
  }

  Map<String, int> _groupOperationsByDevice(List<Map<String, dynamic>> operations) {
    final groups = <String, int>{};
    for (final op in operations) {
      final device = op['device_id'] as String;
      groups[device] = (groups[device] ?? 0) + 1;
    }
    return groups;
  }

  Future<List<Map<String, dynamic>>> _generateRecommendations(
    List<Map<String, dynamic>> monitorResults,
  ) async {
    final recommendations = <Map<String, dynamic>>[];
    
    // Count conflicts by type
    final conflictCounts = _groupConflictsByType(monitorResults);
    
    for (final entry in conflictCounts.entries) {
      if (entry.value > 5) { // Threshold for recommendation
        recommendations.add({
          'type': 'conflict_reduction',
          'issue_type': entry.key,
          'count': entry.value,
          'suggestion': _getConflictReductionSuggestion(entry.key),
          'priority': entry.value > 20 ? 'high' : 'medium',
        });
      }
    }
    
    return recommendations;
  }

  String _getConflictReductionSuggestion(String issueType) {
    switch (issueType) {
      case 'conflictingUpdates':
        return 'Consider implementing optimistic UI updates with conflict resolution';
      case 'clockSkew':
        return 'Synchronize device clocks using NTP or similar protocol';
      case 'causalityViolation':
        return 'Review vector clock implementation and operation ordering';
      default:
        return 'Review CRDT implementation for this issue type';
    }
  }
}