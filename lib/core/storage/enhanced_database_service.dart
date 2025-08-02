import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart' as app_exceptions;
import '../database/crdt_database_service.dart';
import '../database/transaction_manager.dart';
import '../database/audit_service.dart';
import '../database/double_entry_service.dart';
import '../database/data_integrity_service.dart';
import '../database/conflict_resolver.dart';
import '../database/crdt_models.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../crdt/crdt_types.dart';
import '../crdt/vector_clock.dart';

/// Enhanced database service with comprehensive CRDT support, audit trail, 
/// double-entry bookkeeping, and data integrity checks
class EnhancedDatabaseService {
  static EnhancedDatabaseService? _instance;
  
  late CRDTDatabaseService _crdtService;
  late AuditService _auditService;
  late DoubleEntryService _doubleEntryService;
  late DataIntegrityService _integrityService;
  late ConflictResolver _conflictResolver;
  
  EnhancedDatabaseService._internal();
  
  /// Get singleton instance and initialize if needed
  static Future<EnhancedDatabaseService> getInstance([String? nodeId]) async {
    if (_instance == null) {
      _instance = EnhancedDatabaseService._internal();
      await _instance!._initialize(nodeId);
    }
    return _instance!;
  }
  
  /// Initialize all database services
  Future<void> _initialize(String? nodeId) async {
    _crdtService = CRDTDatabaseService();
    await _crdtService.initialize(nodeId);
    
    _auditService = AuditService(_crdtService);
    _doubleEntryService = DoubleEntryService(_crdtService, _auditService);
    _integrityService = DataIntegrityService(_crdtService, _auditService);
    _conflictResolver = ConflictResolver();
    
    // Initialize services that need setup
    await _doubleEntryService.initializeChartOfAccounts();
    await _integrityService.initialize();
  }
  
  // Getters for service access
  CRDTDatabaseService get crdtService => _crdtService;
  AuditService get auditService => _auditService;
  DoubleEntryService get doubleEntryService => _doubleEntryService;
  DataIntegrityService get integrityService => _integrityService;
  ConflictResolver get conflictResolver => _conflictResolver;
  TransactionManager get transactionManager => _crdtService.transactionManager;
  HybridLogicalClock get clock => _crdtService.clock;
  String get nodeId => _crdtService.nodeId;
  
  /// Get the underlying database instance
  Future<Database> get database async {
    return await _crdtService.database;
  }
  
  // Business Entity Operations
  
  /// Create or update a customer
  Future<CRDTCustomer> upsertCustomer({
    String? id,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? taxNumber,
    Map<String, dynamic>? metadata,
  }) async {
    final customerId = id ?? _generateId();
    final timestamp = clock.tick();
    
    final customer = CRDTCustomer(
      id: customerId,
      nodeId: nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(nodeId),
      name: CRDTRegister(name, timestamp),
      email: CRDTRegister(email ?? '', timestamp),
      phone: CRDTRegister(phone ?? '', timestamp),
      address: CRDTRegister(address ?? '', timestamp),
      loyaltyPoints: CRDTCounter(0),
    );
    
    await _crdtService.upsertCustomer(customer);
    
    // Log audit event
    await _auditService.logEvent(
      tableName: 'customers_crdt',
      recordId: customerId,
      eventType: id == null ? AuditEventType.create : AuditEventType.update,
      newValues: customer.toJson(),
    );
    
    return customer;
  }
  
  /// Get customer by ID
  Future<CRDTCustomer?> getCustomer(String id) async {
    return await _crdtService.getCustomer(id);
  }
  
  /// Get all customers
  Future<List<CRDTCustomer>> getAllCustomers() async {
    return await _crdtService.getAllCustomers();
  }

  /// Query customers with filters
  Future<List<CRDTCustomer>> queryCustomers(Map<String, dynamic> filters) async {
    return await _crdtService.queryCustomers(filters);
  }
  
  /// Delete customer (soft delete)
  Future<void> deleteCustomer(String id) async {
    final customer = await getCustomer(id);
    if (customer == null) {
      throw app_exceptions.DatabaseException('Customer not found: $id');
    }
    
    customer.isDeleted = true;
    customer.updatedAt = clock.tick();
    await _crdtService.upsertCustomer(customer);
    
    // Log audit event
    await _auditService.logEvent(
      tableName: 'customers_crdt',
      recordId: id,
      eventType: AuditEventType.delete,
      oldValues: customer.toJson(),
    );
  }
  
  // Financial Operations
  
  /// Create a journal entry with full double-entry validation
  Future<void> createJournalEntry({
    required String description,
    required List<JournalEntryLine> entries,
    String? reference,
  }) async {
    await transactionManager.runInTransaction((transaction) async {
      // Create accounting transaction record
      final transactionId = _generateId();
      final timestamp = clock.tick();
      
      final totalDebits = entries
          .where((e) => e.isDebit)
          .fold(0.0, (sum, e) => sum + e.amount);
      
      final totalCredits = entries
          .where((e) => e.isCredit)
          .fold(0.0, (sum, e) => sum + e.amount);
      
      final accountingTransaction = CRDTAccountingTransaction(
        id: transactionId,
        nodeId: nodeId,
        createdAt: timestamp,
        updatedAt: timestamp,
        version: VectorClock(nodeId),
        transactionNumber: CRDTRegister(_generateTransactionNumber(), timestamp),
        description: CRDTRegister(description, timestamp),
        transactionDate: CRDTRegister(DateTime.now(), timestamp),
        reference: CRDTRegister(reference ?? '', timestamp),
        amount: CRDTRegister(totalDebits, timestamp),
        currency: CRDTRegister('SGD', timestamp),
        debitAccount: CRDTRegister('', timestamp),
        creditAccount: CRDTRegister('', timestamp),
        category: CRDTRegister('', timestamp),
        status: CRDTRegister('pending', timestamp),
      );
      
      // Validate and create journal entries
      await _doubleEntryService.createJournalEntry(
        transactionId: transactionId,
        entries: entries,
        description: description,
        reference: reference,
      );
      
      // Log audit event
      await _auditService.logEvent(
        tableName: 'transactions_crdt',
        recordId: transactionId,
        eventType: AuditEventType.create,
        newValues: accountingTransaction.toJson(),
        transactionId: transaction.id,
      );
    });
  }
  
  /// Get trial balance
  Future<List<TrialBalanceEntry>> getTrialBalance({DateTime? asOfDate}) async {
    return await _doubleEntryService.getTrialBalance(asOfDate: asOfDate);
  }
  
  /// Generate financial statements
  Future<Map<String, dynamic>> generateFinancialStatements({DateTime? asOfDate}) async {
    return await _doubleEntryService.generateFinancialStatements(asOfDate: asOfDate);
  }
  
  // Data Integrity Operations
  
  /// Run comprehensive database health check
  Future<Map<String, dynamic>> runHealthCheck() async {
    final results = <String, dynamic>{};
    
    try {
      // Check foreign key constraints
      final fkViolations = await _integrityService.checkForeignKeyConstraints();
      results['foreign_key_violations'] = fkViolations.length;
      results['fk_violations_details'] = fkViolations.map((v) => v.toJson()).toList();
      
      // Check business rules
      final businessViolations = await _integrityService.checkBusinessRules();
      results['business_rule_violations'] = businessViolations.length;
      results['business_violations_details'] = businessViolations.map((v) => v.toJson()).toList();
      
      // Check trial balance
      final trialBalance = await _doubleEntryService.validateTrialBalance();
      results['trial_balance'] = trialBalance;
      
      // Check audit trail integrity
      final auditIntegrity = await _auditService.verifyIntegrity();
      results['audit_integrity'] = auditIntegrity;
      
      // Get violation statistics
      final violationStats = await _integrityService.getViolationStatistics();
      results['violation_statistics'] = violationStats;
      
      // Run all integrity checks
      final allViolations = await _integrityService.runIntegrityChecks();
      results['all_violations'] = allViolations.map((v) => v.toJson()).toList();
      
      results['overall_health'] = _calculateOverallHealth(results);
      results['check_timestamp'] = DateTime.now().toIso8601String();
      results['node_id'] = nodeId;
      
    } catch (e) {
      results['error'] = e.toString();
      results['overall_health'] = 'ERROR';
    }
    
    return results;
  }
  
  /// Calculate overall database health score
  String _calculateOverallHealth(Map<String, dynamic> results) {
    int criticalIssues = 0;
    int majorIssues = 0;
    
    // Count violations by severity
    final allViolations = results['all_violations'] as List<dynamic>? ?? [];
    for (final violation in allViolations) {
      final severity = violation['severity'] as String;
      if (severity == 'critical') {
        criticalIssues++;
      } else if (severity == 'high') {
        majorIssues++;
      }
    }
    
    // Check specific issues
    if (results['foreign_key_violations'] > 0) criticalIssues++;
    if (results['trial_balance']?['is_balanced'] != true) criticalIssues++;
    if (results['audit_integrity']?['is_valid'] != true) majorIssues++;
    if (results['business_rule_violations'] > 5) majorIssues++;
    
    if (criticalIssues > 0) return 'CRITICAL';
    if (majorIssues > 3) return 'POOR';
    if (majorIssues > 0) return 'FAIR';
    return 'EXCELLENT';
  }
  
  /// Export comprehensive database backup
  Future<Map<String, dynamic>> exportBackup({
    bool includeAuditTrail = true,
    bool includeCRDTMetadata = true,
  }) async {
    final db = await database;
    
    final backup = <String, dynamic>{
      'metadata': {
        'version': AppConstants.databaseVersion,
        'node_id': nodeId,
        'export_timestamp': DateTime.now().toIso8601String(),
        'database_health': await runHealthCheck(),
      },
      'tables': <String, List<Map<String, dynamic>>>{},
    };
    
    // Export CRDT tables with full metadata
    final crdtTables = [
      'customers_crdt',
      'invoices_crdt', 
      'transactions_crdt',
      'tax_rates_crdt'
    ];
    
    for (final table in crdtTables) {
      final data = await db.query(table, where: 'is_deleted = 0');
      backup['tables'][table] = data;
    }
    
    // Export business data tables
    final businessTables = [
      'chart_of_accounts',
      'journal_entries',
      'account_balances',
      'user_settings',
      'business_profile',
    ];
    
    for (final table in businessTables) {
      try {
        final data = await db.query(table);
        backup['tables'][table] = data;
      } catch (e) {
        backup['tables'][table] = [];
        backup['metadata']['warnings'] = (backup['metadata']['warnings'] as List? ?? [])
          ..add('Failed to export table $table: $e');
      }
    }
    
    // Export sync and metadata tables if requested
    if (includeCRDTMetadata) {
      final metadataTables = [
        'sync_metadata',
        'device_registry',
        'conflict_resolution_log',
      ];
      
      for (final table in metadataTables) {
        try {
          final data = await db.query(table, limit: 1000, orderBy: 'created_at DESC');
          backup['tables'][table] = data;
        } catch (e) {
          backup['tables'][table] = [];
        }
      }
    }
    
    // Export recent audit trail if requested
    if (includeAuditTrail) {
      try {
        final auditData = await db.query(
          'audit_trail', 
          limit: 10000, 
          orderBy: 'timestamp DESC'
        );
        backup['tables']['audit_trail'] = auditData;
      } catch (e) {
        backup['tables']['audit_trail'] = [];
        backup['metadata']['warnings'] = (backup['metadata']['warnings'] as List? ?? [])
          ..add('Failed to export audit trail: $e');
      }
    }
    
    // Add integrity check results
    backup['integrity_report'] = await runHealthCheck();
    
    // Add financial statements
    try {
      backup['financial_statements'] = await generateFinancialStatements();
    } catch (e) {
      backup['metadata']['warnings'] = (backup['metadata']['warnings'] as List? ?? [])
        ..add('Failed to generate financial statements: $e');
    }
    
    return backup;
  }
  
  /// Import backup data with conflict resolution
  Future<Map<String, dynamic>> importBackup(
    Map<String, dynamic> backupData,
    {bool overwriteConflicts = false}
  ) async {
    final results = <String, dynamic>{
      'imported_tables': <String, int>{},
      'conflicts': <String, List<Map<String, dynamic>>>{},
      'errors': <String, String>{},
    };
    
    await transactionManager.runInTransaction((transaction) async {
      final tables = backupData['tables'] as Map<String, dynamic>;
      
      for (final entry in tables.entries) {
        final tableName = entry.key;
        final tableData = entry.value as List<dynamic>;
        
        try {
          int importedCount = 0;
          
          for (final record in tableData) {
            final recordMap = record as Map<String, dynamic>;
            
            if (tableName.endsWith('_crdt')) {
              // Handle CRDT imports with conflict resolution
              await _importCRDTRecord(tableName, recordMap, overwriteConflicts);
            } else {
              // Handle regular table imports
              await _importRegularRecord(tableName, recordMap);
            }
            
            importedCount++;
          }
          
          results['imported_tables'][tableName] = importedCount;
          
        } catch (e) {
          results['errors'][tableName] = e.toString();
        }
      }
    });
    
    // Run health check after import
    results['post_import_health'] = await runHealthCheck();
    
    return results;
  }
  
  /// Import CRDT record with conflict resolution
  Future<void> _importCRDTRecord(
    String tableName,
    Map<String, dynamic> recordData,
    bool overwriteConflicts,
  ) async {
    final db = await database;
    final recordId = recordData['id'] as String;
    
    // Check if record exists
    final existing = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [recordId],
    );
    
    if (existing.isNotEmpty && !overwriteConflicts) {
      // Conflict resolution needed
      // This would require implementing specific conflict resolution logic
      // For now, skip conflicting records
      return;
    }
    
    // Insert or replace record
    await db.insert(
      tableName,
      recordData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Log import
    await _auditService.logEvent(
      tableName: tableName,
      recordId: recordId,
      eventType: existing.isEmpty ? AuditEventType.create : AuditEventType.update,
      newValues: recordData,
      metadata: {'imported': true},
    );
  }
  
  /// Import regular record
  Future<void> _importRegularRecord(
    String tableName,
    Map<String, dynamic> recordData,
  ) async {
    final db = await database;
    
    await db.insert(
      tableName,
      recordData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Generate unique ID
  String _generateId() {
    return '${nodeId}_${DateTime.now().microsecondsSinceEpoch}';
  }
  
  /// Generate transaction number
  String _generateTransactionNumber() {
    final now = DateTime.now();
    return 'TXN${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch % 100000}';
  }
  
  /// Close database and cleanup
  Future<void> close() async {
    await _crdtService.closeDatabase();
    _instance = null;
  }
  
  /// Delete database completely
  Future<void> deleteDatabase() async {
    await _crdtService.deleteDatabase();
    _instance = null;
  }
  
  /// Get database statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    
    final stats = <String, dynamic>{
      'node_id': nodeId,
      'database_version': AppConstants.databaseVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Count records in each table
    final tables = [
      'customers_crdt',
      'invoices_crdt',
      'transactions_crdt',
      'tax_rates_crdt',
      'journal_entries',
      'audit_trail',
      'integrity_violations',
    ];
    
    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        stats['${table}_count'] = result.first['count'];
      } catch (e) {
        stats['${table}_count'] = 'ERROR: $e';
      }
    }
    
    // Get database file size
    try {
      final dbPath = db.path;
      final file = File(dbPath);
      if (await file.exists()) {
        stats['database_size_bytes'] = await file.length();
        stats['database_size_mb'] = (await file.length()) / (1024 * 1024);
      }
    } catch (e) {
      stats['database_size'] = 'ERROR: $e';
    }
    
    return stats;
  }
}