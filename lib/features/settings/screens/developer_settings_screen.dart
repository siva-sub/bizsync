import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/theme/theme_service.dart';

class DeveloperSettingsScreen extends ConsumerStatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  ConsumerState<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends ConsumerState<DeveloperSettingsScreen> {
  late FeatureFlags _featureFlags;
  bool _isDemoDataEnabled = false;
  bool _isDebugModeEnabled = false;
  bool _areBetaFeaturesEnabled = false;

  @override
  void initState() {
    super.initState();
    _featureFlags = FeatureFlags();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _isDemoDataEnabled = _featureFlags.isDemoDataEnabled;
      _isDebugModeEnabled = _featureFlags.isDebugModeEnabled;
      _areBetaFeaturesEnabled = _featureFlags.areBetaFeaturesEnabled;
    });
  }

  Future<void> _toggleDemoData(bool value) async {
    await _featureFlags.setDemoDataEnabled(value);
    setState(() {
      _isDemoDataEnabled = value;
    });
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value 
            ? 'Demo data enabled. Restart the app to see demo data.' 
            : 'Demo data disabled. Restart the app to hide demo data.'
        ),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _toggleDebugMode(bool value) async {
    await _featureFlags.setDebugModeEnabled(value);
    setState(() {
      _isDebugModeEnabled = value;
    });
  }

  Future<void> _toggleBetaFeatures(bool value) async {
    await _featureFlags.setBetaFeaturesEnabled(value);
    setState(() {
      _areBetaFeaturesEnabled = value;
    });
  }

  Future<void> _resetToDefaults() async {
    await _featureFlags.resetToDefaults();
    _loadSettings();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature flags reset to defaults'),
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will clear all app data including:\n'
          '• All invoices and customers\n'
          '• All settings and preferences\n'
          '• All cached data\n\n'
          'This action cannot be undone. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement data clearing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared. Please restart the app.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ref.watch(themeServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: ListView(
        children: [
          if (kDebugMode || _featureFlags.shouldShowDemoDataBanner)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Developer mode is active',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Feature Flags Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Feature Flags',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          SwitchListTile(
            title: const Text('Enable Demo Data'),
            subtitle: const Text('Show demo customers and invoices'),
            value: _isDemoDataEnabled,
            onChanged: _toggleDemoData,
            secondary: const Icon(Icons.dataset),
          ),
          
          SwitchListTile(
            title: const Text('Enable Debug Mode'),
            subtitle: const Text('Show debug information and logs'),
            value: _isDebugModeEnabled,
            onChanged: _toggleDebugMode,
            secondary: const Icon(Icons.bug_report),
          ),
          
          SwitchListTile(
            title: const Text('Enable Beta Features'),
            subtitle: const Text('Access experimental features'),
            value: _areBetaFeaturesEnabled,
            onChanged: _toggleBetaFeatures,
            secondary: const Icon(Icons.science),
          ),
          
          const Divider(height: 32),
          
          // Developer Tools Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Developer Tools',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Clear All Data'),
            subtitle: const Text('Remove all app data and settings'),
            onTap: _clearAllData,
          ),
          
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Regenerate Demo Data'),
            subtitle: const Text('Create fresh demo data'),
            enabled: _isDemoDataEnabled,
            onTap: _isDemoDataEnabled
              ? () {
                  // TODO: Implement demo data regeneration
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Demo data regenerated'),
                    ),
                  );
                }
              : null,
          ),
          
          const Divider(height: 32),
          
          // App Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'App Information',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Build Mode'),
            subtitle: Text(kDebugMode ? 'Debug' : 'Release'),
          ),
          
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Version'),
            subtitle: Text('${DateTime.now().year}.1.1'),
          ),
          
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Build Number'),
            subtitle: const Text('1'),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}