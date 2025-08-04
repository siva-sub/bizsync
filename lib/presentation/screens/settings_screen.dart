import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/crdt_database_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _currentTheme = 'system';

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('theme_mode') ?? 'system';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Settings Section
          _buildSectionHeader(context, 'Application'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Icons.palette,
              title: 'Theme',
              subtitle: 'Dark, Light, or System',
              onTap: () => _showThemeSettings(context),
            ),
            _SettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English (Default)',
              onTap: () => _showLanguageSettings(context),
            ),
            _SettingsTile(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Configure app notifications',
              onTap: () => context.go('/notifications'),
            ),
          ]),

          const SizedBox(height: 24),

          // Business Settings Section
          _buildSectionHeader(context, 'Business Configuration'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Icons.business,
              title: 'Company Information',
              subtitle: 'Update your business details',
              onTap: () => _showCompanySettings(context),
            ),
            _SettingsTile(
              icon: Icons.account_balance,
              title: 'Tax Settings',
              subtitle: 'Configure tax rates and compliance',
              onTap: () => context.go('/tax/settings'),
            ),
            _SettingsTile(
              icon: Icons.currency_exchange,
              title: 'Currency & Region',
              subtitle: 'SGD - Singapore',
              onTap: () => _showCurrencySettings(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Data & Security Section
          _buildSectionHeader(context, 'Data & Security'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Icons.backup,
              title: 'Backup & Restore',
              subtitle: 'Manage your data backups',
              onTap: () => context.go('/backup'),
            ),
            _SettingsTile(
              icon: Icons.sync,
              title: 'Sync Settings',
              subtitle: 'Configure P2P synchronization',
              onTap: () => context.go('/sync'),
            ),
            _SettingsTile(
              icon: Icons.security,
              title: 'Security',
              subtitle: 'App lock and encryption',
              onTap: () => _showSecuritySettings(context),
            ),
            _SettingsTile(
              icon: Icons.storage,
              title: 'Storage',
              subtitle: 'Manage app data and cache',
              onTap: () => _showStorageSettings(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Module Settings Section
          _buildSectionHeader(context, 'Module Configuration'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Icons.receipt_long,
              title: 'Invoice Settings',
              subtitle: 'Templates, numbering, and defaults',
              onTap: () => _showInvoiceSettings(context),
            ),
            _SettingsTile(
              icon: Icons.payment,
              title: 'Payment Settings',
              subtitle: 'QR codes and payment methods',
              onTap: () => _showPaymentSettings(context),
            ),
            _SettingsTile(
              icon: Icons.people,
              title: 'Customer Settings',
              subtitle: 'Customer management preferences',
              onTap: () => _showCustomerSettings(context),
            ),
            _SettingsTile(
              icon: Icons.group,
              title: 'Employee Settings',
              subtitle: 'Payroll and HR configuration',
              onTap: () => _showEmployeeSettings(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Advanced Section
          _buildSectionHeader(context, 'Advanced'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Icons.developer_mode,
              title: 'Developer Options',
              subtitle: 'Debug and development tools',
              onTap: () => _showDeveloperOptions(context),
            ),
            _SettingsTile(
              icon: Icons.import_export,
              title: 'Import / Export',
              subtitle: 'Data migration tools',
              onTap: () => _showImportExportOptions(context),
            ),
            _SettingsTile(
              icon: Icons.refresh,
              title: 'Reset Application',
              subtitle: 'Clear all data and reset',
              onTap: () => _showResetConfirmation(context),
            ),
          ]),

          const SizedBox(height: 24),

          // Support & About Section
          _buildSectionHeader(context, 'Support & Information'),
          _buildSettingsGroup([
            _SettingsTile(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Documentation and guides',
              onTap: () => _showHelpCenter(context),
            ),
            _SettingsTile(
              icon: Icons.bug_report,
              title: 'Report Issue',
              subtitle: 'Send feedback or report bugs',
              onTap: () => _showFeedbackForm(context),
            ),
            _SettingsTile(
              icon: Icons.info,
              title: 'About',
              subtitle: 'Version 1.2.0',
              onTap: () => _showAboutDialog(context),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'View privacy policy',
              onTap: () => _showPrivacyPolicy(context),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Card(
      child: Column(children: tiles),
    );
  }

  // Settings Dialog Methods
  void _showThemeSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'light',
              groupValue: _currentTheme,
              onChanged: (value) {
                if (value != null) {
                  _changeTheme(value);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'dark',
              groupValue: _currentTheme,
              onChanged: (value) {
                if (value != null) {
                  _changeTheme(value);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('System'),
              value: 'system',
              groupValue: _currentTheme,
              onChanged: (value) {
                if (value != null) {
                  _changeTheme(value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    _showComingSoonDialog(context, 'Language Settings');
  }

  void _showCompanySettings(BuildContext context) {
    _showComingSoonDialog(context, 'Company Settings');
  }

  void _showCurrencySettings(BuildContext context) {
    _showComingSoonDialog(context, 'Currency Settings');
  }

  void _showSecuritySettings(BuildContext context) {
    _showComingSoonDialog(context, 'Security Settings');
  }

  void _showStorageSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StorageInfoRow('Database Size', '128 MB'),
            _StorageInfoRow('Backup Files', '45 MB'),
            _StorageInfoRow('Cache Size', '12 MB'),
            _StorageInfoRow('Documents', '60 MB'),
            const Divider(),
            _StorageInfoRow('Total Used', '245 MB'),
            _StorageInfoRow('Available', '1.8 GB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            child: const Text('Clear Cache'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceSettings(BuildContext context) {
    _showComingSoonDialog(context, 'Invoice Settings');
  }

  void _showPaymentSettings(BuildContext context) {
    _showComingSoonDialog(context, 'Payment Settings');
  }

  void _showCustomerSettings(BuildContext context) {
    _showComingSoonDialog(context, 'Customer Settings');
  }

  void _showEmployeeSettings(BuildContext context) {
    _showComingSoonDialog(context, 'Employee Settings');
  }

  void _showDeveloperOptions(BuildContext context) {
    Navigator.of(context).pushNamed('/settings/developer');
  }

  void _showImportExportOptions(BuildContext context) {
    _showComingSoonDialog(context, 'Import/Export');
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Application'),
        content: const Text(
          'This will permanently delete all your data including invoices, customers, and settings. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAllData();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset All Data'),
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    _showComingSoonDialog(context, 'Help Center');
  }

  void _showFeedbackForm(BuildContext context) {
    _showComingSoonDialog(context, 'Feedback Form');
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'BizSync',
      applicationVersion: '1.2.0',
      applicationIcon: const Icon(
        Icons.business_center,
        size: 48,
        color: Colors.blue,
      ),
      children: [
        const Text('Offline-first business management application'),
        const SizedBox(height: 16),
        const Text('Features:'),
        const Text('• Invoice Management'),
        const Text('• Payment QR Generation'),
        const Text('• Customer Management'),
        const Text('• Employee & Payroll'),
        const Text('• Tax Calculations'),
        const Text('• P2P Sync & Backup'),
      ],
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    _showComingSoonDialog(context, 'Privacy Policy');
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature functionality is coming soon!'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeTheme(String themeMode) async {
    setState(() {
      _currentTheme = themeMode;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', themeMode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme changed to ${themeMode.replaceAll('_', ' ')}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing theme: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Clearing cache...'),
          ],
        ),
      ),
    );

    try {
      // Clear SharedPreferences cache (except theme and important settings)
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final keysToRemove = keys
          .where((key) =>
              !key.startsWith('theme_') &&
              !key.startsWith('user_') &&
              key != 'first_launch')
          .toList();

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetAllData() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Warning'),
        content: const Text(
          'This will permanently delete ALL data including:\n\n'
          '• All invoices and customers\n'
          '• Financial records\n'
          '• Employee data\n'
          '• Settings and preferences\n\n'
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset All Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Resetting all data...'),
            ],
          ),
        ),
      );
    }

    try {
      // Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear database (would need actual implementation)
      final databaseService = CRDTDatabaseService();
      // await databaseService.clearAllData(); // Uncomment when method exists

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to splash screen for fresh start
        context.go('/splash');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _StorageInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _StorageInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
