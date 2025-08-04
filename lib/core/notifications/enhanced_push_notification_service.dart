import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

// Notification types for business app
enum BusinessNotificationType {
  paymentReminder,
  invoiceDue,
  lowInventory,
  dailyReport,
  weeklyReport,
  monthlyReport,
  syncComplete,
  syncFailed,
  backupComplete,
  taxDeadline,
  customerPayment,
  newOrder,
}

// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

// Business notification model
class BusinessNotification {
  final String id;
  final BusinessNotificationType type;
  final String title;
  final String body;
  final NotificationPriority priority;
  final DateTime scheduledTime;
  final Map<String, dynamic>? payload;
  final bool recurring;
  final Duration? recurringInterval;

  const BusinessNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.priority = NotificationPriority.normal,
    required this.scheduledTime,
    this.payload,
    this.recurring = false,
    this.recurringInterval,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'title': title,
      'body': body,
      'priority': priority.index,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'payload': payload,
      'recurring': recurring,
      'recurringIntervalMinutes': recurringInterval?.inMinutes,
    };
  }

  static BusinessNotification fromJson(Map<String, dynamic> json) {
    return BusinessNotification(
      id: json['id'],
      type: BusinessNotificationType.values[json['type']],
      title: json['title'],
      body: json['body'],
      priority: NotificationPriority.values[json['priority'] ?? 1],
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(json['scheduledTime']),
      payload: json['payload'] != null 
          ? Map<String, dynamic>.from(json['payload']) 
          : null,
      recurring: json['recurring'] ?? false,
      recurringInterval: json['recurringIntervalMinutes'] != null
          ? Duration(minutes: json['recurringIntervalMinutes'])
          : null,
    );
  }
}

// Notification settings
class NotificationSettings {
  final bool enabled;
  final bool enablePaymentReminders;
  final bool enableInvoiceDueAlerts;
  final bool enableInventoryAlerts;
  final bool enableReportNotifications;
  final bool enableSyncNotifications;
  final bool enableTaxDeadlines;
  final bool enableQuietHours;
  final TimeOfDay quietHoursStart;
  final TimeOfDay quietHoursEnd;
  final NotificationPriority minimumPriority;

  const NotificationSettings({
    this.enabled = true,
    this.enablePaymentReminders = true,
    this.enableInvoiceDueAlerts = true,
    this.enableInventoryAlerts = true,
    this.enableReportNotifications = false,
    this.enableSyncNotifications = false,
    this.enableTaxDeadlines = true,
    this.enableQuietHours = true,
    this.quietHoursStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietHoursEnd = const TimeOfDay(hour: 8, minute: 0),
    this.minimumPriority = NotificationPriority.normal,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? enablePaymentReminders,
    bool? enableInvoiceDueAlerts,
    bool? enableInventoryAlerts,
    bool? enableReportNotifications,
    bool? enableSyncNotifications,
    bool? enableTaxDeadlines,
    bool? enableQuietHours,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    NotificationPriority? minimumPriority,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      enablePaymentReminders: enablePaymentReminders ?? this.enablePaymentReminders,
      enableInvoiceDueAlerts: enableInvoiceDueAlerts ?? this.enableInvoiceDueAlerts,
      enableInventoryAlerts: enableInventoryAlerts ?? this.enableInventoryAlerts,
      enableReportNotifications: enableReportNotifications ?? this.enableReportNotifications,
      enableSyncNotifications: enableSyncNotifications ?? this.enableSyncNotifications,
      enableTaxDeadlines: enableTaxDeadlines ?? this.enableTaxDeadlines,
      enableQuietHours: enableQuietHours ?? this.enableQuietHours,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      minimumPriority: minimumPriority ?? this.minimumPriority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'enablePaymentReminders': enablePaymentReminders,
      'enableInvoiceDueAlerts': enableInvoiceDueAlerts,
      'enableInventoryAlerts': enableInventoryAlerts,
      'enableReportNotifications': enableReportNotifications,
      'enableSyncNotifications': enableSyncNotifications,
      'enableTaxDeadlines': enableTaxDeadlines,
      'enableQuietHours': enableQuietHours,
      'quietHoursStartMinutes': quietHoursStart.hour * 60 + quietHoursStart.minute,
      'quietHoursEndMinutes': quietHoursEnd.hour * 60 + quietHoursEnd.minute,
      'minimumPriority': minimumPriority.index,
    };
  }

  static NotificationSettings fromJson(Map<String, dynamic> json) {
    final quietStartMinutes = json['quietHoursStartMinutes'] ?? (22 * 60);
    final quietEndMinutes = json['quietHoursEndMinutes'] ?? (8 * 60);
    
    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      enablePaymentReminders: json['enablePaymentReminders'] ?? true,
      enableInvoiceDueAlerts: json['enableInvoiceDueAlerts'] ?? true,
      enableInventoryAlerts: json['enableInventoryAlerts'] ?? true,
      enableReportNotifications: json['enableReportNotifications'] ?? false,
      enableSyncNotifications: json['enableSyncNotifications'] ?? false,
      enableTaxDeadlines: json['enableTaxDeadlines'] ?? true,
      enableQuietHours: json['enableQuietHours'] ?? true,
      quietHoursStart: TimeOfDay(
        hour: quietStartMinutes ~/ 60, 
        minute: quietStartMinutes % 60,
      ),
      quietHoursEnd: TimeOfDay(
        hour: quietEndMinutes ~/ 60, 
        minute: quietEndMinutes % 60,
      ),
      minimumPriority: NotificationPriority.values[json['minimumPriority'] ?? 1],
    );
  }
}

// Enhanced push notification service
class EnhancedPushNotificationService extends ChangeNotifier {
  static const String _settingsKey = 'notification_settings';
  static const String _scheduledNotificationsKey = 'scheduled_notifications';

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  NotificationSettings _settings = const NotificationSettings();
  final List<BusinessNotification> _scheduledNotifications = [];
  SharedPreferences? _prefs;
  bool _initialized = false;

  NotificationSettings get settings => _settings;
  List<BusinessNotification> get scheduledNotifications => 
      List.unmodifiable(_scheduledNotifications);
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    await _loadScheduledNotifications();
    await _initializeNotificationPlugin();
    
    _initialized = true;
    debugPrint('Enhanced Push Notification Service initialized');
  }

  Future<void> _initializeNotificationPlugin() async {
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to appropriate screen
    // This could trigger navigation through a global navigator or callback
  }

  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    final settingsJson = _prefs!.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final data = _parseJson(settingsJson);
        _settings = NotificationSettings.fromJson(data);
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading notification settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_prefs == null) return;

    try {
      final settingsJson = _stringifyJson(_settings.toJson());
      await _prefs!.setString(_settingsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  Future<void> _loadScheduledNotifications() async {
    if (_prefs == null) return;

    final notificationsJson = _prefs!.getStringList(_scheduledNotificationsKey) ?? [];
    
    for (final notificationJson in notificationsJson) {
      try {
        final data = _parseJson(notificationJson);
        final notification = BusinessNotification.fromJson(data);
        _scheduledNotifications.add(notification);
      } catch (e) {
        debugPrint('Error loading scheduled notification: $e');
      }
    }
  }

  Future<void> _saveScheduledNotifications() async {
    if (_prefs == null) return;

    final notificationsJson = _scheduledNotifications
        .map((notification) => _stringifyJson(notification.toJson()))
        .toList();
    
    await _prefs!.setStringList(_scheduledNotificationsKey, notificationsJson);
  }

  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }

  // Check if notification should be shown based on settings
  bool _shouldShowNotification(BusinessNotification notification) {
    if (!_settings.enabled) return false;

    // Check type-specific settings
    switch (notification.type) {
      case BusinessNotificationType.paymentReminder:
        if (!_settings.enablePaymentReminders) return false;
        break;
      case BusinessNotificationType.invoiceDue:
        if (!_settings.enableInvoiceDueAlerts) return false;
        break;
      case BusinessNotificationType.lowInventory:
        if (!_settings.enableInventoryAlerts) return false;
        break;
      case BusinessNotificationType.dailyReport:
      case BusinessNotificationType.weeklyReport:
      case BusinessNotificationType.monthlyReport:
        if (!_settings.enableReportNotifications) return false;
        break;
      case BusinessNotificationType.syncComplete:
      case BusinessNotificationType.syncFailed:
        if (!_settings.enableSyncNotifications) return false;
        break;
      case BusinessNotificationType.taxDeadline:
        if (!_settings.enableTaxDeadlines) return false;
        break;
      default:
        break;
    }

    // Check priority
    if (notification.priority.index < _settings.minimumPriority.index) {
      return false;
    }

    // Check quiet hours
    if (_settings.enableQuietHours) {
      final now = TimeOfDay.now();
      if (_isInQuietHours(now)) {
        // Only allow urgent notifications during quiet hours
        return notification.priority == NotificationPriority.urgent;
      }
    }

    return true;
  }

  bool _isInQuietHours(TimeOfDay time) {
    final nowMinutes = time.hour * 60 + time.minute;
    final startMinutes = _settings.quietHoursStart.hour * 60 + _settings.quietHoursStart.minute;
    final endMinutes = _settings.quietHoursEnd.hour * 60 + _settings.quietHoursEnd.minute;

    if (startMinutes < endMinutes) {
      // Same day range (e.g., 10 PM - 8 AM next day)
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    } else {
      // Across midnight (e.g., 10 PM - 8 AM)
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
  }

  // Schedule a business notification
  Future<void> scheduleNotification(BusinessNotification notification) async {
    if (!_shouldShowNotification(notification)) {
      debugPrint('Notification filtered out: ${notification.title}');
      return;
    }

    final notificationDetails = _getNotificationDetails(notification);
    
    try {
      if (notification.recurring && notification.recurringInterval != null) {
        // Schedule recurring notification
        await _scheduleRecurringNotification(notification, notificationDetails);
      } else {
        // Schedule one-time notification
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          notification.id.hashCode,
          notification.title,
          notification.body,
          tz.TZDateTime.from(notification.scheduledTime, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: _stringifyJson(notification.payload ?? {}),
        );
      }

      _scheduledNotifications.add(notification);
      await _saveScheduledNotifications();
      
      debugPrint('Scheduled notification: ${notification.title}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> _scheduleRecurringNotification(
    BusinessNotification notification,
    NotificationDetails notificationDetails,
  ) async {
    // Schedule multiple instances of recurring notification
    var nextScheduleTime = notification.scheduledTime;
    final endTime = notification.scheduledTime.add(const Duration(days: 365)); // Limit to 1 year

    int instanceCount = 0;
    while (nextScheduleTime.isBefore(endTime) && instanceCount < 100) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        '${notification.id}_$instanceCount'.hashCode,
        notification.title,
        notification.body,
        tz.TZDateTime.from(nextScheduleTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: _stringifyJson(notification.payload ?? {}),
      );

      nextScheduleTime = nextScheduleTime.add(notification.recurringInterval!);
      instanceCount++;
    }
  }

  NotificationDetails _getNotificationDetails(BusinessNotification notification) {
    final importance = _getAndroidImportance(notification.priority);
    final priority = _getAndroidPriority(notification.priority);

    const androidDetails = AndroidNotificationDetails(
      'bizsync_business',
      'Business Notifications',
      channelDescription: 'Important business-related notifications',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  // Cancel a scheduled notification
  Future<void> cancelNotification(String notificationId) async {
    await _flutterLocalNotificationsPlugin.cancel(notificationId.hashCode);
    
    _scheduledNotifications.removeWhere((n) => n.id == notificationId);
    await _saveScheduledNotifications();
    
    notifyListeners();
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    
    _scheduledNotifications.clear();
    await _saveScheduledNotifications();
    
    notifyListeners();
  }

  // Convenience methods for common business notifications
  Future<void> schedulePaymentReminder({
    required String invoiceId,
    required String customerName,
    required double amount,
    required DateTime dueDate,
  }) async {
    final notification = BusinessNotification(
      id: 'payment_reminder_$invoiceId',
      type: BusinessNotificationType.paymentReminder,
      title: 'Payment Reminder',
      body: 'Payment of \$${amount.toStringAsFixed(2)} from $customerName is due today',
      priority: NotificationPriority.high,
      scheduledTime: dueDate,
      payload: {
        'type': 'payment_reminder',
        'invoiceId': invoiceId,
        'customerId': customerName,
        'amount': amount,
      },
    );

    await scheduleNotification(notification);
  }

  Future<void> scheduleLowInventoryAlert({
    required String productId,
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    final notification = BusinessNotification(
      id: 'low_inventory_$productId',
      type: BusinessNotificationType.lowInventory,
      title: 'Low Inventory Alert',
      body: '$productName is running low (${currentStock} left, minimum: $minStock)',
      priority: NotificationPriority.normal,
      scheduledTime: DateTime.now().add(const Duration(minutes: 1)),
      payload: {
        'type': 'low_inventory',
        'productId': productId,
        'productName': productName,
        'currentStock': currentStock,
        'minStock': minStock,
      },
    );

    await scheduleNotification(notification);
  }

  Future<void> scheduleDailyReport() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final reportTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);

    final notification = BusinessNotification(
      id: 'daily_report_${DateTime.now().day}',
      type: BusinessNotificationType.dailyReport,
      title: 'Daily Business Report',
      body: 'Your daily business summary is ready to view',
      priority: NotificationPriority.low,
      scheduledTime: reportTime,
      recurring: true,
      recurringInterval: const Duration(days: 1),
      payload: {
        'type': 'daily_report',
        'date': DateTime.now().toIso8601String(),
      },
    );

    await scheduleNotification(notification);
  }

  // Simple JSON parsing methods
  Map<String, dynamic> _parseJson(String jsonString) {
    final Map<String, dynamic> result = {};
    
    final content = jsonString.replaceAll(RegExp(r'[{}"]'), '');
    final pairs = content.split(',');
    
    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();
        
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value == 'null') {
          result[key] = null;
        } else if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }
    
    return result;
  }

  String _stringifyJson(Map<String, dynamic> data) {
    final List<String> pairs = [];
    
    data.forEach((key, value) {
      String valueStr;
      if (value == null) {
        valueStr = 'null';
      } else if (value is bool) {
        valueStr = value.toString();
      } else if (value is num) {
        valueStr = value.toString();
      } else {
        valueStr = '"$value"';
      }
      pairs.add('"$key":$valueStr');
    });
    
    return '{${pairs.join(',')}}';
  }
}

// Riverpod providers
final enhancedPushNotificationServiceProvider = Provider<EnhancedPushNotificationService>((ref) {
  final service = EnhancedPushNotificationService();
  service.initialize();
  return service;
});

final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  final service = ref.watch(enhancedPushNotificationServiceProvider);
  return NotificationSettingsNotifier(service);
});

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final EnhancedPushNotificationService _service;

  NotificationSettingsNotifier(this._service) : super(_service.settings) {
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    state = _service.settings;
  }

  Future<void> updateSettings(NotificationSettings settings) async {
    await _service.updateSettings(settings);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }
}