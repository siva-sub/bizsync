import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/backup_models.dart';
import '../services/backup_service.dart';
import 'restore_wizard.dart';

/// Screen showing backup history and management
class BackupHistoryScreen extends ConsumerStatefulWidget {
  const BackupHistoryScreen({super.key});

  @override
  ConsumerState<BackupHistoryScreen> createState() =>
      _BackupHistoryScreenState();
}

class _BackupHistoryScreenState extends ConsumerState<BackupHistoryScreen> {
  String _searchQuery = '';
  BackupType? _filterType;
  BackupStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);
    final filteredBackups = _filterBackups(backupService.backupHistory);

    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: filteredBackups.isEmpty
              ? _buildEmptyState()
              : _buildBackupList(filteredBackups),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search backups...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),

          const SizedBox(height: 12),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type filter
                ChoiceChip(
                  label: Text(_filterType?.name.toUpperCase() ?? 'All Types'),
                  selected: _filterType != null,
                  onSelected: (selected) {
                    if (selected) {
                      _showTypeFilter();
                    } else {
                      setState(() => _filterType = null);
                    }
                  },
                ),

                const SizedBox(width: 8),

                // Status filter
                ChoiceChip(
                  label:
                      Text(_filterStatus?.name.toUpperCase() ?? 'All Status'),
                  selected: _filterStatus != null,
                  onSelected: (selected) {
                    if (selected) {
                      _showStatusFilter();
                    } else {
                      setState(() => _filterStatus = null);
                    }
                  },
                ),

                const SizedBox(width: 8),

                // Clear filters
                if (_filterType != null || _filterStatus != null)
                  ActionChip(
                    label: const Text('Clear'),
                    onPressed: () => setState(() {
                      _filterType = null;
                      _filterStatus = null;
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backup_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No backups found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ||
                    _filterType != null ||
                    _filterStatus != null
                ? 'Try adjusting your search or filters'
                : 'Create your first backup to get started',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBackupList(List<BackupHistoryEntry> backups) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: backups.length,
      itemBuilder: (context, index) {
        final backup = backups[index];
        return _buildBackupCard(backup);
      },
    );
  }

  Widget _buildBackupCard(BackupHistoryEntry backup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: _buildBackupIcon(backup),
        title: Text(backup.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDateTime(backup.createdAt)),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(backup.status),
                const SizedBox(width: 8),
                _buildTypeChip(backup.metadata.type),
                const SizedBox(width: 8),
                Text(
                  _formatFileSize(backup.fileSize),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleBackupAction(backup, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: ListTile(
                leading: Icon(Icons.restore),
                title: Text('Restore'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Details'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Share'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _showBackupDetails(backup),
      ),
    );
  }

  Widget _buildBackupIcon(BackupHistoryEntry backup) {
    IconData icon;
    Color? color;

    switch (backup.status) {
      case BackupStatus.completed:
        icon = backup.isEncrypted ? Icons.lock : Icons.backup;
        color = Theme.of(context).colorScheme.primary;
        break;
      case BackupStatus.failed:
        icon = Icons.error;
        color = Theme.of(context).colorScheme.error;
        break;
      case BackupStatus.inProgress:
        icon = Icons.sync;
        color = Theme.of(context).colorScheme.secondary;
        break;
      default:
        icon = Icons.backup_outlined;
        color = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }

    return Icon(icon, color: color);
  }

  Widget _buildStatusChip(BackupStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case BackupStatus.completed:
        backgroundColor = Theme.of(context).colorScheme.primaryContainer;
        textColor = Theme.of(context).colorScheme.onPrimaryContainer;
        label = 'Completed';
        break;
      case BackupStatus.failed:
        backgroundColor = Theme.of(context).colorScheme.errorContainer;
        textColor = Theme.of(context).colorScheme.onErrorContainer;
        label = 'Failed';
        break;
      case BackupStatus.inProgress:
        backgroundColor = Theme.of(context).colorScheme.secondaryContainer;
        textColor = Theme.of(context).colorScheme.onSecondaryContainer;
        label = 'In Progress';
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.surfaceVariant;
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
        label = status.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
            ),
      ),
    );
  }

  Widget _buildTypeChip(BackupType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
      ),
    );
  }

  List<BackupHistoryEntry> _filterBackups(List<BackupHistoryEntry> backups) {
    return backups.where((backup) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!backup.fileName.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Type filter
      if (_filterType != null && backup.metadata.type != _filterType) {
        return false;
      }

      // Status filter
      if (_filterStatus != null && backup.status != _filterStatus) {
        return false;
      }

      return true;
    }).toList();
  }

  void _handleBackupAction(BackupHistoryEntry backup, String action) {
    switch (action) {
      case 'restore':
        _navigateToRestore(backup);
        break;
      case 'details':
        _showBackupDetails(backup);
        break;
      case 'share':
        _shareBackup(backup);
        break;
      case 'delete':
        _confirmDeleteBackup(backup);
        break;
    }
  }

  void _navigateToRestore(BackupHistoryEntry backup) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestoreWizard(initialBackupPath: backup.filePath),
      ),
    );
  }

  void _showBackupDetails(BackupHistoryEntry backup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Backup Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailItem('File Name', backup.fileName),
                    _buildDetailItem(
                        'Created', _formatDateTime(backup.createdAt)),
                    _buildDetailItem(
                        'Type', backup.metadata.type.name.toUpperCase()),
                    _buildDetailItem(
                        'Scope', _getScopeTitle(backup.metadata.scope)),
                    _buildDetailItem('Size', _formatFileSize(backup.fileSize)),
                    _buildDetailItem('Compressed Size',
                        _formatFileSize(backup.metadata.compressedSize)),
                    _buildDetailItem(
                        'Records', backup.metadata.totalRecords.toString()),
                    _buildDetailItem(
                        'Compression', backup.metadata.compressionAlgorithm),
                    _buildDetailItem(
                        'Encrypted', backup.isEncrypted ? 'Yes' : 'No'),
                    _buildDetailItem(
                        'Status', backup.status.name.toUpperCase()),
                    if (backup.errorMessage != null)
                      _buildDetailItem('Error', backup.errorMessage!),
                    if (backup.metadata.fromDate != null)
                      _buildDetailItem('From Date',
                          _formatDateTime(backup.metadata.fromDate!)),
                    if (backup.metadata.toDate != null)
                      _buildDetailItem(
                          'To Date', _formatDateTime(backup.metadata.toDate!)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _shareBackup(BackupHistoryEntry backup) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality not implemented yet')),
    );
  }

  void _confirmDeleteBackup(BackupHistoryEntry backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this backup?'),
            const SizedBox(height: 8),
            Text(
              backup.fileName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBackup(backup);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteBackup(BackupHistoryEntry backup) async {
    try {
      await ref.read(backupServiceProvider).deleteBackup(backup.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete backup: ${e.toString()}')),
        );
      }
    }
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...BackupType.values.map((type) => ListTile(
                  title: Text(type.name.toUpperCase()),
                  onTap: () {
                    setState(() => _filterType = type);
                    Navigator.of(context).pop();
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...BackupStatus.values.map((status) => ListTile(
                  title: Text(status.name.toUpperCase()),
                  onTap: () {
                    setState(() => _filterStatus = status);
                    Navigator.of(context).pop();
                  },
                )),
          ],
        ),
      ),
    );
  }

  String _getScopeTitle(BackupScope scope) {
    switch (scope) {
      case BackupScope.all:
        return 'Everything';
      case BackupScope.businessData:
        return 'Business Data';
      case BackupScope.userSettings:
        return 'Settings';
      case BackupScope.syncData:
        return 'Sync Data';
      case BackupScope.custom:
        return 'Custom';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
