import 'dart:async';
import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../error/exceptions.dart' as app_exceptions;

/// Transaction isolation levels
enum IsolationLevel {
  readUncommitted,
  readCommitted,
  repeatableRead,
  serializable,
}

/// Transaction operation types for audit trail
enum TransactionOperationType {
  insert,
  update,
  delete,
  select,
}

/// Represents a database operation within a transaction
class TransactionOperation {
  final String id;
  final String table;
  final String operation;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? whereClause;
  final HLCTimestamp timestamp;
  final String? rollbackSql;
  
  TransactionOperation({
    required this.id,
    required this.table,
    required this.operation,
    required this.data,
    this.whereClause,
    required this.timestamp,
    this.rollbackSql,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'operation': operation,
      'data': data,
      'where_clause': whereClause,
      'timestamp': timestamp.toString(),
      'rollback_sql': rollbackSql,
    };
  }
  
  factory TransactionOperation.fromJson(Map<String, dynamic> json) {
    return TransactionOperation(
      id: json['id'] as String,
      table: json['table'] as String,
      operation: json['operation'] as String,
      data: json['data'] as Map<String, dynamic>,
      whereClause: json['where_clause'] as Map<String, dynamic>?,
      timestamp: HLCTimestamp.fromString(json['timestamp'] as String),
      rollbackSql: json['rollback_sql'] as String?,
    );
  }
}

/// Represents a complete transaction with operations and metadata
class DatabaseTransaction {
  final String id;
  final List<TransactionOperation> operations;
  final HLCTimestamp startTime;
  final String nodeId;
  final IsolationLevel isolationLevel;
  HLCTimestamp? commitTime;
  String? status; // 'active', 'committed', 'aborted'
  
  DatabaseTransaction({
    required this.id,
    required this.nodeId,
    required this.startTime,
    this.isolationLevel = IsolationLevel.readCommitted,
  }) : operations = <TransactionOperation>[],
       status = 'active';
  
  void addOperation(TransactionOperation operation) {
    if (status != 'active') {
      throw app_exceptions.DatabaseException('Cannot add operations to non-active transaction');
    }
    operations.add(operation);
  }
  
  void commit(HLCTimestamp timestamp) {
    if (status != 'active') {
      throw app_exceptions.DatabaseException('Cannot commit non-active transaction');
    }
    commitTime = timestamp;
    status = 'committed';
  }
  
  void abort() {
    if (status != 'active') {
      throw app_exceptions.DatabaseException('Cannot abort non-active transaction');
    }
    status = 'aborted';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'start_time': startTime.toString(),
      'commit_time': commitTime?.toString(),
      'status': status,
      'isolation_level': isolationLevel.index,
      'operations': operations.map((op) => op.toJson()).toList(),
    };
  }
}

/// ACID-compliant transaction manager with rollback support
class TransactionManager {
  final Database _database;
  final HybridLogicalClock _clock;
  final Map<String, DatabaseTransaction> _activeTransactions = {};
  final Map<String, List<Map<String, dynamic>>> _savepoints = {};
  
  TransactionManager(this._database, this._clock);
  
  /// Begin a new transaction
  Future<DatabaseTransaction> beginTransaction({
    IsolationLevel isolationLevel = IsolationLevel.readCommitted,
  }) async {
    final transactionId = _generateTransactionId();
    final transaction = DatabaseTransaction(
      id: transactionId,
      nodeId: _clock.nodeId,
      startTime: _clock.tick(),
      isolationLevel: isolationLevel,
    );
    
    _activeTransactions[transactionId] = transaction;
    
    // Set SQLite isolation level
    await _setIsolationLevel(isolationLevel);
    
    // Start SQLite transaction
    await _database.execute('BEGIN IMMEDIATE');
    
    // Log transaction start
    await _logTransactionEvent(transaction, 'BEGIN');
    
    return transaction;
  }
  
  /// Execute an operation within a transaction
  Future<T> executeInTransaction<T>(
    DatabaseTransaction transaction,
    String table,
    String operation,
    Map<String, dynamic> data, {
    Map<String, dynamic>? whereClause,
    Future<T> Function()? customOperation,
  }) async {
    if (transaction.status != 'active') {
      throw app_exceptions.DatabaseException('Transaction is not active');
    }
    
    final operationId = _generateOperationId();
    final timestamp = _clock.tick();
    
    // Prepare rollback data before making changes
    String? rollbackSql;
    if (operation == 'UPDATE' || operation == 'DELETE') {
      rollbackSql = await _prepareRollbackData(table, whereClause);
    }
    
    // Create operation record
    final transactionOp = TransactionOperation(
      id: operationId,
      table: table,
      operation: operation,
      data: data,
      whereClause: whereClause,
      timestamp: timestamp,
      rollbackSql: rollbackSql,
    );
    
    transaction.addOperation(transactionOp);
    
    try {
      T result;
      
      if (customOperation != null) {
        result = await customOperation();
      } else {
        result = await _executeStandardOperation<T>(table, operation, data, whereClause);
      }
      
      // Log successful operation
      await _logOperationEvent(transactionOp, 'SUCCESS');
      
      return result;
    } catch (e) {
      // Log failed operation
      await _logOperationEvent(transactionOp, 'FAILED', e.toString());
      rethrow;
    }
  }
  
  /// Create a savepoint within a transaction
  Future<String> createSavepoint(DatabaseTransaction transaction, String name) async {
    if (transaction.status != 'active') {
      throw app_exceptions.DatabaseException('Transaction is not active');
    }
    
    final savepointId = '${transaction.id}_$name';
    
    // Save current state
    _savepoints[savepointId] = transaction.operations.map((op) => op.toJson()).toList();
    
    // Create SQLite savepoint
    await _database.execute('SAVEPOINT $name');
    
    await _logTransactionEvent(transaction, 'SAVEPOINT', {'name': name});
    
    return savepointId;
  }
  
  /// Rollback to a savepoint
  Future<void> rollbackToSavepoint(DatabaseTransaction transaction, String name) async {
    if (transaction.status != 'active') {
      throw app_exceptions.DatabaseException('Transaction is not active');
    }
    
    final savepointId = '${transaction.id}_$name';
    
    if (!_savepoints.containsKey(savepointId)) {
      throw app_exceptions.DatabaseException('Savepoint not found: $name');
    }
    
    // Rollback SQLite to savepoint
    await _database.execute('ROLLBACK TO SAVEPOINT $name');
    
    // Restore transaction operations to savepoint state
    final savedOperations = _savepoints[savepointId]!;
    transaction.operations.clear();
    transaction.operations.addAll(
      savedOperations.map((json) => TransactionOperation.fromJson(json)),
    );
    
    await _logTransactionEvent(transaction, 'ROLLBACK_TO_SAVEPOINT', {'name': name});
  }
  
  /// Commit a transaction
  Future<void> commitTransaction(DatabaseTransaction transaction) async {
    if (transaction.status != 'active') {
      throw app_exceptions.DatabaseException('Transaction is not active');
    }
    
    try {
      // Validate transaction integrity
      await _validateTransactionIntegrity(transaction);
      
      // Commit SQLite transaction
      await _database.execute('COMMIT');
      
      // Mark transaction as committed
      transaction.commit(_clock.tick());
      
      // Log transaction commit
      await _logTransactionEvent(transaction, 'COMMIT');
      
      // Clean up
      _activeTransactions.remove(transaction.id);
      _cleanupSavepoints(transaction.id);
      
    } catch (e) {
      // Auto-rollback on commit failure
      await rollbackTransaction(transaction);
      rethrow;
    }
  }
  
  /// Rollback a transaction
  Future<void> rollbackTransaction(DatabaseTransaction transaction) async {
    try {
      // Rollback SQLite transaction
      await _database.execute('ROLLBACK');
      
      // Execute custom rollback operations if needed
      await _executeRollbackOperations(transaction);
      
      // Mark transaction as aborted
      transaction.abort();
      
      // Log transaction rollback
      await _logTransactionEvent(transaction, 'ROLLBACK');
      
    } catch (e) {
      // Log rollback failure but don't rethrow to avoid masking original error
      await _logTransactionEvent(transaction, 'ROLLBACK_FAILED', {'error': e.toString()});
    } finally {
      // Clean up
      _activeTransactions.remove(transaction.id);
      _cleanupSavepoints(transaction.id);
    }
  }
  
  /// Execute operations within a transaction boundary
  Future<T> runInTransaction<T>(
    Future<T> Function(DatabaseTransaction) operation, {
    IsolationLevel isolationLevel = IsolationLevel.readCommitted,
  }) async {
    final transaction = await beginTransaction(isolationLevel: isolationLevel);
    
    try {
      final result = await operation(transaction);
      await commitTransaction(transaction);
      return result;
    } catch (e) {
      await rollbackTransaction(transaction);
      rethrow;
    }
  }
  
  /// Set SQLite isolation level
  Future<void> _setIsolationLevel(IsolationLevel level) async {
    switch (level) {
      case IsolationLevel.readUncommitted:
        await _database.execute('PRAGMA read_uncommitted = 1');
        break;
      case IsolationLevel.readCommitted:
        await _database.execute('PRAGMA read_uncommitted = 0');
        break;
      case IsolationLevel.repeatableRead:
      case IsolationLevel.serializable:
        // SQLite uses serializable by default with WAL mode
        await _database.execute('PRAGMA read_uncommitted = 0');
        break;
    }
  }
  
  /// Execute standard database operations
  Future<T> _executeStandardOperation<T>(
    String table,
    String operation,
    Map<String, dynamic> data,
    Map<String, dynamic>? whereClause,
  ) async {
    switch (operation.toUpperCase()) {
      case 'INSERT':
        final result = await _database.insert(table, data);
        return result as T;
      
      case 'UPDATE':
        final whereString = _buildWhereClause(whereClause);
        final result = await _database.update(
          table,
          data,
          where: whereString['clause'],
          whereArgs: whereString['args'],
        );
        return result as T;
      
      case 'DELETE':
        final whereString = _buildWhereClause(whereClause);
        final result = await _database.delete(
          table,
          where: whereString['clause'],
          whereArgs: whereString['args'],
        );
        return result as T;
      
      case 'SELECT':
        final whereString = _buildWhereClause(whereClause);
        final result = await _database.query(
          table,
          where: whereString['clause'],
          whereArgs: whereString['args'],
        );
        return result as T;
      
      default:
        throw app_exceptions.DatabaseException('Unsupported operation: $operation');
    }
  }
  
  /// Prepare rollback data for UPDATE/DELETE operations
  Future<String?> _prepareRollbackData(String table, Map<String, dynamic>? whereClause) async {
    if (whereClause == null) return null;
    
    final whereString = _buildWhereClause(whereClause);
    final existingData = await _database.query(
      table,
      where: whereString['clause'],
      whereArgs: whereString['args'],
    );
    
    if (existingData.isEmpty) return null;
    
    // Create INSERT statements to restore original data
    final rollbackStatements = <String>[];
    for (final row in existingData) {
      final columns = row.keys.join(', ');
      final values = row.values.map((v) => v is String ? "'$v'" : v.toString()).join(', ');
      rollbackStatements.add('INSERT INTO $table ($columns) VALUES ($values)');
    }
    
    return rollbackStatements.join('; ');
  }
  
  /// Execute rollback operations
  Future<void> _executeRollbackOperations(DatabaseTransaction transaction) async {
    // Execute custom rollback SQL if available
    for (final operation in transaction.operations.reversed) {
      if (operation.rollbackSql != null) {
        try {
          await _database.execute(operation.rollbackSql!);
        } catch (e) {
          // Log but don't fail the rollback
          print('Rollback operation failed: $e');
        }
      }
    }
  }
  
  /// Validate transaction integrity
  Future<void> _validateTransactionIntegrity(DatabaseTransaction transaction) async {
    // Check foreign key constraints
    final fkViolations = await _database.rawQuery('PRAGMA foreign_key_check');
    if (fkViolations.isNotEmpty) {
      throw app_exceptions.DatabaseException('Foreign key constraint violations: $fkViolations');
    }
    
    // Additional integrity checks can be added here
    // For example, check business rules, data consistency, etc.
  }
  
  /// Build WHERE clause string and arguments
  Map<String, dynamic> _buildWhereClause(Map<String, dynamic>? whereClause) {
    if (whereClause == null || whereClause.isEmpty) {
      return {'clause': null, 'args': null};
    }
    
    final conditions = <String>[];
    final args = <dynamic>[];
    
    for (final entry in whereClause.entries) {
      conditions.add('${entry.key} = ?');
      args.add(entry.value);
    }
    
    return {
      'clause': conditions.join(' AND '),
      'args': args,
    };
  }
  
  /// Log transaction events
  Future<void> _logTransactionEvent(
    DatabaseTransaction transaction,
    String event, [
    Map<String, dynamic>? metadata,
  ]) async {
    try {
      await _database.insert('transaction_log', {
        'transaction_id': transaction.id,
        'node_id': transaction.nodeId,
        'event': event,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
      });
    } catch (e) {
      // Don't fail transaction due to logging issues
      print('Failed to log transaction event: $e');
    }
  }
  
  /// Log operation events
  Future<void> _logOperationEvent(
    TransactionOperation operation,
    String event, [
    String? errorMessage,
  ]) async {
    try {
      await _database.insert('operation_log', {
        'operation_id': operation.id,
        'table_name': operation.table,
        'operation_type': operation.operation,
        'event': event,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'error_message': errorMessage,
      });
    } catch (e) {
      // Don't fail operation due to logging issues
      print('Failed to log operation event: $e');
    }
  }
  
  /// Clean up savepoints for a transaction
  void _cleanupSavepoints(String transactionId) {
    final keysToRemove = _savepoints.keys
        .where((key) => key.startsWith('${transactionId}_'))
        .toList();
    
    for (final key in keysToRemove) {
      _savepoints.remove(key);
    }
  }
  
  /// Generate unique transaction ID
  String _generateTransactionId() {
    return '${_clock.nodeId}_${DateTime.now().millisecondsSinceEpoch}_${_activeTransactions.length}';
  }
  
  /// Generate unique operation ID
  String _generateOperationId() {
    return '${_clock.nodeId}_${DateTime.now().microsecondsSinceEpoch}';
  }
  
  /// Get active transaction count
  int get activeTransactionCount => _activeTransactions.length;
  
  /// Get transaction by ID
  DatabaseTransaction? getTransaction(String transactionId) {
    return _activeTransactions[transactionId];
  }
  
  /// Check if a transaction is active
  bool isTransactionActive(String transactionId) {
    return _activeTransactions.containsKey(transactionId) &&
           _activeTransactions[transactionId]!.status == 'active';
  }
}