import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart' as app_exceptions;
import 'crdt_database_service.dart';
import 'audit_service.dart';

/// Types of integrity checks
enum IntegrityCheckType {
  foreignKey,
  businessRule,
  balance,
  constraint,
  referentialIntegrity,
  dataConsistency,
}

/// Severity levels for integrity violations
enum ViolationSeverity {
  critical,  // Data corruption, must be fixed immediately
  high,      // Business rule violation, should be fixed soon
  medium,    // Data inconsistency, can be scheduled for fix
  low,       // Minor issue, informational
}

/// Integrity violation record
class IntegrityViolation {
  final String id;
  final String checkId;
  final String tableName;
  final String recordId;
  final IntegrityCheckType violationType;
  final ViolationSeverity severity;
  final String description;
  final Map<String, dynamic> details;
  final bool resolved;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  
  const IntegrityViolation({
    required this.id,
    required this.checkId,
    required this.tableName,
    required this.recordId,
    required this.violationType,
    required this.severity,
    required this.description,
    required this.details,
    this.resolved = false,
    required this.detectedAt,
    this.resolvedAt,
    this.resolutionNotes,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'check_id': checkId,
      'table_name': tableName,
      'record_id': recordId,
      'violation_type': violationType.name,
      'severity': severity.name,
      'description': description,
      'details': jsonEncode(details),
      'resolved': resolved,
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'resolved_at': resolvedAt?.millisecondsSinceEpoch,
      'resolution_notes': resolutionNotes,
    };
  }
  
  factory IntegrityViolation.fromJson(Map<String, dynamic> json) {
    return IntegrityViolation(
      id: json['id'] as String,
      checkId: json['check_id'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      violationType: IntegrityCheckType.values.firstWhere(
        (e) => e.name == json['violation_type'],
      ),
      severity: ViolationSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
      description: json['description'] as String,
      details: jsonDecode(json['details'] as String) as Map<String, dynamic>,
      resolved: json['resolved'] as bool,
      detectedAt: DateTime.fromMillisecondsSinceEpoch(json['detected_at'] as int),
      resolvedAt: json['resolved_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['resolved_at'] as int)
          : null,
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }
}

/// Integrity check definition
class IntegrityCheck {
  final String id;
  final String name;
  final IntegrityCheckType type;
  final String tableName;
  final String description;
  final String checkSql;
  final ViolationSeverity defaultSeverity;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? parameters;
  
  const IntegrityCheck({
    required this.id,
    required this.name,
    required this.type,
    required this.tableName,
    required this.description,
    required this.checkSql,
    required this.defaultSeverity,
    this.isActive = true,
    required this.createdAt,
    this.parameters,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'table_name': tableName,
      'description': description,
      'check_sql': checkSql,
      'default_severity': defaultSeverity.name,
      'is_active': isActive,
      'created_at': createdAt.millisecondsSinceEpoch,
      'parameters': parameters != null ? jsonEncode(parameters) : null,
    };
  }
  
  factory IntegrityCheck.fromJson(Map<String, dynamic> json) {
    return IntegrityCheck(
      id: json['id'] as String,
      name: json['name'] as String,
      type: IntegrityCheckType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      tableName: json['table_name'] as String,
      description: json['description'] as String,
      checkSql: json['check_sql'] as String,
      defaultSeverity: ViolationSeverity.values.firstWhere(
        (e) => e.name == json['default_severity'],
      ),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      parameters: json['parameters'] != null 
          ? jsonDecode(json['parameters'] as String) as Map<String, dynamic>
          : null,
    );
  }
}

/// Data integrity service for maintaining database consistency
class DataIntegrityService {
  final CRDTDatabaseService _databaseService;
  final AuditService _auditService;
  final List<IntegrityCheck> _builtInChecks = [];
  
  DataIntegrityService(this._databaseService, this._auditService) {
    _initializeBuiltInChecks();
  }
  
  /// Initialize the integrity service and install built-in checks
  Future<void> initialize() async {
    await _installBuiltInChecks();
    await _createIntegrityTriggers();
  }
  
  /// Run all active integrity checks
  Future<List<IntegrityViolation>> runIntegrityChecks({
    String? tableName,
    IntegrityCheckType? checkType,
    bool onlyActive = true,
  }) async {
    final db = await _databaseService.database;
    final violations = <IntegrityViolation>[];
    
    // Get checks to run
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (onlyActive) {
      whereClause += ' AND is_active = 1';
    }
    
    if (tableName != null) {
      whereClause += ' AND table_name = ?';
      whereArgs.add(tableName);
    }
    
    if (checkType != null) {
      whereClause += ' AND check_type = ?';
      whereArgs.add(checkType.name);
    }
    
    final checksResult = await db.query(
      'integrity_checks',
      where: whereClause,
      whereArgs: whereArgs,
    );
    
    final checks = checksResult.map((row) => IntegrityCheck.fromJson(row)).toList();
    
    // Run each check
    for (final check in checks) {
      try {
        final checkViolations = await _runSingleCheck(check);
        violations.addAll(checkViolations);
      } catch (e) {
        print('Failed to run integrity check ${check.name}: $e');
        
        // Log the check failure
        await _auditService.logEvent(
          tableName: 'integrity_checks',
          recordId: check.id,
          eventType: AuditEventType.read,
          metadata: {
            'check_failed': true,
            'error': e.toString(),
          },
        );
      }
    }
    
    return violations;
  }
  
  /// Run a single integrity check
  Future<List<IntegrityViolation>> _runSingleCheck(IntegrityCheck check) async {
    final db = await _databaseService.database;
    final violations = <IntegrityViolation>[];
    
    try {
      final results = await db.rawQuery(check.checkSql);
      
      for (final result in results) {
        final violation = IntegrityViolation(
          id: UuidGenerator.generateId(),
          checkId: check.id,
          tableName: check.tableName,
          recordId: result['record_id']?.toString() ?? 'unknown',
          violationType: check.type,
          severity: check.defaultSeverity,
          description: _generateViolationDescription(check, result),
          details: Map<String, dynamic>.from(result),
          detectedAt: DateTime.now(),
        );
        
        violations.add(violation);
        
        // Store violation in database
        await db.insert('integrity_violations', violation.toJson());
      }
    } catch (e) {
      print('Error running check ${check.name}: $e');
      rethrow;
    }
    
    return violations;
  }
  
  /// Run foreign key constraint checks
  Future<List<IntegrityViolation>> checkForeignKeyConstraints() async {
    final db = await _databaseService.database;
    final violations = <IntegrityViolation>[];
    
    // Check SQLite foreign key violations
    final fkViolations = await db.rawQuery('PRAGMA foreign_key_check');
    
    for (final violation in fkViolations) {
      final integrityViolation = IntegrityViolation(
        id: UuidGenerator.generateId(),
        checkId: 'fk_check_builtin',
        tableName: violation['table'] as String,
        recordId: violation['rowid']?.toString() ?? 'unknown',
        violationType: IntegrityCheckType.foreignKey,
        severity: ViolationSeverity.critical,
        description: 'Foreign key constraint violation',
        details: Map<String, dynamic>.from(violation),
        detectedAt: DateTime.now(),
      );
      
      violations.add(integrityViolation);
      
      // Store violation
      final violationDb = await _databaseService.database;
      await violationDb.insert('integrity_violations', integrityViolation.toJson());
    }
    
    return violations;
  }
  
  /// Check business rule violations
  Future<List<IntegrityViolation>> checkBusinessRules() async {
    final violations = <IntegrityViolation>[];
    
    // Check invoice business rules
    violations.addAll(await _checkInvoiceBusinessRules());
    
    // Check customer business rules
    violations.addAll(await _checkCustomerBusinessRules());
    
    // Check accounting transaction rules
    violations.addAll(await _checkAccountingBusinessRules());
    
    return violations;
  }
  
  /// Check invoice-specific business rules
  Future<List<IntegrityViolation>> _checkInvoiceBusinessRules() async {
    final db = await _databaseService.database;
    final violations = <IntegrityViolation>[];
    
    // Check for invoices with negative amounts
    final negativeAmounts = await db.rawQuery('''
      SELECT id, invoice_number, total_amount
      FROM invoices_crdt 
      WHERE total_amount < 0 AND is_deleted = 0
    ''');
    
    for (final result in negativeAmounts) {
      violations.add(IntegrityViolation(
        id: UuidGenerator.generateId(),
        checkId: 'invoice_negative_amount',
        tableName: 'invoices_crdt',
        recordId: result['id'] as String,
        violationType: IntegrityCheckType.businessRule,
        severity: ViolationSeverity.high,
        description: 'Invoice has negative total amount',
        details: Map<String, dynamic>.from(result),
        detectedAt: DateTime.now(),
      ));
    }
    
    // Check for paid invoices with remaining balance
    final paidWithBalance = await db.rawQuery('''
      SELECT id, invoice_number, status, remaining_balance_cents
      FROM invoices_crdt 
      WHERE status = 'paid' AND remaining_balance_cents > 0 AND is_deleted = 0
    ''');
    
    for (final result in paidWithBalance) {
      violations.add(IntegrityViolation(
        id: UuidGenerator.generateId(),
        checkId: 'invoice_paid_with_balance',
        tableName: 'invoices_crdt',
        recordId: result['id'] as String,
        violationType: IntegrityCheckType.businessRule,
        severity: ViolationSeverity.medium,
        description: 'Paid invoice has remaining balance',
        details: Map<String, dynamic>.from(result),
        detectedAt: DateTime.now(),
      ));
    }
    
    return violations;
  }
  
  /// Check customer-specific business rules
  Future<List<IntegrityViolation>> _checkCustomerBusinessRules() async {
    final db = await _databaseService.database;
    final violations = <IntegrityViolation>[];
    
    // Check for customers with invalid email formats
    final invalidEmails = await db.rawQuery('''
      SELECT id, name, email
      FROM customers_crdt 
      WHERE email IS NOT NULL 
        AND email != '' 
        AND email NOT LIKE '%@%.%'
        AND is_deleted = 0
    ''');
    
    for (final result in invalidEmails) {
      violations.add(IntegrityViolation(
        id: UuidGenerator.generateId(),
        checkId: 'customer_invalid_email',
        tableName: 'customers_crdt',
        recordId: result['id'] as String,
        violationType: IntegrityCheckType.businessRule,
        severity: ViolationSeverity.low,
        description: 'Customer has invalid email format',
        details: Map<String, dynamic>.from(result),
        detectedAt: DateTime.now(),
      ));
    }
    
    // Check for duplicate customer names
    final duplicateNames = await db.rawQuery('''
      SELECT name, COUNT(*) as count, GROUP_CONCAT(id) as ids
      FROM customers_crdt 
      WHERE is_deleted = 0
      GROUP BY LOWER(name)
      HAVING count > 1
    ''');
    
    for (final result in duplicateNames) {
      final ids = (result['ids'] as String).split(',');
      for (final id in ids) {
        violations.add(IntegrityViolation(
          id: UuidGenerator.generateId(),
          checkId: 'customer_duplicate_name',
          tableName: 'customers_crdt',
          recordId: id,
          violationType: IntegrityCheckType.businessRule,
          severity: ViolationSeverity.medium,
          description: 'Customer has duplicate name',
          details: {
            'name': result['name'],
            'duplicate_count': result['count'],
            'all_ids': ids,
          },
          detectedAt: DateTime.now(),
        ));
      }
    }
    
    return violations;
  }
  
  /// Check accounting-specific business rules
  Future<List<IntegrityViolation>> _checkAccountingBusinessRules() async {
    final db = await _databaseService.database;
    final violations = <IntegrityViolation>[];
    
    // Check for unbalanced transactions
    final unbalancedTransactions = await db.rawQuery('''
      SELECT t.id, t.transaction_number, t.total_debit, t.total_credit,
             ABS(t.total_debit - t.total_credit) as difference
      FROM transactions_crdt t
      WHERE ABS(t.total_debit - t.total_credit) > 0.01 
        AND t.status = 'posted'
        AND t.is_deleted = 0
    ''');
    
    for (final result in unbalancedTransactions) {
      violations.add(IntegrityViolation(
        id: UuidGenerator.generateId(),
        checkId: 'transaction_unbalanced',
        tableName: 'transactions_crdt',
        recordId: result['id'] as String,
        violationType: IntegrityCheckType.businessRule,
        severity: ViolationSeverity.critical,
        description: 'Posted transaction is not balanced',
        details: Map<String, dynamic>.from(result),
        detectedAt: DateTime.now(),
      ));
    }
    
    // Check for journal entries without corresponding transaction
    final orphanedEntries = await db.rawQuery('''
      SELECT je.id, je.transaction_id
      FROM journal_entries je
      LEFT JOIN transactions_crdt t ON je.transaction_id = t.id
      WHERE t.id IS NULL
    ''');
    
    for (final result in orphanedEntries) {
      violations.add(IntegrityViolation(
        id: UuidGenerator.generateId(),
        checkId: 'journal_entry_orphaned',
        tableName: 'journal_entries',
        recordId: result['id'] as String,
        violationType: IntegrityCheckType.referentialIntegrity,
        severity: ViolationSeverity.high,
        description: 'Journal entry references non-existent transaction',
        details: Map<String, dynamic>.from(result),
        detectedAt: DateTime.now(),
      ));
    }
    
    return violations;
  }
  
  /// Resolve a violation
  Future<void> resolveViolation(String violationId, String resolutionNotes) async {
    final db = await _databaseService.database;
    
    await db.update(
      'integrity_violations',
      {
        'resolved': 1,
        'resolved_at': DateTime.now().millisecondsSinceEpoch,
        'resolution_notes': resolutionNotes,
      },
      where: 'id = ?',
      whereArgs: [violationId],
    );
    
    // Log resolution
    await _auditService.logEvent(
      tableName: 'integrity_violations',
      recordId: violationId,
      eventType: AuditEventType.update,
      metadata: {
        'resolved': true,
        'resolution_notes': resolutionNotes,
      },
    );
  }
  
  /// Get violation statistics
  Future<Map<String, dynamic>> getViolationStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await _databaseService.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (fromDate != null) {
      whereClause += ' AND detected_at >= ?';
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }
    
    if (toDate != null) {
      whereClause += ' AND detected_at <= ?';
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }
    
    // Total violations
    final totalResult = await db.rawQuery('''
      SELECT COUNT(*) as total, 
             SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) as resolved
      FROM integrity_violations
      WHERE $whereClause
    ''', whereArgs);
    
    // Violations by severity
    final severityResult = await db.rawQuery('''
      SELECT severity, COUNT(*) as count
      FROM integrity_violations
      WHERE $whereClause
      GROUP BY severity
    ''', whereArgs);
    
    // Violations by type
    final typeResult = await db.rawQuery('''
      SELECT violation_type, COUNT(*) as count
      FROM integrity_violations
      WHERE $whereClause
      GROUP BY violation_type
    ''', whereArgs);
    
    // Violations by table
    final tableResult = await db.rawQuery('''
      SELECT table_name, COUNT(*) as count
      FROM integrity_violations
      WHERE $whereClause
      GROUP BY table_name
      ORDER BY count DESC
    ''', whereArgs);
    
    return {
      'summary': totalResult.first,
      'by_severity': severityResult,
      'by_type': typeResult,
      'by_table': tableResult,
      'period': {
        'from': fromDate?.toIso8601String(),
        'to': toDate?.toIso8601String(),
      },
      'generated_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// Install built-in integrity checks
  Future<void> _installBuiltInChecks() async {
    final db = await _databaseService.database;
    
    for (final check in _builtInChecks) {
      await db.insert(
        'integrity_checks',
        check.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
  
  /// Create database triggers for real-time integrity checking
  Future<void> _createIntegrityTriggers() async {
    final db = await _databaseService.database;
    
    // Trigger for invoice amount validation
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS validate_invoice_amount
      BEFORE INSERT ON invoices_crdt
      WHEN NEW.total_amount < 0
      BEGIN
        INSERT INTO integrity_violations (
          id, check_id, table_name, record_id, violation_type, severity,
          description, details, resolved, detected_at
        ) VALUES (
          lower(hex(randomblob(16))),
          'trigger_invoice_negative',
          'invoices_crdt',
          NEW.id,
          'businessRule',
          'high',
          'Invoice has negative total amount',
          json_object('total_amount', NEW.total_amount),
          0,
          strftime('%s', 'now') * 1000
        );
      END
    ''');
    
    // Trigger for customer email validation
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS validate_customer_email
      BEFORE INSERT ON customers_crdt
      WHEN NEW.email IS NOT NULL AND NEW.email != '' AND NEW.email NOT LIKE '%@%.%'
      BEGIN
        INSERT INTO integrity_violations (
          id, check_id, table_name, record_id, violation_type, severity,
          description, details, resolved, detected_at
        ) VALUES (
          lower(hex(randomblob(16))),
          'trigger_customer_email',
          'customers_crdt',
          NEW.id,
          'businessRule',
          'low',
          'Customer has invalid email format',
          json_object('email', NEW.email),
          0,
          strftime('%s', 'now') * 1000
        );
      END
    ''');
  }
  
  /// Initialize built-in integrity checks
  void _initializeBuiltInChecks() {
    _builtInChecks.addAll([
      // Foreign key checks
      IntegrityCheck(
        id: 'fk_invoice_customer',
        name: 'Invoice Customer FK',
        type: IntegrityCheckType.foreignKey,
        tableName: 'invoices_crdt',
        description: 'Check that invoice customer references exist',
        checkSql: '''
          SELECT i.id as record_id, i.customer_id
          FROM invoices_crdt i
          LEFT JOIN customers_crdt c ON i.customer_id = c.id
          WHERE i.customer_id IS NOT NULL 
            AND c.id IS NULL 
            AND i.is_deleted = 0
        ''',
        defaultSeverity: ViolationSeverity.high,
        createdAt: DateTime.now(),
      ),
      
      // Business rule checks
      IntegrityCheck(
        id: 'invoice_amount_positive',
        name: 'Invoice Amount Positive',
        type: IntegrityCheckType.businessRule,
        tableName: 'invoices_crdt',
        description: 'Check that invoice amounts are positive',
        checkSql: '''
          SELECT id as record_id, total_amount
          FROM invoices_crdt
          WHERE total_amount < 0 AND is_deleted = 0
        ''',
        defaultSeverity: ViolationSeverity.high,
        createdAt: DateTime.now(),
      ),
      
      // Balance checks
      IntegrityCheck(
        id: 'transaction_balanced',
        name: 'Transaction Balanced',
        type: IntegrityCheckType.balance,
        tableName: 'transactions_crdt',
        description: 'Check that accounting transactions are balanced',
        checkSql: '''
          SELECT id as record_id, total_debit, total_credit,
                 ABS(total_debit - total_credit) as difference
          FROM transactions_crdt
          WHERE ABS(total_debit - total_credit) > 0.01 
            AND status = 'posted'
            AND is_deleted = 0
        ''',
        defaultSeverity: ViolationSeverity.critical,
        createdAt: DateTime.now(),
      ),
    ]);
  }
  
  /// Generate violation description
  String _generateViolationDescription(IntegrityCheck check, Map<String, dynamic> result) {
    switch (check.id) {
      case 'fk_invoice_customer':
        return 'Invoice ${result['record_id']} references non-existent customer ${result['customer_id']}';
      case 'invoice_amount_positive':
        return 'Invoice ${result['record_id']} has negative amount: ${result['total_amount']}';
      case 'transaction_balanced':
        return 'Transaction ${result['record_id']} is unbalanced by ${result['difference']}';
      default:
        return check.description;
    }
  }
}