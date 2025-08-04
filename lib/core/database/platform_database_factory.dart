import 'dart:io';
import 'package:sqflite/sqflite.dart' as sqflite;
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
      // SQLCipher temporarily disabled for build stability
      // TODO: Re-enable when sqflite_sqlcipher package is re-added
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

      // Use SQLite without encryption (SQLCipher support temporarily disabled)
      print(
          'INFO: Using SQLite without encryption on ${Platform.operatingSystem}');

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
    } catch (e) {
      throw app_exceptions.DatabaseException(
          'Failed to open database: $e. Platform: ${Platform.operatingSystem}');
    }
  }

  /// Get database implementation info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'supports_sqlcipher': false,
      'database_type': 'SQLite (Unencrypted)',
      'encryption_available': false,
      'fallback_reason': 'SQLCipher temporarily disabled for build stability',
      'database_factory':
          Platform.isLinux || Platform.isWindows || Platform.isMacOS
              ? 'sqflite_common_ffi'
              : 'sqflite',
    };
  }

  /// Reset support check (useful for testing)
  static void resetSupportCheck() {
    _hasCheckedSupport = false;
    _supportsSqlcipher = null;
  }
}
