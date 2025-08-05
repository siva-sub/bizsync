import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart' as app_exceptions;

/// Robust platform-aware database factory with comprehensive error handling
/// Provides seamless cross-platform SQLite support for Android and Linux
/// with intelligent PRAGMA command handling and graceful fallback mechanisms
class PlatformDatabaseFactory {
  static bool? _supportsSqlcipher;
  static bool _hasCheckedSupport = false;
  static bool _isInitialized = false;

  /// Check if SQLCipher is supported on the current platform
  static Future<bool> get supportsSqlcipher async {
    if (!_hasCheckedSupport) {
      _supportsSqlcipher = await _checkSqlcipherSupport();
      _hasCheckedSupport = true;
    }
    return _supportsSqlcipher ?? false;
  }

  /// Check if SQLCipher plugin is available and functional
  static Future<bool> _checkSqlcipherSupport() async {
    try {
      // SQLCipher support disabled for cross-platform compatibility
      // Can be re-enabled when proper cross-platform SQLCipher is available
      debugPrint('INFO: SQLCipher support disabled for maximum compatibility');
      return false;
    } catch (e) {
      debugPrint('WARNING: SQLCipher check failed: $e');
      return false;
    }
  }

  /// Initialize platform-specific database factory
  static Future<void> _initializePlatform() async {
    if (_isInitialized) return;

    try {
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        debugPrint('✅ SQLite FFI initialized for ${Platform.operatingSystem}');
      } else {
        debugPrint('✅ Using native SQLite for ${Platform.operatingSystem}');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Platform initialization failed: $e');
      throw app_exceptions.DatabaseException(
          'Failed to initialize database platform: $e');
    }
  }

  /// Open database with robust cross-platform support
  static Future<sqflite.Database> openDatabase(
    String path, {
    int? version,
    String? password,
    sqflite.OnDatabaseCreateFn? onCreate,
    sqflite.OnDatabaseVersionChangeFn? onUpgrade,
    sqflite.OnDatabaseOpenFn? onOpen,
  }) async {
    debugPrint('🔧 Opening database: $path on ${Platform.operatingSystem}');
    
    try {
      // Initialize platform-specific factory
      await _initializePlatform();

      // Create platform-appropriate onOpen wrapper that handles PRAGMA commands safely
      sqflite.OnDatabaseOpenFn? safeOnOpen;
      if (onOpen != null) {
        safeOnOpen = (db) async {
          await _executeSafePragmas(db);
          await onOpen(db);
        };
      } else {
        safeOnOpen = _executeSafePragmas;
      }

      sqflite.Database database;
      
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // Desktop platforms - use FFI
        database = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
            onOpen: safeOnOpen,
          ),
        );
      } else {
        // Mobile platforms - use native sqflite
        database = await sqflite.openDatabase(
          path,
          version: version,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
          onOpen: safeOnOpen,
        );
      }

      debugPrint('✅ Database opened successfully: ${await _getDatabaseVersion(database)}');
      return database;
      
    } catch (e) {
      debugPrint('❌ Database open failed: $e');
      
      // Attempt recovery by opening without onOpen callback
      try {
        debugPrint('🔄 Attempting database recovery without PRAGMA commands');
        
        sqflite.Database database;
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
          database = await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: version,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
              // Skip onOpen to avoid PRAGMA issues
            ),
          );
        } else {
          database = await sqflite.openDatabase(
            path,
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
            // Skip onOpen to avoid PRAGMA issues
          );
        }
        
        debugPrint('✅ Database recovery successful');
        return database;
        
      } catch (recoveryError) {
        final dbInfo = await getDatabaseInfo();
        throw app_exceptions.DatabaseException(
            'Failed to open database: $e\n'
            'Recovery attempt failed: $recoveryError\n'
            'Platform: ${dbInfo['platform']}\n'
            'Database type: ${dbInfo['database_type']}\n'
            'Factory: ${dbInfo['database_factory']}');
      }
    }
  }

  /// Execute PRAGMA commands safely with platform-specific handling
  static Future<void> _executeSafePragmas(sqflite.Database db) async {
    final pragmas = _getPlatformSpecificPragmas();
    
    for (final pragma in pragmas) {
      try {
        await db.execute(pragma.command);
        debugPrint('✅ ${pragma.name}: SUCCESS');
      } catch (e) {
        if (pragma.required) {
          debugPrint('❌ ${pragma.name}: FAILED (Required) - $e');
          throw app_exceptions.DatabaseException(
              'Required PRAGMA command failed: ${pragma.command} - $e');
        } else {
          debugPrint('⚠️  ${pragma.name}: FAILED (Optional) - $e');
        }
      }
    }
  }

  /// Get platform-specific PRAGMA commands
  static List<_PragmaCommand> _getPlatformSpecificPragmas() {
    if (Platform.isAndroid) {
      // Android-specific pragmas - be more conservative
      return [
        _PragmaCommand('Foreign Keys', 'PRAGMA foreign_keys = ON', required: false),
        _PragmaCommand('Synchronous Mode', 'PRAGMA synchronous = NORMAL', required: false),
        _PragmaCommand('Cache Size', 'PRAGMA cache_size = 2000', required: false),
        _PragmaCommand('Temp Store', 'PRAGMA temp_store = MEMORY', required: false),
        // Skip WAL mode for Android - causes issues on some devices
      ];
    } else {
      // Desktop platforms - more permissive
      return [
        _PragmaCommand('Foreign Keys', 'PRAGMA foreign_keys = ON', required: false),
        _PragmaCommand('WAL Mode', 'PRAGMA journal_mode = WAL', required: false),
        _PragmaCommand('Synchronous Mode', 'PRAGMA synchronous = NORMAL', required: false),
        _PragmaCommand('Cache Size', 'PRAGMA cache_size = 10000', required: false),
        _PragmaCommand('Temp Store', 'PRAGMA temp_store = MEMORY', required: false),
      ];
    }
  }

  /// Get database version for debugging
  static Future<String> _getDatabaseVersion(sqflite.Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      final version = result.first['user_version'] as int;
      return 'v$version';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get comprehensive database implementation info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    
    return {
      'platform': Platform.operatingSystem,
      'is_desktop': isDesktop,
      'is_mobile': Platform.isAndroid || Platform.isIOS,
      'supports_sqlcipher': await supportsSqlcipher,
      'database_type': 'SQLite (Unencrypted)',
      'encryption_available': false,
      'encryption_status': 'Disabled for compatibility',
      'database_factory': isDesktop ? 'sqflite_common_ffi' : 'sqflite',
      'pragma_support': _getPragmaSupport(),
      'wal_mode_supported': !Platform.isAndroid,
      'initialization_status': _isInitialized ? 'Ready' : 'Pending',
    };
  }

  /// Get PRAGMA support information
  static Map<String, bool> _getPragmaSupport() {
    return {
      'foreign_keys': true,
      'wal_mode': !Platform.isAndroid, // Disabled on Android for compatibility
      'synchronous': true,
      'cache_size': true,
      'temp_store': true,
    };
  }

  /// Test database connectivity
  static Future<bool> testDatabaseConnectivity(String path) async {
    try {
      final db = await openDatabase(path, version: 1);
      await db.rawQuery('SELECT 1');
      await db.close();
      return true;
    } catch (e) {
      debugPrint('❌ Database connectivity test failed: $e');
      return false;
    }
  }

  /// Reset factory state (useful for testing)
  static void resetFactoryState() {
    _hasCheckedSupport = false;
    _supportsSqlcipher = null;
    _isInitialized = false;
  }
}

/// Helper class for PRAGMA command configuration
class _PragmaCommand {
  final String name;
  final String command;
  final bool required;

  const _PragmaCommand(this.name, this.command, {this.required = false});
}