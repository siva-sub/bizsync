import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/singapore_gst_service.dart';

/// Screen for configuring company tax settings including GST registration
class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({Key? key}) : super(key: key);

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Company GST Settings
  bool _isGstRegistered = false;
  final TextEditingController _gstRegistrationNumberController =
      TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyUenController = TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();
  DateTime? _gstRegistrationDate;

  // Default Tax Rates
  double _defaultGstRate = SingaporeGstService.currentGstRate * 100; // 9%
  bool _autoApplyGst = true;
  bool _gstInclusive = false;

  // Tax Exemptions
  final List<String> _exemptCategories = [];
  final TextEditingController _newExemptionController = TextEditingController();

  // CPF Settings
  bool _enableCpfCalculations = true;
  bool _autoCalculateAge = true;
  final TextEditingController _cpfRateOverrideController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _gstRegistrationNumberController.dispose();
    _companyNameController.dispose();
    _companyUenController.dispose();
    _companyAddressController.dispose();
    _newExemptionController.dispose();
    _cpfRateOverrideController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    // In a real app, load from SharedPreferences or database
    // For now, set some default values
    setState(() {
      _companyNameController.text = 'Sample Company Pte Ltd';
      _companyUenController.text = '200012345M';
      _companyAddressController.text = '123 Business Street, Singapore 123456';
      _isGstRegistered = true;
      _gstRegistrationNumberController.text = '200012345M';
      _gstRegistrationDate = DateTime(2020, 1, 1);
      _exemptCategories.addAll(['Financial Services', 'Residential Property']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompanyInformationSection(),
              const SizedBox(height: 24),
              _buildGstSettingsSection(),
              const SizedBox(height: 24),
              _buildTaxExemptionsSection(),
              const SizedBox(height: 24),
              _buildCpfSettingsSection(),
              const SizedBox(height: 24),
              _buildAdvancedSettingsSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInformationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Company name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyUenController,
              decoration: const InputDecoration(
                labelText: 'UEN (Unique Entity Number)',
                hintText: 'e.g., 200012345M',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^\d{9}[A-Z]$').hasMatch(value)) {
                    return 'Invalid UEN format (should be 9 digits + 1 letter)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyAddressController,
              decoration: const InputDecoration(
                labelText: 'Company Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GST Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Company is GST Registered'),
              subtitle: Text(_isGstRegistered
                  ? 'Your company is registered for GST'
                  : 'Your company is not GST registered'),
              value: _isGstRegistered,
              onChanged: (value) {
                setState(() {
                  _isGstRegistered = value;
                });
              },
            ),
            if (_isGstRegistered) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstRegistrationNumberController,
                decoration: const InputDecoration(
                  labelText: 'GST Registration Number *',
                  hintText: 'e.g., 200012345M',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_isGstRegistered && (value == null || value.isEmpty)) {
                    return 'GST registration number is required';
                  }
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^\d{9}[A-Z]$').hasMatch(value)) {
                      return 'Invalid GST number format';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'GST Registration Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _gstRegistrationDate != null
                        ? _formatDate(_gstRegistrationDate!)
                        : 'Select registration date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _defaultGstRate.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Default GST Rate (%)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      readOnly: true, // Current rate is fixed by law
                      onChanged: (value) {
                        final rate = double.tryParse(value);
                        if (rate != null) {
                          setState(() {
                            _defaultGstRate = rate;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Rate Info',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        Text(
                          '9% effective from 1 Jan 2023',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto-apply GST to Standard Items'),
                subtitle:
                    const Text('Automatically add GST to standard-rated items'),
                value: _autoApplyGst,
                onChanged: (value) {
                  setState(() {
                    _autoApplyGst = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('GST Inclusive Pricing'),
                subtitle: const Text('Display prices including GST by default'),
                value: _gstInclusive,
                onChanged: (value) {
                  setState(() {
                    _gstInclusive = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaxExemptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tax Exemptions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: _showExemptionInfo,
                  tooltip: 'Exemption Information',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newExemptionController,
                    decoration: const InputDecoration(
                      labelText: 'Add Exempt Category',
                      hintText: 'e.g., Financial Services',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addExemption,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_exemptCategories.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Exemptions:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _exemptCategories
                        .map((category) => Chip(
                              label: Text(category),
                              onDeleted: () => _removeExemption(category),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ))
                        .toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCpfSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CPF Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable CPF Calculations'),
              subtitle: const Text(
                  'Automatically calculate CPF contributions for payroll'),
              value: _enableCpfCalculations,
              onChanged: (value) {
                setState(() {
                  _enableCpfCalculations = value;
                });
              },
            ),
            if (_enableCpfCalculations) ...[
              SwitchListTile(
                title: const Text('Auto-calculate Age-based Rates'),
                subtitle: const Text('Use employee age to determine CPF rates'),
                value: _autoCalculateAge,
                onChanged: (value) {
                  setState(() {
                    _autoCalculateAge = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildCpfRatesSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCpfRatesSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current CPF Rates (2024)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Below 55: Employee 20%, Employer 17%'),
          const Text('55-60: Employee 13%, Employer 13%'),
          const Text('60-65: Employee 7.5%, Employer 9%'),
          const Text('Above 65: Employee 5%, Employer 7.5%'),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('View GST Registration Info'),
              subtitle: const Text('Requirements and obligations'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showGstRegistrationInfo,
            ),
            ListTile(
              title: const Text('Tax Rate History'),
              subtitle: const Text('Historical GST rates'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showTaxRateHistory,
            ),
            ListTile(
              title: const Text('Export Tax Settings'),
              subtitle: const Text('Backup your tax configuration'),
              trailing: const Icon(Icons.download),
              onTap: _exportSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset to Defaults'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('Save Settings'),
          ),
        ),
      ],
    );
  }

  void _selectDate(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _gstRegistrationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select GST Registration Date',
    ).then((date) {
      if (date != null) {
        setState(() {
          _gstRegistrationDate = date;
        });
      }
    });
  }

  void _addExemption() {
    final category = _newExemptionController.text.trim();
    if (category.isNotEmpty && !_exemptCategories.contains(category)) {
      setState(() {
        _exemptCategories.add(category);
        _newExemptionController.clear();
      });
    }
  }

  void _removeExemption(String category) {
    setState(() {
      _exemptCategories.remove(category);
    });
  }

  void _showExemptionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GST Exemptions in Singapore'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Common exempt categories:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...SingaporeGstExemptions.exemptCategories
                  .map((category) => Text('• $category')),
              const SizedBox(height: 16),
              const Text('Zero-rated categories:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...SingaporeGstExemptions.zeroRatedCategories
                  .map((category) => Text('• $category')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGstRegistrationInfo() {
    final info = SingaporeGstService.getGstRegistrationInfo();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GST Registration Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mandatory Threshold: S\$${info['mandatory_threshold']}'),
              Text('Registration Period: ${info['registration_period']} days'),
              Text('Effective Date: ${info['effective_date']}'),
              const SizedBox(height: 16),
              const Text('Benefits:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...info['benefits'].map<Widget>((benefit) => Text('• $benefit')),
              const SizedBox(height: 16),
              const Text('Obligations:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...info['obligations']
                  .map<Widget>((obligation) => Text('• $obligation')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTaxRateHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Singapore GST Rate History'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1 Jan 2023 onwards: 9%',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('1 Jan 2022 - 31 Dec 2022: 8%'),
            Text('1 Jan 2016 - 31 Dec 2021: 7%'),
            Text('1 Jul 2007 - 31 Dec 2015: 7%'),
            Text('1 Jan 2004 - 30 Jun 2007: 5%'),
            Text('1 Apr 1994 - 31 Dec 2003: 3%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportSettings() {
    // In a real app, this would export settings to a file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings exported successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
            'This will reset all tax settings to default values. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isGstRegistered = false;
                _gstRegistrationNumberController.clear();
                _companyNameController.clear();
                _companyUenController.clear();
                _companyAddressController.clear();
                _gstRegistrationDate = null;
                _defaultGstRate = SingaporeGstService.currentGstRate * 100;
                _autoApplyGst = true;
                _gstInclusive = false;
                _exemptCategories.clear();
                _enableCpfCalculations = true;
                _autoCalculateAge = true;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // In a real app, save to SharedPreferences or database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tax settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
