import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../utils/uuid_generator.dart';
import 'crdt_database_service.dart';

/// Audit event types
enum AuditEventType {
  create,
  read,
  update,
  delete,
  sync,
  login,
  logout,
  export,
  import,
  backup,
  restore,
}

/// Audit entry representing a single auditable event
class AuditEntry {
  final String id;
  final String tableName;
  final String recordId;
  final AuditEventType eventType;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? userId;
  final String nodeId;
  final DateTime timestamp;
  final HLCTimestamp hlcTimestamp;
  final String? transactionId;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? metadata;
  
  const AuditEntry({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.eventType,
    this.oldValues,
    this.newValues,
    this.userId,
    required this.nodeId,
    required this.timestamp,
    required this.hlcTimestamp,
    this.transactionId,
    this.ipAddress,
    this.userAgent,
    this.metadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_name': tableName,
      'record_id': recordId,
      'event_type': eventType.name,
      'old_values': oldValues != null ? jsonEncode(oldValues) : null,
      'new_values': newValues != null ? jsonEncode(newValues) : null,
      'user_id': userId,
      'node_id': nodeId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'hlc_timestamp': hlcTimestamp.toString(),
      'transaction_id': transactionId,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }
  
  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      eventType: AuditEventType.values.firstWhere(
        (e) => e.name == json['event_type'],
      ),
      oldValues: json['old_values'] != null 
          ? jsonDecode(json['old_values'] as String) as Map<String, dynamic>
          : null,
      newValues: json['new_values'] != null 
          ? jsonDecode(json['new_values'] as String) as Map<String, dynamic>
          : null,
      userId: json['user_id'] as String?,
      nodeId: json['node_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      hlcTimestamp: HLCTimestamp.fromString(json['hlc_timestamp'] as String),
      transactionId: json['transaction_id'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      metadata: json['metadata'] != null 
          ? jsonDecode(json['metadata'] as String) as Map<String, dynamic>
          : null,
    );
  }
}

/// Comprehensive audit service for tracking all database changes
class AuditService {
  final CRDTDatabaseService _databaseService;
  final List<String> _sensitiveFields = [
    'password',
    'api_key',
    'secret',
    'token',
    'private_key',
  ];
  
  AuditService(this._databaseService);
  
  /// Log an audit event
  Future<void> logEvent({
    required String tableName,
    required String recordId,
    required AuditEventType eventType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? userId,
    String? transactionId,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final db = await _databaseService.database;
      
      // Sanitize sensitive data
      final sanitizedOldValues = _sanitizeData(oldValues);
      final sanitizedNewValues = _sanitizeData(newValues);
      
      final auditEntry = AuditEntry(
        id: UuidGenerator.generateId(),
        tableName: tableName,
        recordId: recordId,
        eventType: eventType,
        oldValues: sanitizedOldValues,
        newValues: sanitizedNewValues,
        userId: userId,
        nodeId: _databaseService.nodeId,
        timestamp: DateTime.now(),
        hlcTimestamp: _databaseService.clock.tick(),
        transactionId: transactionId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        metadata: metadata,
      );
      
      await db.insert('audit_trail', auditEntry.toJson());
      
      // Also log to separate audit file for compliance
      await _logToAuditFile(auditEntry);
      
    } catch (e) {
      // Don't fail the main operation due to audit logging issues
      print('Failed to log audit event: $e');
    }
  }
  
  /// Log data access (SELECT operations)
  Future<void> logDataAccess({
    required String tableName,
    required String recordId,
    String? userId,
    String? query,
    Map<String, dynamic>? filters,
  }) async {
    await logEvent(
      tableName: tableName,
      recordId: recordId,
      eventType: AuditEventType.read,
      userId: userId,
      metadata: {
        'query': query,
        'filters': filters,
        'access_time': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Log bulk operations
  Future<void> logBulkOperation({
    required String tableName,
    required AuditEventType eventType,
    required List<String> recordIds,
    String? userId,
    String? transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    for (final recordId in recordIds) {
      await logEvent(
        tableName: tableName,
        recordId: recordId,
        eventType: eventType,
        userId: userId,
        transactionId: transactionId,
        metadata: {
          ...?metadata,
          'bulk_operation': true,
          'total_records': recordIds.length,
        },
      );
    }
  }
  
  /// Get audit trail for a specific record
  Future<List<AuditEntry>> getAuditTrail({
    required String tableName,
    required String recordId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) async {
    final db = await _databaseService.database;
    
    String whereClause = 'table_name = ? AND record_id = ?';
    List<dynamic> whereArgs = [tableName, recordId];
    
    if (fromDate != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }
    
    if (toDate != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }
    
    final result = await db.query(
      'audit_trail',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return result.map((row) => AuditEntry.fromJson(row)).toList();
  }
  
  /// Get audit summary for a time period
  Future<Map<String, dynamic>> getAuditSummary({
    DateTime? fromDate,
    DateTime? toDate,
    String? tableName,
    String? userId,
  }) async {
    final db = await _databaseService.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (fromDate != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }
    
    if (toDate != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }
    
    if (tableName != null) {
      whereClause += ' AND table_name = ?';
      whereArgs.add(tableName);
    }
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    // Get event counts by type
    final eventCounts = await db.rawQuery('''
      SELECT operation as event_type, COUNT(*) as count
      FROM audit_trail
      WHERE $whereClause
      GROUP BY operation
    ''', whereArgs);
    
    // Get most active tables
    final tableCounts = await db.rawQuery('''
      SELECT table_name, COUNT(*) as count
      FROM audit_trail
      WHERE $whereClause
      GROUP BY table_name
      ORDER BY count DESC
      LIMIT 10
    ''', whereArgs);
    
    // Get most active users
    final userCounts = await db.rawQuery('''
      SELECT user_id, COUNT(*) as count
      FROM audit_trail
      WHERE $whereClause AND user_id IS NOT NULL
      GROUP BY user_id
      ORDER BY count DESC
      LIMIT 10
    ''', whereArgs);
    
    // Get total events
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM audit_trail
      WHERE $whereClause
    ''', whereArgs);
    
    return {
      'total_events': totalResult.first['total'],
      'event_counts': eventCounts,
      'table_activity': tableCounts,
      'user_activity': userCounts,
      'period': {
        'from': fromDate?.toIso8601String(),
        'to': toDate?.toIso8601String(),
      },
    };
  }
  
  /// Export audit trail for compliance
  Future<String> exportAuditTrail({
    DateTime? fromDate,
    DateTime? toDate,
    String? tableName,
    String format = 'json',
  }) async {
    final db = await _databaseService.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (fromDate != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }
    
    if (toDate != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }
    
    if (tableName != null) {
      whereClause += ' AND table_name = ?';
      whereArgs.add(tableName);
    }
    
    final result = await db.query(
      'audit_trail',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    
    final auditEntries = result.map((row) => AuditEntry.fromJson(row)).toList();
    
    if (format.toLowerCase() == 'csv') {
      return _exportToCSV(auditEntries);
    } else {
      return jsonEncode({
        'export_timestamp': DateTime.now().toIso8601String(),
        'export_criteria': {
          'from_date': fromDate?.toIso8601String(),
          'to_date': toDate?.toIso8601String(),
          'table_name': tableName,
        },
        'total_records': auditEntries.length,
        'audit_entries': auditEntries.map((e) => e.toJson()).toList(),
      });
    }
  }
  
  /// Clean up old audit entries
  Future<int> cleanupOldEntries({
    required Duration retentionPeriod,
    String? tableName,
  }) async {
    final db = await _databaseService.database;
    final cutoffDate = DateTime.now().subtract(retentionPeriod);
    
    String whereClause = 'timestamp < ?';
    List<dynamic> whereArgs = [cutoffDate.millisecondsSinceEpoch];
    
    if (tableName != null) {
      whereClause += ' AND table_name = ?';
      whereArgs.add(tableName);
    }
    
    // Archive before deletion (for compliance)
    await _archiveOldEntries(whereClause, whereArgs);
    
    // Delete old entries
    final deletedCount = await db.delete(
      'audit_trail',
      where: whereClause,
      whereArgs: whereArgs,
    );
    
    // Log the cleanup operation
    await logEvent(
      tableName: 'audit_trail',
      recordId: 'cleanup_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.delete,
      metadata: {
        'cleanup_operation': true,
        'retention_period_days': retentionPeriod.inDays,
        'deleted_count': deletedCount,
        'cutoff_date': cutoffDate.toIso8601String(),
      },
    );
    
    return deletedCount;
  }
  
  /// Verify audit trail integrity
  Future<Map<String, dynamic>> verifyIntegrity() async {
    final db = await _databaseService.database;
    final issues = <String>[];
    
    // Check for gaps in timestamps
    final timestampGaps = await db.rawQuery('''
      SELECT 
        LAG(timestamp) OVER (ORDER BY timestamp) as prev_timestamp,
        timestamp,
        timestamp - LAG(timestamp) OVER (ORDER BY timestamp) as gap
      FROM audit_trail
      HAVING gap > 3600000 -- More than 1 hour gap
      ORDER BY timestamp
    ''');
    
    if (timestampGaps.isNotEmpty) {
      issues.add('Found ${timestampGaps.length} significant timestamp gaps');
    }
    
    // Check for missing create events
    final orphanedUpdates = await db.rawQuery('''
      SELECT DISTINCT a1.table_name, a1.record_id
      FROM audit_trail a1
      LEFT JOIN audit_trail a2 ON a1.table_name = a2.table_name 
        AND a1.record_id = a2.record_id 
        AND a2.operation = 'INSERT'
      WHERE a1.operation IN ('UPDATE', 'DELETE') 
        AND a2.id IS NULL
    ''');
    
    if (orphanedUpdates.isNotEmpty) {
      issues.add('Found ${orphanedUpdates.length} records with updates/deletes but no create events');
    }
    
    // Check for invalid JSON in values
    final invalidJson = await db.rawQuery('''
      SELECT id, table_name, record_id
      FROM audit_trail
      WHERE (old_values IS NOT NULL AND NOT json_valid(old_values))
         OR (new_values IS NOT NULL AND NOT json_valid(new_values))
    ''');
    
    if (invalidJson.isNotEmpty) {
      issues.add('Found ${invalidJson.length} entries with invalid JSON data');
    }
    
    return {
      'is_valid': issues.isEmpty,
      'issues': issues,
      'timestamp_gaps': timestampGaps,
      'orphaned_updates': orphanedUpdates,
      'invalid_json_entries': invalidJson,
      'verification_time': DateTime.now().toIso8601String(),
    };
  }
  
  /// Sanitize sensitive data from audit logs
  Map<String, dynamic>? _sanitizeData(Map<String, dynamic>? data) {
    if (data == null) return null;
    
    final sanitized = Map<String, dynamic>.from(data);
    
    for (final field in _sensitiveFields) {
      if (sanitized.containsKey(field)) {
        sanitized[field] = '[REDACTED]';
      }
    }
    
    return sanitized;
  }
  
  /// Log to separate audit file for compliance
  Future<void> _logToAuditFile(AuditEntry entry) async {
    // Implementation would write to a separate tamper-evident audit file
    // This could be a write-only file with cryptographic signatures
    print('Audit: ${entry.eventType.name} on ${entry.tableName}:${entry.recordId} at ${entry.timestamp}');
  }
  
  /// Export audit entries to CSV format
  String _exportToCSV(List<AuditEntry> entries) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('timestamp,table_name,record_id,event_type,user_id,node_id,transaction_id');
    
    // Data rows
    for (final entry in entries) {
      buffer.writeln([
        entry.timestamp.toIso8601String(),
        entry.tableName,
        entry.recordId,
        entry.eventType.name,
        entry.userId ?? '',
        entry.nodeId,
        entry.transactionId ?? '',
      ].join(','));
    }
    
    return buffer.toString();
  }
  
  /// Archive old audit entries before deletion
  Future<void> _archiveOldEntries(String whereClause, List<dynamic> whereArgs) async {
    // Implementation would archive to external storage or compressed format
    // This ensures compliance with data retention requirements
    print('Archiving old audit entries matching: $whereClause');
  }
}