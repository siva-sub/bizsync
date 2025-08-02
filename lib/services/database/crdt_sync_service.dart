import 'dart:async';
import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

/// CRDT Sync Service for offline-first synchronization (metadata only)
class CRDTSyncService {
  static const String _databaseName = 'bizsync_crdt.db';
  static const int _databaseVersion = 1;
  
  Database? _database;
  
  /// Singleton instance
  static final CRDTSyncService _instance = CRDTSyncService._internal();
  factory CRDTSyncService() => _instance;
  CRDTSyncService._internal();
  
  /// Get the database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      password: 'bizsync_secure_key_2024', // Simple encryption
    );
  }
  
  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE crdt_operations (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        data TEXT,
        timestamp INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE vector_clocks (
        device_id TEXT PRIMARY KEY,
        clock_value INTEGER NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_entity ON crdt_operations(entity_type, entity_id)');
    await db.execute('CREATE INDEX idx_sync ON crdt_operations(synced, timestamp)');
  }
  
  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema migrations here
    if (oldVersion < newVersion) {
      // Add migration logic as needed
    }
  }
  
  /// Insert a CRDT operation
  Future<void> insertOperation({
    required String id,
    required String entityType,
    required String entityId,
    required String operationType,
    Map<String, dynamic>? data,
    required int timestamp,
    required String deviceId,
  }) async {
    final db = await database;
    await db.insert(
      'crdt_operations',
      {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation_type': operationType,
        'data': data != null ? jsonEncode(data) : null,
        'timestamp': timestamp,
        'device_id': deviceId,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get unsynced operations
  Future<List<Map<String, dynamic>>> getUnsyncedOperations() async {
    final db = await database;
    return await db.query(
      'crdt_operations',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }
  
  /// Mark operations as synced
  Future<void> markOperationsAsSynced(List<String> operationIds) async {
    final db = await database;
    final batch = db.batch();
    
    for (final id in operationIds) {
      batch.update(
        'crdt_operations',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    
    await batch.commit();
  }
  
  /// Update vector clock
  Future<void> updateVectorClock(String deviceId, int clockValue) async {
    final db = await database;
    await db.insert(
      'vector_clocks',
      {
        'device_id': deviceId,
        'clock_value': clockValue,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get vector clock for device
  Future<int?> getVectorClock(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'vector_clocks',
      columns: ['clock_value'],
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    
    if (result.isNotEmpty) {
      return result.first['clock_value'] as int;
    }
    return null;
  }
  
  /// Get all vector clocks
  Future<Map<String, int>> getAllVectorClocks() async {
    final db = await database;
    final result = await db.query('vector_clocks');
    
    final clocks = <String, int>{};
    for (final row in result) {
      clocks[row['device_id'] as String] = row['clock_value'] as int;
    }
    return clocks;
  }
  
  /// Store sync metadata
  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Get sync metadata
  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final result = await db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }
  
  /// Clean up old operations (keep last 30 days)
  Future<void> cleanupOldOperations() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    
    await db.delete(
      'crdt_operations',
      where: 'timestamp < ? AND synced = 1',
      whereArgs: [thirtyDaysAgo],
    );
  }
  
  /// Get operations for a specific entity
  Future<List<Map<String, dynamic>>> getEntityOperations(
    String entityType,
    String entityId,
  ) async {
    final db = await database;
    return await db.query(
      'crdt_operations',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'timestamp ASC',
    );
  }
  
  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
  
  /// Delete the database (for testing purposes)
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
  
  /// Execute raw query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }
  
  /// Execute raw insert/update/delete
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }
}