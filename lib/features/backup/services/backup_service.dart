import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/crdt_database_service.dart';
import '../models/backup_models.dart';
import '../utils/backup_format.dart';

/// Comprehensive backup service for BizSync
class BackupService extends ChangeNotifier {
  final CRDTDatabaseService _databaseService = CRDTDatabaseService();

  BackupConfig _config = const BackupConfig();
  final List<BackupHistoryEntry> _backupHistory = [];
  BackupProgress? _currentBackup;

  BackupService();

  // Getters
  BackupConfig get config => _config;
  List<BackupHistoryEntry> get backupHistory =>
      List.unmodifiable(_backupHistory);
  BackupProgress? get currentBackup => _currentBackup;
  bool get isBackupInProgress => _currentBackup != null;

  /// Initialize the backup service
  Future<void> initialize() async {
    await _loadConfig();
    await _loadBackupHistory();

    if (_config.autoBackupEnabled) {
      await _scheduleAutoBackup();
    }
  }

  /// Create a full backup
  Future<String> createFullBackup({
    required String outputPath,
    String? password,
    BackupScope scope = BackupScope.all,
    bool includeAttachments = true,
    void Function(BackupProgress)? onProgress,
  }) async {
    return _createBackup(
      type: BackupType.full,
      outputPath: outputPath,
      password: password,
      scope: scope,
      includeAttachments: includeAttachments,
      onProgress: onProgress,
    );
  }

  /// Create an incremental backup
  Future<String> createIncrementalBackup({
    required String outputPath,
    required DateTime fromDate,
    String? password,
    BackupScope scope = BackupScope.all,
    bool includeAttachments = true,
    void Function(BackupProgress)? onProgress,
  }) async {
    return _createBackup(
      type: BackupType.incremental,
      outputPath: outputPath,
      password: password,
      scope: scope,
      includeAttachments: includeAttachments,
      fromDate: fromDate,
      onProgress: onProgress,
    );
  }

  /// Create a backup with custom options
  Future<String> _createBackup({
    required BackupType type,
    required String outputPath,
    String? password,
    BackupScope scope = BackupScope.all,
    bool includeAttachments = true,
    DateTime? fromDate,
    DateTime? toDate,
    void Function(BackupProgress)? onProgress,
  }) async {
    if (isBackupInProgress) {
      throw BackupException('Another backup is already in progress');
    }

    final backupId = const Uuid().v4();
    _currentBackup = BackupProgress(
      id: backupId,
      type: type,
      status: BackupStatus.pending,
      totalSteps: _calculateTotalSteps(scope, includeAttachments),
      completedSteps: 0,
      currentOperation: 'Preparing backup...',
      progressPercentage: 0.0,
      startedAt: DateTime.now(),
    );

    notifyListeners();
    onProgress?.call(_currentBackup!);

    try {
      // Step 1: Gather metadata
      await _updateProgress('Gathering system information...', onProgress);
      final deviceInfo = await _getDeviceInfo();

      // Step 2: Export database
      await _updateProgress('Exporting database...', onProgress);
      final tableData = await _exportDatabase(scope, fromDate, toDate);

      // Step 3: Collect attachments
      Map<String, Uint8List> attachments = {};
      if (includeAttachments) {
        await _updateProgress('Collecting attachments...', onProgress);
        attachments = await _collectAttachments();
      }

      // Step 4: Generate manifest
      await _updateProgress('Generating manifest...', onProgress);
      final manifest = await _generateManifest(
        type: type,
        scope: scope,
        tableData: tableData,
        attachments: attachments,
        deviceInfo: deviceInfo,
        fromDate: fromDate,
        toDate: toDate,
        password: password,
      );

      // Step 5: Create backup file
      await _updateProgress('Creating backup file...', onProgress);
      final backupFilePath = await BackupFormatHandler.createBackupFile(
        outputPath: outputPath,
        manifest: manifest,
        tableData: tableData,
        attachments: attachments,
        password: password,
      );

      // Step 6: Update history
      await _updateProgress('Finalizing...', onProgress);
      final backupFile = File(backupFilePath);
      final fileSize = await backupFile.length();

      final historyEntry = BackupHistoryEntry(
        id: backupId,
        fileName: path.basename(backupFilePath),
        filePath: backupFilePath,
        metadata: manifest.metadata,
        fileSize: fileSize,
        createdAt: DateTime.now(),
        status: BackupStatus.completed,
        isEncrypted: password != null && password.isNotEmpty,
      );

      await _addToHistory(historyEntry);

      _currentBackup = _currentBackup!.copyWith(
        status: BackupStatus.completed,
        completedSteps: _currentBackup!.totalSteps,
        progressPercentage: 100.0,
        currentOperation: 'Backup completed successfully',
        completedAt: DateTime.now(),
      );

      onProgress?.call(_currentBackup!);

      // Cleanup old backups if needed
      await _cleanupOldBackups();

      return backupFilePath;
    } catch (e) {
      _currentBackup = _currentBackup!.copyWith(
        status: BackupStatus.failed,
        currentOperation: 'Backup failed: ${e.toString()}',
        completedAt: DateTime.now(),
        errorMessage: e.toString(),
      );

      onProgress?.call(_currentBackup!);
      rethrow;
    } finally {
      // Clear current backup after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _currentBackup = null;
        notifyListeners();
      });
    }
  }

  /// Export database tables based on scope
  Future<Map<String, List<Map<String, dynamic>>>> _exportDatabase(
    BackupScope scope,
    DateTime? fromDate,
    DateTime? toDate,
  ) async {
    final db = await _databaseService.database;
    final tableData = <String, List<Map<String, dynamic>>>{};

    final tablesToExport = _getTablesForScope(scope);

    for (final tableName in tablesToExport) {
      String query = 'SELECT * FROM $tableName';
      final args = <dynamic>[];

      // Add date filtering if provided
      if (fromDate != null || toDate != null) {
        final conditions = <String>[];

        if (fromDate != null) {
          conditions.add('updated_at >= ?');
          args.add(fromDate.millisecondsSinceEpoch);
        }

        if (toDate != null) {
          conditions.add('updated_at <= ?');
          args.add(toDate.millisecondsSinceEpoch);
        }

        if (conditions.isNotEmpty) {
          query += ' WHERE ${conditions.join(' AND ')}';
        }
      }

      query += ' ORDER BY created_at ASC';

      final results = await db.rawQuery(query, args);
      tableData[tableName] = results;
    }

    return tableData;
  }

  /// Collect file attachments
  Future<Map<String, Uint8List>> _collectAttachments() async {
    final attachments = <String, Uint8List>{};

    // This would be extended to collect actual file attachments
    // For now, we'll just return an empty map
    // In a real implementation, you would:
    // 1. Query for records that reference files
    // 2. Collect the actual files from storage
    // 3. Add them to the attachments map

    return attachments;
  }

  /// Generate backup manifest
  Future<BackupManifest> _generateManifest({
    required BackupType type,
    required BackupScope scope,
    required Map<String, List<Map<String, dynamic>>> tableData,
    required Map<String, Uint8List> attachments,
    required Map<String, String> deviceInfo,
    DateTime? fromDate,
    DateTime? toDate,
    String? password,
  }) async {
    final db = await _databaseService.database;

    // Generate table information
    final tables = <BackupTable>[];
    for (final entry in tableData.entries) {
      final tableName = entry.key;
      final data = entry.value;

      // Get table schema
      final schemaResult = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      final schema =
          schemaResult.isNotEmpty ? schemaResult.first['sql'] as String : '';

      // Calculate size and checksum
      final jsonData = jsonEncode(data);
      final size = utf8.encode(jsonData).length;
      final checksum = sha256.convert(utf8.encode(jsonData)).toString();

      tables.add(BackupTable(
        name: tableName,
        schema: schema,
        recordCount: data.length,
        size: size,
        checksum: checksum,
        lastModified: DateTime.now(),
      ));
    }

    // Generate attachment information
    final attachmentFiles = <BackupFile>[];
    for (final entry in attachments.entries) {
      final fileName = entry.key;
      final data = entry.value;

      attachmentFiles.add(BackupFile(
        path: 'attachments/$fileName',
        name: fileName,
        size: data.length,
        checksum: sha256.convert(data).toString(),
        mimeType: _getMimeType(fileName),
        lastModified: DateTime.now(),
      ));
    }

    // Calculate total size
    final totalSize = tables.fold(0, (sum, table) => sum + table.size) +
        attachmentFiles.fold(0, (sum, file) => sum + file.size);

    final metadata = BackupMetadata(
      type: type,
      scope: scope,
      totalRecords: tables.fold(0, (sum, table) => sum + table.recordCount),
      totalSize: totalSize.toInt(),
      compressedSize: 0, // Will be calculated after compression
      compressionAlgorithm: _config.compressionAlgorithm,
      fromDate: fromDate,
      toDate: toDate,
      customData: {
        'app_version': AppConstants.appVersion,
        'database_version': AppConstants.databaseVersion.toString(),
      },
    );

    // Generate integrity information
    final tableChecksums = <String, String>{};
    final fileChecksums = <String, String>{};

    for (final table in tables) {
      tableChecksums[table.name] = table.checksum;
    }

    for (final file in attachmentFiles) {
      fileChecksums[file.name] = file.checksum;
    }

    final integrity = BackupIntegrity(
      manifestChecksum: '', // Will be calculated later
      dataChecksum: '', // Will be calculated later
      algorithm: 'SHA-256',
      tableChecksums: tableChecksums,
      fileChecksums: fileChecksums,
    );

    // Generate encryption information if password provided
    BackupEncryption? encryption;
    if (password != null && password.isNotEmpty) {
      encryption = BackupEncryption(
        algorithm: BackupFormatHandler.encryptionAlgorithm,
        keyDerivation: BackupFormatHandler.keyDerivationAlgorithm,
        salt: '', // Will be generated during encryption
        iterations: BackupFormatHandler.keyDerivationIterations,
        iv: '', // Will be generated during encryption
      );
    }

    return BackupManifest(
      version: '1.0',
      appVersion: AppConstants.appVersion,
      createdAt: DateTime.now(),
      deviceId: deviceInfo['deviceId'] ?? 'unknown',
      deviceName: deviceInfo['deviceName'] ?? 'Unknown Device',
      metadata: metadata,
      tables: tables,
      attachments: attachmentFiles,
      integrity: integrity,
      encryption: encryption,
    );
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final info = <String, String>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['deviceId'] = androidInfo.id;
        info['deviceName'] = '${androidInfo.brand} ${androidInfo.model}';
        info['platform'] = 'Android ${androidInfo.version.release}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        info['deviceId'] = linuxInfo.machineId ?? 'linux-device';
        info['deviceName'] = linuxInfo.name;
        info['platform'] = 'Linux ${linuxInfo.version ?? 'Unknown'}';
      } else {
        info['deviceId'] = 'unknown-device';
        info['deviceName'] = 'Unknown Device';
        info['platform'] = Platform.operatingSystem;
      }
    } catch (e) {
      info['deviceId'] = 'unknown-device';
      info['deviceName'] = 'Unknown Device';
      info['platform'] = Platform.operatingSystem;
    }

    return info;
  }

  /// Get tables to export based on scope
  List<String> _getTablesForScope(BackupScope scope) {
    switch (scope) {
      case BackupScope.all:
        return [
          'customers',
          'products',
          'categories',
          'sales_transactions',
          'sales_items',
          'user_settings',
          'business_profile',
          'sync_log',
          'device_registry',
        ];
      case BackupScope.businessData:
        return [
          'customers',
          'products',
          'categories',
          'sales_transactions',
          'sales_items',
        ];
      case BackupScope.userSettings:
        return ['user_settings', 'business_profile'];
      case BackupScope.syncData:
        return ['sync_log', 'device_registry'];
      case BackupScope.custom:
        return _config.excludedTables.isEmpty
            ? [
                'customers',
                'products',
                'categories',
                'sales_transactions',
                'sales_items'
              ]
            : [
                'customers',
                'products',
                'categories',
                'sales_transactions',
                'sales_items'
              ]
                .where((table) => !_config.excludedTables.contains(table))
                .toList();
    }
  }

  /// Calculate total steps for progress tracking
  int _calculateTotalSteps(BackupScope scope, bool includeAttachments) {
    int steps =
        6; // Base steps: prepare, export, manifest, create, finalize, cleanup

    if (includeAttachments) {
      steps += 1; // Additional step for collecting attachments
    }

    // Add steps based on scope complexity
    final tableCount = _getTablesForScope(scope).length;
    steps += (tableCount / 3).ceil(); // Group tables for progress updates

    return steps;
  }

  /// Update backup progress
  Future<void> _updateProgress(
    String operation,
    void Function(BackupProgress)? onProgress,
  ) async {
    if (_currentBackup != null) {
      _currentBackup = _currentBackup!.copyWith(
        completedSteps: _currentBackup!.completedSteps + 1,
        currentOperation: operation,
        progressPercentage: (_currentBackup!.completedSteps + 1) /
            _currentBackup!.totalSteps *
            100,
      );

      notifyListeners();
      onProgress?.call(_currentBackup!);
    }

    // Add small delay for UI responsiveness
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Get MIME type for file
  String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  /// Add entry to backup history
  Future<void> _addToHistory(BackupHistoryEntry entry) async {
    _backupHistory.insert(0, entry); // Add to beginning
    await _saveBackupHistory();
    notifyListeners();
  }

  /// Load backup configuration
  Future<void> _loadConfig() async {
    // In a real implementation, load from shared preferences or database
    // For now, use default config
  }

  /// Load backup history
  Future<void> _loadBackupHistory() async {
    // In a real implementation, load from database or file
    // For now, start with empty history
  }

  /// Save backup history
  Future<void> _saveBackupHistory() async {
    // In a real implementation, save to database or file
  }

  /// Schedule automatic backup
  Future<void> _scheduleAutoBackup() async {
    // In a real implementation, use WorkManager or similar
    // to schedule periodic backups
  }

  /// Cleanup old backups based on configuration
  Future<void> _cleanupOldBackups() async {
    if (_backupHistory.length > _config.maxBackupHistory) {
      final toRemove = _backupHistory.skip(_config.maxBackupHistory).toList();

      for (final entry in toRemove) {
        try {
          final file = File(entry.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Log error but don't fail the backup
          debugPrint('Failed to delete old backup: ${entry.fileName}');
        }
      }

      _backupHistory.removeRange(
          _config.maxBackupHistory, _backupHistory.length);
      await _saveBackupHistory();
    }
  }

  /// Update backup configuration
  Future<void> updateConfig(BackupConfig config) async {
    _config = config;
    // Save config to persistent storage
    notifyListeners();
  }

  /// Delete a backup from history and file system
  Future<void> deleteBackup(String backupId) async {
    final index = _backupHistory.indexWhere((entry) => entry.id == backupId);
    if (index >= 0) {
      final entry = _backupHistory[index];

      try {
        final file = File(entry.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Log error but continue with removal from history
        debugPrint('Failed to delete backup file: ${entry.fileName}');
      }

      _backupHistory.removeAt(index);
      await _saveBackupHistory();
      notifyListeners();
    }
  }

  /// Cancel current backup
  Future<void> cancelBackup() async {
    if (_currentBackup != null) {
      _currentBackup = _currentBackup!.copyWith(
        status: BackupStatus.cancelled,
        currentOperation: 'Backup cancelled by user',
        completedAt: DateTime.now(),
      );

      notifyListeners();

      // Clear after delay
      Future.delayed(const Duration(seconds: 3), () {
        _currentBackup = null;
        notifyListeners();
      });
    }
  }

  /// Schedule automatic backups based on configuration
  Future<void> scheduleAutomaticBackups() async {
    if (!_config.autoBackupEnabled) {
      debugPrint('Automatic backups disabled');
      return;
    }

    try {
      debugPrint(
          'Scheduling automatic backups every ${_config.autoBackupInterval.inHours} hours');
      await _scheduleAutoBackup();
    } catch (e) {
      debugPrint('Failed to schedule automatic backups: $e');
    }
  }
}

/// Backup progress information
class BackupProgress {
  final String id;
  final BackupType type;
  final BackupStatus status;
  final int totalSteps;
  final int completedSteps;
  final String currentOperation;
  final double progressPercentage;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const BackupProgress({
    required this.id,
    required this.type,
    required this.status,
    required this.totalSteps,
    required this.completedSteps,
    required this.currentOperation,
    required this.progressPercentage,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  BackupProgress copyWith({
    String? id,
    BackupType? type,
    BackupStatus? status,
    int? totalSteps,
    int? completedSteps,
    String? currentOperation,
    double? progressPercentage,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return BackupProgress(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      currentOperation: currentOperation ?? this.currentOperation,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for backup service
final backupServiceProvider = ChangeNotifierProvider<BackupService>((ref) {
  return BackupService();
});
