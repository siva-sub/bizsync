import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../models/backup_models.dart';
import '../services/backup_service.dart';

/// Settings screen for backup configuration
class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  late BackupConfig _config;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _config = ref.read(backupServiceProvider).config;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) {
        if (!didPop && _hasUnsavedChanges) {
          _showUnsavedChangesDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backup Settings'),
          actions: [
            if (_hasUnsavedChanges)
              TextButton(
                onPressed: _saveSettings,
                child: const Text('Save'),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAutoBackupSection(),
            const SizedBox(height: 16),
            _buildDefaultsSection(),
            const SizedBox(height: 16),
            _buildStorageSection(),
            const SizedBox(height: 16),
            _buildAdvancedSection(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatic Backups',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Auto Backup'),
              subtitle: const Text('Automatically create backups on schedule'),
              value: _config.autoBackupEnabled,
              onChanged: (value) => _updateConfig(_config.copyWith(autoBackupEnabled: value)),
            ),
            
            if (_config.autoBackupEnabled) ...[
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Backup Interval'),
                subtitle: Text(_formatDuration(_config.autoBackupInterval)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showIntervalPicker,
              ),
              
              ListTile(
                title: const Text('Default Backup Type'),
                subtitle: Text(_config.defaultBackupType.name.toUpperCase()),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showBackupTypePicker,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('Default Scope'),
              subtitle: Text(_getScopeTitle(_config.defaultScope)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showScopePicker,
            ),
            
            SwitchListTile(
              title: const Text('Encryption by Default'),
              subtitle: const Text('Enable encryption for new backups'),
              value: _config.encryptionEnabled,
              onChanged: (value) => _updateConfig(_config.copyWith(encryptionEnabled: value)),
            ),
            
            SwitchListTile(
              title: const Text('Include Attachments'),
              subtitle: const Text('Include file attachments in backups'),
              value: _config.includeAttachments,
              onChanged: (value) => _updateConfig(_config.copyWith(includeAttachments: value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage & Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('Default Export Path'),
              subtitle: Text(_config.defaultExportPath.isEmpty 
                  ? 'Not set' 
                  : _config.defaultExportPath),
              trailing: const Icon(Icons.folder_open),
              onTap: _selectDefaultExportPath,
            ),
            
            ListTile(
              title: const Text('Maximum Backup History'),
              subtitle: Text('Keep up to ${_config.maxBackupHistory} backups'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showMaxHistoryPicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('Compression Algorithm'),
              subtitle: Text(_config.compressionAlgorithm),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showCompressionPicker,
            ),
            
            ListTile(
              title: const Text('Compression Level'),
              subtitle: Text('Level ${_config.compressionLevel}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showCompressionLevelPicker,
            ),
            
            ListTile(
              title: const Text('Excluded Tables'),
              subtitle: Text(_config.excludedTables.isEmpty 
                  ? 'None' 
                  : '${_config.excludedTables.length} tables excluded'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showExcludedTablesPicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    if (!_hasUnsavedChanges) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveSettings,
        child: const Text('Save Settings'),
      ),
    );
  }

  void _updateConfig(BackupConfig newConfig) {
    setState(() {
      _config = newConfig;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    try {
      await ref.read(backupServiceProvider).updateConfig(_config);
      setState(() => _hasUnsavedChanges = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    }
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveSettings().then((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showIntervalPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIntervalOption('Every 6 hours', const Duration(hours: 6)),
            _buildIntervalOption('Daily', const Duration(days: 1)),
            _buildIntervalOption('Every 3 days', const Duration(days: 3)),
            _buildIntervalOption('Weekly', const Duration(days: 7)),
            _buildIntervalOption('Monthly', const Duration(days: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalOption(String label, Duration duration) {
    final isSelected = _config.autoBackupInterval == duration;
    
    return ListTile(
      title: Text(label),
      leading: Radio<Duration>(
        value: duration,
        groupValue: _config.autoBackupInterval,
        onChanged: (value) {
          if (value != null) {
            _updateConfig(_config.copyWith(autoBackupInterval: value));
            Navigator.of(context).pop();
          }
        },
      ),
      onTap: () {
        _updateConfig(_config.copyWith(autoBackupInterval: duration));
        Navigator.of(context).pop();
      },
    );
  }

  void _showBackupTypePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Backup Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BackupType.values.map((type) => ListTile(
            title: Text(type.name.toUpperCase()),
            leading: Radio<BackupType>(
              value: type,
              groupValue: _config.defaultBackupType,
              onChanged: (value) {
                if (value != null) {
                  _updateConfig(_config.copyWith(defaultBackupType: value));
                  Navigator.of(context).pop();
                }
              },
            ),
            onTap: () {
              _updateConfig(_config.copyWith(defaultBackupType: type));
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showScopePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Backup Scope'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BackupScope.values.map((scope) => ListTile(
            title: Text(_getScopeTitle(scope)),
            leading: Radio<BackupScope>(
              value: scope,
              groupValue: _config.defaultScope,
              onChanged: (value) {
                if (value != null) {
                  _updateConfig(_config.copyWith(defaultScope: value));
                  Navigator.of(context).pop();
                }
              },
            ),
            onTap: () {
              _updateConfig(_config.copyWith(defaultScope: scope));
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showCompressionPicker() {
    final algorithms = ['zstd', 'gzip', 'none'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compression Algorithm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: algorithms.map((algorithm) => ListTile(
            title: Text(algorithm == 'zstd' ? 'Zstandard (Recommended)' : algorithm),
            leading: Radio<String>(
              value: algorithm,
              groupValue: _config.compressionAlgorithm,
              onChanged: (value) {
                if (value != null) {
                  _updateConfig(_config.copyWith(compressionAlgorithm: value));
                  Navigator.of(context).pop();
                }
              },
            ),
            onTap: () {
              _updateConfig(_config.copyWith(compressionAlgorithm: algorithm));
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showCompressionLevelPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compression Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: Level ${_config.compressionLevel}'),
            const SizedBox(height: 16),
            Slider(
              value: _config.compressionLevel.toDouble(),
              min: 1,
              max: 9,
              divisions: 8,
              label: _config.compressionLevel.toString(),
              onChanged: (value) {
                _updateConfig(_config.copyWith(compressionLevel: value.round()));
              },
            ),
            const SizedBox(height: 8),
            const Text('1 = Fastest, 9 = Best compression'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showMaxHistoryPicker() {
    final options = [5, 10, 15, 20, 25, 50];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Backup History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((count) => ListTile(
            title: Text('$count backups'),
            leading: Radio<int>(
              value: count,
              groupValue: _config.maxBackupHistory,
              onChanged: (value) {
                if (value != null) {
                  _updateConfig(_config.copyWith(maxBackupHistory: value));
                  Navigator.of(context).pop();
                }
              },
            ),
            onTap: () {
              _updateConfig(_config.copyWith(maxBackupHistory: count));
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showExcludedTablesPicker() {
    final availableTables = [
      'customers', 'products', 'categories', 'sales_transactions', 
      'sales_items', 'user_settings', 'business_profile', 'sync_log', 'device_registry'
    ];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Excluded Tables'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: availableTables.map((table) => CheckboxListTile(
                title: Text(table),
                value: _config.excludedTables.contains(table),
                onChanged: (value) {
                  final newExcluded = List<String>.from(_config.excludedTables);
                  if (value == true) {
                    newExcluded.add(table);
                  } else {
                    newExcluded.remove(table);
                  }
                  _updateConfig(_config.copyWith(excludedTables: newExcluded));
                  setDialogState(() {});
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDefaultExportPath() async {
    try {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select default backup location',
      );
      
      if (directory != null) {
        _updateConfig(_config.copyWith(defaultExportPath: directory));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select directory: ${e.toString()}')),
        );
      }
    }
  }

  String _getScopeTitle(BackupScope scope) {
    switch (scope) {
      case BackupScope.all:
        return 'Everything';
      case BackupScope.businessData:
        return 'Business Data Only';
      case BackupScope.userSettings:
        return 'Settings Only';
      case BackupScope.syncData:
        return 'Sync Data Only';
      case BackupScope.custom:
        return 'Custom Selection';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }
}

/// Extension to add copyWith method to BackupConfig
extension BackupConfigExtension on BackupConfig {
  BackupConfig copyWith({
    bool? autoBackupEnabled,
    Duration? autoBackupInterval,
    BackupType? defaultBackupType,
    BackupScope? defaultScope,
    bool? encryptionEnabled,
    String? compressionAlgorithm,
    int? compressionLevel,
    bool? includeAttachments,
    int? maxBackupHistory,
    String? defaultExportPath,
    List<String>? excludedTables,
  }) {
    return BackupConfig(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupInterval: autoBackupInterval ?? this.autoBackupInterval,
      defaultBackupType: defaultBackupType ?? this.defaultBackupType,
      defaultScope: defaultScope ?? this.defaultScope,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      compressionAlgorithm: compressionAlgorithm ?? this.compressionAlgorithm,
      compressionLevel: compressionLevel ?? this.compressionLevel,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      maxBackupHistory: maxBackupHistory ?? this.maxBackupHistory,
      defaultExportPath: defaultExportPath ?? this.defaultExportPath,
      excludedTables: excludedTables ?? this.excludedTables,
    );
  }
}