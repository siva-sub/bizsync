import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../../navigation/app_navigation_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      await _requestPermission();

      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Linux initialization
      const LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: 'Open notification');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        linux: initializationSettingsLinux,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      _initialized = true;
    } catch (e) {
      throw BizSyncException('Failed to initialize notifications: $e');
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.notification.request();
    if (status != PermissionStatus.granted) {
      throw BizSyncException('Notification permission denied');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: 'Notifications for BizSync business management',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    final payload = response.payload;
    if (payload != null) {
      // Parse payload and navigate accordingly
      _handleNotificationPayload(payload);
    }
  }

  void _handleNotificationPayload(String payload) {
    try {
      final Map<String, dynamic> payloadData = json.decode(payload);
      final String? type = payloadData['type'];
      final String? id = payloadData['id'];
      final Map<String, dynamic>? data = payloadData['data'];

      final navigationService = AppNavigationService();

      switch (type) {
        case 'invoice':
          if (id != null) {
            navigationService.goToInvoiceDetail(id);
          } else {
            navigationService.goToInvoices();
          }
          break;

        case 'payment':
          if (data != null) {
            navigationService.goToPaymentQR(
              amount: data['amount']?.toDouble(),
              reference: data['reference'],
              description: data['description'],
            );
          } else {
            navigationService.goToPayments();
          }
          break;

        case 'customer':
          if (id != null) {
            navigationService.goToEditCustomer(id);
          } else {
            navigationService.goToCustomers();
          }
          break;

        case 'employee':
          navigationService.goToEmployees();
          break;

        case 'tax':
          if (data != null && data['calculator'] == true) {
            navigationService.goToTaxCalculator(
              income: data['income']?.toDouble(),
              taxYear: data['taxYear'],
            );
          } else {
            navigationService.goToTaxCenter();
          }
          break;

        case 'backup':
          navigationService.goToBackup();
          break;

        case 'sync':
          navigationService.goToSync();
          break;

        case 'dashboard':
          navigationService.goToDashboard();
          break;

        case 'settings':
          navigationService.goToSettings();
          break;

        default:
          // Navigate to home/dashboard by default
          navigationService.goHome();
          break;
      }
    } catch (e) {
      // If payload parsing fails, navigate to notifications center
      debugPrint('Error parsing notification payload: $e');
      AppNavigationService().goToNotifications();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    if (!_initialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: 'BizSync business notifications',
      importance: _mapPriorityToImportance(priority),
      priority: _mapPriorityToAndroidPriority(priority),
      enableVibration: true,
      playSound: true,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    if (!_initialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: 'BizSync scheduled notifications',
      importance: _mapPriorityToImportance(priority),
      priority: _mapPriorityToAndroidPriority(priority),
      enableVibration: true,
      playSound: true,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Importance _mapPriorityToImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.min:
        return Importance.min;
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.defaultPriority:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.max:
        return Importance.max;
    }
  }

  Priority _mapPriorityToAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.min:
        return Priority.min;
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.defaultPriority:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.max:
        return Priority.max;
    }
  }

  /// Alias for showNotification for backward compatibility
  Future<void> sendNotification({
    int? id,
    required String title,
    required String message,
    String? body,
    String? type,
    String? payload,
    Map<String, dynamic>? data,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    return showNotification(
      id: id ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body ?? message,
      payload: payload ?? type,
      priority: priority,
    );
  }

  /// Helper method to create structured notification payloads
  static String createPayload({
    required String type,
    String? id,
    Map<String, dynamic>? data,
  }) {
    return json.encode({
      'type': type,
      'id': id,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Create payload for invoice notifications
  static String createInvoicePayload(String invoiceId,
      {Map<String, dynamic>? data}) {
    return createPayload(type: 'invoice', id: invoiceId, data: data);
  }

  /// Create payload for payment notifications
  static String createPaymentPayload(
      {double? amount, String? reference, String? description}) {
    return createPayload(
      type: 'payment',
      data: {
        'amount': amount,
        'reference': reference,
        'description': description,
      },
    );
  }

  /// Create payload for customer notifications
  static String createCustomerPayload(String customerId) {
    return createPayload(type: 'customer', id: customerId);
  }

  /// Create payload for tax calculator notifications
  static String createTaxCalculatorPayload({double? income, String? taxYear}) {
    return createPayload(
      type: 'tax',
      data: {
        'calculator': true,
        'income': income,
        'taxYear': taxYear,
      },
    );
  }
}

enum NotificationPriority {
  min,
  low,
  defaultPriority,
  high,
  max,
}
