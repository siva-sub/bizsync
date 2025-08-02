import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/material.dart' as material show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_settings.dart';
import '../models/notification_types.dart';
import '../providers/notification_providers.dart';

/// Notification settings screen
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationSettingsScreen> createState() => 
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState 
    extends ConsumerState<NotificationSettingsScreen> {
  
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _showResetDialog(context),
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Global settings
          _buildGlobalSettings(settings),
          
          const Divider(),
          
          // Category settings
          _buildCategorySettings(settings),
          
          const Divider(),
          
          // Do Not Disturb settings
          _buildDoNotDisturbSettings(settings),
          
          const Divider(),
          
          // Batching settings
          _buildBatchingSettings(settings),
          
          const Divider(),
          
          // Intelligent settings
          _buildIntelligentSettings(settings),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGlobalSettings(NotificationSettings settings) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Master switch for all notifications'),
              value: settings.globalEnabled,
              onChanged: (value) {
                ref.read(notificationSettingsProvider.notifier)
                    .updateGlobalEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySettings(NotificationSettings settings) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Configure notification settings for each category',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            ...NotificationCategory.values.map((category) {
              final categorySettings = settings.categorySettings[category] ??
                  CategorySettings.defaultForCategory(category);
              
              return ExpansionTile(
                leading: Icon(_getCategoryIcon(category)),
                title: Text(category.displayName),
                subtitle: Text(
                  categorySettings.enabled 
                      ? 'Enabled • ${categorySettings.minimumPriority.name}'
                      : 'Disabled',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enabled'),
                          value: categorySettings.enabled,
                          onChanged: (value) => _updateCategorySettings(
                            category,
                            categorySettings.copyWith(enabled: value),
                          ),
                        ),
                        
                        if (categorySettings.enabled) ...[
                          ListTile(
                            title: const Text('Minimum Priority'),
                            subtitle: DropdownButton<NotificationPriority>(
                              value: categorySettings.minimumPriority,
                              isExpanded: true,
                              items: NotificationPriority.values.map((priority) =>
                                DropdownMenuItem(
                                  value: priority,
                                  child: Text(priority.name.toUpperCase()),
                                ),
                              ).toList(),
                              onChanged: (priority) {
                                if (priority != null) {
                                  _updateCategorySettings(
                                    category,
                                    categorySettings.copyWith(minimumPriority: priority),
                                  );
                                }
                              },
                            ),
                          ),
                          
                          SwitchListTile(
                            title: const Text('Sound'),
                            value: categorySettings.soundEnabled,
                            onChanged: (value) => _updateCategorySettings(
                              category,
                              categorySettings.copyWith(soundEnabled: value),
                            ),
                          ),
                          
                          SwitchListTile(
                            title: const Text('Vibration'),
                            value: categorySettings.vibrationEnabled,
                            onChanged: (value) => _updateCategorySettings(
                              category,
                              categorySettings.copyWith(vibrationEnabled: value),
                            ),
                          ),
                          
                          SwitchListTile(
                            title: const Text('Show Preview'),
                            subtitle: const Text('Show notification content'),
                            value: categorySettings.showPreview,
                            onChanged: (value) => _updateCategorySettings(
                              category,
                              categorySettings.copyWith(showPreview: value),
                            ),
                          ),
                          
                          ListTile(
                            title: const Text('Max per Hour'),
                            subtitle: Slider(
                              value: categorySettings.maxPerHour.toDouble(),
                              min: 1,
                              max: 50,
                              divisions: 49,
                              label: categorySettings.maxPerHour.toString(),
                              onChanged: (value) => _updateCategorySettings(
                                category,
                                categorySettings.copyWith(maxPerHour: value.round()),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoNotDisturbSettings(NotificationSettings settings) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do Not Disturb',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Quiet hours when notifications are limited',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Do Not Disturb'),
              value: settings.doNotDisturb.enabled,
              onChanged: (value) => _updateDoNotDisturbSettings(
                settings.doNotDisturb.copyWith(enabled: value),
              ),
            ),
            
            if (settings.doNotDisturb.enabled) ...[
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(settings.doNotDisturb.startTime.format12Hour()),
                onTap: () => _selectTime(
                  context,
                  settings.doNotDisturb.startTime,
                  (time) => _updateDoNotDisturbSettings(
                    settings.doNotDisturb.copyWith(startTime: time),
                  ),
                ),
              ),
              
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(settings.doNotDisturb.endTime.format12Hour()),
                onTap: () => _selectTime(
                  context,
                  settings.doNotDisturb.endTime,
                  (time) => _updateDoNotDisturbSettings(
                    settings.doNotDisturb.copyWith(endTime: time),
                  ),
                ),
              ),
              
              ExpansionTile(
                title: const Text('Days of Week'),
                subtitle: Text('${settings.doNotDisturb.daysOfWeek.length} days selected'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: _buildDayOfWeekCheckboxes(settings.doNotDisturb),
                    ),
                  ),
                ],
              ),
              
              ExpansionTile(
                title: const Text('Allowed Priorities'),
                subtitle: Text('${settings.doNotDisturb.allowedPriorities.length} priorities'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: NotificationPriority.values.map((priority) =>
                        CheckboxListTile(
                          title: Text(priority.name.toUpperCase()),
                          value: settings.doNotDisturb.allowedPriorities.contains(priority),
                          onChanged: (value) {
                            final priorities = List<NotificationPriority>.from(
                              settings.doNotDisturb.allowedPriorities,
                            );
                            if (value == true) {
                              priorities.add(priority);
                            } else {
                              priorities.remove(priority);
                            }
                            _updateDoNotDisturbSettings(
                              settings.doNotDisturb.copyWith(allowedPriorities: priorities),
                            );
                          },
                        ),
                      ).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayOfWeekCheckboxes(DoNotDisturbSettings dndSettings) {
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 
      'Friday', 'Saturday', 'Sunday'
    ];
    
    return List.generate(7, (index) {
      final dayNumber = index + 1;
      return CheckboxListTile(
        title: Text(days[index]),
        value: dndSettings.daysOfWeek.contains(dayNumber),
        onChanged: (value) {
          final selectedDays = List<int>.from(dndSettings.daysOfWeek);
          if (value == true) {
            selectedDays.add(dayNumber);
          } else {
            selectedDays.remove(dayNumber);
          }
          _updateDoNotDisturbSettings(
            dndSettings.copyWith(daysOfWeek: selectedDays),
          );
        },
      );
    });
  }

  Widget _buildBatchingSettings(NotificationSettings settings) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Batching',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Group similar notifications together',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Batching'),
              value: settings.batching.enabled,
              onChanged: (value) => _updateBatchingSettings(
                settings.batching.copyWith(enabled: value),
              ),
            ),
            
            if (settings.batching.enabled) ...[
              ListTile(
                title: const Text('Batch Window'),
                subtitle: Text('${settings.batching.batchWindow.inMinutes} minutes'),
                trailing: Slider(
                  value: settings.batching.batchWindow.inMinutes.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: '${settings.batching.batchWindow.inMinutes} min',
                  onChanged: (value) => _updateBatchingSettings(
                    settings.batching.copyWith(
                      batchWindow: Duration(minutes: value.round()),
                    ),
                  ),
                ),
              ),
              
              ListTile(
                title: const Text('Max Batch Size'),
                subtitle: Text('${settings.batching.maxBatchSize} notifications'),
                trailing: Slider(
                  value: settings.batching.maxBatchSize.toDouble(),
                  min: 2,
                  max: 20,
                  divisions: 18,
                  label: settings.batching.maxBatchSize.toString(),
                  onChanged: (value) => _updateBatchingSettings(
                    settings.batching.copyWith(maxBatchSize: value.round()),
                  ),
                ),
              ),
              
              SwitchListTile(
                title: const Text('Intelligent Batching'),
                subtitle: const Text('Use AI to determine optimal batching'),
                value: settings.batching.intelligentBatching,
                onChanged: (value) => _updateBatchingSettings(
                  settings.batching.copyWith(intelligentBatching: value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntelligentSettings(NotificationSettings settings) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intelligent Notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Smart timing and personalization features',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Intelligent Features'),
              value: settings.intelligent.enabled,
              onChanged: (value) => _updateIntelligentSettings(
                settings.intelligent.copyWith(enabled: value),
              ),
            ),
            
            if (settings.intelligent.enabled) ...[
              SwitchListTile(
                title: const Text('Adapt to User Behavior'),
                subtitle: const Text('Learn from your interaction patterns'),
                value: settings.intelligent.adaptToUserBehavior,
                onChanged: (value) => _updateIntelligentSettings(
                  settings.intelligent.copyWith(adaptToUserBehavior: value),
                ),
              ),
              
              SwitchListTile(
                title: const Text('Consider App Usage'),
                subtitle: const Text('Delay notifications when app is inactive'),
                value: settings.intelligent.considerAppUsage,
                onChanged: (value) => _updateIntelligentSettings(
                  settings.intelligent.copyWith(considerAppUsage: value),
                ),
              ),
              
              SwitchListTile(
                title: const Text('Respect Business Hours'),
                value: settings.intelligent.respectBusinessHours,
                onChanged: (value) => _updateIntelligentSettings(
                  settings.intelligent.copyWith(respectBusinessHours: value),
                ),
              ),
              
              if (settings.intelligent.respectBusinessHours) ...[
                ListTile(
                  title: const Text('Business Hours Start'),
                  subtitle: Text(settings.intelligent.businessHoursStart.format12Hour()),
                  onTap: () => _selectTime(
                    context,
                    settings.intelligent.businessHoursStart,
                    (time) => _updateIntelligentSettings(
                      settings.intelligent.copyWith(businessHoursStart: time),
                    ),
                  ),
                ),
                
                ListTile(
                  title: const Text('Business Hours End'),
                  subtitle: Text(settings.intelligent.businessHoursEnd.format12Hour()),
                  onTap: () => _selectTime(
                    context,
                    settings.intelligent.businessHoursEnd,
                    (time) => _updateIntelligentSettings(
                      settings.intelligent.copyWith(businessHoursEnd: time),
                    ),
                  ),
                ),
                
                SwitchListTile(
                  title: const Text('Weekends are Business Days'),
                  value: settings.intelligent.weekendsAreBusinessDays,
                  onChanged: (value) => _updateIntelligentSettings(
                    settings.intelligent.copyWith(weekendsAreBusinessDays: value),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _updateCategorySettings(
    NotificationCategory category,
    CategorySettings newSettings,
  ) {
    ref.read(notificationSettingsProvider.notifier)
        .updateCategorySettings(category, newSettings);
  }

  void _updateDoNotDisturbSettings(DoNotDisturbSettings newSettings) {
    ref.read(notificationSettingsProvider.notifier)
        .updateDoNotDisturbSettings(newSettings);
  }

  void _updateBatchingSettings(BatchingSettings newSettings) {
    ref.read(notificationSettingsProvider.notifier)
        .updateBatchingSettings(newSettings);
  }

  void _updateIntelligentSettings(IntelligentSettings newSettings) {
    ref.read(notificationSettingsProvider.notifier)
        .updateIntelligentSettings(newSettings);
  }

  Future<void> _selectTime(
    BuildContext context,
    NotificationTimeOfDay currentTime,
    Function(NotificationTimeOfDay) onTimeSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: material.TimeOfDay(
        hour: currentTime.hour,
        minute: currentTime.minute,
      ),
    );
    
    if (time != null) {
      onTimeSelected(NotificationTimeOfDay(hour: time.hour, minute: time.minute));
    }
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all notification settings to their default values? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final defaultSettings = NotificationSettings.defaultSettings();
              ref.read(notificationSettingsProvider.notifier)
                  .updateSettings(defaultSettings);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.invoice:
        return Icons.receipt;
      case NotificationCategory.payment:
        return Icons.payment;
      case NotificationCategory.tax:
        return Icons.account_balance;
      case NotificationCategory.backup:
        return Icons.backup;
      case NotificationCategory.insight:
        return Icons.analytics;
      case NotificationCategory.reminder:
        return Icons.schedule;
      case NotificationCategory.system:
        return Icons.settings;
      case NotificationCategory.custom:
        return Icons.notifications;
    }
  }
}

/// Extension to convert NotificationTimeOfDay to material TimeOfDay
extension NotificationTimeOfDayExtension on NotificationTimeOfDay {
  material.TimeOfDay toMaterialTimeOfDay() {
    return material.TimeOfDay(hour: hour, minute: minute);
  }
}

/// Extension to add copyWith to CategorySettings
extension CategorySettingsExtension on CategorySettings {
  CategorySettings copyWith({
    bool? enabled,
    NotificationPriority? minimumPriority,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? showPreview,
    int? maxPerHour,
    List<String>? keywords,
    bool? smartTiming,
  }) {
    return CategorySettings(
      enabled: enabled ?? this.enabled,
      minimumPriority: minimumPriority ?? this.minimumPriority,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      showPreview: showPreview ?? this.showPreview,
      maxPerHour: maxPerHour ?? this.maxPerHour,
      keywords: keywords ?? this.keywords,
      smartTiming: smartTiming ?? this.smartTiming,
    );
  }
}

/// Extension to add copyWith to DoNotDisturbSettings
extension DoNotDisturbSettingsExtension on DoNotDisturbSettings {
  DoNotDisturbSettings copyWith({
    bool? enabled,
    NotificationTimeOfDay? startTime,
    NotificationTimeOfDay? endTime,
    List<int>? daysOfWeek,
    List<NotificationPriority>? allowedPriorities,
    List<NotificationCategory>? allowedCategories,
    bool? allowRepeatedCalls,
    Duration? repeatedCallWindow,
  }) {
    return DoNotDisturbSettings(
      enabled: enabled ?? this.enabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      allowedPriorities: allowedPriorities ?? this.allowedPriorities,
      allowedCategories: allowedCategories ?? this.allowedCategories,
      allowRepeatedCalls: allowRepeatedCalls ?? this.allowRepeatedCalls,
      repeatedCallWindow: repeatedCallWindow ?? this.repeatedCallWindow,
    );
  }
}

/// Extension to add copyWith to BatchingSettings
extension BatchingSettingsExtension on BatchingSettings {
  BatchingSettings copyWith({
    bool? enabled,
    Duration? batchWindow,
    int? maxBatchSize,
    Map<NotificationCategory, int>? categoryThresholds,
    bool? intelligentBatching,
    List<NotificationCategory>? neverBatchCategories,
  }) {
    return BatchingSettings(
      enabled: enabled ?? this.enabled,
      batchWindow: batchWindow ?? this.batchWindow,
      maxBatchSize: maxBatchSize ?? this.maxBatchSize,
      categoryThresholds: categoryThresholds ?? this.categoryThresholds,
      intelligentBatching: intelligentBatching ?? this.intelligentBatching,
      neverBatchCategories: neverBatchCategories ?? this.neverBatchCategories,
    );
  }
}

/// Extension to add copyWith to IntelligentSettings
extension IntelligentSettingsExtension on IntelligentSettings {
  IntelligentSettings copyWith({
    bool? enabled,
    bool? adaptToUserBehavior,
    bool? considerAppUsage,
    bool? respectBusinessHours,
    NotificationTimeOfDay? businessHoursStart,
    NotificationTimeOfDay? businessHoursEnd,
    bool? weekendsAreBusinessDays,
    Duration? optimalDelay,
    bool? learnFromDismissals,
    double? engagementThreshold,
  }) {
    return IntelligentSettings(
      enabled: enabled ?? this.enabled,
      adaptToUserBehavior: adaptToUserBehavior ?? this.adaptToUserBehavior,
      considerAppUsage: considerAppUsage ?? this.considerAppUsage,
      respectBusinessHours: respectBusinessHours ?? this.respectBusinessHours,
      businessHoursStart: businessHoursStart ?? this.businessHoursStart,
      businessHoursEnd: businessHoursEnd ?? this.businessHoursEnd,
      weekendsAreBusinessDays: weekendsAreBusinessDays ?? this.weekendsAreBusinessDays,
      optimalDelay: optimalDelay ?? this.optimalDelay,
      learnFromDismissals: learnFromDismissals ?? this.learnFromDismissals,
      engagementThreshold: engagementThreshold ?? this.engagementThreshold,
    );
  }
}