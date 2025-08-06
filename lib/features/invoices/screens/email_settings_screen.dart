import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/email_models.dart';
import '../services/invoice_email_service.dart';

/// Screen for managing email settings and configurations
class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final InvoiceEmailService _emailService = InvoiceEmailService.instance;

  List<EmailConfiguration> _configurations = [];
  bool _isLoading = true;
  String? _testEmail;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  Future<void> _loadConfigurations() async {
    setState(() => _isLoading = true);

    try {
      final configs = await _emailService.getAllEmailConfigurations();
      setState(() {
        _configurations = configs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading configurations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testEmailConfiguration(EmailConfiguration config) async {
    if (_testEmail == null || _testEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a test email address')),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final result =
          await _emailService.testEmailConfiguration(config, _testEmail!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Test email sent successfully!'
                  : 'Test failed: ${result.error}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _setAsDefault(EmailConfiguration config) async {
    try {
      final updatedConfig = config.copyWith(
        isDefault: true,
        updatedAt: DateTime.now(),
      );

      await _emailService.saveEmailConfiguration(updatedConfig);
      await _loadConfigurations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${config.providerName} set as default'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting default: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _loadConfigurations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTestEmailSection(),
                const Divider(),
                Expanded(
                  child: _configurations.isEmpty
                      ? _buildEmptyState()
                      : _buildConfigurationsList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddConfigurationDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Email Configuration',
      ),
    );
  }

  Widget _buildTestEmailSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Email Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your email address to test the email configuration',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Test Email Address',
                      hintText: 'your@email.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => _testEmail = value,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isTesting
                      ? null
                      : () {
                          final defaultConfig = _configurations
                              .where((c) => c.isDefault)
                              .firstOrNull;
                          if (defaultConfig != null) {
                            _testEmailConfiguration(defaultConfig);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please set a default email configuration first'),
                              ),
                            );
                          }
                        },
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Test'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.email_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Email Configurations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Add an email configuration to start\nsending invoices automatically',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationsList() {
    return ListView.builder(
      itemCount: _configurations.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final config = _configurations[index];
        return _buildConfigurationCard(config);
      },
    );
  }

  Widget _buildConfigurationCard(EmailConfiguration config) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: config.isDefault
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          child: Icon(
            config.isDefault ? Icons.email : Icons.email_outlined,
            color: config.isDefault ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          config.providerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.fromEmail),
            Text(
              '${config.smtpHost}:${config.smtpPort}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (config.isDefault)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (!config.isDefault)
              PopupMenuItem(
                value: 'set_default',
                child: const Text('Set as Default'),
              ),
            PopupMenuItem(
              value: 'test',
              child: const Text('Test Configuration'),
            ),
            PopupMenuItem(
              value: 'edit',
              child: const Text('Edit'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: const Text('Delete'),
            ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'set_default':
                await _setAsDefault(config);
                break;
              case 'test':
                if (_testEmail != null && _testEmail!.isNotEmpty) {
                  await _testEmailConfiguration(config);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please enter a test email address first')),
                  );
                }
                break;
              case 'edit':
                await _showEditConfigurationDialog(config);
                break;
              case 'delete':
                await _deleteConfiguration(config);
                break;
            }
          },
        ),
      ),
    );
  }

  Future<void> _showAddConfigurationDialog() async {
    final result = await showDialog<EmailConfiguration>(
      context: context,
      builder: (context) => const EmailConfigurationDialog(),
    );

    if (result != null) {
      try {
        await _emailService.saveEmailConfiguration(result);
        await _loadConfigurations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Email configuration saved successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditConfigurationDialog(EmailConfiguration config) async {
    final result = await showDialog<EmailConfiguration>(
      context: context,
      builder: (context) => EmailConfigurationDialog(configuration: config),
    );

    if (result != null) {
      try {
        await _emailService.saveEmailConfiguration(result);
        await _loadConfigurations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Email configuration updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteConfiguration(EmailConfiguration config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Email Configuration'),
        content: Text(
          'Are you sure you want to delete the ${config.providerName} configuration?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement delete functionality in the service
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete functionality coming soon')),
      );
    }
  }
}

/// Dialog for adding/editing email configurations
class EmailConfigurationDialog extends StatefulWidget {
  final EmailConfiguration? configuration;

  const EmailConfigurationDialog({
    super.key,
    this.configuration,
  });

  @override
  State<EmailConfigurationDialog> createState() =>
      _EmailConfigurationDialogState();
}

class _EmailConfigurationDialogState extends State<EmailConfigurationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _providerController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fromEmailController = TextEditingController();
  final _fromNameController = TextEditingController();

  bool _useSSL = true;
  bool _useTLS = false;
  bool _isDefault = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.configuration != null) {
      _populateForm(widget.configuration!);
    }
  }

  @override
  void dispose() {
    _providerController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fromEmailController.dispose();
    _fromNameController.dispose();
    super.dispose();
  }

  void _populateForm(EmailConfiguration config) {
    _providerController.text = config.providerName;
    _hostController.text = config.smtpHost;
    _portController.text = config.smtpPort.toString();
    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _fromEmailController.text = config.fromEmail;
    _fromNameController.text = config.fromName;
    _useSSL = config.useSSL;
    _useTLS = config.useTLS;
    _isDefault = config.isDefault;
  }

  void _useGmailPreset() {
    _providerController.text = 'Gmail';
    _hostController.text = 'smtp.gmail.com';
    _portController.text = '587';
    _useSSL = false;
    _useTLS = true;
    setState(() {});
  }

  void _useOutlookPreset() {
    _providerController.text = 'Outlook';
    _hostController.text = 'smtp-mail.outlook.com';
    _portController.text = '587';
    _useSSL = false;
    _useTLS = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.configuration != null
          ? 'Edit Email Configuration'
          : 'Add Email Configuration'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick setup buttons
                if (widget.configuration == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _useGmailPreset,
                          icon: const Icon(Icons.email),
                          label: const Text('Gmail'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _useOutlookPreset,
                          icon: const Icon(Icons.email),
                          label: const Text('Outlook'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _providerController,
                  decoration: const InputDecoration(
                    labelText: 'Provider Name',
                    hintText: 'e.g., Gmail, Outlook',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a provider name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Host',
                          hintText: 'smtp.gmail.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '587',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          final port = int.tryParse(value ?? '');
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid port';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('SSL'),
                        value: _useSSL,
                        onChanged: (value) => setState(() => _useSSL = value!),
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('TLS'),
                        value: _useTLS,
                        onChanged: (value) => setState(() => _useTLS = value!),
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'your-email@gmail.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'App password or regular password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                    ),
                  ),
                  obscureText: !_showPassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _fromEmailController,
                  decoration: const InputDecoration(
                    labelText: 'From Email',
                    hintText: 'noreply@yourcompany.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter from email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _fromNameController,
                  decoration: const InputDecoration(
                    labelText: 'From Name',
                    hintText: 'Your Company Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter from name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CheckboxListTile(
                  title: const Text('Set as Default'),
                  subtitle:
                      const Text('Use this configuration for sending invoices'),
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final configuration = EmailConfiguration(
                id: widget.configuration?.id ??
                    'config-${DateTime.now().millisecondsSinceEpoch}',
                providerName: _providerController.text.trim(),
                smtpHost: _hostController.text.trim(),
                smtpPort: int.parse(_portController.text),
                useSSL: _useSSL,
                useTLS: _useTLS,
                username: _usernameController.text.trim(),
                password: _passwordController.text.trim(),
                fromEmail: _fromEmailController.text.trim(),
                fromName: _fromNameController.text.trim(),
                isDefault: _isDefault,
                createdAt: widget.configuration?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              Navigator.of(context).pop(configuration);
            }
          },
          child: Text(widget.configuration != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
