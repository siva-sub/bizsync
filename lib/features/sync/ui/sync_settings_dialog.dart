import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sync_models.dart';

/// Dialog for configuring sync settings before starting a sync session
class SyncSettingsDialog extends StatefulWidget {
  const SyncSettingsDialog({super.key});

  @override
  State<SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends State<SyncSettingsDialog> {
  final _bandwidthController = TextEditingController(text: '1024');

  bool _syncInvoices = true;
  bool _syncCustomers = true;
  bool _syncProducts = true;
  bool _syncPayments = true;
  bool _syncReports = false;
  bool _syncSettings = true;
  bool _compressData = true;
  bool _encryptData = true;

  DateTime? _syncFromDate;
  DateTime? _syncToDate;

  final List<String> _excludedTables = [];
  final TextEditingController _excludeTableController = TextEditingController();

  @override
  void dispose() {
    _bandwidthController.dispose();
    _excludeTableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.sync_alt, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sync Configuration',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data to Sync section
                    _buildSectionHeader('Data to Sync'),
                    _buildDataSelectionSection(),

                    const SizedBox(height: 24),

                    // Date Range section
                    _buildSectionHeader('Date Range (Optional)'),
                    _buildDateRangeSection(),

                    const SizedBox(height: 24),

                    // Performance Settings section
                    _buildSectionHeader('Performance Settings'),
                    _buildPerformanceSection(),

                    const SizedBox(height: 24),

                    // Security Settings section
                    _buildSectionHeader('Security Settings'),
                    _buildSecuritySection(),

                    const SizedBox(height: 24),

                    // Advanced Settings section
                    _buildSectionHeader('Advanced Settings'),
                    _buildAdvancedSection(),
                  ],
                ),
              ),
            ),

            const Divider(),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _validateAndStartSync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Start Sync'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDataSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Invoices'),
              subtitle: const Text('Invoice data and line items'),
              value: _syncInvoices,
              onChanged: (value) {
                setState(() {
                  _syncInvoices = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Customers'),
              subtitle: const Text('Customer information and contacts'),
              value: _syncCustomers,
              onChanged: (value) {
                setState(() {
                  _syncCustomers = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Products'),
              subtitle: const Text('Product catalog and inventory'),
              value: _syncProducts,
              onChanged: (value) {
                setState(() {
                  _syncProducts = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Payments'),
              subtitle: const Text('Payment records and transactions'),
              value: _syncPayments,
              onChanged: (value) {
                setState(() {
                  _syncPayments = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Reports'),
              subtitle: const Text('Generated reports and analytics'),
              value: _syncReports,
              onChanged: (value) {
                setState(() {
                  _syncReports = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Settings'),
              subtitle: const Text('Application configuration'),
              value: _syncSettings,
              onChanged: (value) {
                setState(() {
                  _syncSettings = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Sync only data within a specific date range',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('From Date'),
                    subtitle: Text(
                      _syncFromDate?.toString().split(' ')[0] ?? 'No limit',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectFromDate(context),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('To Date'),
                    subtitle: Text(
                      _syncToDate?.toString().split(' ')[0] ?? 'No limit',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectToDate(context),
                  ),
                ),
              ],
            ),
            if (_syncFromDate != null || _syncToDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _syncFromDate = null;
                    _syncToDate = null;
                  });
                },
                child: const Text('Clear Date Range'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              title: const Text('Bandwidth Limit (KB/s)'),
              subtitle: TextField(
                controller: _bandwidthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'Enter bandwidth limit',
                  suffixText: 'KB/s',
                ),
              ),
            ),
            CheckboxListTile(
              title: const Text('Compress Data'),
              subtitle: const Text('Reduce transfer size (recommended)'),
              value: _compressData,
              onChanged: (value) {
                setState(() {
                  _compressData = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Encrypt Data'),
              subtitle:
                  const Text('End-to-end encryption (strongly recommended)'),
              value: _encryptData,
              onChanged: (value) {
                setState(() {
                  _encryptData = value ?? false;
                });
              },
            ),
            if (!_encryptData)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disabling encryption is not recommended for sensitive data.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Excluded Tables',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tables to exclude from sync (expert use only)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // List of excluded tables
            if (_excludedTables.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _excludedTables.map((table) {
                  return Chip(
                    label: Text(table),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _excludedTables.remove(table);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Add excluded table
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _excludeTableController,
                    decoration: const InputDecoration(
                      hintText: 'Table name to exclude',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addExcludedTable,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add table to exclusion list',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addExcludedTable() {
    final tableName = _excludeTableController.text.trim();
    if (tableName.isNotEmpty && !_excludedTables.contains(tableName)) {
      setState(() {
        _excludedTables.add(tableName);
        _excludeTableController.clear();
      });
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _syncFromDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _syncFromDate = date;
        // Ensure from date is before to date
        if (_syncToDate != null && date.isAfter(_syncToDate!)) {
          _syncToDate = null;
        }
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _syncToDate ?? DateTime.now(),
      firstDate: _syncFromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _syncToDate = date;
      });
    }
  }

  void _validateAndStartSync() {
    // Validate settings
    if (!_syncInvoices &&
        !_syncCustomers &&
        !_syncProducts &&
        !_syncPayments &&
        !_syncReports &&
        !_syncSettings) {
      _showValidationError('Please select at least one type of data to sync.');
      return;
    }

    final bandwidthText = _bandwidthController.text.trim();
    if (bandwidthText.isEmpty) {
      _showValidationError('Please enter a bandwidth limit.');
      return;
    }

    final bandwidth = int.tryParse(bandwidthText);
    if (bandwidth == null || bandwidth <= 0) {
      _showValidationError('Please enter a valid bandwidth limit.');
      return;
    }

    if (_syncFromDate != null &&
        _syncToDate != null &&
        _syncFromDate!.isAfter(_syncToDate!)) {
      _showValidationError('From date must be before to date.');
      return;
    }

    // Create configuration
    final configuration = SyncConfiguration(
      syncInvoices: _syncInvoices,
      syncCustomers: _syncCustomers,
      syncProducts: _syncProducts,
      syncPayments: _syncPayments,
      syncReports: _syncReports,
      syncSettings: _syncSettings,
      syncFromDate: _syncFromDate,
      syncToDate: _syncToDate,
      maxBandwidthKbps: bandwidth,
      compressData: _compressData,
      encryptData: _encryptData,
      excludedTables: List.from(_excludedTables),
    );

    Navigator.of(context).pop(configuration);
  }

  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
