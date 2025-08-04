import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_linux/flutter_local_notifications_linux.dart';
import 'package:path/path.dart' as path;

/// Desktop Notification Priority Levels
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Desktop Notification Categories
enum NotificationCategory {
  business,
  invoice,
  payment,
  inventory,
  system,
  reminder,
  error,
}

/// Desktop Notification with Rich Actions
class DesktopNotification {
  final String id;
  final String title;
  final String body;
  final NotificationPriority priority;
  final NotificationCategory category;
  final String? iconPath;
  final List<NotificationAction> actions;
  final Map<String, dynamic> payload;
  final Duration? timeout;
  final bool persistent;
  final String? soundPath;

  DesktopNotification({
    required this.id,
    required this.title,
    required this.body,
    this.priority = NotificationPriority.normal,
    this.category = NotificationCategory.business,
    this.iconPath,
    this.actions = const [],
    this.payload = const {},
    this.timeout,
    this.persistent = false,
    this.soundPath,
  });
}

/// Notification Action (buttons in notifications)
class NotificationAction {
  final String id;
  final String label;
  final String? iconPath;
  final Function(String notificationId, String actionId)? onPressed;

  NotificationAction({
    required this.id,
    required this.label,
    this.iconPath,
    this.onPressed,
  });
}

/// Desktop Notifications Service for Linux
/// 
/// Provides native Linux notifications using libnotify:
/// - Rich notifications with actions
/// - Different priority levels
/// - Custom icons and sounds
/// - Notification center integration
/// - Action handling
class DesktopNotificationsService {
  static final DesktopNotificationsService _instance = DesktopNotificationsService._internal();
  factory DesktopNotificationsService() => _instance;
  DesktopNotificationsService._internal();

  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  // LinuxNotificationManager? _linuxNotificationManager; // Type from missing dependency
  bool _isInitialized = false;
  final Map<String, DesktopNotification> _activeNotifications = {};

  /// Initialize the desktop notifications service
  Future<void> initialize() async {
    if (!Platform.isLinux) {
      debugPrint('Desktop notifications only supported on Linux');
      return;
    }

    try {
      // Initialize Flutter Local Notifications
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Linux notification manager disabled - type dependencies missing
      // _linuxNotificationManager = LinuxNotificationManager(
      //   applicationName: 'BizSync',
      //   applicationId: 'com.bizsync.app',
      // );

      // Configure notification settings
      final LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
        defaultIcon: AssetsLinuxIcon('assets/icon/app_icon.png'),
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        linux: initializationSettingsLinux,
      );

      // Initialize with callback for when notification is tapped
      await _notificationsPlugin!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      _isInitialized = true;
      debugPrint('✅ Desktop notifications service initialized successfully');
      
      // Show initialization notification
      await _showInitializationNotification();
      
    } catch (e) {
      debugPrint('❌ Failed to initialize desktop notifications: $e');
    }
  }

  /// Handle notification response (when user clicks notification or action)
  void _onNotificationResponse(NotificationResponse response) {
    final notificationId = response.id.toString();
    final actionId = response.actionId;
    
    debugPrint('Notification response: ID=$notificationId, Action=$actionId');
    
    final notification = _activeNotifications[notificationId];
    if (notification != null) {
      if (actionId != null) {
        // Handle action button press
        final action = notification.actions.firstWhere(
          (a) => a.id == actionId,
          orElse: () => NotificationAction(id: '', label: ''),
        );
        
        if (action.onPressed != null) {
          action.onPressed!(notificationId, actionId);
        }
      } else {
        // Handle main notification tap
        _handleNotificationTap(notification);
      }
      
      // Remove from active notifications if not persistent
      if (!notification.persistent) {
        _activeNotifications.remove(notificationId);
      }
    }
  }

  /// Handle main notification tap
  void _handleNotificationTap(DesktopNotification notification) {
    debugPrint('Notification tapped: ${notification.title}');
    
    // Navigate based on category
    switch (notification.category) {
      case NotificationCategory.invoice:
        _navigateToInvoices(notification.payload);
        break;
      case NotificationCategory.payment:
        _navigateToPayments(notification.payload);
        break;
      case NotificationCategory.inventory:
        _navigateToInventory(notification.payload);
        break;
      case NotificationCategory.reminder:
        _handleReminder(notification.payload);
        break;
      default:
        _navigateToDashboard();
    }
  }

  /// Show a desktop notification
  Future<void> showNotification(DesktopNotification notification) async {
    if (!_isInitialized || _notificationsPlugin == null) {
      debugPrint('Desktop notifications not initialized');
      return;
    }

    try {
      final id = int.parse(notification.id.replaceAll(RegExp(r'[^0-9]'), '')) % 2147483647;
      
      // Convert priority to Linux importance level
      final importance = _getImportanceLevel(notification.priority);
      
      // Set up notification details
      final linuxDetails = LinuxNotificationDetails(
        icon: notification.iconPath != null 
            ? FilePathLinuxIcon(notification.iconPath!)
            : AssetsLinuxIcon('assets/icon/app_icon.png'),
        category: LinuxNotificationCategory.email, // Generic category
        actions: notification.actions.map((action) => LinuxNotificationAction(
          key: action.id,
          label: action.label,
        )).toList(),
      );

      final platformChannelSpecifics = NotificationDetails(
        linux: linuxDetails,
      );

      // Show the notification
      await _notificationsPlugin!.show(
        id,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: notification.id,
      );

      // Store active notification
      _activeNotifications[notification.id] = notification;
      
      debugPrint('Desktop notification shown: ${notification.title}');
      
    } catch (e) {
      debugPrint('Failed to show desktop notification: $e');
    }
  }

  /// Show business-related notifications
  Future<void> showBusinessNotification({
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    List<NotificationAction> actions = const [],
    Map<String, dynamic> payload = const {},
  }) async {
    final notification = DesktopNotification(
      id: 'business_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: message,
      priority: priority,
      category: NotificationCategory.business,
      actions: actions,
      payload: payload,
    );
    
    await showNotification(notification);
  }

  /// Show invoice notifications
  Future<void> showInvoiceNotification({
    required String invoiceNumber,
    required String message,
    String? customerId,
    double? amount,
    List<NotificationAction>? customActions,
  }) async {
    final actions = customActions ?? [
      NotificationAction(
        id: 'view_invoice',
        label: 'View Invoice',
        onPressed: (notificationId, actionId) {
          _navigateToInvoice(invoiceNumber);
        },
      ),
      NotificationAction(
        id: 'mark_paid',
        label: 'Mark as Paid',
        onPressed: (notificationId, actionId) {
          _markInvoiceAsPaid(invoiceNumber);
        },
      ),
    ];

    final notification = DesktopNotification(
      id: 'invoice_$invoiceNumber',
      title: 'Invoice #$invoiceNumber',
      body: message,
      priority: NotificationPriority.high,
      category: NotificationCategory.invoice,
      actions: actions,
      payload: {
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'amount': amount,
      },
    );
    
    await showNotification(notification);
  }

  /// Show payment notifications
  Future<void> showPaymentNotification({
    required String paymentId,
    required String message,
    required double amount,
    String? invoiceNumber,
  }) async {
    final actions = [
      NotificationAction(
        id: 'view_payment',
        label: 'View Payment',
        onPressed: (notificationId, actionId) {
          _navigateToPayment(paymentId);
        },
      ),
    ];

    final notification = DesktopNotification(
      id: 'payment_$paymentId',
      title: 'Payment Received',
      body: message,
      priority: NotificationPriority.high,
      category: NotificationCategory.payment,
      actions: actions,
      payload: {
        'paymentId': paymentId,
        'amount': amount,
        'invoiceNumber': invoiceNumber,
      },
    );
    
    await showNotification(notification);
  }

  /// Show inventory notifications
  Future<void> showInventoryNotification({
    required String productId,
    required String productName,
    required String message,
    int? stockLevel,
  }) async {
    final actions = [
      NotificationAction(
        id: 'view_product',
        label: 'View Product',
        onPressed: (notificationId, actionId) {
          _navigateToProduct(productId);
        },
      ),
      NotificationAction(
        id: 'restock',
        label: 'Restock',
        onPressed: (notificationId, actionId) {
          _showRestockDialog(productId);
        },
      ),
    ];

    final notification = DesktopNotification(
      id: 'inventory_$productId',
      title: 'Inventory Alert',
      body: message,
      priority: NotificationPriority.normal,
      category: NotificationCategory.inventory,
      actions: actions,
      payload: {
        'productId': productId,
        'productName': productName,
        'stockLevel': stockLevel,
      },
    );
    
    await showNotification(notification);
  }

  /// Show system notifications
  Future<void> showSystemNotification({
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    bool persistent = false,
  }) async {
    final notification = DesktopNotification(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: message,
      priority: priority,
      category: NotificationCategory.system,
      persistent: persistent,
    );
    
    await showNotification(notification);
  }

  /// Show error notifications
  Future<void> showErrorNotification({
    required String title,
    required String error,
    String? details,
  }) async {
    final actions = [
      NotificationAction(
        id: 'view_details',
        label: 'View Details',
        onPressed: (notificationId, actionId) {
          _showErrorDetails(error, details);
        },
      ),
    ];

    final notification = DesktopNotification(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: error,
      priority: NotificationPriority.urgent,
      category: NotificationCategory.error,
      actions: details != null ? actions : [],
      payload: {
        'error': error,
        'details': details,
      },
    );
    
    await showNotification(notification);
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(String notificationId) async {
    if (!_isInitialized || _notificationsPlugin == null) return;

    try {
      final id = int.parse(notificationId.replaceAll(RegExp(r'[^0-9]'), '')) % 2147483647;
      await _notificationsPlugin!.cancel(id);
      _activeNotifications.remove(notificationId);
      
      debugPrint('Notification cancelled: $notificationId');
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized || _notificationsPlugin == null) return;

    try {
      await _notificationsPlugin!.cancelAll();
      _activeNotifications.clear();
      
      debugPrint('All notifications cancelled');
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }

  /// Convert priority to Linux importance level
  dynamic _getImportanceLevel(NotificationPriority priority) {
    // Stub implementation - would return LinuxNotificationImportance values
    return null;
  }

  /// Convert priority to Linux urgency level
  dynamic _getUrgencyLevel(NotificationPriority priority) {
    // Stub implementation - would return LinuxNotificationUrgency values
    return null;
  }

  /// Show initialization notification
  Future<void> _showInitializationNotification() async {
    if (kDebugMode) {
      await showSystemNotification(
        title: 'BizSync Desktop',
        message: 'Desktop notifications are now active',
        priority: NotificationPriority.low,
      );
    }
  }

  // Navigation handlers
  void _navigateToInvoices(Map<String, dynamic> payload) {
    debugPrint('Navigate to invoices: $payload');
  }

  void _navigateToInvoice(String invoiceNumber) {
    debugPrint('Navigate to invoice: $invoiceNumber');
  }

  void _navigateToPayments(Map<String, dynamic> payload) {
    debugPrint('Navigate to payments: $payload');
  }

  void _navigateToPayment(String paymentId) {
    debugPrint('Navigate to payment: $paymentId');
  }

  void _navigateToInventory(Map<String, dynamic> payload) {
    debugPrint('Navigate to inventory: $payload');
  }

  void _navigateToProduct(String productId) {
    debugPrint('Navigate to product: $productId');
  }

  void _navigateToDashboard() {
    debugPrint('Navigate to dashboard');
  }

  void _handleReminder(Map<String, dynamic> payload) {
    debugPrint('Handle reminder: $payload');
  }

  void _markInvoiceAsPaid(String invoiceNumber) {
    debugPrint('Mark invoice as paid: $invoiceNumber');
  }

  void _showRestockDialog(String productId) {
    debugPrint('Show restock dialog for product: $productId');
  }

  void _showErrorDetails(String error, String? details) {
    debugPrint('Show error details: $error - $details');
  }

  /// Get active notifications
  List<DesktopNotification> get activeNotifications => _activeNotifications.values.toList();

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of the desktop notifications service
  Future<void> dispose() async {
    await cancelAllNotifications();
    _isInitialized = false;
    debugPrint('Desktop notifications service disposed');
  }
}