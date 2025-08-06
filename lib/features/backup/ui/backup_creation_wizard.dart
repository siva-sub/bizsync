import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../models/backup_models.dart';
import '../services/backup_service.dart';

/// Wizard for creating custom backups with advanced options
class BackupCreationWizard extends ConsumerStatefulWidget {
  const BackupCreationWizard({super.key});

  @override
  ConsumerState<BackupCreationWizard> createState() =>
      _BackupCreationWizardState();
}

class _BackupCreationWizardState extends ConsumerState<BackupCreationWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Configuration state
  BackupType _backupType = BackupType.full;
  BackupScope _backupScope = BackupScope.all;
  String? _outputPath;
  String? _password;
  bool _encryptionEnabled = true;
  bool _includeAttachments = true;
  String _compressionAlgorithm = 'zstd';
  int _compressionLevel = 3;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<String> _excludedTables = [];

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Wizard'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Wizard pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBackupTypeStep(),
                _buildScopeAndOptionsStep(),
                _buildEncryptionStep(),
                _buildLocationStep(),
                _buildSummaryStep(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == 4 ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBackupTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Backup Type',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          _buildBackupTypeCard(
            type: BackupType.full,
            title: 'Full Backup',
            description:
                'Complete backup of all data. Recommended for first backup or when you want a complete copy.',
            icon: Icons.backup,
          ),
          const SizedBox(height: 16),
          _buildBackupTypeCard(
            type: BackupType.incremental,
            title: 'Incremental Backup',
            description:
                'Only backs up data that has changed since the last backup. Faster and smaller.',
            icon: Icons.update,
          ),
          const SizedBox(height: 16),
          _buildBackupTypeCard(
            type: BackupType.differential,
            title: 'Differential Backup',
            description:
                'Backs up all changes since the last full backup. Balance between speed and completeness.',
            icon: Icons.difference,
          ),
          if (_backupType == BackupType.incremental ||
              _backupType == BackupType.differential)
            _buildDateRangeSelection(),
        ],
      ),
    );
  }

  Widget _buildBackupTypeCard({
    required BackupType type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _backupType == type;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => setState(() => _backupType = type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Radio<BackupType>(
                value: type,
                groupValue: _backupType,
                onChanged: (value) => setState(() => _backupType = value!),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelection() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectFromDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From Date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _fromDate != null
                            ? _formatDate(_fromDate!)
                            : 'Select start date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectToDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To Date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _toDate != null
                            ? _formatDate(_toDate!)
                            : 'Select end date',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeAndOptionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup Scope & Options',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // Backup scope
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What to Include',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...BackupScope.values
                      .map((scope) => RadioListTile<BackupScope>(
                            title: Text(_getScopeTitle(scope)),
                            subtitle: Text(_getScopeDescription(scope)),
                            value: scope,
                            groupValue: _backupScope,
                            onChanged: (value) =>
                                setState(() => _backupScope = value!),
                          )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Additional options
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional Options',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Include Attachments'),
                    subtitle:
                        const Text('Include file attachments in the backup'),
                    value: _includeAttachments,
                    onChanged: (value) =>
                        setState(() => _includeAttachments = value),
                  ),
                  ListTile(
                    title: const Text('Compression'),
                    subtitle: Text(
                        'Algorithm: $_compressionAlgorithm, Level: $_compressionLevel'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _showCompressionOptions,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Encryption Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Enable Encryption'),
                    subtitle: const Text('Protect your backup with a password'),
                    value: _encryptionEnabled,
                    onChanged: (value) =>
                        setState(() => _encryptionEnabled = value),
                  ),
                  if (_encryptionEnabled) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText:
                            'Choose a strong password to protect your backup',
                        suffixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      onChanged: (value) => _password = value,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        errorText: _getPasswordError(),
                        suffixIcon: const Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your backup will be encrypted using AES-256-GCM. Keep your password safe - it cannot be recovered if lost.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup Location',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Destination',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _selectOutputPath,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _outputPath ?? 'Select backup location',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The backup file will be saved with a timestamp in the filename. Make sure you have enough storage space.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup Summary',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryItem('Type', _backupType.name.toUpperCase()),
                  _buildSummaryItem('Scope', _getScopeTitle(_backupScope)),
                  _buildSummaryItem('Encryption',
                      _encryptionEnabled ? 'Enabled' : 'Disabled'),
                  _buildSummaryItem('Attachments',
                      _includeAttachments ? 'Included' : 'Excluded'),
                  _buildSummaryItem('Compression',
                      '$_compressionAlgorithm (Level $_compressionLevel)'),
                  if (_outputPath != null)
                    _buildSummaryItem('Location', _outputPath!),
                  if (_fromDate != null)
                    _buildSummaryItem('From Date', _formatDate(_fromDate!)),
                  if (_toDate != null)
                    _buildSummaryItem('To Date', _formatDate(_toDate!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Review your settings and tap "Create Backup" to start the backup process.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _canProceed() ? _nextStep : null,
              child: Text(_currentStep == 4 ? 'Create Backup' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        if (_backupType == BackupType.incremental ||
            _backupType == BackupType.differential) {
          return _fromDate != null;
        }
        return true;
      case 1:
        return true;
      case 2:
        if (_encryptionEnabled) {
          return _password != null &&
              _password!.isNotEmpty &&
              _password == _confirmPasswordController.text;
        }
        return true;
      case 3:
        return _outputPath != null;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createBackup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createBackup() async {
    try {
      final backupService = ref.read(backupServiceProvider);

      String backupPath;
      if (_backupType == BackupType.full) {
        backupPath = await backupService.createFullBackup(
          outputPath: _outputPath!,
          password: _encryptionEnabled ? _password : null,
          scope: _backupScope,
          includeAttachments: _includeAttachments,
        );
      } else {
        backupPath = await backupService.createIncrementalBackup(
          outputPath: _outputPath!,
          fromDate: _fromDate!,
          password: _encryptionEnabled ? _password : null,
          scope: _backupScope,
          includeAttachments: _includeAttachments,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Backup created: ${backupPath.split('/').last}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}')),
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

  String _getScopeDescription(BackupScope scope) {
    switch (scope) {
      case BackupScope.all:
        return 'All data including business records, settings, and sync data';
      case BackupScope.businessData:
        return 'Customers, products, sales, and inventory data';
      case BackupScope.userSettings:
        return 'App settings and preferences';
      case BackupScope.syncData:
        return 'Device sync and communication data';
      case BackupScope.custom:
        return 'Choose specific data to include';
    }
  }

  String? _getPasswordError() {
    if (_encryptionEnabled &&
        _confirmPasswordController.text.isNotEmpty &&
        _password != _confirmPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _fromDate ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _fromDate = date);
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _toDate = date);
    }
  }

  Future<void> _selectOutputPath() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup location',
    );
    if (directory != null) {
      setState(() => _outputPath = directory);
    }
  }

  void _showCompressionOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compression Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _compressionAlgorithm,
                decoration: const InputDecoration(labelText: 'Algorithm'),
                items: const [
                  DropdownMenuItem(
                      value: 'zstd', child: Text('Zstandard (Recommended)')),
                  DropdownMenuItem(value: 'gzip', child: Text('Gzip')),
                  DropdownMenuItem(
                      value: 'none', child: Text('No Compression')),
                ],
                onChanged: (value) {
                  setModalState(() => _compressionAlgorithm = value!);
                  setState(() => _compressionAlgorithm = value!);
                },
              ),
              const SizedBox(height: 16),
              Text('Compression Level: $_compressionLevel'),
              Slider(
                value: _compressionLevel.toDouble(),
                min: 1,
                max: 9,
                divisions: 8,
                label: _compressionLevel.toString(),
                onChanged: _compressionAlgorithm != 'none'
                    ? (value) {
                        setModalState(() => _compressionLevel = value.round());
                        setState(() => _compressionLevel = value.round());
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
