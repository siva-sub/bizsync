import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';
import '../database/crdt_database_service.dart';

/// Schema consistency validation result
class SchemaValidationResult {
  final String id;
  final String checkName;
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic> details;
  final SchemaSeverity severity;
  final DateTime timestamp;
  final String? suggestedFix;

  const SchemaValidationResult({
    required this.id,
    required this.checkName,
    required this.isValid,
    this.errorMessage,
    required this.details,
    required this.severity,
    required this.timestamp,
    this.suggestedFix,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'check_name': checkName,
      'is_valid': isValid,
      'error_message': errorMessage,
      'details': jsonEncode(details),
      'severity': severity.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'suggested_fix': suggestedFix,
    };
  }
}

/// Schema validation severity levels
enum SchemaSeverity {
  info,
  warning,
  error,
  critical,
  fatal,
}

/// Types of schema inconsistencies
enum SchemaInconsistencyType {
  missingTable,
  missingColumn,
  missingIndex,
  wrongDataType,
  missingConstraint,
  versionMismatch,
  corruptedSchema,
  orphanedData,
  invalidForeignKey,
  missingTrigger,
}

/// Schema definition for validation
class ExpectedSchema {
  final Map<String, TableSchema> tables;
  final List<IndexSchema> indexes;
  final List<TriggerSchema> triggers;
  final int version;

  const ExpectedSchema({
    required this.tables,
    required this.indexes,
    required this.triggers,
    required this.version,
  });
}

/// Table schema definition
class TableSchema {
  final String name;
  final Map<String, ColumnSchema> columns;
  final List<String> primaryKey;
  final List<ForeignKeySchema> foreignKeys;
  final List<String> constraints;

  const TableSchema({
    required this.name,
    required this.columns,
    this.primaryKey = const [],
    this.foreignKeys = const [],
    this.constraints = const [],
  });
}

/// Column schema definition
class ColumnSchema {
  final String name;
  final String dataType;
  final bool isNullable;
  final String? defaultValue;
  final bool isUnique;

  const ColumnSchema({
    required this.name,
    required this.dataType,
    this.isNullable = true,
    this.defaultValue,
    this.isUnique = false,
  });
}

/// Foreign key schema definition
class ForeignKeySchema {
  final String columnName;
  final String referencedTable;
  final String referencedColumn;
  final String onDelete;
  final String onUpdate;

  const ForeignKeySchema({
    required this.columnName,
    required this.referencedTable,
    required this.referencedColumn,
    this.onDelete = 'NO ACTION',
    this.onUpdate = 'NO ACTION',
  });
}

/// Index schema definition
class IndexSchema {
  final String name;
  final String tableName;
  final List<String> columns;
  final bool isUnique;

  const IndexSchema({
    required this.name,
    required this.tableName,
    required this.columns,
    this.isUnique = false,
  });
}

/// Trigger schema definition
class TriggerSchema {
  final String name;
  final String tableName;
  final String event; // INSERT, UPDATE, DELETE
  final String timing; // BEFORE, AFTER
  final String body;

  const TriggerSchema({
    required this.name,
    required this.tableName,
    required this.event,
    required this.timing,
    required this.body,
  });
}

/// Comprehensive schema consistency validator
class SchemaValidator {
  final CRDTDatabaseService _databaseService;
  final ExpectedSchema _expectedSchema;
  final List<SchemaValidationResult> _validationHistory = [];

  SchemaValidator(this._databaseService, this._expectedSchema);

  /// Validate the entire database schema
  Future<List<SchemaValidationResult>> validateSchema() async {
    final results = <SchemaValidationResult>[];

    try {
      // Check database version
      results.add(await _validateSchemaVersion());

      // Check tables
      results.addAll(await _validateTables());

      // Check columns
      results.addAll(await _validateColumns());

      // Check indexes
      results.addAll(await _validateIndexes());

      // Check foreign keys
      results.addAll(await _validateForeignKeys());

      // Check triggers
      results.addAll(await _validateTriggers());

      // Check data consistency
      results.addAll(await _validateDataConsistency());

      // Store validation history
      _validationHistory.addAll(results);
      await _storeValidationResults(results);

    } catch (e) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Schema Validation Error',
        isValid: false,
        errorMessage: 'Failed to validate schema: ${e.toString()}',
        details: {'error': e.toString()},
        severity: SchemaSeverity.fatal,
        timestamp: DateTime.now(),
        suggestedFix: 'Check database accessibility and permissions',
      ));
    }

    return results;
  }

  /// Validate a specific table schema
  Future<List<SchemaValidationResult>> validateTable(String tableName) async {
    final results = <SchemaValidationResult>[];

    if (!_expectedSchema.tables.containsKey(tableName)) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Unknown Table',
        isValid: false,
        errorMessage: 'Table $tableName is not in expected schema',
        details: {'table_name': tableName},
        severity: SchemaSeverity.warning,
        timestamp: DateTime.now(),
      ));
      return results;
    }

    final expectedTable = _expectedSchema.tables[tableName]!;

    // Check if table exists
    final tableExists = await _checkTableExists(tableName);
    if (!tableExists) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Missing Table',
        isValid: false,
        errorMessage: 'Required table $tableName does not exist',
        details: {'table_name': tableName},
        severity: SchemaSeverity.critical,
        timestamp: DateTime.now(),
        suggestedFix: 'Create table $tableName with proper schema',
      ));
      return results;
    }

    // Validate table structure
    results.addAll(await _validateTableStructure(expectedTable));

    return results;
  }

  /// Get schema migration recommendations
  Future<List<Map<String, dynamic>>> getMigrationRecommendations() async {
    final recommendations = <Map<String, dynamic>>[];
    final validationResults = await validateSchema();

    for (final result in validationResults.where((r) => !r.isValid)) {
      switch (result.checkName) {
        case 'Missing Table':
          recommendations.add({
            'type': 'create_table',
            'table_name': result.details['table_name'],
            'priority': 'high',
            'sql': _generateCreateTableSQL(result.details['table_name']),
          });
          break;

        case 'Missing Column':
          recommendations.add({
            'type': 'add_column',
            'table_name': result.details['table_name'],
            'column_name': result.details['column_name'],
            'priority': 'medium',
            'sql': _generateAddColumnSQL(
              result.details['table_name'],
              result.details['column_name'],
            ),
          });
          break;

        case 'Missing Index':
          recommendations.add({
            'type': 'create_index',
            'index_name': result.details['index_name'],
            'priority': 'low',
            'sql': _generateCreateIndexSQL(result.details['index_name']),
          });
          break;

        case 'Schema Version Mismatch':
          recommendations.add({
            'type': 'update_version',
            'current_version': result.details['current_version'],
            'target_version': result.details['expected_version'],
            'priority': 'critical',
            'sql': _generateUpdateVersionSQL(result.details['expected_version']),
          });
          break;
      }
    }

    return recommendations;
  }

  /// Execute schema migration
  Future<void> executeMigration(List<String> migrationSQL) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      for (final sql in migrationSQL) {
        await txn.execute(sql);
      }
    });

    // Validate schema after migration
    final validationResults = await validateSchema();
    final hasErrors = validationResults.any((r) => !r.isValid && 
        (r.severity == SchemaSeverity.error || r.severity == SchemaSeverity.critical));

    if (hasErrors) {
      throw DatabaseException('Schema migration completed but validation failed');
    }
  }

  /// Get schema health report
  Future<Map<String, dynamic>> getSchemaHealthReport() async {
    final validationResults = await validateSchema();
    
    final totalChecks = validationResults.length;
    final failedChecks = validationResults.where((r) => !r.isValid).length;
    final healthScore = totalChecks > 0 
        ? ((totalChecks - failedChecks) / totalChecks * 100) 
        : 100.0;

    // Group by severity
    final bySeverity = <String, int>{};
    for (final result in validationResults.where((r) => !r.isValid)) {
      bySeverity[result.severity.name] = (bySeverity[result.severity.name] ?? 0) + 1;
    }

    // Group by check type
    final byCheckType = <String, int>{};
    for (final result in validationResults.where((r) => !r.isValid)) {
      byCheckType[result.checkName] = (byCheckType[result.checkName] ?? 0) + 1;
    }

    return {
      'health_score': healthScore,
      'total_checks': totalChecks,
      'failed_checks': failedChecks,
      'by_severity': bySeverity,
      'by_check_type': byCheckType,
      'critical_issues': validationResults
          .where((r) => !r.isValid && 
                  (r.severity == SchemaSeverity.critical || 
                   r.severity == SchemaSeverity.fatal))
          .map((r) => {
            'check_name': r.checkName,
            'error_message': r.errorMessage,
            'suggested_fix': r.suggestedFix,
          })
          .toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Private helper methods

  Future<SchemaValidationResult> _validateSchemaVersion() async {
    final db = await _databaseService.database;
    
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      final currentVersion = result.first['user_version'] as int;
      
      final isValid = currentVersion == _expectedSchema.version;
      
      return SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Schema Version',
        isValid: isValid,
        errorMessage: isValid ? null : 
            'Schema version mismatch: expected ${_expectedSchema.version}, got $currentVersion',
        details: {
          'current_version': currentVersion,
          'expected_version': _expectedSchema.version,
        },
        severity: isValid ? SchemaSeverity.info : SchemaSeverity.critical,
        timestamp: DateTime.now(),
        suggestedFix: isValid ? null : 'Update schema version to ${_expectedSchema.version}',
      );
    } catch (e) {
      return SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Schema Version Check Failed',
        isValid: false,
        errorMessage: 'Failed to check schema version: ${e.toString()}',
        details: {'error': e.toString()},
        severity: SchemaSeverity.error,
        timestamp: DateTime.now(),
      );
    }
  }

  Future<List<SchemaValidationResult>> _validateTables() async {
    final results = <SchemaValidationResult>[];
    final db = await _databaseService.database;

    try {
      // Get existing tables
      final existingTables = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name NOT LIKE 'sqlite_%'
      ''');
      
      final existingTableNames = existingTables
          .map((t) => t['name'] as String)
          .toSet();

      // Check for missing tables
      for (final expectedTableName in _expectedSchema.tables.keys) {
        if (!existingTableNames.contains(expectedTableName)) {
          results.add(SchemaValidationResult(
            id: UuidGenerator.generateId(),
            checkName: 'Missing Table',
            isValid: false,
            errorMessage: 'Required table $expectedTableName does not exist',
            details: {'table_name': expectedTableName},
            severity: SchemaSeverity.critical,
            timestamp: DateTime.now(),
            suggestedFix: 'Create table $expectedTableName',
          ));
        }
      }

      // Check for unexpected tables
      for (final existingTableName in existingTableNames) {
        if (!_expectedSchema.tables.containsKey(existingTableName)) {
          results.add(SchemaValidationResult(
            id: UuidGenerator.generateId(),
            checkName: 'Unexpected Table',
            isValid: false,
            errorMessage: 'Unexpected table $existingTableName found',
            details: {'table_name': existingTableName},
            severity: SchemaSeverity.warning,
            timestamp: DateTime.now(),
            suggestedFix: 'Consider removing table $existingTableName if not needed',
          ));
        }
      }
    } catch (e) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Table Validation Failed',
        isValid: false,
        errorMessage: 'Failed to validate tables: ${e.toString()}',
        details: {'error': e.toString()},
        severity: SchemaSeverity.error,
        timestamp: DateTime.now(),
      ));
    }

    return results;
  }

  Future<List<SchemaValidationResult>> _validateColumns() async {
    final results = <SchemaValidationResult>[];
    final db = await _databaseService.database;

    for (final tableEntry in _expectedSchema.tables.entries) {
      final tableName = tableEntry.key;
      final expectedTable = tableEntry.value;

      try {
        // Check if table exists first
        if (!await _checkTableExists(tableName)) continue;

        // Get existing columns
        final existingColumns = await db.rawQuery('PRAGMA table_info($tableName)');
        final existingColumnNames = existingColumns
            .map((c) => c['name'] as String)
            .toSet();

        // Check for missing columns
        for (final expectedColumn in expectedTable.columns.values) {
          if (!existingColumnNames.contains(expectedColumn.name)) {
            results.add(SchemaValidationResult(
              id: UuidGenerator.generateId(),
              checkName: 'Missing Column',
              isValid: false,
              errorMessage: 'Column ${expectedColumn.name} missing in table $tableName',
              details: {
                'table_name': tableName,
                'column_name': expectedColumn.name,
                'expected_type': expectedColumn.dataType,
              },
              severity: SchemaSeverity.error,
              timestamp: DateTime.now(),
              suggestedFix: 'Add column ${expectedColumn.name} to table $tableName',
            ));
          }
        }

        // Check column types and constraints
        for (final existingColumn in existingColumns) {
          final columnName = existingColumn['name'] as String;
          final columnType = existingColumn['type'] as String;
          final isNullable = (existingColumn['notnull'] as int) == 0;

          if (expectedTable.columns.containsKey(columnName)) {
            final expectedColumn = expectedTable.columns[columnName]!;

            // Check data type
            if (!_isCompatibleType(columnType, expectedColumn.dataType)) {
              results.add(SchemaValidationResult(
                id: UuidGenerator.generateId(),
                checkName: 'Column Type Mismatch',
                isValid: false,
                errorMessage: 'Column $columnName in table $tableName has wrong type: expected ${expectedColumn.dataType}, got $columnType',
                details: {
                  'table_name': tableName,
                  'column_name': columnName,
                  'expected_type': expectedColumn.dataType,
                  'actual_type': columnType,
                },
                severity: SchemaSeverity.error,
                timestamp: DateTime.now(),
                suggestedFix: 'Migrate column $columnName to type ${expectedColumn.dataType}',
              ));
            }

            // Check nullability
            if (isNullable != expectedColumn.isNullable) {
              results.add(SchemaValidationResult(
                id: UuidGenerator.generateId(),
                checkName: 'Column Nullability Mismatch',
                isValid: false,
                errorMessage: 'Column $columnName in table $tableName has wrong nullability',
                details: {
                  'table_name': tableName,
                  'column_name': columnName,
                  'expected_nullable': expectedColumn.isNullable,
                  'actual_nullable': isNullable,
                },
                severity: SchemaSeverity.warning,
                timestamp: DateTime.now(),
                suggestedFix: expectedColumn.isNullable 
                    ? 'Allow NULL values for column $columnName'
                    : 'Add NOT NULL constraint to column $columnName',
              ));
            }
          }
        }
      } catch (e) {
        results.add(SchemaValidationResult(
          id: UuidGenerator.generateId(),
          checkName: 'Column Validation Failed',
          isValid: false,
          errorMessage: 'Failed to validate columns for table $tableName: ${e.toString()}',
          details: {
            'table_name': tableName,
            'error': e.toString(),
          },
          severity: SchemaSeverity.error,
          timestamp: DateTime.now(),
        ));
      }
    }

    return results;
  }

  Future<List<SchemaValidationResult>> _validateIndexes() async {
    final results = <SchemaValidationResult>[];
    final db = await _databaseService.database;

    try {
      // Get existing indexes
      final existingIndexes = await db.rawQuery('''
        SELECT name, tbl_name, sql FROM sqlite_master 
        WHERE type='index' AND name NOT LIKE 'sqlite_%'
      ''');

      final existingIndexNames = existingIndexes
          .map((i) => i['name'] as String)
          .toSet();

      // Check for missing indexes
      for (final expectedIndex in _expectedSchema.indexes) {
        if (!existingIndexNames.contains(expectedIndex.name)) {
          results.add(SchemaValidationResult(
            id: UuidGenerator.generateId(),
            checkName: 'Missing Index',
            isValid: false,
            errorMessage: 'Index ${expectedIndex.name} is missing',
            details: {
              'index_name': expectedIndex.name,
              'table_name': expectedIndex.tableName,
              'columns': expectedIndex.columns,
            },
            severity: SchemaSeverity.warning,
            timestamp: DateTime.now(),
            suggestedFix: 'Create index ${expectedIndex.name}',
          ));
        }
      }
    } catch (e) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Index Validation Failed',
        isValid: false,
        errorMessage: 'Failed to validate indexes: ${e.toString()}',
        details: {'error': e.toString()},
        severity: SchemaSeverity.error,
        timestamp: DateTime.now(),
      ));
    }

    return results;
  }

  Future<List<SchemaValidationResult>> _validateForeignKeys() async {
    final results = <SchemaValidationResult>[];
    final db = await _databaseService.database;

    // Check foreign key constraints
    try {
      final violations = await db.rawQuery('PRAGMA foreign_key_check');
      
      if (violations.isNotEmpty) {
        results.add(SchemaValidationResult(
          id: UuidGenerator.generateId(),
          checkName: 'Foreign Key Violations',
          isValid: false,
          errorMessage: '${violations.length} foreign key violations found',
          details: {'violations': violations},
          severity: SchemaSeverity.critical,
          timestamp: DateTime.now(),
          suggestedFix: 'Fix foreign key constraint violations',
        ));
      }
    } catch (e) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Foreign Key Check Failed',
        isValid: false,
        errorMessage: 'Failed to check foreign keys: ${e.toString()}',
        details: {'error': e.toString()},
        severity: SchemaSeverity.error,
        timestamp: DateTime.now(),
      ));
    }

    return results;
  }

  Future<List<SchemaValidationResult>> _validateTriggers() async {
    final results = <SchemaValidationResult>[];
    final db = await _databaseService.database;

    try {
      // Get existing triggers
      final existingTriggers = await db.rawQuery('''
        SELECT name, tbl_name, sql FROM sqlite_master 
        WHERE type='trigger'
      ''');

      final existingTriggerNames = existingTriggers
          .map((t) => t['name'] as String)
          .toSet();

      // Check for missing triggers
      for (final expectedTrigger in _expectedSchema.triggers) {
        if (!existingTriggerNames.contains(expectedTrigger.name)) {
          results.add(SchemaValidationResult(
            id: UuidGenerator.generateId(),
            checkName: 'Missing Trigger',
            isValid: false,
            errorMessage: 'Trigger ${expectedTrigger.name} is missing',
            details: {
              'trigger_name': expectedTrigger.name,
              'table_name': expectedTrigger.tableName,
            },
            severity: SchemaSeverity.warning,
            timestamp: DateTime.now(),
            suggestedFix: 'Create trigger ${expectedTrigger.name}',
          ));
        }
      }
    } catch (e) {
      results.add(SchemaValidationResult(
        id: UuidGenerator.generateId(),
        checkName: 'Trigger Validation Failed',
        isValid: false,
        errorMessage: 'Failed to validate triggers: ${e.toString()}',
        details: {'error': e.toString()},
        severity: SchemaSeverity.error,
        timestamp: DateTime.now(),
      ));
    }

    return results;
  }

  Future<List<SchemaValidationResult>> _validateDataConsistency() async {
    final results = <SchemaValidationResult>[];
    final db = await _databaseService.database;

    // Check for orphaned records
    for (final tableEntry in _expectedSchema.tables.entries) {
      final tableName = tableEntry.key;
      final tableSchema = tableEntry.value;

      for (final fk in tableSchema.foreignKeys) {
        try {
          final orphans = await db.rawQuery('''
            SELECT COUNT(*) as count FROM $tableName t
            LEFT JOIN ${fk.referencedTable} r ON t.${fk.columnName} = r.${fk.referencedColumn}
            WHERE t.${fk.columnName} IS NOT NULL AND r.${fk.referencedColumn} IS NULL
          ''');

          final orphanCount = orphans.first['count'] as int;
          if (orphanCount > 0) {
            results.add(SchemaValidationResult(
              id: UuidGenerator.generateId(),
              checkName: 'Orphaned Records',
              isValid: false,
              errorMessage: '$orphanCount orphaned records in $tableName.${fk.columnName}',
              details: {
                'table_name': tableName,
                'column_name': fk.columnName,
                'referenced_table': fk.referencedTable,
                'orphan_count': orphanCount,
              },
              severity: SchemaSeverity.error,
              timestamp: DateTime.now(),
              suggestedFix: 'Clean up orphaned records or restore referenced data',
            ));
          }
        } catch (e) {
          // Skip if table doesn't exist
          continue;
        }
      }
    }

    return results;
  }

  Future<List<SchemaValidationResult>> _validateTableStructure(TableSchema expectedTable) async {
    final results = <SchemaValidationResult>[];
    // Implementation would validate specific table structure
    return results;
  }

  Future<bool> _checkTableExists(String tableName) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name=?
    ''', [tableName]);
    return result.isNotEmpty;
  }

  bool _isCompatibleType(String actualType, String expectedType) {
    // Normalize types for comparison
    final normalizedActual = actualType.toUpperCase();
    final normalizedExpected = expectedType.toUpperCase();

    // Direct match
    if (normalizedActual == normalizedExpected) return true;

    // Common SQLite type equivalencies
    final typeMap = {
      'INTEGER': ['INT', 'BIGINT', 'SMALLINT'],
      'TEXT': ['VARCHAR', 'CHAR', 'STRING'],
      'REAL': ['FLOAT', 'DOUBLE', 'DECIMAL'],
      'BLOB': ['BINARY'],
    };

    for (final entry in typeMap.entries) {
      if (entry.value.contains(normalizedActual) && 
          entry.value.contains(normalizedExpected)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _storeValidationResults(List<SchemaValidationResult> results) async {
    final db = await _databaseService.database;

    // Create table if not exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_validation_results (
        id TEXT PRIMARY KEY,
        check_name TEXT NOT NULL,
        is_valid INTEGER NOT NULL,
        error_message TEXT,
        details TEXT NOT NULL,
        severity TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        suggested_fix TEXT
      )
    ''');

    for (final result in results) {
      await db.insert('schema_validation_results', result.toJson());
    }
  }

  String _generateCreateTableSQL(String tableName) {
    if (!_expectedSchema.tables.containsKey(tableName)) {
      return '-- Table $tableName not found in expected schema';
    }

    final table = _expectedSchema.tables[tableName]!;
    final columnDefs = table.columns.values.map((col) {
      var def = '${col.name} ${col.dataType}';
      if (!col.isNullable) def += ' NOT NULL';
      if (col.defaultValue != null) def += ' DEFAULT ${col.defaultValue}';
      if (col.isUnique) def += ' UNIQUE';
      return def;
    }).join(', ');

    var sql = 'CREATE TABLE $tableName ($columnDefs';
    
    if (table.primaryKey.isNotEmpty) {
      sql += ', PRIMARY KEY (${table.primaryKey.join(', ')})';
    }

    for (final fk in table.foreignKeys) {
      sql += ', FOREIGN KEY (${fk.columnName}) REFERENCES ${fk.referencedTable}(${fk.referencedColumn})';
      if (fk.onDelete != 'NO ACTION') sql += ' ON DELETE ${fk.onDelete}';
      if (fk.onUpdate != 'NO ACTION') sql += ' ON UPDATE ${fk.onUpdate}';
    }

    sql += ')';
    return sql;
  }

  String _generateAddColumnSQL(String tableName, String columnName) {
    if (!_expectedSchema.tables.containsKey(tableName)) {
      return '-- Table $tableName not found in expected schema';
    }

    final table = _expectedSchema.tables[tableName]!;
    if (!table.columns.containsKey(columnName)) {
      return '-- Column $columnName not found in expected schema for table $tableName';
    }

    final col = table.columns[columnName]!;
    var sql = 'ALTER TABLE $tableName ADD COLUMN ${col.name} ${col.dataType}';
    
    if (!col.isNullable) sql += ' NOT NULL';
    if (col.defaultValue != null) sql += ' DEFAULT ${col.defaultValue}';

    return sql;
  }

  String _generateCreateIndexSQL(String indexName) {
    final index = _expectedSchema.indexes.firstWhere(
      (i) => i.name == indexName,
      orElse: () => throw ArgumentError('Index $indexName not found'),
    );

    final uniqueClause = index.isUnique ? 'UNIQUE ' : '';
    return 'CREATE ${uniqueClause}INDEX $indexName ON ${index.tableName} (${index.columns.join(', ')})';
  }

  String _generateUpdateVersionSQL(int version) {
    return 'PRAGMA user_version = $version';
  }
}

/// Factory for creating expected schema definitions
class SchemaDefinitionFactory {
  /// Create the expected schema for BizSync database
  static ExpectedSchema createBizSyncSchema() {
    return ExpectedSchema(
      version: 1,
      tables: {
        'customers_crdt': TableSchema(
          name: 'customers_crdt',
          columns: {
            'id': const ColumnSchema(name: 'id', dataType: 'TEXT', isNullable: false),
            'name': const ColumnSchema(name: 'name', dataType: 'TEXT', isNullable: false),
            'email': const ColumnSchema(name: 'email', dataType: 'TEXT'),
            'phone': const ColumnSchema(name: 'phone', dataType: 'TEXT'),
            'address': const ColumnSchema(name: 'address', dataType: 'TEXT'),
            'created_at': const ColumnSchema(name: 'created_at', dataType: 'INTEGER', isNullable: false),
            'updated_at': const ColumnSchema(name: 'updated_at', dataType: 'INTEGER', isNullable: false),
            'is_deleted': const ColumnSchema(name: 'is_deleted', dataType: 'INTEGER', defaultValue: '0'),
            'vector_clock': const ColumnSchema(name: 'vector_clock', dataType: 'TEXT'),
          },
          primaryKey: ['id'],
        ),
        'invoices_crdt': TableSchema(
          name: 'invoices_crdt',
          columns: {
            'id': const ColumnSchema(name: 'id', dataType: 'TEXT', isNullable: false),
            'invoice_number': const ColumnSchema(name: 'invoice_number', dataType: 'TEXT', isNullable: false),
            'customer_id': const ColumnSchema(name: 'customer_id', dataType: 'TEXT'),
            'total_amount': const ColumnSchema(name: 'total_amount', dataType: 'REAL', isNullable: false),
            'status': const ColumnSchema(name: 'status', dataType: 'TEXT', defaultValue: "'draft'"),
            'created_at': const ColumnSchema(name: 'created_at', dataType: 'INTEGER', isNullable: false),
            'updated_at': const ColumnSchema(name: 'updated_at', dataType: 'INTEGER', isNullable: false),
            'is_deleted': const ColumnSchema(name: 'is_deleted', dataType: 'INTEGER', defaultValue: '0'),
            'vector_clock': const ColumnSchema(name: 'vector_clock', dataType: 'TEXT'),
          },
          primaryKey: ['id'],
          foreignKeys: [
            const ForeignKeySchema(
              columnName: 'customer_id',
              referencedTable: 'customers_crdt',
              referencedColumn: 'id',
            ),
          ],
        ),
        'products_crdt': TableSchema(
          name: 'products_crdt',
          columns: {
            'id': const ColumnSchema(name: 'id', dataType: 'TEXT', isNullable: false),
            'name': const ColumnSchema(name: 'name', dataType: 'TEXT', isNullable: false),
            'description': const ColumnSchema(name: 'description', dataType: 'TEXT'),
            'price': const ColumnSchema(name: 'price', dataType: 'REAL', isNullable: false),
            'stock_quantity': const ColumnSchema(name: 'stock_quantity', dataType: 'INTEGER', defaultValue: '0'),
            'created_at': const ColumnSchema(name: 'created_at', dataType: 'INTEGER', isNullable: false),
            'updated_at': const ColumnSchema(name: 'updated_at', dataType: 'INTEGER', isNullable: false),
            'is_deleted': const ColumnSchema(name: 'is_deleted', dataType: 'INTEGER', defaultValue: '0'),
            'vector_clock': const ColumnSchema(name: 'vector_clock', dataType: 'TEXT'),
          },
          primaryKey: ['id'],
        ),
      },
      indexes: [
        const IndexSchema(
          name: 'idx_customers_name',
          tableName: 'customers_crdt',
          columns: ['name'],
        ),
        const IndexSchema(
          name: 'idx_customers_email',
          tableName: 'customers_crdt',
          columns: ['email'],
        ),
        const IndexSchema(
          name: 'idx_invoices_customer',
          tableName: 'invoices_crdt',
          columns: ['customer_id'],
        ),
        const IndexSchema(
          name: 'idx_invoices_status',
          tableName: 'invoices_crdt',
          columns: ['status'],
        ),
        const IndexSchema(
          name: 'idx_products_name',
          tableName: 'products_crdt',
          columns: ['name'],
        ),
      ],
      triggers: [
        const TriggerSchema(
          name: 'update_customer_timestamp',
          tableName: 'customers_crdt',
          event: 'UPDATE',
          timing: 'BEFORE',
          body: 'UPDATE customers_crdt SET updated_at = strftime("%s", "now") * 1000 WHERE id = NEW.id',
        ),
        const TriggerSchema(
          name: 'update_invoice_timestamp',
          tableName: 'invoices_crdt',
          event: 'UPDATE',
          timing: 'BEFORE',
          body: 'UPDATE invoices_crdt SET updated_at = strftime("%s", "now") * 1000 WHERE id = NEW.id',
        ),
      ],
    );
  }
}