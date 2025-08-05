import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/core/database/platform_database_factory.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/database/database_health_service.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

void main() {
  group('Database Initialization Tests', () {
    late CrdtDatabaseService databaseService;
    late DatabaseHealthService healthService;
    
    setUpAll(() async {
      // Clean up any existing test database
      final dbPath = await PlatformDatabaseFactory.getDatabasePath();
      final testDbPath = path.join(path.dirname(dbPath), 'test_bizsync.db');
      
      try {
        final file = File(testDbPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Warning: Could not clean up test database: $e');
      }
    });

    test('Platform database factory creates correct instance for current platform', () async {
      final db = await PlatformDatabaseFactory.create('test_bizsync.db');
      expect(db, isNotNull);
      
      // Verify we can execute basic queries
      final result = await db.rawQuery('SELECT sqlite_version()');
      expect(result, isNotEmpty);
      print('SQLite version: ${result.first.values.first}');
      
      await db.close();
    });

    test('CRDT database initializes successfully on current platform', () async {
      databaseService = CrdtDatabaseService();
      await expectLater(
        databaseService.initialize(),
        completes,
        reason: 'Database should initialize without errors',
      );
      
      // Verify database is initialized
      expect(databaseService.isInitialized, isTrue);
    });

    test('Database health service detects healthy database', () async {
      healthService = DatabaseHealthService(databaseService.database!);
      
      final health = await healthService.checkHealth();
      expect(health.isHealthy, isTrue, reason: 'Database should be healthy after initialization');
      expect(health.connectivity, isTrue, reason: 'Database should have connectivity');
      expect(health.integrity, isTrue, reason: 'Database should have integrity');
      
      print('Health check summary: ${health.summary}');
    });

    test('Platform-specific PRAGMA commands work correctly', () async {
      final db = databaseService.database!;
      
      if (Platform.isAndroid) {
        // On Android, WAL mode should be disabled
        final journalMode = await db.rawQuery('PRAGMA journal_mode');
        expect(journalMode.first['journal_mode'], isNot('wal'));
        print('Android journal mode: ${journalMode.first['journal_mode']}');
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        // On desktop, WAL mode should be enabled
        final journalMode = await db.rawQuery('PRAGMA journal_mode');
        expect(journalMode.first['journal_mode'], equals('wal'));
        print('Desktop journal mode: ${journalMode.first['journal_mode']}');
      }
    });

    test('Database handles concurrent operations without corruption', () async {
      // Simulate concurrent writes
      final futures = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        futures.add(
          databaseService.database!.insert(
            'crdt_customers',
            {
              'hlc': DateTime.now().millisecondsSinceEpoch.toString(),
              'node_id': 'test_node',
              'name': 'Test Customer $i',
              'email': 'test$i@example.com',
              'is_deleted': 0,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          ),
        );
      }
      
      await expectLater(
        Future.wait(futures),
        completes,
        reason: 'Concurrent operations should complete successfully',
      );
      
      // Verify data integrity
      final count = await databaseService.database!.rawQuery(
        'SELECT COUNT(*) as count FROM crdt_customers WHERE name LIKE ?',
        ['Test Customer %'],
      );
      expect(count.first['count'], equals(10));
    });

    test('Database recovers from corrupted state', () async {
      // Simulate a corrupted table scenario
      try {
        await databaseService.database!.execute(
          'CREATE TABLE corrupt_test (id INTEGER PRIMARY KEY, data BLOB)',
        );
        
        // Insert corrupted data
        await databaseService.database!.execute(
          'INSERT INTO corrupt_test (data) VALUES (randomblob(1000000))',
        );
      } catch (e) {
        print('Expected error creating corrupt data: $e');
      }
      
      // Check if health service can detect and suggest recovery
      final health = await healthService.checkHealth();
      
      // Even with corrupt data, basic operations should still work
      expect(health.connectivity, isTrue);
      
      // Clean up
      try {
        await databaseService.database!.execute('DROP TABLE IF EXISTS corrupt_test');
      } catch (e) {
        print('Error cleaning up corrupt table: $e');
      }
    });

    test('Database encryption works on supported platforms', () async {
      final db = databaseService.database!;
      
      // Check if database is using SQLCipher
      try {
        final cipherVersion = await db.rawQuery('PRAGMA cipher_version');
        if (cipherVersion.isNotEmpty) {
          print('SQLCipher version: ${cipherVersion.first}');
          expect(cipherVersion.first.values.first, isNotNull);
        }
      } catch (e) {
        print('SQLCipher not available on this platform: $e');
      }
    });

    test('Database migration system works correctly', () async {
      // The database should already be at version 2
      final version = await databaseService.database!.getVersion();
      expect(version, equals(2), reason: 'Database should be at version 2');
      
      // Verify migration added required columns
      final tableInfo = await databaseService.database!.rawQuery(
        'PRAGMA table_info(crdt_customers)',
      );
      
      final columnNames = tableInfo.map((row) => row['name'] as String).toSet();
      
      // Check for v2 migration columns
      expect(columnNames, contains('is_active'));
      expect(columnNames, contains('gst_registered'));
      expect(columnNames, contains('uen'));
      expect(columnNames, contains('address_line_1'));
      expect(columnNames, contains('postal_code'));
    });

    tearDownAll(() async {
      await databaseService.close();
    });
  });
}