import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_service.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/offline/offline_service.dart';
import '../../../core/feedback/haptic_service.dart';
import '../../../core/notifications/enhanced_push_notification_service.dart';
import '../../../core/performance/performance_optimizer.dart';

class MobileFeaturesSettingsScreen extends ConsumerStatefulWidget {
  const MobileFeaturesSettingsScreen({super.key});

  @override
  ConsumerState<MobileFeaturesSettingsScreen> createState() =>
      _MobileFeaturesSettingsScreenState();
}

class _MobileFeaturesSettingsScreenState
    extends ConsumerState<MobileFeaturesSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Features'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.palette), text: 'Theme'),
            Tab(icon: Icon(Icons.fingerprint), text: 'Security'),
            Tab(icon: Icon(Icons.cloud_off), text: 'Offline'),
            Tab(icon: Icon(Icons.vibration), text: 'Haptic'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            Tab(icon: Icon(Icons.speed), text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ThemeSettingsTab(),
          _BiometricSettingsTab(),
          _OfflineSettingsTab(),
          _HapticSettingsTab(),
          _NotificationSettingsTab(),
          _PerformanceSettingsTab(),
        ],
      ),
    );
  }
}

// Theme Settings Tab
class _ThemeSettingsTab extends ConsumerWidget {
  const _ThemeSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreferences = ref.watch(themePreferencesProvider);
    final themeNotifier = ref.read(themePreferencesProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Appearance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                RadioListTile<AppThemeMode>(
                  title: const Text('Light'),
                  subtitle: const Text('Always use light theme'),
                  value: AppThemeMode.light,
                  groupValue: themePreferences.mode,
                  onChanged: (value) {
                    if (value != null) {
                      themeNotifier.updateThemeMode(value);
                    }
                  },
                ),
                RadioListTile<AppThemeMode>(
                  title: const Text('Dark'),
                  subtitle: const Text('Always use dark theme'),
                  value: AppThemeMode.dark,
                  groupValue: themePreferences.mode,
                  onChanged: (value) {
                    if (value != null) {
                      themeNotifier.updateThemeMode(value);
                    }
                  },
                ),
                RadioListTile<AppThemeMode>(
                  title: const Text('System'),
                  subtitle: const Text('Follow system theme'),
                  value: AppThemeMode.system,
                  groupValue: themePreferences.mode,
                  onChanged: (value) {
                    if (value != null) {
                      themeNotifier.updateThemeMode(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customization',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Use System Accent Color'),
                  subtitle: const Text('Follow system color scheme'),
                  value: themePreferences.useSystemAccentColor,
                  onChanged: (value) {
                    themeNotifier.updateSystemAccentColor(value);
                  },
                ),
                if (themePreferences.customPrimaryColor != null)
                  ListTile(
                    title: const Text('Custom Primary Color'),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themePreferences.customPrimaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    onTap: () {
                      _showColorPicker(context, themeNotifier);
                    },
                  ),
                if (themePreferences.customPrimaryColor == null)
                  ListTile(
                    title: const Text('Set Custom Color'),
                    leading: const Icon(Icons.color_lens),
                    onTap: () {
                      _showColorPicker(context, themeNotifier);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context, ThemeNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Colors.blue,
              Colors.red,
              Colors.green,
              Colors.purple,
              Colors.orange,
              Colors.teal,
              Colors.indigo,
              Colors.pink,
            ]
                .map((color) => GestureDetector(
                      onTap: () {
                        notifier.updateCustomPrimaryColor(color);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.updateCustomPrimaryColor(null);
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// Biometric Settings Tab
class _BiometricSettingsTab extends ConsumerWidget {
  const _BiometricSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricConfig = ref.watch(biometricConfigProvider);
    final biometricNotifier = ref.read(biometricConfigProvider.notifier);
    final biometricsService = ref.watch(biometricAuthServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Biometric Authentication',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (biometricsService.capabilities?.isDeviceSupported == true) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fingerprint,
                          color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '${biometricsService.capabilities?.primaryBiometricName} Available',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Biometric Authentication'),
                    subtitle: const Text('Use biometrics to secure app access'),
                    value: biometricConfig.enabled,
                    onChanged: (value) async {
                      if (value) {
                        await biometricNotifier.enableBiometricAuth();
                      } else {
                        await biometricNotifier.disableBiometricAuth();
                      }
                    },
                  ),
                  if (biometricConfig.enabled) ...[
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Require for Sensitive Data'),
                      subtitle: const Text(
                          'Require biometrics for financial data access'),
                      value: biometricConfig.requireForSensitiveData,
                      onChanged: (value) {
                        biometricNotifier.updateConfig(
                          biometricConfig.copyWith(
                              requireForSensitiveData: value),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Require at App Launch'),
                      subtitle:
                          const Text('Require biometrics when opening the app'),
                      value: biometricConfig.requireForAppLaunch,
                      onChanged: (value) {
                        biometricNotifier.updateConfig(
                          biometricConfig.copyWith(requireForAppLaunch: value),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Biometric Authentication Not Available',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your device does not support biometric authentication or it has not been set up.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Offline Settings Tab
class _OfflineSettingsTab extends ConsumerWidget {
  const _OfflineSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineService = ref.watch(offlineServiceProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final syncStats = ref.watch(syncStatsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Offline & Sync',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connectionStatus == ConnectionStatus.online
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: connectionStatus == ConnectionStatus.online
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connectionStatus == ConnectionStatus.online
                          ? 'Online'
                          : 'Offline',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Pending Operations'),
                  subtitle: Text(
                      '${syncStats.pendingOperations} operations waiting to sync'),
                  trailing: Text('${syncStats.pendingOperations}'),
                ),
                ListTile(
                  title: const Text('Completed Operations'),
                  subtitle: const Text('Successfully synced operations'),
                  trailing: Text('${syncStats.completedOperations}'),
                ),
                ListTile(
                  title: const Text('Failed Operations'),
                  subtitle: const Text('Operations that failed to sync'),
                  trailing: Text('${syncStats.failedOperations}'),
                ),
                if (syncStats.lastSyncTime != null)
                  ListTile(
                    title: const Text('Last Sync'),
                    subtitle: Text(_formatDateTime(syncStats.lastSyncTime!)),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connectionStatus == ConnectionStatus.online
                            ? () => offlineService.forcSync()
                            : null,
                        icon: const Icon(Icons.sync),
                        label: const Text('Force Sync'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            offlineService.clearPendingOperations(),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Queue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

// Haptic Settings Tab
class _HapticSettingsTab extends ConsumerWidget {
  const _HapticSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticConfig = ref.watch(hapticConfigProvider);
    final hapticNotifier = ref.read(hapticConfigProvider.notifier);
    final hapticService = ref.watch(hapticServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Haptic Feedback',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Enable Haptic Feedback'),
                  subtitle: Text(hapticService.hasVibration
                      ? 'Device supports vibration'
                      : 'Device does not support vibration'),
                  value: hapticConfig.enabled,
                  onChanged: hapticService.hasVibration
                      ? (value) => hapticNotifier.toggleEnabled()
                      : null,
                ),
                if (hapticConfig.enabled) ...[
                  const Divider(),
                  const Text(
                    'Feedback Types',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Button Interactions'),
                    subtitle: const Text('Vibrate when tapping buttons'),
                    value: hapticConfig.enableForButtons,
                    onChanged: (value) => hapticNotifier.toggleButtons(),
                  ),
                  SwitchListTile(
                    title: const Text('Gesture Actions'),
                    subtitle:
                        const Text('Vibrate for swipe and gesture actions'),
                    value: hapticConfig.enableForGestures,
                    onChanged: (value) => hapticNotifier.toggleGestures(),
                  ),
                  SwitchListTile(
                    title: const Text('Notifications'),
                    subtitle: const Text('Vibrate for app notifications'),
                    value: hapticConfig.enableForNotifications,
                    onChanged: (value) => hapticNotifier.toggleNotifications(),
                  ),
                  SwitchListTile(
                    title: const Text('Error Alerts'),
                    subtitle: const Text('Vibrate for error messages'),
                    value: hapticConfig.enableForErrors,
                    onChanged: (value) => hapticNotifier.toggleErrors(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Intensity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: hapticConfig.intensity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: '${(hapticConfig.intensity * 100).round()}%',
                    onChanged: (value) => hapticNotifier.setIntensity(value),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => hapticService.buttonPress(),
                      icon: const Icon(Icons.vibration),
                      label: const Text('Test Vibration'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Notification Settings Tab
class _NotificationSettingsTab extends ConsumerWidget {
  const _NotificationSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationSettings = ref.watch(notificationSettingsProvider);
    final notificationNotifier =
        ref.read(notificationSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Push Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle:
                      const Text('Receive push notifications from the app'),
                  value: notificationSettings.enabled,
                  onChanged: (value) {
                    notificationNotifier.updateSettings(
                      notificationSettings.copyWith(enabled: value),
                    );
                  },
                ),
                if (notificationSettings.enabled) ...[
                  const Divider(),
                  const Text(
                    'Business Notifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Payment Reminders'),
                    subtitle: const Text('Notify when payments are due'),
                    value: notificationSettings.enablePaymentReminders,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(
                            enablePaymentReminders: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Invoice Due Alerts'),
                    subtitle: const Text('Alert when invoices are overdue'),
                    value: notificationSettings.enableInvoiceDueAlerts,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(
                            enableInvoiceDueAlerts: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Inventory Alerts'),
                    subtitle: const Text('Notify when stock is low'),
                    value: notificationSettings.enableInventoryAlerts,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(
                            enableInventoryAlerts: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Tax Deadlines'),
                    subtitle: const Text('Remind about tax filing deadlines'),
                    value: notificationSettings.enableTaxDeadlines,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(
                            enableTaxDeadlines: value),
                      );
                    },
                  ),
                  const Divider(),
                  const Text(
                    'System Notifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Sync Notifications'),
                    subtitle: const Text('Notify about sync status'),
                    value: notificationSettings.enableSyncNotifications,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(
                            enableSyncNotifications: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Report Notifications'),
                    subtitle: const Text('Daily and weekly business reports'),
                    value: notificationSettings.enableReportNotifications,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(
                            enableReportNotifications: value),
                      );
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Quiet Hours'),
                    subtitle: Text(
                      notificationSettings.enableQuietHours
                          ? 'Enabled: ${_formatTime(notificationSettings.quietHoursStart)} - ${_formatTime(notificationSettings.quietHoursEnd)}'
                          : 'Disabled',
                    ),
                    value: notificationSettings.enableQuietHours,
                    onChanged: (value) {
                      notificationNotifier.updateSettings(
                        notificationSettings.copyWith(enableQuietHours: value),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// Performance Settings Tab
class _PerformanceSettingsTab extends ConsumerWidget {
  const _PerformanceSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceOptimizer = ref.watch(performanceOptimizerProvider);
    final metrics = ref.watch(performanceMetricsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Performance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (metrics != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        metrics.isPerformanceGood
                            ? Icons.check_circle
                            : Icons.warning,
                        color: metrics.isPerformanceGood
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Performance Status: ${metrics.isPerformanceGood ? "Good" : "Needs Attention"}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PerformanceMetricCard(
                          title: 'FPS',
                          value: metrics.averageFps.toStringAsFixed(1),
                          isGood: metrics.averageFps >= 55,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PerformanceMetricCard(
                          title: 'Dropped Frames',
                          value:
                              '${metrics.droppedFramePercentage.toStringAsFixed(1)}%',
                          isGood: metrics.droppedFramePercentage < 5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PerformanceMetricCard(
                          title: 'Frame Time',
                          value:
                              '${metrics.frameRenderTime.toStringAsFixed(1)}ms',
                          isGood: metrics.frameRenderTime < 16.67,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PerformanceMetricCard(
                          title: 'Total Frames',
                          value: '${metrics.frameCount}',
                          isGood: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimization Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Performance Monitoring'),
                  subtitle: const Text('Track app performance metrics'),
                  value: performanceOptimizer.enablePerformanceMonitoring,
                  onChanged: (value) {
                    performanceOptimizer.enablePerformanceMonitoring(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Image Caching'),
                  subtitle: const Text('Cache images for faster loading'),
                  value: performanceOptimizer.enableImageCaching,
                  onChanged: (value) {
                    performanceOptimizer.enableImageCaching(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Lazy Loading'),
                  subtitle: const Text('Load content as needed'),
                  value: performanceOptimizer.enableLazyLoading,
                  onChanged: (value) {
                    performanceOptimizer.enableLazyLoading(value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await performanceOptimizer.clearImageCache();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Image cache cleared'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Cache'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PerformanceMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isGood;

  const _PerformanceMetricCard({
    required this.title,
    required this.value,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGood
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGood
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isGood ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}
