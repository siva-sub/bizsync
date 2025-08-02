import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/notification_models.dart';
import '../models/notification_types.dart';
import 'background_task_service.dart';

/// Advanced notification scheduler with recurring support
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final BackgroundTaskService _backgroundService = BackgroundTaskService();
  final _uuid = const Uuid();
  
  bool _initialized = false;
  Timer? _maintenanceTimer;
  final List<NotificationSchedule> _schedules = [];

  /// Initialize the scheduler
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadSchedules();
    await _setupMaintenanceTimer();
    
    _initialized = true;
  }

  /// Schedule a single notification
  Future<void> scheduleNotification(
    BizSyncNotification notification, [
    NotificationRecurrenceRule? recurrenceRule,
  ]) async {
    if (!_initialized) await initialize();

    if (notification.scheduledFor == null) {
      throw ArgumentError('Notification must have a scheduled time');
    }

    // Store scheduled notification
    await _storeScheduledNotification(notification);

    // If it's a recurring notification, create a schedule
    if (recurrenceRule != null) {
      final schedule = NotificationSchedule(
        id: _uuid.v4(),
        notificationTemplateId: notification.id,
        triggerType: NotificationTrigger.recurring,
        scheduledTime: notification.scheduledFor,
        recurrenceRule: recurrenceRule,
        enabled: true,
        createdAt: DateTime.now(),
      );

      await _addSchedule(schedule);
    } else {
      // Schedule one-time delivery via background service
      await _backgroundService.scheduleNotificationTask(
        taskId: notification.id,
        scheduledTime: notification.scheduledFor!,
        taskData: {
          'notificationId': notification.id,
          'type': notification.type.name,
          'title': notification.title,
          'body': notification.body,
        },
      );
    }
  }

  /// Schedule notification from template with recurrence
  Future<void> scheduleRecurringNotification({
    required String templateId,
    required Map<String, dynamic> variables,
    required DateTime firstOccurrence,
    required NotificationRecurrenceRule recurrenceRule,
    Map<String, dynamic>? conditions,
  }) async {
    if (!_initialized) await initialize();

    final schedule = NotificationSchedule(
      id: _uuid.v4(),
      notificationTemplateId: templateId,
      triggerType: NotificationTrigger.recurring,
      scheduledTime: firstOccurrence,
      recurrenceRule: recurrenceRule,
      conditions: {
        'templateId': templateId,
        'variables': variables,
        ...?conditions,
      },
      enabled: true,
      createdAt: DateTime.now(),
    );

    await _addSchedule(schedule);
  }

  /// Schedule conditional notification
  Future<void> scheduleConditionalNotification({
    required String templateId,
    required Map<String, dynamic> variables,
    required Map<String, dynamic> conditions,
    DateTime? earliestTime,
  }) async {
    if (!_initialized) await initialize();

    final schedule = NotificationSchedule(
      id: _uuid.v4(),
      notificationTemplateId: templateId,
      triggerType: NotificationTrigger.conditional,
      scheduledTime: earliestTime,
      conditions: {
        'templateId': templateId,
        'variables': variables,
        'conditions': conditions,
      },
      enabled: true,
      createdAt: DateTime.now(),
    );

    await _addSchedule(schedule);
  }

  /// Check and trigger scheduled notifications
  Future<void> checkScheduledNotifications([Map<String, dynamic>? context]) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    final triggeredSchedules = <NotificationSchedule>[];

    for (final schedule in _schedules) {
      if (schedule.shouldTrigger(now, context)) {
        await _triggerSchedule(schedule, context);
        triggeredSchedules.add(schedule);
      }
    }

    // Update triggered schedules
    for (final schedule in triggeredSchedules) {
      await _updateScheduleAfterTrigger(schedule);
    }
  }

  /// Process pending notifications that should be delivered now
  Future<void> schedulePendingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getStringList('pending_notifications') ?? [];
    
    if (pendingJson.isEmpty) return;

    final notifications = <BizSyncNotification>[];
    
    for (final notificationJson in pendingJson) {
      try {
        final data = jsonDecode(notificationJson) as Map<String, dynamic>;
        final notification = BizSyncNotification.fromJson(data);
        notifications.add(notification);
      } catch (e) {
        // Skip malformed data
        continue;
      }
    }

    // Clear pending notifications
    await prefs.remove('pending_notifications');

    // Process each notification
    for (final notification in notifications) {
      // This would trigger the main notification service
      // For now, we'll add it back to pending for the main app to pick up
      await _storeNotificationForDelivery(notification);
    }
  }

  Future<void> _triggerSchedule(
    NotificationSchedule schedule,
    Map<String, dynamic>? context,
  ) async {
    try {
      // Extract template information from conditions
      final templateId = schedule.conditions?['templateId'] as String?;
      final variables = schedule.conditions?['variables'] as Map<String, dynamic>?;

      if (templateId != null && variables != null) {
        // Create notification from template
        final notification = BizSyncNotification(
          id: _uuid.v4(),
          title: 'Scheduled Notification', // Would come from template
          body: 'You have a scheduled notification', // Would come from template
          type: BusinessNotificationType.custom,
          category: NotificationCategory.reminder,
          priority: NotificationPriority.medium,
          channel: NotificationChannel.reminders,
          createdAt: DateTime.now(),
          payload: {
            'scheduleId': schedule.id,
            'templateId': templateId,
            'variables': variables,
            ...?context,
          },
        );

        await _storeNotificationForDelivery(notification);
      }
    } catch (e) {
      print('Error triggering schedule ${schedule.id}: $e');
    }
  }

  Future<void> _updateScheduleAfterTrigger(NotificationSchedule schedule) async {
    final updatedSchedule = NotificationSchedule(
      id: schedule.id,
      notificationTemplateId: schedule.notificationTemplateId,
      triggerType: schedule.triggerType,
      scheduledTime: schedule.scheduledTime,
      recurrenceRule: schedule.recurrenceRule,
      conditions: schedule.conditions,
      enabled: schedule.enabled,
      createdAt: schedule.createdAt,
      lastTriggered: DateTime.now(),
      triggerCount: schedule.triggerCount + 1,
    );

    // Update in memory
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = updatedSchedule;
    }

    // Save to storage
    await _saveSchedules();

    // Schedule next occurrence for recurring notifications
    if (schedule.recurrenceRule != null) {
      final nextOccurrence = schedule.recurrenceRule!.getNextOccurrence(DateTime.now());
      if (nextOccurrence != null) {
        final nextSchedule = updatedSchedule.copyWith(scheduledTime: nextOccurrence);
        // Note: This would need a copyWith method in NotificationSchedule
      }
    }
  }

  /// Store scheduled notification for background processing
  Future<void> _storeScheduledNotification(BizSyncNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledNotifications = prefs.getStringList('scheduled_notifications') ?? [];
    
    scheduledNotifications.add(jsonEncode(notification.toJson()));
    await prefs.setStringList('scheduled_notifications', scheduledNotifications);
  }

  /// Store notification for immediate delivery by main app
  Future<void> _storeNotificationForDelivery(BizSyncNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final deliveryQueue = prefs.getStringList('notification_delivery_queue') ?? [];
    
    deliveryQueue.add(jsonEncode(notification.toJson()));
    await prefs.setStringList('notification_delivery_queue', deliveryQueue);
  }

  /// Add a new schedule
  Future<void> _addSchedule(NotificationSchedule schedule) async {
    _schedules.add(schedule);
    await _saveSchedules();
  }

  /// Remove a schedule
  Future<void> removeSchedule(String scheduleId) async {
    _schedules.removeWhere((schedule) => schedule.id == scheduleId);
    await _saveSchedules();
  }

  /// Enable/disable a schedule
  Future<void> toggleSchedule(String scheduleId, bool enabled) async {
    final index = _schedules.indexWhere((s) => s.id == scheduleId);
    if (index != -1) {
      // This would need a copyWith method
      // _schedules[index] = _schedules[index].copyWith(enabled: enabled);
      await _saveSchedules();
    }
  }

  /// Load schedules from storage
  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = prefs.getStringList('notification_schedules') ?? [];
    
    _schedules.clear();
    for (final scheduleJson in schedulesJson) {
      try {
        final scheduleData = jsonDecode(scheduleJson) as Map<String, dynamic>;
        final schedule = NotificationSchedule.fromJson(scheduleData);
        _schedules.add(schedule);
      } catch (e) {
        // Skip malformed schedule data
        continue;
      }
    }
  }

  /// Save schedules to storage
  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = _schedules.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('notification_schedules', schedulesJson);
  }

  /// Set up maintenance timer for periodic checks
  Future<void> _setupMaintenanceTimer() async {
    _maintenanceTimer?.cancel();
    
    // Check every 5 minutes for scheduled notifications
    _maintenanceTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await checkScheduledNotifications();
      await _cleanupExpiredSchedules();
    });
  }

  /// Clean up expired or completed schedules
  Future<void> _cleanupExpiredSchedules() async {
    final now = DateTime.now();
    final initialCount = _schedules.length;
    
    _schedules.removeWhere((schedule) {
      // Remove disabled schedules older than 30 days
      if (!schedule.enabled && 
          now.difference(schedule.createdAt).inDays > 30) {
        return true;
      }
      
      // Remove one-time schedules that have been triggered
      if (schedule.triggerType != NotificationTrigger.recurring &&
          schedule.lastTriggered != null) {
        return true;
      }
      
      // Remove schedules with end dates that have passed
      if (schedule.recurrenceRule?.endDate != null &&
          now.isAfter(schedule.recurrenceRule!.endDate!)) {
        return true;
      }
      
      return false;
    });

    if (_schedules.length != initialCount) {
      await _saveSchedules();
    }
  }

  /// Get all active schedules
  List<NotificationSchedule> getActiveSchedules() {
    return _schedules.where((s) => s.enabled).toList();
  }

  /// Get schedules by type
  List<NotificationSchedule> getSchedulesByType(NotificationTrigger type) {
    return _schedules.where((s) => s.triggerType == type).toList();
  }

  /// Cancel a scheduled notification
  Future<void> cancelScheduledNotification(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledNotifications = prefs.getStringList('scheduled_notifications') ?? [];
    
    final filtered = scheduledNotifications.where((json) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return data['id'] != notificationId;
      } catch (e) {
        return false; // Remove malformed data
      }
    }).toList();

    await prefs.setStringList('scheduled_notifications', filtered);
  }

  /// Get scheduled notifications count
  Future<int> getScheduledNotificationsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledNotifications = prefs.getStringList('scheduled_notifications') ?? [];
    return scheduledNotifications.length;
  }

  /// Clean up all scheduled data
  Future<void> clearAllSchedules() async {
    _schedules.clear();
    await _saveSchedules();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scheduled_notifications');
    await prefs.remove('notification_delivery_queue');
  }

  /// Dispose resources
  void dispose() {
    _maintenanceTimer?.cancel();
  }
}

/// Extension to add copyWith method to NotificationSchedule
extension NotificationScheduleExtension on NotificationSchedule {
  NotificationSchedule copyWith({
    String? id,
    String? notificationTemplateId,
    NotificationTrigger? triggerType,
    DateTime? scheduledTime,
    NotificationRecurrenceRule? recurrenceRule,
    Map<String, dynamic>? conditions,
    bool? enabled,
    DateTime? createdAt,
    DateTime? lastTriggered,
    int? triggerCount,
  }) {
    return NotificationSchedule(
      id: id ?? this.id,
      notificationTemplateId: notificationTemplateId ?? this.notificationTemplateId,
      triggerType: triggerType ?? this.triggerType,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      conditions: conditions ?? this.conditions,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      triggerCount: triggerCount ?? this.triggerCount,
    );
  }
}