import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'platform_database_factory.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart' as app_exceptions;

/// Comprehensive database health monitoring and recovery service
/// Provides diagnostics, monitoring, and automated recovery capabilities
class DatabaseHealthService {
  static DatabaseHealthService? _instance;
  
  factory DatabaseHealthService() => _instance ??= DatabaseHealthService._internal();
  DatabaseHealthService._internal();

  /// Perform comprehensive database health check
  Future<DatabaseHealthReport> performHealthCheck(Database? database) async {
    final report = DatabaseHealthReport();
    
    try {
      // Basic connectivity test
      if (database != null) {
        await _testBasicConnectivity(database, report);
        await _testTableIntegrity(database, report);
        await _testIndexPerformance(database, report);
        await _testPragmaSettings(database, report);
        await _testCRDTConsistency(database, report);
      } else {
        report.addError('Database instance is null');
      }
      
      // Platform-specific tests
      await _testPlatformSpecificFeatures(report);
      
    } catch (e) {
      report.addError('Health check failed: $e');
    }
    
    return report;
  }

  /// Test basic database connectivity
  Future<void> _testBasicConnectivity(Database database, DatabaseHealthReport report) async {
    try {
      final result = await database.rawQuery('SELECT 1 as test');
      if (result.isNotEmpty && result.first['test'] == 1) {
        report.addSuccess('Basic connectivity: OK');
      } else {
        report.addWarning('Basic connectivity: Unexpected result');
      }
    } catch (e) {
      report.addError('Basic connectivity failed: $e');
    }
  }

  /// Test table integrity
  Future<void> _testTableIntegrity(Database database, DatabaseHealthReport report) async {
    final requiredTables = [
      'customers_crdt',
      'invoices_crdt',
      'products_crdt',
      'sync_metadata',
      'audit_trail'
    ];

    try {
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      final existingTables = tables.map((row) => row['name'] as String).toSet();

      for (final table in requiredTables) {
        if (existingTables.contains(table)) {
          report.addSuccess('Table $table: EXISTS');
        } else {
          report.addError('Table $table: MISSING');
        }
      }
    } catch (e) {
      report.addError('Table integrity check failed: $e');
    }
  }

  /// Test index performance
  Future<void> _testIndexPerformance(Database database, DatabaseHealthReport report) async {
    try {
      // Test index usage on customers table
      final explain = await database.rawQuery(
        'EXPLAIN QUERY PLAN SELECT * FROM customers_crdt WHERE name = ? AND is_deleted = FALSE',
        ['test']
      );
      
      final usesIndex = explain.any((row) => 
        row['detail'].toString().toLowerCase().contains('index'));
      
      if (usesIndex) {
        report.addSuccess('Index performance: Using indexes efficiently');
      } else {
        report.addWarning('Index performance: May not be using indexes optimally');
      }
    } catch (e) {
      report.addWarning('Index performance test failed: $e');
    }
  }

  /// Test PRAGMA settings
  Future<void> _testPragmaSettings(Database database, DatabaseHealthReport report) async {
    final pragmaTests = [
      {'name': 'Foreign Keys', 'command': 'PRAGMA foreign_keys'},
      {'name': 'Journal Mode', 'command': 'PRAGMA journal_mode'},
      {'name': 'Synchronous', 'command': 'PRAGMA synchronous'},
      {'name': 'Cache Size', 'command': 'PRAGMA cache_size'},
    ];

    for (final test in pragmaTests) {
      try {
        final result = await database.rawQuery(test['command'] as String);
        if (result.isNotEmpty) {
          final value = result.first.values.first;
          report.addInfo('${test['name']}: $value');
        }
      } catch (e) {
        report.addWarning('${test['name']} check failed: $e');
      }
    }
  }

  /// Test CRDT consistency
  Future<void> _testCRDTConsistency(Database database, DatabaseHealthReport report) async {
    try {
      // Check for orphaned CRDT records
      final orphanedCount = await database.rawQuery('''
        SELECT COUNT(*) as count 
        FROM sync_metadata sm 
        LEFT JOIN customers_crdt c ON sm.record_id = c.id 
        WHERE sm.table_name = 'customers_crdt' AND c.id IS NULL
      ''');
      
      final count = orphanedCount.first['count'] as int;
      if (count > 0) {
        report.addWarning('CRDT consistency: $count orphaned sync records found');
      } else {
        report.addSuccess('CRDT consistency: No orphaned records');
      }
    } catch (e) {
      report.addWarning('CRDT consistency check failed: $e');
    }
  }

  /// Test platform-specific features
  Future<void> _testPlatformSpecificFeatures(DatabaseHealthReport report) async {
    try {
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      
      report.addInfo('Platform: ${dbInfo['platform']}');
      report.addInfo('Database Factory: ${dbInfo['database_factory']}');
      report.addInfo('WAL Mode Supported: ${dbInfo['wal_mode_supported']}');
      report.addInfo('Encryption Status: ${dbInfo['encryption_status']}');
      
      // Platform-specific recommendations
      if (Platform.isAndroid && dbInfo['wal_mode_supported'] == false) {
        report.addInfo('Recommendation: WAL mode disabled for Android compatibility');
      }
      
    } catch (e) {
      report.addWarning('Platform feature test failed: $e');
    }
  }

  /// Attempt automated database recovery
  Future<bool> attemptRecovery(String databasePath) async {
    debugPrint('🔧 Starting database recovery process...');
    
    try {
      // Step 1: Test basic connectivity
      final connectivityTest = await PlatformDatabaseFactory.testDatabaseConnectivity(databasePath);
      if (!connectivityTest) {
        debugPrint('❌ Connectivity test failed during recovery');
        return false;
      }
      
      // Step 2: Open database with minimal configuration
      final database = await PlatformDatabaseFactory.openDatabase(
        databasePath,
        version: AppConstants.databaseVersion,
      );
      
      // Step 3: Verify table structure
      await _verifyAndRepairTables(database);
      
      // Step 4: Run integrity check
      final integrityCheck = await database.rawQuery('PRAGMA integrity_check');
      final isIntact = integrityCheck.length == 1 && 
          integrityCheck.first.values.first == 'ok';
      
      if (!isIntact) {
        debugPrint('❌ Database integrity check failed');
        await database.close();
        return false;
      }
      
      await database.close();
      debugPrint('✅ Database recovery completed successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Database recovery failed: $e');
      return false;
    }
  }

  /// Verify and repair table structure
  Future<void> _verifyAndRepairTables(Database database) async {
    final requiredTables = {
      'customers_crdt': _getCustomersCRDTSchema(),
      'products_crdt': _getProductsCRDTSchema(),
      'sync_metadata': _getSyncMetadataSchema(),
    };

    for (final entry in requiredTables.entries) {
      final tableName = entry.key;
      final schema = entry.value;
      
      try {
        final tableExists = await _tableExists(database, tableName);
        if (!tableExists) {
          debugPrint('🔧 Creating missing table: $tableName');
          await database.execute(schema);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to repair table $tableName: $e');
      }
    }
  }

  /// Check if table exists
  Future<bool> _tableExists(Database database, String tableName) async {
    final result = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName]
    );
    return result.isNotEmpty;
  }

  /// Get basic customers CRDT table schema
  String _getCustomersCRDTSchema() {
    return '''
      CREATE TABLE customers_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        name TEXT,
        email TEXT,
        CHECK(json_valid(crdt_data))
      )
    ''';
  }

  /// Get basic products CRDT table schema
  String _getProductsCRDTSchema() {
    return '''
      CREATE TABLE products_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        name TEXT,
        price REAL,
        CHECK(json_valid(crdt_data))
      )
    ''';
  }

  /// Get sync metadata table schema
  String _getSyncMetadataSchema() {
    return '''
      CREATE TABLE sync_metadata (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        last_sync_vector TEXT NOT NULL,
        last_sync_timestamp TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''';
  }
}

/// Database health report containing diagnostics and recommendations
class DatabaseHealthReport {
  final List<String> _successes = [];
  final List<String> _warnings = [];
  final List<String> _errors = [];
  final List<String> _info = [];
  
  List<String> get successes => List.unmodifiable(_successes);
  List<String> get warnings => List.unmodifiable(_warnings);
  List<String> get errors => List.unmodifiable(_errors);
  List<String> get info => List.unmodifiable(_info);
  
  bool get isHealthy => _errors.isEmpty;
  bool get hasWarnings => _warnings.isNotEmpty;
  
  void addSuccess(String message) => _successes.add(message);
  void addWarning(String message) => _warnings.add(message);
  void addError(String message) => _errors.add(message);
  void addInfo(String message) => _info.add(message);
  
  /// Get formatted report
  String getFormattedReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Database Health Report ===');
    
    if (_successes.isNotEmpty) {
      buffer.writeln('\n✅ Successes:');
      for (final success in _successes) {
        buffer.writeln('  - $success');
      }
    }
    
    if (_info.isNotEmpty) {
      buffer.writeln('\nℹ️  Information:');
      for (final info in _info) {
        buffer.writeln('  - $info');
      }
    }
    
    if (_warnings.isNotEmpty) {
      buffer.writeln('\n⚠️  Warnings:');
      for (final warning in _warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    if (_errors.isNotEmpty) {
      buffer.writeln('\n❌ Errors:');
      for (final error in _errors) {
        buffer.writeln('  - $error');
      }
    }
    
    buffer.writeln('\n=== End Report ===');
    return buffer.toString();
  }
  
  /// Get summary status
  String getStatusSummary() {
    if (_errors.isNotEmpty) {
      return 'CRITICAL: ${_errors.length} error(s), ${_warnings.length} warning(s)';
    } else if (_warnings.isNotEmpty) {
      return 'WARNING: ${_warnings.length} warning(s)';
    } else {
      return 'HEALTHY: All checks passed';
    }
  }
}