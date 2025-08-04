import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/notification_models.dart';
import '../models/notification_types.dart';
import '../models/notification_template.dart';
import '../models/notification_settings.dart';
import '../utils/notification_utils.dart';
import 'notification_scheduler.dart';
import 'background_task_service.dart';

/// Enhanced notification service with comprehensive business features
class EnhancedNotificationService {
  static final EnhancedNotificationService _instance =
      EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final NotificationScheduler _scheduler = NotificationScheduler();
  final BackgroundTaskService _backgroundTaskService = BackgroundTaskService();
  final _uuid = const Uuid();

  bool _initialized = false;
  NotificationSettings? _settings;
  final Map<String, BizSyncNotification> _activeNotifications = {};
  final Map<String, NotificationBatch> _activeBatches = {};
  final List<NotificationMetrics> _metrics = [];

  // Notification ID counter for unique IDs
  int _notificationIdCounter = 1000;

  /// Stream controllers for real-time updates
  final StreamController<BizSyncNotification> _notificationStream =
      StreamController<BizSyncNotification>.broadcast();
  final StreamController<NotificationMetrics> _metricsStream =
      StreamController<NotificationMetrics>.broadcast();

  Stream<BizSyncNotification> get notificationStream =>
      _notificationStream.stream;
  Stream<NotificationMetrics> get metricsStream => _metricsStream.stream;

  /// Initialize the enhanced notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Create notification channels
      await _createNotificationChannels();

      // Load settings
      await _loadSettings();

      // Initialize scheduler
      await _scheduler.initialize();

      // Initialize background tasks
      await _backgroundTaskService.initialize();

      // Set up periodic maintenance
      await _setupPeriodicMaintenance();

      _initialized = true;

      // Schedule any pending notifications
      await _schedulePendingNotifications();
    } catch (e) {
      throw Exception('Failed to initialize enhanced notification service: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    if (notificationStatus != PermissionStatus.granted) {
      throw Exception('Notification permission denied');
    }

    // Request scheduling exact alarms for Android 12+
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Request system alert window for critical notifications
    if (await Permission.systemAlertWindow.isDenied) {
      await Permission.systemAlertWindow.request();
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open BizSync');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      linux: initializationSettingsLinux,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Create channels for each notification channel type
    for (final channel in NotificationChannel.values) {
      final config = _getChannelConfig(channel);

      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          channel.name,
          config.name,
          description: config.description,
          importance: _mapPriorityToImportance(config.defaultPriority),
          enableVibration: config.enableVibration,
          enableLights: config.enableLights,
          playSound: config.enableSound,
          sound: config.soundUri != null
              ? RawResourceAndroidNotificationSound(config.soundUri!)
              : null,
          ledColor:
              config.lightColor != null ? Color(config.lightColor!) : null,
          vibrationPattern: config.vibrationPattern != null
              ? Int64List.fromList(config.vibrationPattern!)
              : null,
          showBadge: config.showBadge,
        ),
      );
    }
  }

  NotificationChannelConfig _getChannelConfig(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.urgent:
        return const NotificationChannelConfig(
          channel: NotificationChannel.urgent,
          name: 'Urgent Notifications',
          description:
              'Critical business notifications requiring immediate attention',
          defaultPriority: NotificationPriority.critical,
          bypassDnd: true,
          lightColor: 0xFFFF0000,
        );

      case NotificationChannel.business:
        return const NotificationChannelConfig(
          channel: NotificationChannel.business,
          name: 'Business Notifications',
          description: 'Important business operations and updates',
          defaultPriority: NotificationPriority.high,
          lightColor: 0xFF0000FF,
        );

      case NotificationChannel.reminders:
        return const NotificationChannelConfig(
          channel: NotificationChannel.reminders,
          name: 'Reminders',
          description: 'Task and event reminders',
          defaultPriority: NotificationPriority.medium,
          lightColor: 0xFF00FF00,
        );

      case NotificationChannel.insights:
        return const NotificationChannelConfig(
          channel: NotificationChannel.insights,
          name: 'Business Insights',
          description: 'Analytics and business intelligence notifications',
          defaultPriority: NotificationPriority.low,
          enableSound: false,
          lightColor: 0xFFFFFF00,
        );

      case NotificationChannel.system:
        return const NotificationChannelConfig(
          channel: NotificationChannel.system,
          name: 'System Notifications',
          description: 'App system updates and maintenance notifications',
          defaultPriority: NotificationPriority.low,
          enableSound: false,
          enableVibration: false,
        );

      case NotificationChannel.marketing:
        return const NotificationChannelConfig(
          channel: NotificationChannel.marketing,
          name: 'Marketing',
          description: 'Promotional and marketing notifications',
          defaultPriority: NotificationPriority.info,
          enableSound: false,
        );
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('notification_settings');

    if (settingsJson != null) {
      try {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = NotificationSettings.fromJson(settingsMap);
      } catch (e) {
        // Use default settings if parsing fails
        _settings = NotificationSettings.defaultSettings();
      }
    } else {
      _settings = NotificationSettings.defaultSettings();
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    final prefs = await SharedPreferences.getInstance();
    final settingsJson = jsonEncode(_settings!.toJson());
    await prefs.setString('notification_settings', settingsJson);
  }

  /// Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    BusinessNotificationType? type,
    NotificationCategory? category,
    NotificationPriority? priority,
    NotificationChannel? channel,
    Map<String, dynamic>? payload,
    List<NotificationAction>? actions,
    String? imageUrl,
    String? bigText,
    NotificationStyle? style,
    bool? persistent,
    String? groupKey,
    int? progress,
    int? maxProgress,
    bool? indeterminate,
  }) async {
    if (!_initialized) await initialize();

    final notification = BizSyncNotification(
      id: _uuid.v4(),
      title: title,
      body: body,
      type: type ?? BusinessNotificationType.custom,
      category: category ?? NotificationCategory.custom,
      priority: priority ?? NotificationPriority.medium,
      channel: channel ?? NotificationChannel.business,
      createdAt: DateTime.now(),
      payload: payload,
      actions: actions,
      bigText: bigText,
      style: style ?? NotificationStyle.basic,
      persistent: persistent ?? false,
      groupKey: groupKey,
      progress: progress,
      maxProgress: maxProgress,
      indeterminate: indeterminate ?? false,
    );

    await _processNotification(notification);
  }

  /// Show notification from template
  Future<void> showNotificationFromTemplate({
    required String templateId,
    required Map<String, dynamic> variables,
    DateTime? scheduledFor,
    Map<String, dynamic>? additionalPayload,
  }) async {
    if (!_initialized) await initialize();

    final template = NotificationTemplates.findTemplate(templateId);
    if (template == null) {
      throw ArgumentError('Template not found: $templateId');
    }

    if (!template.validateVariables(variables)) {
      final missing = template.getMissingVariables(variables);
      throw ArgumentError('Missing required variables: ${missing.join(', ')}');
    }

    final notification = BizSyncNotification(
      id: _uuid.v4(),
      title: template.generateTitle(variables),
      body: template.generateBody(variables),
      type: template.type,
      category: template.category,
      priority: template.priority,
      channel: template.channel,
      createdAt: DateTime.now(),
      scheduledFor: scheduledFor,
      payload: {
        ...?template.defaultPayload,
        ...?additionalPayload,
        'templateId': templateId,
        'variables': variables,
      },
      actions: template.actions,
      bigText: template.generateBigText(variables),
      style: template.style,
      persistent: template.persistent,
      autoCancel: template.autoCancel,
    );

    if (scheduledFor != null) {
      await _scheduleNotification(notification);
    } else {
      await _processNotification(notification);
    }
  }

  /// Schedule notification for future delivery
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledFor,
    BusinessNotificationType? type,
    NotificationCategory? category,
    NotificationPriority? priority,
    NotificationChannel? channel,
    Map<String, dynamic>? payload,
    List<NotificationAction>? actions,
    NotificationRecurrenceRule? recurrenceRule,
  }) async {
    if (!_initialized) await initialize();

    final notification = BizSyncNotification(
      id: _uuid.v4(),
      title: title,
      body: body,
      type: type ?? BusinessNotificationType.custom,
      category: category ?? NotificationCategory.custom,
      priority: priority ?? NotificationPriority.medium,
      channel: channel ?? NotificationChannel.business,
      createdAt: DateTime.now(),
      scheduledFor: scheduledFor,
      payload: payload,
      actions: actions,
      status: NotificationStatus.scheduled,
    );

    await _scheduleNotification(notification, recurrenceRule: recurrenceRule);
  }

  Future<void> _processNotification(BizSyncNotification notification) async {
    // Check if notification should be shown based on settings
    if (!_shouldShowNotification(notification)) {
      return;
    }

    // Apply intelligent scheduling if enabled
    final optimalTime = _getOptimalDeliveryTime(notification);
    if (optimalTime != null && optimalTime.isAfter(DateTime.now())) {
      final delayedNotification = notification.copyWith(
        scheduledFor: optimalTime,
        status: NotificationStatus.scheduled,
      );
      await _scheduleNotification(delayedNotification);
      return;
    }

    // Check if notification should be batched
    if (_shouldBatchNotification(notification)) {
      await _addToBatch(notification);
      return;
    }

    // Show notification immediately
    await _displayNotification(notification);
  }

  bool _shouldShowNotification(BizSyncNotification notification) {
    if (_settings == null) return true;

    return _settings!.shouldShowNotification(
      notification.category,
      notification.priority,
      DateTime.now(),
    );
  }

  DateTime? _getOptimalDeliveryTime(BizSyncNotification notification) {
    if (_settings?.intelligent.enabled != true) return null;

    final now = DateTime.now();
    return _settings!.intelligent.getOptimalDeliveryTime(now);
  }

  bool _shouldBatchNotification(BizSyncNotification notification) {
    if (_settings?.batching.enabled != true) return false;

    final pendingCount = _activeNotifications.values
        .where((n) =>
            n.category == notification.category &&
            n.status == NotificationStatus.pending)
        .length;

    return _settings!.batching.shouldBatch(notification.category, pendingCount);
  }

  Future<void> _addToBatch(BizSyncNotification notification) async {
    final batchKey = '${notification.category.name}_batch';

    if (_activeBatches.containsKey(batchKey)) {
      // Add to existing batch
      final batch = _activeBatches[batchKey]!;
      final updatedBatch = NotificationBatch(
        id: batch.id,
        title: batch.title,
        summary:
            '${batch.notificationCount + 1} ${notification.category.displayName}',
        notificationIds: [...batch.notificationIds, notification.id],
        category: batch.category,
        createdAt: batch.createdAt,
        collapsed: batch.collapsed,
        maxNotifications: batch.maxNotifications,
      );
      _activeBatches[batchKey] = updatedBatch;
    } else {
      // Create new batch
      final batch = NotificationBatch(
        id: _uuid.v4(),
        title: notification.category.displayName,
        summary: '1 ${notification.category.displayName}',
        notificationIds: [notification.id],
        category: notification.category,
        createdAt: DateTime.now(),
      );
      _activeBatches[batchKey] = batch;
    }

    // Store notification for later display
    _activeNotifications[notification.id] = notification;

    // Schedule batch delivery
    await _scheduleBatchDelivery(batchKey);
  }

  Future<void> _scheduleBatchDelivery(String batchKey) async {
    final delay =
        _settings?.batching.batchWindow ?? const Duration(minutes: 15);

    Timer(delay, () async {
      await _deliverBatch(batchKey);
    });
  }

  Future<void> _deliverBatch(String batchKey) async {
    final batch = _activeBatches[batchKey];
    if (batch == null) return;

    // Create summary notification
    final summaryNotification = BizSyncNotification(
      id: batch.id,
      title: batch.title,
      body: batch.summary,
      type: BusinessNotificationType.custom,
      category: batch.category,
      priority: NotificationPriority.medium,
      channel: batch.category.defaultChannel,
      createdAt: batch.createdAt,
      style: NotificationStyle.inbox,
      groupKey: batchKey,
      payload: {
        'batchId': batch.id,
        'notificationIds': batch.notificationIds,
        'isBatch': true,
      },
    );

    await _displayNotification(summaryNotification);

    // Remove from active batches
    _activeBatches.remove(batchKey);
  }

  Future<void> _displayNotification(BizSyncNotification notification) async {
    final platformDetails = _buildPlatformDetails(notification);
    final notificationId = _getNextNotificationId();

    try {
      await _notifications.show(
        notificationId,
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode({
          'notificationId': notification.id,
          ...?notification.payload,
        }),
      );

      // Update notification status
      final updatedNotification = notification.copyWith(
        deliveredAt: DateTime.now(),
        status: NotificationStatus.delivered,
      );

      _activeNotifications[notification.id] = updatedNotification;
      _notificationStream.add(updatedNotification);

      // Record metrics
      final metrics = NotificationMetrics(
        notificationId: notification.id,
        deliveredAt: DateTime.now(),
      );
      _metrics.add(metrics);
      _metricsStream.add(metrics);
    } catch (e) {
      // Update notification status to failed
      final failedNotification = notification.copyWith(
        status: NotificationStatus.failed,
      );
      _activeNotifications[notification.id] = failedNotification;
      _notificationStream.add(failedNotification);
    }
  }

  NotificationDetails _buildPlatformDetails(BizSyncNotification notification) {
    final androidDetails = AndroidNotificationDetails(
      notification.channel.name,
      _getChannelConfig(notification.channel).name,
      channelDescription: _getChannelConfig(notification.channel).description,
      importance: _mapPriorityToImportance(notification.priority),
      priority: _mapPriorityToAndroidPriority(notification.priority),
      enableVibration: true,
      playSound: true,
      ongoing: notification.persistent,
      autoCancel: notification.autoCancel,
      groupKey: notification.groupKey,
      setAsGroupSummary: notification.groupKey != null,
      styleInformation: _buildStyleInformation(notification),
      actions: _buildAndroidActions(notification.actions),
      largeIcon: notification.largeIcon != null
          ? FilePathAndroidBitmap(notification.largeIcon!)
          : null,
      progress: notification.progress ?? 0,
      maxProgress: notification.maxProgress ?? 100,
      indeterminate: notification.indeterminate,
      tag: notification.tag,
      color: _getNotificationColor(notification.category),
    );

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    return NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );
  }

  StyleInformation? _buildStyleInformation(BizSyncNotification notification) {
    switch (notification.style) {
      case NotificationStyle.bigText:
        return BigTextStyleInformation(
          notification.bigText ?? notification.body,
          htmlFormatBigText: true,
          contentTitle: notification.title,
          htmlFormatContentTitle: true,
        );

      case NotificationStyle.inbox:
        // For batched notifications
        final lines = <String>[];
        if (notification.payload?['notificationIds'] != null) {
          final ids = notification.payload!['notificationIds'] as List;
          for (final id in ids.take(5)) {
            final notif = _activeNotifications[id];
            if (notif != null) {
              lines.add(notif.body);
            }
          }
        }
        return InboxStyleInformation(
          lines,
          htmlFormatLines: true,
          contentTitle: notification.title,
          htmlFormatContentTitle: true,
          summaryText: notification.body,
          htmlFormatSummaryText: true,
        );

      case NotificationStyle.bigPicture:
        if (notification.imageUrl != null) {
          return BigPictureStyleInformation(
            FilePathAndroidBitmap(notification.imageUrl!),
            contentTitle: notification.title,
            htmlFormatContentTitle: true,
          );
        }
        return null;

      default:
        return null;
    }
  }

  List<AndroidNotificationAction>? _buildAndroidActions(
    List<NotificationAction>? actions,
  ) {
    if (actions == null || actions.isEmpty) return null;

    return actions
        .map((action) => AndroidNotificationAction(
              action.id,
              action.title,
              icon: action.icon != null
                  ? FilePathAndroidBitmap(action.icon!)
                  : null,
              inputs: action.type == NotificationActionType.custom &&
                      action.payload?['requiresInput'] == true
                  ? [
                      const AndroidNotificationActionInput(
                        label: 'Enter text',
                      )
                    ]
                  : [],
            ))
        .toList();
  }

  Color? _getNotificationColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.invoice:
        return const Color(0xFF2196F3); // Blue
      case NotificationCategory.payment:
        return const Color(0xFF4CAF50); // Green
      case NotificationCategory.tax:
        return const Color(0xFFFF9800); // Orange
      case NotificationCategory.backup:
        return const Color(0xFF9C27B0); // Purple
      case NotificationCategory.insight:
        return const Color(0xFFFFEB3B); // Yellow
      case NotificationCategory.reminder:
        return const Color(0xFF00BCD4); // Cyan
      case NotificationCategory.system:
        return const Color(0xFF607D8B); // Blue Grey
      case NotificationCategory.custom:
        return const Color(0xFF795548); // Brown
    }
  }

  int _getNextNotificationId() {
    return _notificationIdCounter++;
  }

  Future<void> _scheduleNotification(
    BizSyncNotification notification, {
    NotificationRecurrenceRule? recurrenceRule,
  }) async {
    await _scheduler.scheduleNotification(notification, recurrenceRule);
  }

  Future<void> _schedulePendingNotifications() async {
    await _scheduler.schedulePendingNotifications();
  }

  void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationAction(response.payload, response.actionId);
  }

  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Handle background notification responses
    // This method must be static for background processing
  }

  void _handleNotificationAction(String? payload, String? actionId) {
    if (payload == null) return;

    try {
      final payloadData = jsonDecode(payload) as Map<String, dynamic>;
      final notificationId = payloadData['notificationId'] as String?;

      if (notificationId != null) {
        final notification = _activeNotifications[notificationId];
        if (notification != null) {
          // Record interaction
          final metrics = NotificationMetrics(
            notificationId: notificationId,
            deliveredAt: notification.deliveredAt ?? DateTime.now(),
            openedAt: DateTime.now(),
            actionTaken: actionId,
          );
          _metrics.add(metrics);
          _metricsStream.add(metrics);

          // Mark as read
          final updatedNotification = notification.copyWith(
            readAt: DateTime.now(),
            status: NotificationStatus.opened,
          );
          _activeNotifications[notificationId] = updatedNotification;
          _notificationStream.add(updatedNotification);
        }
      }

      // Handle specific actions
      if (actionId != null) {
        _handleSpecificAction(actionId, payloadData);
      }
    } catch (e) {
      // Log error but don't crash
      print('Error handling notification action: $e');
    }
  }

  void _handleSpecificAction(String actionId, Map<String, dynamic> payload) {
    // Implement specific action handlers
    switch (actionId) {
      case 'view_invoice':
        // Navigate to invoice detail
        break;
      case 'mark_complete':
        // Mark task as complete
        break;
      case 'snooze':
        // Snooze notification
        _snoozeNotification(payload['notificationId']);
        break;
      case 'start_backup':
        // Start backup process
        break;
      default:
        // Handle custom actions
        break;
    }
  }

  Future<void> _snoozeNotification(String notificationId) async {
    final notification = _activeNotifications[notificationId];
    if (notification == null) return;

    // Cancel current notification
    await cancelNotification(notificationId);

    // Reschedule for later (e.g., 15 minutes)
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
    final snoozedNotification = notification.copyWith(
      scheduledFor: snoozeTime,
      status: NotificationStatus.scheduled,
    );

    await _scheduleNotification(snoozedNotification);
  }

  Future<void> _setupPeriodicMaintenance() async {
    // Clean up old notifications and metrics
    Timer.periodic(const Duration(hours: 24), (_) async {
      await _cleanupOldData();
    });
  }

  Future<void> _cleanupOldData() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    // Remove old notifications
    _activeNotifications.removeWhere(
      (key, notification) =>
          notification.createdAt.isBefore(cutoffDate) &&
          notification.status != NotificationStatus.pending &&
          notification.status != NotificationStatus.scheduled,
    );

    // Remove old metrics
    _metrics.removeWhere(
      (metrics) => metrics.deliveredAt.isBefore(cutoffDate),
    );
  }

  // Utility methods for external access
  Importance _mapPriorityToImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return Importance.max;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.medium:
        return Importance.defaultImportance;
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.info:
        return Importance.min;
    }
  }

  Priority _mapPriorityToAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return Priority.max;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.medium:
        return Priority.defaultPriority;
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.info:
        return Priority.min;
    }
  }

  /// Public API methods

  Future<void> updateSettings(NotificationSettings settings) async {
    _settings = settings;
    await _saveSettings();
  }

  NotificationSettings? get settings => _settings;

  List<BizSyncNotification> getActiveNotifications() {
    return _activeNotifications.values.toList();
  }

  List<BizSyncNotification> getNotificationsByCategory(
      NotificationCategory category) {
    return _activeNotifications.values
        .where((notification) => notification.category == category)
        .toList();
  }

  List<NotificationMetrics> getMetrics() {
    return List.from(_metrics);
  }

  Future<void> cancelNotification(String notificationId) async {
    final notification = _activeNotifications[notificationId];
    if (notification == null) return;

    // Cancel from system
    await _notifications.cancel(notificationId.hashCode);

    // Update status
    final cancelledNotification = notification.copyWith(
      status: NotificationStatus.cancelled,
    );
    _activeNotifications[notificationId] = cancelledNotification;
    _notificationStream.add(cancelledNotification);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();

    // Update all active notifications
    for (final entry in _activeNotifications.entries) {
      final cancelled = entry.value.copyWith(
        status: NotificationStatus.cancelled,
      );
      _activeNotifications[entry.key] = cancelled;
      _notificationStream.add(cancelled);
    }
  }

  Future<void> clearNotificationHistory() async {
    _activeNotifications.clear();
    _metrics.clear();
  }

  /// Dispose resources
  void dispose() {
    _notificationStream.close();
    _metricsStream.close();
  }
}
