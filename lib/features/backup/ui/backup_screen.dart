import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../models/backup_models.dart';
import '../services/backup_service.dart';
import '../services/restore_service.dart';
import 'backup_creation_wizard.dart';
import 'restore_wizard.dart';
import 'backup_history_screen.dart';
import 'backup_settings_screen.dart';

/// Main backup and restore screen
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);
    final restoreService = ref.watch(restoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.backup), text: 'Backup'),
            Tab(icon: Icon(Icons.restore), text: 'Restore'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBackupTab(context, backupService),
          _buildRestoreTab(context, restoreService),
          const BackupHistoryScreen(),
        ],
      ),
    );
  }

  Widget _buildBackupTab(BuildContext context, BackupService backupService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current backup progress
          if (backupService.isBackupInProgress)
            _buildBackupProgressCard(context, backupService.currentBackup!),

          const SizedBox(height: 16),

          // Quick backup options
          _buildQuickBackupSection(context, backupService),

          const SizedBox(height: 24),

          // Advanced backup options
          _buildAdvancedBackupSection(context),

          const SizedBox(height: 24),

          // Recent backups
          _buildRecentBackupsSection(context, backupService),
        ],
      ),
    );
  }

  Widget _buildRestoreTab(BuildContext context, RestoreService restoreService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current restore progress
          if (restoreService.isRestoreInProgress)
            _buildRestoreProgressCard(context, restoreService.currentRestore!),

          const SizedBox(height: 16),

          // Restore from file
          _buildRestoreFromFileSection(context, restoreService),

          const SizedBox(height: 24),

          // Pending conflicts
          if (restoreService.hasPendingConflicts)
            _buildPendingConflictsSection(context, restoreService),

          const SizedBox(height: 24),

          // Restore options
          _buildRestoreOptionsSection(context),
        ],
      ),
    );
  }

  Widget _buildBackupProgressCard(
      BuildContext context, BackupProgress progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Creating ${progress.type.name.toUpperCase()} Backup',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (progress.status != BackupStatus.completed)
                  TextButton(
                    onPressed: () =>
                        ref.read(backupServiceProvider).cancelBackup(),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.progressPercentage / 100,
            ),
            const SizedBox(height: 8),
            Text(
              progress.currentOperation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.completedSteps}/${progress.totalSteps} steps completed (${progress.progressPercentage.toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreProgressCard(
      BuildContext context, RestoreProgress progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Restoring Backup',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (progress.status != RestoreStatus.completed)
                  TextButton(
                    onPressed: () =>
                        ref.read(restoreServiceProvider).cancelRestore(),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.progressPercentage / 100,
            ),
            const SizedBox(height: 8),
            Text(
              progress.currentOperation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.completedSteps}/${progress.totalSteps} steps completed (${progress.progressPercentage.toStringAsFixed(1)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBackupSection(
      BuildContext context, BackupService backupService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: backupService.isBackupInProgress
                        ? null
                        : () => _createQuickBackup(context, BackupType.full),
                    icon: const Icon(Icons.backup),
                    label: const Text('Full Backup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: backupService.isBackupInProgress
                        ? null
                        : () =>
                            _createQuickBackup(context, BackupType.incremental),
                    icon: const Icon(Icons.update),
                    label: const Text('Incremental'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Quick backups use default settings and save to the default location.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedBackupSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Custom Backup'),
              subtitle: const Text(
                  'Configure backup options, location, and encryption'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToBackupWizard(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Scheduled Backups'),
              subtitle: const Text('Set up automatic backups'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToScheduledBackups(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBackupsSection(
      BuildContext context, BackupService backupService) {
    final recentBackups = backupService.backupHistory.take(3).toList();

    if (recentBackups.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.backup_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No backups yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first backup to secure your data',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Backups',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(2),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recentBackups
                .map((backup) => _buildBackupListItem(context, backup)),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreFromFileSection(
      BuildContext context, RestoreService restoreService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restore from File',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: restoreService.isRestoreInProgress
                  ? null
                  : () => _selectBackupFileToRestore(context),
              icon: const Icon(Icons.file_open),
              label: const Text('Select Backup File'),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a .bdb backup file to restore your data. Make sure to backup your current data first.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingConflictsSection(
      BuildContext context, RestoreService restoreService) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Conflicts Detected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${restoreService.pendingConflicts.length} conflicts need resolution before restore can continue.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _navigateToConflictResolution(context),
              child: const Text('Resolve Conflicts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreOptionsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restore Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.restore_page),
              title: const Text('Advanced Restore'),
              subtitle: const Text(
                  'Configure restore options and conflict resolution'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToRestoreWizard(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupListItem(BuildContext context, BackupHistoryEntry backup) {
    return ListTile(
      leading: Icon(
        backup.isEncrypted ? Icons.lock : Icons.backup,
        color: _getStatusColor(context, backup.status),
      ),
      title: Text(backup.fileName),
      subtitle: Text(
        '${_formatFileSize(backup.fileSize)} • ${_formatDateTime(backup.createdAt)}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleBackupAction(context, backup, value),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'restore',
            child: Text('Restore'),
          ),
          const PopupMenuItem(
            value: 'share',
            child: Text('Share'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, BackupStatus status) {
    switch (status) {
      case BackupStatus.completed:
        return Theme.of(context).colorScheme.primary;
      case BackupStatus.failed:
        return Theme.of(context).colorScheme.error;
      case BackupStatus.inProgress:
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createQuickBackup(BuildContext context, BackupType type) async {
    try {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select backup location',
      );

      if (directory != null) {
        final backupService = ref.read(backupServiceProvider);

        if (type == BackupType.full) {
          await backupService.createFullBackup(
            outputPath: directory,
            onProgress: (progress) {
              // Progress is handled by the provider
            },
          );
        } else {
          // For incremental backup, use last backup date
          final lastBackup = backupService.backupHistory.isNotEmpty
              ? backupService.backupHistory.first.createdAt
              : DateTime.now().subtract(const Duration(days: 7));

          await backupService.createIncrementalBackup(
            outputPath: directory,
            fromDate: lastBackup,
            onProgress: (progress) {
              // Progress is handled by the provider
            },
          );
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup created successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectBackupFileToRestore(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bdb'],
        dialogTitle: 'Select backup file to restore',
      );

      if (result != null && result.files.single.path != null) {
        final backupPath = result.files.single.path!;

        if (context.mounted) {
          _navigateToRestoreWizard(context, backupPath: backupPath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: ${e.toString()}')),
        );
      }
    }
  }

  void _handleBackupAction(
      BuildContext context, BackupHistoryEntry backup, String action) {
    switch (action) {
      case 'restore':
        _navigateToRestoreWizard(context, backupPath: backup.filePath);
        break;
      case 'share':
        // Implement share functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Share functionality not implemented yet')),
        );
        break;
      case 'delete':
        _showDeleteBackupDialog(context, backup);
        break;
    }
  }

  void _showDeleteBackupDialog(
      BuildContext context, BackupHistoryEntry backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete "${backup.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(backupServiceProvider).deleteBackup(backup.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToBackupWizard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackupCreationWizard(),
      ),
    );
  }

  void _navigateToRestoreWizard(BuildContext context, {String? backupPath}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestoreWizard(initialBackupPath: backupPath),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackupSettingsScreen(),
      ),
    );
  }

  void _navigateToScheduledBackups(BuildContext context) {
    // Implement scheduled backups screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Scheduled backups screen not implemented yet')),
    );
  }

  void _navigateToConflictResolution(BuildContext context) {
    // Implement conflict resolution screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Conflict resolution screen not implemented yet')),
    );
  }
}
