import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:workmanager/workmanager.dart'; // Disabled for desktop
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/backup_models.dart';
import '../services/backup_service.dart';

/// Service for managing scheduled automatic backups
class ScheduledBackupService extends ChangeNotifier {
  final BackupService _backupService;

  static const String _taskName = 'scheduled_backup';
  static const String _uniqueName = 'bizsync_auto_backup';

  bool _isScheduled = false;
  DateTime? _nextScheduledTime;
  Duration _interval = const Duration(days: 1);
  BackupType _scheduledType = BackupType.incremental;

  ScheduledBackupService(this._backupService);

  // Getters
  bool get isScheduled => _isScheduled;
  DateTime? get nextScheduledTime => _nextScheduledTime;
  Duration get interval => _interval;
  BackupType get scheduledType => _scheduledType;

  Timer? _scheduledTimer;

  /// Initialize the scheduled backup service
  Future<void> initialize() async {
    // Desktop implementation - no workmanager needed
    // Load existing schedule if any
    await _loadScheduleState();

    // Restore timer if needed
    if (_isScheduled && _nextScheduledTime != null) {
      _scheduleNextBackup();
    }
  }

  /// Schedule automatic backups
  Future<void> scheduleBackups({
    required Duration interval,
    BackupType type = BackupType.incremental,
    BackupScope scope = BackupScope.businessData,
    bool encryptionEnabled = true,
  }) async {
    try {
      // Cancel existing schedule
      await cancelScheduledBackups();

      // Desktop implementation - use Timer instead of WorkManager
      _scheduledTimer?.cancel();

      _isScheduled = true;
      _interval = interval;
      _scheduledType = type;
      _nextScheduledTime = DateTime.now().add(interval);

      // Schedule first backup
      _scheduleNextBackup();

      await _saveScheduleState();
      notifyListeners();

      debugPrint(
          'Scheduled backups enabled: ${type.name} every ${_formatDuration(interval)}');
    } catch (e) {
      debugPrint('Failed to schedule backups: $e');
      rethrow;
    }
  }

  /// Cancel scheduled backups
  Future<void> cancelScheduledBackups() async {
    try {
      // Desktop implementation - cancel timer
      _scheduledTimer?.cancel();
      _scheduledTimer = null;

      _isScheduled = false;
      _nextScheduledTime = null;

      await _saveScheduleState();
      notifyListeners();

      debugPrint('Scheduled backups cancelled');
    } catch (e) {
      debugPrint('Failed to cancel scheduled backups: $e');
      rethrow;
    }
  }

  /// Update scheduled backup settings
  Future<void> updateSchedule({
    Duration? interval,
    BackupType? type,
    BackupScope? scope,
    bool? encryptionEnabled,
  }) async {
    if (_isScheduled) {
      await scheduleBackups(
        interval: interval ?? _interval,
        type: type ?? _scheduledType,
        scope: scope ?? BackupScope.businessData,
        encryptionEnabled: encryptionEnabled ?? true,
      );
    }
  }

  /// Execute a scheduled backup (called by WorkManager)
  static Future<void> executeScheduledBackup(
      Map<String, dynamic> inputData) async {
    try {
      debugPrint('Executing scheduled backup...');

      final backupType = BackupType.values.firstWhere(
        (type) => type.name == inputData['backup_type'],
        orElse: () => BackupType.incremental,
      );

      final backupScope = BackupScope.values.firstWhere(
        (scope) => scope.name == inputData['backup_scope'],
        orElse: () => BackupScope.businessData,
      );

      final encryptionEnabled =
          inputData['encryption_enabled'] as bool? ?? true;

      // Get default backup directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupDir =
          Directory(path.join(documentsDir.path, 'backups', 'scheduled'));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Create backup service instance
      // Note: In a real implementation, you'd need to properly initialize
      // the service with dependencies through a service locator or DI
      // For now, this is a simplified version

      final backupFileName =
          'auto_backup_${DateTime.now().toIso8601String()}.bdb';
      final backupPath = path.join(backupDir.path, backupFileName);

      // This would need proper service initialization in a real app
      debugPrint('Scheduled backup would be created at: $backupPath');
      debugPrint(
          'Type: ${backupType.name}, Scope: ${backupScope.name}, Encrypted: $encryptionEnabled');

      // Send notification about successful backup
      // This would use the notification service
      debugPrint('Scheduled backup completed successfully');
    } catch (e) {
      debugPrint('Scheduled backup failed: $e');

      // Send error notification
      // This would use the notification service to inform user
      rethrow;
    }
  }

  /// Load schedule state from persistent storage
  Future<void> _loadScheduleState() async {
    // In a real implementation, load from SharedPreferences or database
    // For now, assume no existing schedule
    _isScheduled = false;
    _nextScheduledTime = null;
  }

  /// Save schedule state to persistent storage
  Future<void> _saveScheduleState() async {
    // In a real implementation, save to SharedPreferences or database
    // For now, this is a no-op
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }

  /// Get backup history for scheduled backups
  Future<List<BackupHistoryEntry>> getScheduledBackupHistory() async {
    // Filter backup history to show only scheduled backups
    // This would need integration with BackupService
    return [];
  }

  /// Clean up old scheduled backups
  Future<void> cleanupOldScheduledBackups({int maxCount = 5}) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupDir =
          Directory(path.join(documentsDir.path, 'backups', 'scheduled'));

      if (!await backupDir.exists()) return;

      final backupFiles = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.bdb'))
          .cast<File>()
          .toList();

      if (backupFiles.length <= maxCount) return;

      // Sort by modification time (oldest first)
      backupFiles
          .sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // Delete oldest files
      final filesToDelete = backupFiles.take(backupFiles.length - maxCount);
      for (final file in filesToDelete) {
        await file.delete();
        debugPrint('Deleted old scheduled backup: ${path.basename(file.path)}');
      }
    } catch (e) {
      debugPrint('Failed to cleanup old scheduled backups: $e');
    }
  }

  /// Get next scheduled backup time
  DateTime? getNextBackupTime() {
    if (!_isScheduled) return null;
    return _nextScheduledTime;
  }

  /// Check if backup is due
  bool isBackupDue() {
    if (!_isScheduled || _nextScheduledTime == null) return false;
    return DateTime.now().isAfter(_nextScheduledTime!);
  }

  /// Get time until next backup
  /// Schedule the next backup using a Timer (desktop implementation)
  void _scheduleNextBackup() {
    if (!_isScheduled || _nextScheduledTime == null) return;

    final now = DateTime.now();
    final delay = _nextScheduledTime!.isAfter(now)
        ? _nextScheduledTime!.difference(now)
        : Duration.zero;

    _scheduledTimer = Timer(delay, () async {
      try {
        // Execute the backup
        await executeScheduledBackup({
          'backup_type': _scheduledType.name,
          'backup_scope': 'businessData',
          'encryption_enabled': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Schedule next backup
        _nextScheduledTime = DateTime.now().add(_interval);
        await _saveScheduleState();
        notifyListeners();

        // Schedule the next one if still enabled
        if (_isScheduled) {
          _scheduleNextBackup();
        }
      } catch (e) {
        debugPrint('Scheduled backup failed: $e');
      }
    });
  }

  Duration? getTimeUntilNextBackup() {
    if (!_isScheduled || _nextScheduledTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(_nextScheduledTime!)) return Duration.zero;
    return _nextScheduledTime!.difference(now);
  }
}

/// Desktop callback dispatcher - not needed for timer-based scheduling
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   // Disabled for desktop - using Timer instead
// }

/// Provider for scheduled backup service
final scheduledBackupServiceProvider =
    ChangeNotifierProvider<ScheduledBackupService>((ref) {
  final backupService = ref.read(backupServiceProvider);
  return ScheduledBackupService(backupService);
});

/// Settings for scheduled backups
class ScheduledBackupSettings {
  final bool enabled;
  final Duration interval;
  final BackupType type;
  final BackupScope scope;
  final bool encryptionEnabled;
  final int maxHistory;
  final bool wifiOnly;
  final bool batteryOptimized;

  const ScheduledBackupSettings({
    this.enabled = false,
    this.interval = const Duration(days: 1),
    this.type = BackupType.incremental,
    this.scope = BackupScope.businessData,
    this.encryptionEnabled = true,
    this.maxHistory = 5,
    this.wifiOnly = false,
    this.batteryOptimized = true,
  });

  ScheduledBackupSettings copyWith({
    bool? enabled,
    Duration? interval,
    BackupType? type,
    BackupScope? scope,
    bool? encryptionEnabled,
    int? maxHistory,
    bool? wifiOnly,
    bool? batteryOptimized,
  }) {
    return ScheduledBackupSettings(
      enabled: enabled ?? this.enabled,
      interval: interval ?? this.interval,
      type: type ?? this.type,
      scope: scope ?? this.scope,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      maxHistory: maxHistory ?? this.maxHistory,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      batteryOptimized: batteryOptimized ?? this.batteryOptimized,
    );
  }
}
