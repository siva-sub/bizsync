import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/database/crdt_database_service.dart';

/// Audit logging service for IRAS API operations
/// Ensures compliance and traceability for all tax operations
class IrasAuditService {
  final CRDTDatabaseService _database;
  static IrasAuditService? _instance;
  
  IrasAuditService._({CRDTDatabaseService? database}) 
      : _database = database ?? CRDTDatabaseService();
  
  /// Singleton instance
  static IrasAuditService get instance {
    _instance ??= IrasAuditService._();
    return _instance!;
  }
  
  /// Log a general operation
  Future<void> logOperation({
    required String operation,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? details,
    String? userId,
  }) async {
    await _logAuditEntry(
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      status: 'INITIATED',
      details: details,
      userId: userId,
    );
  }
  
  /// Log successful operation
  Future<void> logSuccess({
    required String operation,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? details,
    String? userId,
  }) async {
    await _logAuditEntry(
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      status: 'SUCCESS',
      details: details,
      userId: userId,
    );
  }
  
  /// Log failed operation
  Future<void> logFailure({
    required String operation,
    required String entityType,
    required String entityId,
    required String error,
    Map<String, dynamic>? details,
    String? userId,
  }) async {
    await _logAuditEntry(
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      status: 'FAILURE',
      error: error,
      details: details,
      userId: userId,
    );
  }
  
  /// Log authentication events
  Future<void> logAuthentication({
    required String authType,
    required String status,
    String? userId,
    Map<String, dynamic>? details,
  }) async {
    await _logAuditEntry(
      operation: 'AUTHENTICATION',
      entityType: 'USER_SESSION',
      entityId: userId ?? 'anonymous',
      status: status,
      details: {
        'auth_type': authType,
        ...?details,
      },
      userId: userId,
    );
  }
  
  /// Log data access events
  Future<void> logDataAccess({
    required String operation,
    required String entityType,
    required String entityId,
    String? userId,
    Map<String, dynamic>? details,
  }) async {
    await _logAuditEntry(
      operation: 'DATA_ACCESS_$operation',
      entityType: entityType,
      entityId: entityId,
      status: 'SUCCESS',
      details: details,
      userId: userId,
    );
  }
  
  /// Get audit logs for a specific entity
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? entityType,
    String? entityId,
    String? operation,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    try {
      final db = await _database.database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      final conditions = <String>[];
      
      if (entityType != null) {
        conditions.add('entity_type = ?');
        whereArgs.add(entityType);
      }
      
      if (entityId != null) {
        conditions.add('entity_id = ?');
        whereArgs.add(entityId);
      }
      
      if (operation != null) {
        conditions.add('operation = ?');
        whereArgs.add(operation);
      }
      
      if (fromDate != null) {
        conditions.add('timestamp >= ?');
        whereArgs.add(fromDate.toIso8601String());
      }
      
      if (toDate != null) {
        conditions.add('timestamp <= ?');
        whereArgs.add(toDate.toIso8601String());
      }
      
      if (conditions.isNotEmpty) {
        whereClause = 'WHERE ${conditions.join(' AND ')}';
      }
      
      final limitClause = limit != null ? 'LIMIT $limit' : '';
      
      final query = '''
        SELECT * FROM iras_audit_log 
        $whereClause 
        ORDER BY timestamp DESC 
        $limitClause
      ''';
      
      final results = await db.rawQuery(query, whereArgs);
      
      // Deserialize JSON fields
      return results.map((row) {
        final Map<String, dynamic> entry = Map.from(row);
        if (entry['details'] is String) {
          try {
            entry['details'] = json.decode(entry['details'] as String);
          } catch (e) {
            if (kDebugMode) {
              print('Failed to parse audit log details: $e');
            }
          }
        }
        return entry;
      }).toList();
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to retrieve audit logs: $e');
      }
      return [];
    }
  }
  
  /// Get audit summary for compliance reporting
  Future<Map<String, dynamic>> getAuditSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final db = await _database.database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (fromDate != null && toDate != null) {
        whereClause = 'WHERE timestamp BETWEEN ? AND ?';
        whereArgs = [fromDate.toIso8601String(), toDate.toIso8601String()];
      } else if (fromDate != null) {
        whereClause = 'WHERE timestamp >= ?';
        whereArgs = [fromDate.toIso8601String()];
      } else if (toDate != null) {
        whereClause = 'WHERE timestamp <= ?';
        whereArgs = [toDate.toIso8601String()];
      }
      
      // Get operation counts
      final operationCountsQuery = '''
        SELECT operation, COUNT(*) as count
        FROM iras_audit_log 
        $whereClause 
        GROUP BY operation
        ORDER BY count DESC
      ''';
      
      final operationCounts = await db.rawQuery(operationCountsQuery, whereArgs);
      
      // Get status counts
      final statusCountsQuery = '''
        SELECT status, COUNT(*) as count
        FROM iras_audit_log 
        $whereClause 
        GROUP BY status
      ''';
      
      final statusCounts = await db.rawQuery(statusCountsQuery, whereArgs);
      
      // Get entity type counts
      final entityCountsQuery = '''
        SELECT entity_type, COUNT(*) as count
        FROM iras_audit_log 
        $whereClause 
        GROUP BY entity_type
        ORDER BY count DESC
      ''';
      
      final entityCounts = await db.rawQuery(entityCountsQuery, whereArgs);
      
      // Get total count
      final totalCountQuery = '''
        SELECT COUNT(*) as total
        FROM iras_audit_log 
        $whereClause
      ''';
      
      final totalResult = await db.rawQuery(totalCountQuery, whereArgs);
      final totalCount = totalResult.first['total'] as int;
      
      return {
        'total_operations': totalCount,
        'operation_breakdown': Map.fromEntries(
          operationCounts.map((row) => MapEntry(
            row['operation'] as String,
            row['count'] as int,
          )),
        ),
        'status_breakdown': Map.fromEntries(
          statusCounts.map((row) => MapEntry(
            row['status'] as String,
            row['count'] as int,
          )),
        ),
        'entity_breakdown': Map.fromEntries(
          entityCounts.map((row) => MapEntry(
            row['entity_type'] as String,
            row['count'] as int,
          )),
        ),
        'period': {
          'from': fromDate?.toIso8601String(),
          'to': toDate?.toIso8601String(),
        },
        'generated_at': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to generate audit summary: $e');
      }
      return {
        'error': 'Failed to generate audit summary: $e',
        'generated_at': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Export audit logs for compliance
  Future<List<Map<String, dynamic>>> exportAuditLogs({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await getAuditLogs(
      fromDate: fromDate,
      toDate: toDate,
    );
  }
  
  /// Clean old audit logs (retain for compliance period)
  Future<int> cleanOldAuditLogs({
    required Duration retentionPeriod,
  }) async {
    try {
      final db = await _database.database;
      final cutoffDate = DateTime.now().subtract(retentionPeriod);
      
      final deleteCount = await db.delete(
        'iras_audit_log',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      
      if (kDebugMode) {
        print('Cleaned $deleteCount old audit log entries');
      }
      
      return deleteCount;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clean old audit logs: $e');
      }
      return 0;
    }
  }
  
  /// Internal method to log audit entries
  Future<void> _logAuditEntry({
    required String operation,
    required String entityType,
    required String entityId,
    required String status,
    String? error,
    Map<String, dynamic>? details,
    String? userId,
  }) async {
    try {
      final db = await _database.database;
      
      // Ensure audit table exists
      await _ensureAuditTableExists(db);
      
      final auditEntry = {
        'id': _generateAuditId(),
        'timestamp': DateTime.now().toIso8601String(),
        'operation': operation,
        'entity_type': entityType,
        'entity_id': entityId,
        'status': status,
        'user_id': userId,
        'error_message': error,
        'details': details != null ? json.encode(details) : null,
        'ip_address': null, // Could be populated from request context
        'user_agent': null, // Could be populated from request context
      };
      
      await db.insert('iras_audit_log', auditEntry);
      
      if (kDebugMode) {
        print('📋 Audit logged: $operation - $entityType($entityId) - $status');
      }
      
    } catch (e) {
      // Audit logging should not break the main flow
      if (kDebugMode) {
        print('Failed to log audit entry: $e');
      }
    }
  }
  
  /// Ensure audit table exists
  Future<void> _ensureAuditTableExists(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS iras_audit_log (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        operation TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        status TEXT NOT NULL,
        user_id TEXT,
        error_message TEXT,
        details TEXT,
        ip_address TEXT,
        user_agent TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // Create indexes for common queries
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audit_timestamp 
      ON iras_audit_log(timestamp)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audit_entity 
      ON iras_audit_log(entity_type, entity_id)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_audit_operation 
      ON iras_audit_log(operation)
    ''');
  }
  
  /// Generate unique audit ID
  String _generateAuditId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return 'audit_${timestamp}_$random';
  }
}