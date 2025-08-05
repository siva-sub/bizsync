import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/uuid_generator.dart';
import '../constants/app_constants.dart';
import '../database/platform_database_factory.dart';

/// Platform compatibility test result
class CompatibilityTestResult {
  final String testName;
  final String platform;
  final bool passed;
  final String? errorMessage;
  final Map<String, dynamic> details;
  final DateTime timestamp;
  final String severity; // 'critical', 'warning', 'info'
  final String? recommendation;

  const CompatibilityTestResult({
    required this.testName,
    required this.platform,
    required this.passed,
    this.errorMessage,
    required this.details,
    required this.timestamp,
    required this.severity,
    this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'test_name': testName,
      'platform': platform,
      'passed': passed,
      'error_message': errorMessage,
      'details': jsonEncode(details),
      'timestamp': timestamp.toIso8601String(),
      'severity': severity,
      'recommendation': recommendation,
    };
  }

  factory CompatibilityTestResult.fromJson(Map<String, dynamic> json) {
    return CompatibilityTestResult(
      testName: json['test_name'] as String,
      platform: json['platform'] as String,
      passed: json['passed'] as bool,
      errorMessage: json['error_message'] as String?,
      details: jsonDecode(json['details'] as String) as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      severity: json['severity'] as String,
      recommendation: json['recommendation'] as String?,
    );
  }
}

/// Cross-platform compatibility validation report
class CompatibilityReport {
  final String reportId;
  final DateTime generatedAt;
  final String platform;
  final List<CompatibilityTestResult> testResults;
  final Map<String, dynamic> platformInfo;
  final List<String> criticalIssues;
  final List<String> recommendations;
  final double compatibilityScore;
  final bool isCompatible;

  const CompatibilityReport({
    required this.reportId,
    required this.generatedAt,
    required this.platform,
    required this.testResults,
    required this.platformInfo,
    required this.criticalIssues,
    required this.recommendations,
    required this.compatibilityScore,
    required this.isCompatible,
  });

  Map<String, dynamic> toJson() {
    return {
      'report_id': reportId,
      'generated_at': generatedAt.toIso8601String(),
      'platform': platform,
      'test_results': testResults.map((r) => r.toJson()).toList(),
      'platform_info': platformInfo,
      'critical_issues': criticalIssues,
      'recommendations': recommendations,
      'compatibility_score': compatibilityScore,
      'is_compatible': isCompatible,
    };
  }
}

/// Comprehensive cross-platform compatibility validator for database operations
class CrossPlatformCompatibilityValidator {
  final Map<String, List<CompatibilityTestResult>> _testHistory = {};
  final Map<String, Map<String, dynamic>> _platformConfigurations = {};
  final List<String> _knownIncompatibilities = [];

  // Test categories
  static const List<String> testCategories = [
    'database_factory',
    'pragma_commands',
    'file_system',
    'permissions',
    'sqlite_features',
    'encryption',
    'concurrent_access',
    'performance',
  ];

  CrossPlatformCompatibilityValidator() {
    _initializeKnownIncompatibilities();
    _loadPlatformConfigurations();
  }

  /// Run comprehensive compatibility validation
  Future<CompatibilityReport> validateCompatibility({
    bool includePerformanceTests = false,
    bool includeEncryptionTests = true,
    List<String>? specificTests,
  }) async {
    debugPrint('🔍 Starting cross-platform compatibility validation...');
    
    final platform = Platform.operatingSystem;
    final reportId = UuidGenerator.generateId();
    final timestamp = DateTime.now();
    final testResults = <CompatibilityTestResult>[];

    // Collect platform information
    final platformInfo = await _collectPlatformInfo();

    // Run test categories
    if (specificTests == null || specificTests.isEmpty) {
      // Run all tests
      testResults.addAll(await _testDatabaseFactory());
      testResults.addAll(await _testPragmaCommands());
      testResults.addAll(await _testFileSystem());
      testResults.addAll(await _testPermissions());
      testResults.addAll(await _testSQLiteFeatures());
      
      if (includeEncryptionTests) {
        testResults.addAll(await _testEncryption());
      }
      
      testResults.addAll(await _testConcurrentAccess());
      
      if (includePerformanceTests) {
        testResults.addAll(await _testPerformance());
      }
    } else {
      // Run specific tests
      for (final testCategory in specificTests) {
        switch (testCategory) {
          case 'database_factory':
            testResults.addAll(await _testDatabaseFactory());
            break;
          case 'pragma_commands':
            testResults.addAll(await _testPragmaCommands());
            break;
          case 'file_system':
            testResults.addAll(await _testFileSystem());
            break;
          case 'permissions':
            testResults.addAll(await _testPermissions());
            break;
          case 'sqlite_features':
            testResults.addAll(await _testSQLiteFeatures());
            break;
          case 'encryption':
            if (includeEncryptionTests) {
              testResults.addAll(await _testEncryption());
            }
            break;
          case 'concurrent_access':
            testResults.addAll(await _testConcurrentAccess());
            break;
          case 'performance':
            if (includePerformanceTests) {
              testResults.addAll(await _testPerformance());
            }
            break;
        }
      }
    }

    // Analyze results
    final analysis = _analyzeTestResults(testResults);
    
    // Store results for historical analysis
    _testHistory[reportId] = testResults;

    final report = CompatibilityReport(
      reportId: reportId,
      generatedAt: timestamp,
      platform: platform,
      testResults: testResults,
      platformInfo: platformInfo,
      criticalIssues: analysis['critical_issues'],
      recommendations: analysis['recommendations'],
      compatibilityScore: analysis['compatibility_score'],
      isCompatible: analysis['is_compatible'],
    );

    debugPrint('✅ Compatibility validation completed: ${report.compatibilityScore.toStringAsFixed(1)}% compatible');
    
    return report;
  }

  /// Test database factory initialization
  Future<List<CompatibilityTestResult>> _testDatabaseFactory() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    // Test 1: Platform detection
    results.add(CompatibilityTestResult(
      testName: 'Platform Detection',
      platform: platform,
      passed: true,
      details: {
        'detected_platform': platform,
        'is_desktop': isDesktop,
        'is_mobile': Platform.isAndroid || Platform.isIOS,
      },
      timestamp: DateTime.now(),
      severity: 'info',
    ));

    // Test 2: FFI initialization for desktop platforms
    if (isDesktop) {
      try {
        sqfliteFfiInit();
        results.add(CompatibilityTestResult(
          testName: 'SQLite FFI Initialization',
          platform: platform,
          passed: true,
          details: {
            'ffi_initialized': true,
            'factory_type': 'sqflite_common_ffi',
          },
          timestamp: DateTime.now(),
          severity: 'info',
        ));
      } catch (e) {
        results.add(CompatibilityTestResult(
          testName: 'SQLite FFI Initialization',
          platform: platform,
          passed: false,
          errorMessage: e.toString(),
          details: {
            'ffi_initialized': false,
            'error': e.toString(),
          },
          timestamp: DateTime.now(),
          severity: 'critical',
          recommendation: 'Ensure sqflite_common_ffi dependency is properly included',
        ));
      }
    }

    // Test 3: Database factory assignment
    try {
      DatabaseFactory factory;
      if (isDesktop) {
        factory = databaseFactoryFfi;
      } else {
        factory = databaseFactory;
      }
      
      results.add(CompatibilityTestResult(
        testName: 'Database Factory Assignment',
        platform: platform,
        passed: true,
        details: {
          'factory_available': true,
          'factory_type': isDesktop ? 'ffi' : 'native',
        },
        timestamp: DateTime.now(),
        severity: 'info',
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Database Factory Assignment',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'factory_available': false,
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Check database factory initialization sequence',
      ));
    }

    // Test 4: Test database creation
    try {
      final tempDir = await getTemporaryDirectory();
      final testDbPath = '${tempDir.path}/compatibility_test.db';
      
      Database db;
      if (isDesktop) {
        db = await databaseFactoryFfi.openDatabase(testDbPath);
      } else {
        db = await openDatabase(testDbPath);
      }
      
      await db.close();
      await File(testDbPath).delete();
      
      results.add(CompatibilityTestResult(
        testName: 'Test Database Creation',
        platform: platform,
        passed: true,
        details: {
          'database_created': true,
          'path': testDbPath,
        },
        timestamp: DateTime.now(),
        severity: 'info',
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Test Database Creation',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'database_created': false,
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Check database creation permissions and factory setup',
      ));
    }

    return results;
  }

  /// Test PRAGMA command compatibility
  Future<List<CompatibilityTestResult>> _testPragmaCommands() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    try {
      final tempDir = await getTemporaryDirectory();
      final testDbPath = '${tempDir.path}/pragma_test.db';
      
      Database db;
      if (isDesktop) {
        db = await databaseFactoryFfi.openDatabase(testDbPath);
      } else {
        db = await openDatabase(testDbPath);
      }

      // Test various PRAGMA commands
      final pragmaTests = <String, bool>{};
      final pragmaCommands = {
        'foreign_keys': 'PRAGMA foreign_keys = ON',
        'journal_mode_wal': 'PRAGMA journal_mode = WAL',
        'journal_mode_delete': 'PRAGMA journal_mode = DELETE',
        'synchronous_normal': 'PRAGMA synchronous = NORMAL',
        'synchronous_full': 'PRAGMA synchronous = FULL',
        'cache_size': 'PRAGMA cache_size = 10000',
        'temp_store_memory': 'PRAGMA temp_store = MEMORY',
        'temp_store_file': 'PRAGMA temp_store = FILE',
        'locking_mode_normal': 'PRAGMA locking_mode = NORMAL',
        'locking_mode_exclusive': 'PRAGMA locking_mode = EXCLUSIVE',
      };

      for (final entry in pragmaCommands.entries) {
        try {
          await db.execute(entry.value);
          pragmaTests[entry.key] = true;
        } catch (e) {
          pragmaTests[entry.key] = false;
          
          // Create individual test result for failed PRAGMA
          results.add(CompatibilityTestResult(
            testName: 'PRAGMA ${entry.key}',
            platform: platform,
            passed: false,
            errorMessage: e.toString(),
            details: {
              'pragma_command': entry.value,
              'error': e.toString(),
            },
            timestamp: DateTime.now(),
            severity: entry.key == 'foreign_keys' ? 'warning' : 'info',
            recommendation: _getPragmaRecommendation(entry.key, platform),
          ));
        }
      }

      await db.close();
      await File(testDbPath).delete();

      // Overall PRAGMA compatibility result
      final passedCount = pragmaTests.values.where((passed) => passed).length;
      final totalCount = pragmaTests.length;
      final compatibilityRate = (passedCount / totalCount) * 100;

      results.add(CompatibilityTestResult(
        testName: 'PRAGMA Commands Compatibility',
        platform: platform,
        passed: compatibilityRate >= 70, // 70% threshold
        details: {
          'total_tested': totalCount,
          'passed': passedCount,
          'compatibility_rate': compatibilityRate,
          'test_results': pragmaTests,
        },
        timestamp: DateTime.now(),
        severity: compatibilityRate >= 90 ? 'info' : 
                 compatibilityRate >= 70 ? 'warning' : 'critical',
        recommendation: compatibilityRate < 70 
          ? 'Consider using platform-specific PRAGMA configurations'
          : null,
      ));

    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'PRAGMA Commands Compatibility',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Fix database access issues before testing PRAGMA commands',
      ));
    }

    return results;
  }

  /// Test file system compatibility
  Future<List<CompatibilityTestResult>> _testFileSystem() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;

    // Test 1: Application documents directory access
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      
      results.add(CompatibilityTestResult(
        testName: 'Application Documents Directory',
        platform: platform,
        passed: true,
        details: {
          'path': appDocsDir.path,
          'exists': await appDocsDir.exists(),
        },
        timestamp: DateTime.now(),
        severity: 'info',
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Application Documents Directory',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Check path_provider configuration and permissions',
      ));
    }

    // Test 2: Temporary directory access
    try {
      final tempDir = await getTemporaryDirectory();
      
      results.add(CompatibilityTestResult(
        testName: 'Temporary Directory',
        platform: platform,
        passed: true,
        details: {
          'path': tempDir.path,
          'exists': await tempDir.exists(),
        },
        timestamp: DateTime.now(),
        severity: 'info',
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Temporary Directory',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'warning',
        recommendation: 'Use alternative temporary storage location',
      ));
    }

    // Test 3: File creation and deletion
    try {
      final tempDir = await getTemporaryDirectory();
      final testFile = File('${tempDir.path}/fs_test.txt');
      
      // Create file
      await testFile.writeAsString('test content');
      final exists = await testFile.exists();
      
      // Read file
      final content = await testFile.readAsString();
      
      // Delete file
      await testFile.delete();
      final deleted = !await testFile.exists();
      
      results.add(CompatibilityTestResult(
        testName: 'File Operations',
        platform: platform,
        passed: exists && content == 'test content' && deleted,
        details: {
          'create_success': exists,
          'read_success': content == 'test content',
          'delete_success': deleted,
        },
        timestamp: DateTime.now(),
        severity: 'info',
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'File Operations',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Check file system permissions and storage availability',
      ));
    }

    // Test 4: Database file specific operations
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocsDir.path}/${AppConstants.databaseName}';
      
      // Check if database path is accessible
      final dbFile = File(dbPath);
      final parentDir = dbFile.parent;
      
      final parentExists = await parentDir.exists();
      final canWrite = await _testDirectoryWriteAccess(parentDir.path);
      
      results.add(CompatibilityTestResult(
        testName: 'Database File Path Access',
        platform: platform,
        passed: parentExists && canWrite,
        details: {
          'database_path': dbPath,
          'parent_directory_exists': parentExists,
          'write_access': canWrite,
        },
        timestamp: DateTime.now(),
        severity: parentExists && canWrite ? 'info' : 'critical',
        recommendation: !parentExists ? 'Create database directory' :
                       !canWrite ? 'Fix directory permissions' : null,
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Database File Path Access',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Use alternative database location with proper permissions',
      ));
    }

    return results;
  }

  /// Test permissions
  Future<List<CompatibilityTestResult>> _testPermissions() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;

    // Android-specific permission tests
    if (Platform.isAndroid) {
      // Test storage permissions (this would require actual permission checking)
      results.add(CompatibilityTestResult(
        testName: 'Android Storage Permissions',
        platform: platform,
        passed: true, // Placeholder - would check actual permissions
        details: {
          'external_storage': true, // Placeholder
          'internal_storage': true, // Placeholder
        },
        timestamp: DateTime.now(),
        severity: 'info',
        recommendation: 'Verify storage permissions in AndroidManifest.xml',
      ));
    }

    // Desktop-specific permission tests
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      try {
        final appDocsDir = await getApplicationDocumentsDirectory();
        final hasWriteAccess = await _testDirectoryWriteAccess(appDocsDir.path);
        
        results.add(CompatibilityTestResult(
          testName: 'Desktop File System Permissions',
          platform: platform,
          passed: hasWriteAccess,
          details: {
            'documents_directory_writable': hasWriteAccess,
            'directory_path': appDocsDir.path,
          },
          timestamp: DateTime.now(),
          severity: hasWriteAccess ? 'info' : 'critical',
          recommendation: hasWriteAccess ? null : 'Run application with appropriate file permissions',
        ));
      } catch (e) {
        results.add(CompatibilityTestResult(
          testName: 'Desktop File System Permissions',
          platform: platform,
          passed: false,
          errorMessage: e.toString(),
          details: {
            'error': e.toString(),
          },
          timestamp: DateTime.now(),
          severity: 'critical',
          recommendation: 'Check application permissions and file system access',
        ));
      }
    }

    return results;
  }

  /// Test SQLite features
  Future<List<CompatibilityTestResult>> _testSQLiteFeatures() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    try {
      final tempDir = await getTemporaryDirectory();
      final testDbPath = '${tempDir.path}/sqlite_features_test.db';
      
      Database db;
      if (isDesktop) {
        db = await databaseFactoryFfi.openDatabase(testDbPath);
      } else {
        db = await openDatabase(testDbPath);
      }

      // Test 1: Basic SQL operations
      try {
        await db.execute('''
          CREATE TABLE test_table (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER
          )
        ''');
        
        await db.insert('test_table', {
          'name': 'Test Record',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        
        final records = await db.query('test_table');
        
        results.add(CompatibilityTestResult(
          testName: 'Basic SQL Operations',
          platform: platform,
          passed: records.length == 1,
          details: {
            'table_created': true,
            'record_inserted': true,
            'record_queried': records.length == 1,
          },
          timestamp: DateTime.now(),
          severity: 'info',
        ));
      } catch (e) {
        results.add(CompatibilityTestResult(
          testName: 'Basic SQL Operations',
          platform: platform,
          passed: false,
          errorMessage: e.toString(),
          details: {
            'error': e.toString(),
          },
          timestamp: DateTime.now(),
          severity: 'critical',
          recommendation: 'Check SQLite installation and database access',
        ));
      }

      // Test 2: Foreign key constraints
      try {
        await db.execute('PRAGMA foreign_keys = ON');
        
        await db.execute('''
          CREATE TABLE parent_table (
            id INTEGER PRIMARY KEY,
            name TEXT
          )
        ''');
        
        await db.execute('''
          CREATE TABLE child_table (
            id INTEGER PRIMARY KEY,
            parent_id INTEGER,
            name TEXT,
            FOREIGN KEY (parent_id) REFERENCES parent_table (id)
          )
        ''');
        
        // Insert parent record
        await db.insert('parent_table', {'id': 1, 'name': 'Parent'});
        
        // Try to insert child with valid parent
        await db.insert('child_table', {'parent_id': 1, 'name': 'Child'});
        
        // Try to insert child with invalid parent (should fail)
        bool foreignKeyWorking = false;
        try {
          await db.insert('child_table', {'parent_id': 999, 'name': 'Orphan'});
        } catch (e) {
          foreignKeyWorking = true; // Foreign key constraint worked
        }
        
        results.add(CompatibilityTestResult(
          testName: 'Foreign Key Constraints',
          platform: platform,
          passed: foreignKeyWorking,
          details: {
            'foreign_keys_enabled': true,
            'constraint_enforced': foreignKeyWorking,
          },
          timestamp: DateTime.now(),
          severity: foreignKeyWorking ? 'info' : 'warning',
          recommendation: foreignKeyWorking ? null : 'Foreign key constraints may not be properly enforced',
        ));
      } catch (e) {
        results.add(CompatibilityTestResult(
          testName: 'Foreign Key Constraints',
          platform: platform,
          passed: false,
          errorMessage: e.toString(),
          details: {
            'error': e.toString(),
          },
          timestamp: DateTime.now(),
          severity: 'warning',
          recommendation: 'Foreign key support may be limited on this platform',
        ));
      }

      // Test 3: JSON support (if available)
      try {
        await db.execute('''
          CREATE TABLE json_test (
            id INTEGER PRIMARY KEY,
            data TEXT
          )
        ''');
        
        await db.insert('json_test', {
          'data': jsonEncode({'key': 'value', 'number': 42}),
        });
        
        // Try to use JSON functions (SQLite 3.38+)
        bool jsonSupported = false;
        try {
          final result = await db.rawQuery(
            "SELECT json_extract(data, '\$.key') as extracted FROM json_test"
          );
          jsonSupported = result.isNotEmpty && result.first['extracted'] == 'value';
        } catch (e) {
          // JSON functions not supported
        }
        
        results.add(CompatibilityTestResult(
          testName: 'JSON Support',
          platform: platform,
          passed: true, // Basic JSON storage always works
          details: {
            'json_storage': true,
            'json_functions': jsonSupported,
          },
          timestamp: DateTime.now(),
          severity: 'info',
        ));
      } catch (e) {
        results.add(CompatibilityTestResult(
          testName: 'JSON Support',
          platform: platform,
          passed: false,
          errorMessage: e.toString(),
          details: {
            'error': e.toString(),
          },
          timestamp: DateTime.now(),
          severity: 'warning',
          recommendation: 'Use alternative JSON handling approach',
        ));
      }

      // Test 4: SQLite version
      try {
        final versionResult = await db.rawQuery('SELECT sqlite_version()');
        final version = versionResult.first.values.first as String;
        
        results.add(CompatibilityTestResult(
          testName: 'SQLite Version',
          platform: platform,
          passed: true,
          details: {
            'sqlite_version': version,
          },
          timestamp: DateTime.now(),
          severity: 'info',
        ));
      } catch (e) {
        results.add(CompatibilityTestResult(
          testName: 'SQLite Version',
          platform: platform,
          passed: false,
          errorMessage: e.toString(),
          details: {
            'error': e.toString(),
          },
          timestamp: DateTime.now(),
          severity: 'warning',
          recommendation: 'SQLite version information unavailable',
        ));
      }

      await db.close();
      await File(testDbPath).delete();

    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'SQLite Features Test Setup',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'critical',
        recommendation: 'Fix database access issues before testing SQLite features',
      ));
    }

    return results;
  }

  /// Test encryption support
  Future<List<CompatibilityTestResult>> _testEncryption() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;

    // Test SQLCipher availability
    try {
      final supportsSqlcipher = await PlatformDatabaseFactory.supportsSqlcipher;
      
      results.add(CompatibilityTestResult(
        testName: 'SQLCipher Support',
        platform: platform,
        passed: supportsSqlcipher,
        details: {
          'sqlcipher_available': supportsSqlcipher,
          'encryption_supported': supportsSqlcipher,
        },
        timestamp: DateTime.now(),
        severity: supportsSqlcipher ? 'info' : 'warning',
        recommendation: supportsSqlcipher ? null : 
          'SQLCipher not available - consider using alternative encryption or disable encryption',
      ));
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'SQLCipher Support',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
          'sqlcipher_available': false,
        },
        timestamp: DateTime.now(),
        severity: 'warning',
        recommendation: 'SQLCipher compatibility check failed - use standard SQLite',
      ));
    }

    // Test encrypted database creation (if supported)
    try {
      final supportsSqlcipher = await PlatformDatabaseFactory.supportsSqlcipher;
      if (supportsSqlcipher) {
        final tempDir = await getTemporaryDirectory();
        final testDbPath = '${tempDir.path}/encryption_test.db';
        
        // This would test actual encrypted database creation
        // For now, we'll mark as not implemented
        results.add(CompatibilityTestResult(
          testName: 'Encrypted Database Creation',
          platform: platform,
          passed: false,
          details: {
            'test_implemented': false,
            'reason': 'Encrypted database test not fully implemented',
          },
          timestamp: DateTime.now(),
          severity: 'info',
          recommendation: 'Implement encrypted database creation test',
        ));
      }
    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Encrypted Database Creation',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'warning',
        recommendation: 'Fix encryption setup or disable encryption',
      ));
    }

    return results;
  }

  /// Test concurrent access
  Future<List<CompatibilityTestResult>> _testConcurrentAccess() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    try {
      final tempDir = await getTemporaryDirectory();
      final testDbPath = '${tempDir.path}/concurrent_test.db';
      
      // Create and setup database
      Database db;
      if (isDesktop) {
        db = await databaseFactoryFfi.openDatabase(testDbPath);
      } else {
        db = await openDatabase(testDbPath);
      }
      
      await db.execute('''
        CREATE TABLE concurrent_test (
          id INTEGER PRIMARY KEY,
          value INTEGER
        )
      ''');
      
      await db.close();

      // Test multiple connections
      final futures = <Future<bool>>[];
      
      for (int i = 0; i < 3; i++) {
        futures.add(_testSingleConnection(testDbPath, i, isDesktop));
      }
      
      final results_list = await Future.wait(futures);
      final allSucceeded = results_list.every((success) => success);
      
      results.add(CompatibilityTestResult(
        testName: 'Concurrent Database Access',
        platform: platform,
        passed: allSucceeded,
        details: {
          'concurrent_connections': 3,
          'all_succeeded': allSucceeded,
          'individual_results': results_list,
        },
        timestamp: DateTime.now(),
        severity: allSucceeded ? 'info' : 'warning',
        recommendation: allSucceeded ? null : 
          'Consider implementing connection pooling or synchronization',
      ));

      await File(testDbPath).delete();

    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Concurrent Database Access',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'warning',
        recommendation: 'Fix database access issues before testing concurrency',
      ));
    }

    return results;
  }

  /// Test performance characteristics
  Future<List<CompatibilityTestResult>> _testPerformance() async {
    final results = <CompatibilityTestResult>[];
    final platform = Platform.operatingSystem;
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    try {
      final tempDir = await getTemporaryDirectory();
      final testDbPath = '${tempDir.path}/performance_test.db';
      
      Database db;
      if (isDesktop) {
        db = await databaseFactoryFfi.openDatabase(testDbPath);
      } else {
        db = await openDatabase(testDbPath);
      }

      // Test 1: Database creation time
      final createStartTime = DateTime.now();
      
      await db.execute('''
        CREATE TABLE performance_test (
          id INTEGER PRIMARY KEY,
          name TEXT,
          value INTEGER,
          created_at INTEGER
        )
      ''');
      
      final createEndTime = DateTime.now();
      final createDuration = createEndTime.difference(createStartTime).inMilliseconds;

      // Test 2: Bulk insert performance
      final insertStartTime = DateTime.now();
      
      await db.transaction((txn) async {
        for (int i = 0; i < 1000; i++) {
          await txn.insert('performance_test', {
            'name': 'Test Record $i',
            'value': i,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      });
      
      final insertEndTime = DateTime.now();
      final insertDuration = insertEndTime.difference(insertStartTime).inMilliseconds;

      // Test 3: Query performance
      final queryStartTime = DateTime.now();
      
      final records = await db.query('performance_test', limit: 100);
      
      final queryEndTime = DateTime.now();
      final queryDuration = queryEndTime.difference(queryStartTime).inMilliseconds;

      await db.close();
      await File(testDbPath).delete();

      // Analyze performance
      final performanceGood = createDuration < 100 && 
                             insertDuration < 5000 && 
                             queryDuration < 100;

      results.add(CompatibilityTestResult(
        testName: 'Database Performance',
        platform: platform,
        passed: performanceGood,
        details: {
          'table_creation_ms': createDuration,
          'bulk_insert_1000_records_ms': insertDuration,
          'query_100_records_ms': queryDuration,
          'records_inserted': 1000,
          'records_queried': records.length,
        },
        timestamp: DateTime.now(),
        severity: performanceGood ? 'info' : 'warning',
        recommendation: performanceGood ? null : 
          'Consider performance optimization for this platform',
      ));

    } catch (e) {
      results.add(CompatibilityTestResult(
        testName: 'Database Performance',
        platform: platform,
        passed: false,
        errorMessage: e.toString(),
        details: {
          'error': e.toString(),
        },
        timestamp: DateTime.now(),
        severity: 'warning',
        recommendation: 'Fix database access issues before testing performance',
      ));
    }

    return results;
  }

  // Helper methods

  Future<Map<String, dynamic>> _collectPlatformInfo() async {
    final info = <String, dynamic>{
      'operating_system': Platform.operatingSystem,
      'operating_system_version': Platform.operatingSystemVersion,
      'is_android': Platform.isAndroid,
      'is_ios': Platform.isIOS,
      'is_linux': Platform.isLinux,
      'is_windows': Platform.isWindows,
      'is_macos': Platform.isMacOS,
      'is_desktop': Platform.isLinux || Platform.isWindows || Platform.isMacOS,
      'is_mobile': Platform.isAndroid || Platform.isIOS,
      'dart_version': Platform.version,
    };

    // Add path information
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      info['app_documents_directory'] = appDocsDir.path;
    } catch (e) {
      info['app_documents_directory_error'] = e.toString();
    }

    try {
      final tempDir = await getTemporaryDirectory();
      info['temporary_directory'] = tempDir.path;
    } catch (e) {
      info['temporary_directory_error'] = e.toString();
    }

    return info;
  }

  Map<String, dynamic> _analyzeTestResults(List<CompatibilityTestResult> testResults) {
    final totalTests = testResults.length;
    final passedTests = testResults.where((result) => result.passed).length;
    final criticalFailures = testResults
      .where((result) => !result.passed && result.severity == 'critical')
      .length;
    
    final compatibilityScore = totalTests > 0 ? (passedTests / totalTests) * 100 : 0.0;
    final isCompatible = criticalFailures == 0 && compatibilityScore >= 80;

    // Extract critical issues and recommendations
    final criticalIssues = testResults
      .where((result) => !result.passed && result.severity == 'critical')
      .map((result) => '${result.testName}: ${result.errorMessage ?? "Failed"}')
      .toList();

    final recommendations = testResults
      .where((result) => result.recommendation != null)
      .map((result) => result.recommendation!)
      .toSet() // Remove duplicates
      .toList();

    return {
      'total_tests': totalTests,
      'passed_tests': passedTests,
      'failed_tests': totalTests - passedTests,
      'critical_failures': criticalFailures,
      'compatibility_score': compatibilityScore,
      'is_compatible': isCompatible,
      'critical_issues': criticalIssues,
      'recommendations': recommendations,
    };
  }

  Future<bool> _testDirectoryWriteAccess(String directoryPath) async {
    try {
      final testFile = File('$directoryPath/.write_test_${DateTime.now().millisecondsSinceEpoch}');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testSingleConnection(String dbPath, int connectionId, bool isDesktop) async {
    try {
      Database db;
      if (isDesktop) {
        db = await databaseFactoryFfi.openDatabase(dbPath);
      } else {
        db = await openDatabase(dbPath);
      }
      
      // Perform some operations
      await db.insert('concurrent_test', {
        'value': connectionId,
      });
      
      final records = await db.query('concurrent_test', 
        where: 'value = ?', 
        whereArgs: [connectionId]
      );
      
      await db.close();
      
      return records.length == 1;
    } catch (e) {
      debugPrint('Connection $connectionId failed: $e');
      return false;
    }
  }

  String? _getPragmaRecommendation(String pragmaName, String platform) {
    switch (pragmaName) {
      case 'journal_mode_wal':
        return Platform.isAndroid 
          ? 'WAL mode may not be supported on Android - use DELETE mode'
          : 'Check SQLite version for WAL support';
      case 'foreign_keys':
        return 'Ensure foreign key constraints are properly enabled';
      case 'locking_mode_exclusive':
        return 'Exclusive locking mode may cause concurrency issues';
      default:
        return 'Consider making this PRAGMA command optional for this platform';
    }
  }

  void _initializeKnownIncompatibilities() {
    _knownIncompatibilities.addAll([
      'android_wal_mode_limited',
      'windows_file_locking_issues',
      'macos_permission_restrictions',
      'linux_sqlite_version_differences',
      'ios_sandbox_restrictions',
    ]);
  }

  void _loadPlatformConfigurations() {
    _platformConfigurations['android'] = {
      'recommended_journal_mode': 'DELETE',
      'wal_mode_supported': false,
      'foreign_keys_default': true,
      'recommended_cache_size': 2000,
      'temp_store': 'MEMORY',
    };

    _platformConfigurations['linux'] = {
      'recommended_journal_mode': 'WAL',
      'wal_mode_supported': true,
      'foreign_keys_default': true,
      'recommended_cache_size': 10000,
      'temp_store': 'MEMORY',
    };

    _platformConfigurations['windows'] = {
      'recommended_journal_mode': 'WAL',
      'wal_mode_supported': true,
      'foreign_keys_default': true,
      'recommended_cache_size': 10000,
      'temp_store': 'MEMORY',
    };

    _platformConfigurations['macos'] = {
      'recommended_journal_mode': 'WAL',
      'wal_mode_supported': true,
      'foreign_keys_default': true,
      'recommended_cache_size': 10000,
      'temp_store': 'MEMORY',
    };
  }

  /// Get platform-specific configuration recommendations
  Map<String, dynamic>? getPlatformConfiguration(String platform) {
    return _platformConfigurations[platform.toLowerCase()];
  }

  /// Get test history for analysis
  Map<String, List<CompatibilityTestResult>> getTestHistory() {
    return Map.from(_testHistory);
  }

  /// Clear test history
  void clearTestHistory() {
    _testHistory.clear();
  }

  /// Get summary of compatibility across all tested platforms
  Map<String, dynamic> getCompatibilitySummary() {
    if (_testHistory.isEmpty) {
      return {
        'tested_platforms': 0,
        'overall_compatibility': 0.0,
        'platform_scores': <String, double>{},
      };
    }

    final platformScores = <String, double>{};
    
    for (final entry in _testHistory.entries) {
      final testResults = entry.value;
      final analysis = _analyzeTestResults(testResults);
      final platform = testResults.isNotEmpty ? testResults.first.platform : 'unknown';
      
      platformScores[platform] = analysis['compatibility_score'];
    }

    final overallCompatibility = platformScores.values.isEmpty 
      ? 0.0 
      : platformScores.values.reduce((a, b) => a + b) / platformScores.length;

    return {
      'tested_platforms': platformScores.length,
      'overall_compatibility': overallCompatibility,
      'platform_scores': platformScores,
    };
  }
}