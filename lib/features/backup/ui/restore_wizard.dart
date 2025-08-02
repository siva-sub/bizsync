import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../models/backup_models.dart';
import '../services/restore_service.dart';

/// Wizard for restoring backups with advanced options
class RestoreWizard extends ConsumerStatefulWidget {
  final String? initialBackupPath;
  
  const RestoreWizard({
    super.key,
    this.initialBackupPath,
  });

  @override
  ConsumerState<RestoreWizard> createState() => _RestoreWizardState();
}

class _RestoreWizardState extends ConsumerState<RestoreWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Configuration state
  String? _backupFilePath;
  String? _password;
  bool _createPreRestoreBackup = true;
  ConflictResolutionStrategy _defaultConflictStrategy = ConflictResolutionStrategy.prompt;
  BackupValidationResult? _validationResult;
  
  final _passwordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    if (widget.initialBackupPath != null) {
      _backupFilePath = widget.initialBackupPath;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Wizard'),
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
                _buildFileSelectionStep(),
                _buildValidationStep(),
                _buildOptionsStep(),
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
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == 3 ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFileSelectionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Backup File',
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
                    'Backup File',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  InkWell(
                    onTap: _selectBackupFile,
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
                          const Icon(Icons.file_present),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _backupFilePath != null 
                                  ? _backupFilePath!.split('/').last
                                  : 'Select .bdb backup file',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.folder_open),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
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
                            'Select a .bdb backup file created by BizSync. The file will be validated before restoration.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup Validation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          if (_validationResult == null)
            _buildValidationInProgress()
          else if (_validationResult!.isValid)
            _buildValidationSuccess()
          else
            _buildValidationError(),
          
          // Password input if backup is encrypted
          if (_validationResult?.manifest?.encryption?.isEncrypted == true)
            _buildPasswordInput(),
        ],
      ),
    );
  }

  Widget _buildValidationInProgress() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Validating backup file...'),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationSuccess() {
    final manifest = _validationResult!.manifest!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Backup Validated Successfully',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow('Created', _formatDateTime(manifest.createdAt)),
            _buildInfoRow('Device', manifest.deviceName),
            _buildInfoRow('App Version', manifest.appVersion),
            _buildInfoRow('Type', manifest.metadata.type.name.toUpperCase()),
            _buildInfoRow('Records', manifest.metadata.totalRecords.toString()),
            _buildInfoRow('Size', _formatFileSize(manifest.metadata.totalSize)),
            _buildInfoRow('Encrypted', manifest.encryption?.isEncrypted == true ? 'Yes' : 'No'),
            
            if (_validationResult!.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Warnings',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._validationResult!.warnings.map((warning) => 
                      Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 4),
                        child: Text(
                          '• $warning',
                          style: Theme.of(context).textTheme.bodySmall,
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
    );
  }

  Widget _buildValidationError() {
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
                  Icons.error,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  'Validation Failed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ..._validationResult!.errors.map((error) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $error',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => setState(() {
                _validationResult = null;
                _currentStep = 0;
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }),
              child: const Text('Select Different File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encrypted Backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Enter the password used to encrypt this backup',
                suffixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              onChanged: (value) => _password = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restore Options',
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
                    'Safety Options',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Create Backup Before Restore'),
                    subtitle: const Text('Recommended: Create a backup of current data before restoring'),
                    value: _createPreRestoreBackup,
                    onChanged: (value) => setState(() => _createPreRestoreBackup = value),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conflict Resolution',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How should conflicts be handled when restoring data?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  
                  ...ConflictResolutionStrategy.values.map((strategy) => 
                    RadioListTile<ConflictResolutionStrategy>(
                      title: Text(_getStrategyTitle(strategy)),
                      subtitle: Text(_getStrategyDescription(strategy)),
                      value: strategy,
                      groupValue: _defaultConflictStrategy,
                      onChanged: (value) => setState(() => _defaultConflictStrategy = value!),
                    ),
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
            'Restore Summary',
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
                    'Restore Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_backupFilePath != null)
                    _buildSummaryItem('File', _backupFilePath!.split('/').last),
                  if (_validationResult?.manifest != null) ...[
                    _buildSummaryItem('Created', _formatDateTime(_validationResult!.manifest!.createdAt)),
                    _buildSummaryItem('Type', _validationResult!.manifest!.metadata.type.name.toUpperCase()),
                    _buildSummaryItem('Records', _validationResult!.manifest!.metadata.totalRecords.toString()),
                  ],
                  _buildSummaryItem('Pre-restore Backup', _createPreRestoreBackup ? 'Yes' : 'No'),
                  _buildSummaryItem('Conflict Resolution', _getStrategyTitle(_defaultConflictStrategy)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CAUTION: This will replace your current data with the backup data. Make sure you have a backup of your current data if needed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
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
              child: Text(_currentStep == 3 ? 'Start Restore' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _backupFilePath != null;
      case 1:
        return _validationResult?.isValid == true &&
               (_validationResult?.manifest?.encryption?.isEncrypted != true ||
                (_password != null && _password!.isNotEmpty));
      case 2:
        return true;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_currentStep == 0) {
        _validateBackup();
      }
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _startRestore();
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

  Future<void> _selectBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bdb'],
        dialogTitle: 'Select backup file to restore',
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _backupFilePath = result.files.single.path!;
          _validationResult = null; // Reset validation when file changes
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _validateBackup() async {
    if (_backupFilePath == null) return;
    
    try {
      final restoreService = ref.read(restoreServiceProvider);
      final result = await restoreService.validateBackup(
        backupFilePath: _backupFilePath!,
        password: _password,
      );
      
      setState(() {
        _validationResult = result;
      });
    } catch (e) {
      setState(() {
        _validationResult = BackupValidationResult(
          isValid: false,
          errors: [e.toString()],
          warnings: [],
          compatibilityIssues: [],
        );
      });
    }
  }

  Future<void> _startRestore() async {
    try {
      final restoreService = ref.read(restoreServiceProvider);
      
      await restoreService.restoreFromBackup(
        backupFilePath: _backupFilePath!,
        password: _password,
        defaultStrategy: _defaultConflictStrategy,
        createBackupBeforeRestore: _createPreRestoreBackup,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore started successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: ${e.toString()}')),
        );
      }
    }
  }

  String _getStrategyTitle(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.skip:
        return 'Skip Conflicts';
      case ConflictResolutionStrategy.overwrite:
        return 'Overwrite Existing';
      case ConflictResolutionStrategy.merge:
        return 'Merge Data';
      case ConflictResolutionStrategy.prompt:
        return 'Ask Me (Recommended)';
    }
  }

  String _getStrategyDescription(ConflictResolutionStrategy strategy) {
    switch (strategy) {
      case ConflictResolutionStrategy.skip:
        return 'Keep existing data when conflicts occur';
      case ConflictResolutionStrategy.overwrite:
        return 'Replace existing data with backup data';
      case ConflictResolutionStrategy.merge:
        return 'Attempt to merge conflicting data';
      case ConflictResolutionStrategy.prompt:
        return 'Pause and ask for resolution on each conflict';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}