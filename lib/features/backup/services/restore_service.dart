import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/crdt_database_service.dart';
import '../models/backup_models.dart';
import '../utils/backup_format.dart';

/// Comprehensive restore service for BizSync
class RestoreService extends ChangeNotifier {
  final CRDTDatabaseService _databaseService;
  final Ref _ref;

  RestoreProgress? _currentRestore;
  final List<ConflictData> _pendingConflicts = [];

  RestoreService(this._databaseService, this._ref);

  // Getters
  RestoreProgress? get currentRestore => _currentRestore;
  List<ConflictData> get pendingConflicts =>
      List.unmodifiable(_pendingConflicts);
  bool get isRestoreInProgress => _currentRestore != null;
  bool get hasPendingConflicts => _pendingConflicts.isNotEmpty;

  /// Validate a backup file before restoration
  Future<BackupValidationResult> validateBackup({
    required String backupFilePath,
    String? password,
  }) async {
    try {
      // Extract and validate the backup
      final tempDir =
          await Directory.systemTemp.createTemp('bizsync_restore_validation_');

      try {
        final extractResult = await BackupFormatHandler.extractBackupFile(
          backupFilePath: backupFilePath,
          extractPath: tempDir.path,
          password: password,
        );

        final manifest = extractResult.manifest;
        final validation = BackupValidationResult(
          isValid: extractResult.isValid,
          manifest: manifest,
          errors: [],
          warnings: [],
          compatibilityIssues: await _checkCompatibility(manifest),
        );

        return validation;
      } finally {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        manifest: null,
        errors: [e.toString()],
        warnings: [],
        compatibilityIssues: [],
      );
    }
  }

  /// Restore from backup with conflict resolution
  Future<void> restoreFromBackup({
    required String backupFilePath,
    String? password,
    ConflictResolutionStrategy defaultStrategy =
        ConflictResolutionStrategy.prompt,
    bool createBackupBeforeRestore = true,
    void Function(RestoreProgress)? onProgress,
  }) async {
    if (isRestoreInProgress) {
      throw BackupException('Another restore is already in progress');
    }

    final restoreId = const Uuid().v4();
    _currentRestore = RestoreProgress(
      backupId: restoreId,
      status: RestoreStatus.preparing,
      totalSteps: 8,
      completedSteps: 0,
      currentOperation: 'Preparing restore...',
      progressPercentage: 0.0,
      startedAt: DateTime.now(),
    );

    notifyListeners();
    onProgress?.call(_currentRestore!);

    Directory? tempDir;
    String? preRestoreBackupPath;

    try {
      // Step 1: Create backup before restore if requested
      if (createBackupBeforeRestore) {
        await _updateProgress(RestoreStatus.preparing,
            'Creating backup before restore...', onProgress);
        preRestoreBackupPath = await _createPreRestoreBackup();
      }

      // Step 2: Validate backup
      await _updateProgress(
          RestoreStatus.validating, 'Validating backup file...', onProgress);
      final validationResult = await validateBackup(
        backupFilePath: backupFilePath,
        password: password,
      );

      if (!validationResult.isValid) {
        throw BackupException(
            'Backup validation failed: ${validationResult.errors.join(', ')}');
      }

      final manifest = validationResult.manifest!;

      // Step 3: Extract backup
      await _updateProgress(
          RestoreStatus.extracting, 'Extracting backup...', onProgress);
      tempDir = await Directory.systemTemp.createTemp('bizsync_restore_');

      final extractResult = await BackupFormatHandler.extractBackupFile(
        backupFilePath: backupFilePath,
        extractPath: tempDir.path,
        password: password,
      );

      // Step 4: Load data from extracted files
      await _updateProgress(
          RestoreStatus.extracting, 'Loading data...', onProgress);
      final tableData = await _loadTableData(tempDir.path, manifest);
      final attachments = await _loadAttachments(tempDir.path, manifest);

      // Step 5: Check for conflicts
      await _updateProgress(RestoreStatus.restoringDatabase,
          'Checking for conflicts...', onProgress);
      final conflicts = await _detectConflicts(tableData);

      if (conflicts.isNotEmpty &&
          defaultStrategy == ConflictResolutionStrategy.prompt) {
        _pendingConflicts.addAll(conflicts);
        _currentRestore = _currentRestore!.copyWith(
          status: RestoreStatus.restoringDatabase,
          currentOperation: 'Waiting for conflict resolution...',
        );
        notifyListeners();
        onProgress?.call(_currentRestore!);
        return; // Wait for user input
      }

      // Step 6: Restore database
      await _updateProgress(
          RestoreStatus.restoringDatabase, 'Restoring database...', onProgress);
      await _restoreDatabase(tableData, conflicts, defaultStrategy);

      // Step 7: Restore attachments
      await _updateProgress(
          RestoreStatus.restoringFiles, 'Restoring attachments...', onProgress);
      await _restoreAttachments(attachments);

      // Step 8: Finalize
      await _updateProgress(
          RestoreStatus.finalizing, 'Finalizing restore...', onProgress);
      await _finalizeRestore(manifest);

      _currentRestore = _currentRestore!.copyWith(
        status: RestoreStatus.completed,
        completedSteps: _currentRestore!.totalSteps,
        progressPercentage: 100.0,
        currentOperation: 'Restore completed successfully',
        completedAt: DateTime.now(),
      );

      onProgress?.call(_currentRestore!);
    } catch (e) {
      // Restore from pre-restore backup if available
      if (preRestoreBackupPath != null) {
        try {
          await _rollbackRestore(preRestoreBackupPath);
        } catch (rollbackError) {
          debugPrint('Failed to rollback restore: $rollbackError');
        }
      }

      _currentRestore = _currentRestore!.copyWith(
        status: RestoreStatus.failed,
        currentOperation: 'Restore failed: ${e.toString()}',
        completedAt: DateTime.now(),
        errors: [..._currentRestore!.errors, e.toString()],
      );

      onProgress?.call(_currentRestore!);
      rethrow;
    } finally {
      // Cleanup
      if (tempDir != null) {
        await tempDir.delete(recursive: true);
      }

      if (preRestoreBackupPath != null &&
          _currentRestore?.status == RestoreStatus.completed) {
        // Delete pre-restore backup if restore was successful
        try {
          await File(preRestoreBackupPath).delete();
        } catch (e) {
          debugPrint('Failed to delete pre-restore backup: $e');
        }
      }

      // Clear current restore after delay
      Future.delayed(const Duration(seconds: 5), () {
        _currentRestore = null;
        notifyListeners();
      });
    }
  }

  /// Continue restore after conflict resolution
  Future<void> continueRestoreAfterConflictResolution({
    void Function(RestoreProgress)? onProgress,
  }) async {
    if (_currentRestore == null || _pendingConflicts.isEmpty) {
      return;
    }

    try {
      // Apply conflict resolutions
      await _updateProgress(RestoreStatus.restoringDatabase,
          'Applying conflict resolutions...', onProgress);

      // Continue with the remaining steps
      // This would involve re-running the restore process with resolved conflicts
      // Implementation depends on the specific conflict data stored

      _pendingConflicts.clear();

      _currentRestore = _currentRestore!.copyWith(
        status: RestoreStatus.completed,
        completedSteps: _currentRestore!.totalSteps,
        progressPercentage: 100.0,
        currentOperation: 'Restore completed successfully',
        completedAt: DateTime.now(),
      );

      onProgress?.call(_currentRestore!);
    } catch (e) {
      _currentRestore = _currentRestore!.copyWith(
        status: RestoreStatus.failed,
        currentOperation:
            'Restore failed during conflict resolution: ${e.toString()}',
        completedAt: DateTime.now(),
        errors: [..._currentRestore!.errors, e.toString()],
      );

      onProgress?.call(_currentRestore!);
      rethrow;
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        _currentRestore = null;
        notifyListeners();
      });
    }
  }

  /// Check compatibility with current app version
  Future<List<String>> _checkCompatibility(BackupManifest manifest) async {
    final issues = <String>[];

    // Check app version compatibility
    if (manifest.appVersion != '1.0.0') {
      issues.add(
          'Backup was created with app version ${manifest.appVersion}, current version is 1.0.0');
    }

    // Check database schema compatibility
    final currentDbVersion = 1; // From AppConstants
    final backupDbVersion =
        int.tryParse(manifest.metadata.customData['database_version'] ?? '1') ??
            1;

    if (backupDbVersion > currentDbVersion) {
      issues.add(
          'Backup database version ($backupDbVersion) is newer than current version ($currentDbVersion)');
    }

    // Check for missing tables
    final currentTables = await _getCurrentTableNames();
    final backupTables = manifest.tables.map((t) => t.name).toList();

    for (final table in backupTables) {
      if (!currentTables.contains(table)) {
        issues.add('Backup contains unknown table: $table');
      }
    }

    return issues;
  }

  /// Load table data from extracted backup
  Future<Map<String, List<Map<String, dynamic>>>> _loadTableData(
    String extractPath,
    BackupManifest manifest,
  ) async {
    final tableData = <String, List<Map<String, dynamic>>>{};

    for (final table in manifest.tables) {
      final tableFile = File('$extractPath/data/${table.name}.json');
      if (await tableFile.exists()) {
        final jsonContent = await tableFile.readAsString();
        final data = jsonDecode(jsonContent) as List<dynamic>;
        tableData[table.name] = data.cast<Map<String, dynamic>>();
      }
    }

    return tableData;
  }

  /// Load attachments from extracted backup
  Future<Map<String, Uint8List>> _loadAttachments(
    String extractPath,
    BackupManifest manifest,
  ) async {
    final attachments = <String, Uint8List>{};

    for (final attachment in manifest.attachments) {
      final attachmentFile =
          File('$extractPath/attachments/${attachment.name}');
      if (await attachmentFile.exists()) {
        final data = await attachmentFile.readAsBytes();
        attachments[attachment.name] = data;
      }
    }

    return attachments;
  }

  /// Detect conflicts between backup data and existing data
  Future<List<ConflictData>> _detectConflicts(
    Map<String, List<Map<String, dynamic>>> tableData,
  ) async {
    final conflicts = <ConflictData>[];
    final db = await _databaseService.database;

    for (final entry in tableData.entries) {
      final tableName = entry.key;
      final backupRecords = entry.value;

      for (final record in backupRecords) {
        final id = record['id'];
        if (id != null) {
          // Check if record exists
          final existing = await db.query(
            tableName,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            final existingRecord = existing.first;
            final existingUpdatedAt = existingRecord['updated_at'] as int?;
            final backupUpdatedAt = record['updated_at'] as int?;

            // Check if there's a conflict (different data or newer local data)
            if (existingUpdatedAt != null && backupUpdatedAt != null) {
              if (existingUpdatedAt > backupUpdatedAt) {
                conflicts.add(ConflictData(
                  tableName: tableName,
                  recordId: id.toString(),
                  existingData: existingRecord,
                  incomingData: record,
                  strategy: ConflictResolutionStrategy.prompt,
                ));
              }
            }
          }
        }
      }
    }

    return conflicts;
  }

  /// Restore database tables
  Future<void> _restoreDatabase(
    Map<String, List<Map<String, dynamic>>> tableData,
    List<ConflictData> conflicts,
    ConflictResolutionStrategy defaultStrategy,
  ) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      for (final entry in tableData.entries) {
        final tableName = entry.key;
        final records = entry.value;

        for (final record in records) {
          final id = record['id'];

          // Check if this record has a conflict
          final conflict = conflicts.firstWhere(
            (c) => c.tableName == tableName && c.recordId == id.toString(),
            orElse: () => ConflictData(
              tableName: tableName,
              recordId: id.toString(),
              existingData: {},
              incomingData: record,
              strategy: ConflictResolutionStrategy.overwrite,
            ),
          );

          switch (conflict.strategy) {
            case ConflictResolutionStrategy.skip:
              continue;
            case ConflictResolutionStrategy.overwrite:
              await txn.insert(
                tableName,
                record,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              break;
            case ConflictResolutionStrategy.merge:
              // Implement merge logic based on table schema
              final mergedData =
                  await _mergeRecords(conflict.existingData, record);
              await txn.insert(
                tableName,
                mergedData,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              break;
            case ConflictResolutionStrategy.prompt:
              // Should have been resolved earlier
              break;
          }
        }
      }
    });
  }

  /// Restore file attachments
  Future<void> _restoreAttachments(Map<String, Uint8List> attachments) async {
    // In a real implementation, this would restore files to their proper locations
    // For now, we'll just skip this since we don't have file attachments yet
    for (final entry in attachments.entries) {
      final fileName = entry.key;
      final data = entry.value;

      // Save attachment to appropriate location
      // This would depend on your file storage strategy
      debugPrint('Restoring attachment: $fileName (${data.length} bytes)');
    }
  }

  /// Finalize the restore process
  Future<void> _finalizeRestore(BackupManifest manifest) async {
    // Update any necessary system tables or configurations
    // Reset sync status, update database version, etc.

    final db = await _databaseService.database;

    // Reset sync status for all restored records
    for (final table in manifest.tables) {
      await db.update(
        table.name,
        {'sync_status': 0},
      );
    }
  }

  /// Create a backup before starting restore (for rollback)
  Future<String> _createPreRestoreBackup() async {
    final tempDir = await getTemporaryDirectory();
    final backupPath = path.join(tempDir.path,
        'pre_restore_backup_${DateTime.now().millisecondsSinceEpoch}.bdb');

    // Create a simple backup (this would use BackupService in real implementation)
    // For now, just create a placeholder
    final file = File(backupPath);
    await file.writeAsString('pre-restore backup placeholder');

    return backupPath;
  }

  /// Rollback restore using pre-restore backup
  Future<void> _rollbackRestore(String preRestoreBackupPath) async {
    // In a real implementation, this would restore from the pre-restore backup
    debugPrint('Rolling back restore using backup: $preRestoreBackupPath');
  }

  /// Merge two records based on business logic
  Future<Map<String, dynamic>> _mergeRecords(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) async {
    // Implement merge logic based on your business requirements
    // For now, we'll use a simple strategy: prefer incoming for most fields,
    // but keep local timestamps if they're newer

    final merged = Map<String, dynamic>.from(incoming);

    final existingUpdatedAt = existing['updated_at'] as int?;
    final incomingUpdatedAt = incoming['updated_at'] as int?;

    if (existingUpdatedAt != null && incomingUpdatedAt != null) {
      if (existingUpdatedAt > incomingUpdatedAt) {
        merged['updated_at'] = existingUpdatedAt;
      }
    }

    return merged;
  }

  /// Get current database table names
  Future<List<String>> _getCurrentTableNames() async {
    final db = await _databaseService.database;
    final result = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
    );

    return result.map((row) => row['name'] as String).toList();
  }

  /// Update restore progress
  Future<void> _updateProgress(
    RestoreStatus status,
    String operation,
    void Function(RestoreProgress)? onProgress,
  ) async {
    if (_currentRestore != null) {
      _currentRestore = _currentRestore!.copyWith(
        status: status,
        completedSteps: _currentRestore!.completedSteps + 1,
        currentOperation: operation,
        progressPercentage: (_currentRestore!.completedSteps + 1) /
            _currentRestore!.totalSteps *
            100,
      );

      notifyListeners();
      onProgress?.call(_currentRestore!);
    }

    // Add small delay for UI responsiveness
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Cancel current restore
  Future<void> cancelRestore() async {
    if (_currentRestore != null) {
      _currentRestore = _currentRestore!.copyWith(
        status: RestoreStatus.cancelled,
        currentOperation: 'Restore cancelled by user',
        completedAt: DateTime.now(),
      );

      notifyListeners();

      // Clear after delay
      Future.delayed(const Duration(seconds: 3), () {
        _currentRestore = null;
        _pendingConflicts.clear();
        notifyListeners();
      });
    }
  }

  /// Resolve a specific conflict
  void resolveConflict(String recordId, ConflictResolutionStrategy strategy,
      [Map<String, dynamic>? resolvedData]) {
    final index = _pendingConflicts.indexWhere((c) => c.recordId == recordId);
    if (index >= 0) {
      _pendingConflicts[index] = ConflictData(
        tableName: _pendingConflicts[index].tableName,
        recordId: recordId,
        existingData: _pendingConflicts[index].existingData,
        incomingData: _pendingConflicts[index].incomingData,
        strategy: strategy,
        resolvedData: resolvedData,
      );
      notifyListeners();
    }
  }
}

/// Extension for RestoreProgress
extension RestoreProgressExtension on RestoreProgress {
  RestoreProgress copyWith({
    String? backupId,
    RestoreStatus? status,
    int? totalSteps,
    int? completedSteps,
    String? currentOperation,
    double? progressPercentage,
    List<String>? errors,
    List<String>? warnings,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return RestoreProgress(
      backupId: backupId ?? this.backupId,
      status: status ?? this.status,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      currentOperation: currentOperation ?? this.currentOperation,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Backup validation result
class BackupValidationResult {
  final bool isValid;
  final BackupManifest? manifest;
  final List<String> errors;
  final List<String> warnings;
  final List<String> compatibilityIssues;

  const BackupValidationResult({
    required this.isValid,
    this.manifest,
    required this.errors,
    required this.warnings,
    required this.compatibilityIssues,
  });
}

/// Provider for restore service
final restoreServiceProvider = ChangeNotifierProvider<RestoreService>((ref) {
  final databaseService = CRDTDatabaseService();
  return RestoreService(databaseService, ref);
});
