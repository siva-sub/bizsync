import 'dart:io';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart' as app_exceptions;

/// Platform-aware database factory that chooses the appropriate database implementation
/// based on platform capabilities and plugin availability
class PlatformDatabaseFactory {
  static bool? _supportsSqlcipher;
  static bool _hasCheckedSupport = false;

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
      // Desktop platforms generally don't support sqlcipher plugin
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        return false;
      }
      
      // For mobile platforms, try to use sqlcipher
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          // Attempt to use sqlcipher with a test database
          final testDb = await sqlcipher.openDatabase(
            ':memory:',
            password: 'test',
            version: 1,
            onCreate: (db, version) async {
              await db.execute('CREATE TABLE test (id INTEGER)');
            },
          );
          await testDb.close();
          return true;
        } catch (e) {
          // SQLCipher not available on this platform
          return false;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Open database with platform-appropriate implementation
  static Future<sqflite.Database> openDatabase(
    String path, {
    int? version,
    String? password,
    sqflite.OnDatabaseCreateFn? onCreate,
    sqflite.OnDatabaseVersionChangeFn? onUpgrade,
    sqflite.OnDatabaseOpenFn? onOpen,
  }) async {
    try {
      // Initialize FFI for desktop platforms
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        print('INFO: Initialized SQLite FFI for ${Platform.operatingSystem}');
      }
      
      final usesSqlcipher = await supportsSqlcipher;
      
      if (usesSqlcipher && password != null) {
        // Use SQLCipher for encrypted database (mobile only)
        return await sqlcipher.openDatabase(
          path,
          version: version,
          password: password,
          onCreate: (db, version) async {
            if (onCreate != null) {
              await onCreate(db as sqflite.Database, version);
            }
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (onUpgrade != null) {
              await onUpgrade(db as sqflite.Database, oldVersion, newVersion);
            }
          },
          onOpen: (db) async {
            if (onOpen != null) {
              await onOpen(db as sqflite.Database);
            }
          },
        ) as sqflite.Database;
      } else {
        // Use SQLite without encryption
        print('INFO: Using SQLite without encryption on ${Platform.operatingSystem}');
        
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
          // Use FFI database for desktop platforms
          return await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: version,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
              onOpen: onOpen,
            ),
          );
        } else {
          // Use regular sqflite for mobile platforms
          return await sqflite.openDatabase(
            path,
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
            onOpen: onOpen,
          );
        }
      }
    } catch (e) {
      throw app_exceptions.DatabaseException(
        'Failed to open database: $e. Platform: ${Platform.operatingSystem}'
      );
    }
  }

  /// Get database implementation info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final usesSqlcipher = await supportsSqlcipher;
    
    return {
      'platform': Platform.operatingSystem,
      'supports_sqlcipher': usesSqlcipher,
      'database_type': usesSqlcipher ? 'SQLCipher (Encrypted)' : 'SQLite (Unencrypted)',
      'encryption_available': usesSqlcipher,
      'fallback_reason': usesSqlcipher 
        ? null 
        : 'SQLCipher plugin not available on ${Platform.operatingSystem}',
    };
  }

  /// Reset support check (useful for testing)
  static void resetSupportCheck() {
    _hasCheckedSupport = false;
    _supportsSqlcipher = null;
  }
}