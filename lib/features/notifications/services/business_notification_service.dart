import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_models.dart';
import '../models/notification_types.dart';
import '../models/notification_template.dart';
import 'enhanced_notification_service.dart';
import 'notification_template_service.dart';
import 'notification_scheduler.dart';

/// Business-specific notification service for invoices, payments, tax, etc.
class BusinessNotificationService {
  static final BusinessNotificationService _instance = 
      BusinessNotificationService._internal();
  factory BusinessNotificationService() => _instance;
  BusinessNotificationService._internal();

  final EnhancedNotificationService _notificationService = 
      EnhancedNotificationService();
  final NotificationTemplateService _templateService = 
      NotificationTemplateService();
  final NotificationScheduler _scheduler = NotificationScheduler();

  bool _initialized = false;
  Timer? _monitoringTimer;

  /// Initialize business notification service
  Future<void> initialize() async {
    if (_initialized) return;

    await _notificationService.initialize();
    await _templateService.initialize();
    await _scheduler.initialize();

    // Start business monitoring
    await _startBusinessMonitoring();

    _initialized = true;
  }

  /// Start monitoring business events for notifications
  Future<void> _startBusinessMonitoring() async {
    // Monitor every 30 minutes for business events
    _monitoringTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      await _checkInvoiceReminders();
      await _checkPaymentAlerts();
      await _checkTaxDeadlines();
      await _checkBackupStatus();
      await _generateBusinessInsights();
    });
  }

  // ======================== INVOICE NOTIFICATIONS ========================

  /// Send invoice due reminder
  Future<void> sendInvoiceDueReminder({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    required DateTime dueDate,
    required double amount,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'invoice_due_reminder',
      variables: {
        'invoiceNumber': invoiceNumber,
        'customerName': customerName,
        'dueDate': _formatDate(dueDate),
        'amount': _formatCurrency(amount, currency!),
      },
      additionalPayload: {
        'invoiceId': invoiceId,
        'actionType': 'view_invoice',
      },
    );
  }

  /// Send invoice overdue alert
  Future<void> sendInvoiceOverdueAlert({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    required DateTime originalDueDate,
    required double amount,
    required int daysPastDue,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'invoice_overdue',
      variables: {
        'invoiceNumber': invoiceNumber,
        'customerName': customerName,
        'originalDueDate': _formatDate(originalDueDate),
        'amount': _formatCurrency(amount, currency!),
        'daysPastDue': daysPastDue.toString(),
      },
      additionalPayload: {
        'invoiceId': invoiceId,
        'actionType': 'contact_customer',
        'priority': 'urgent',
      },
    );
  }

  /// Send invoice paid notification
  Future<void> sendInvoicePaidNotification({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    required double amount,
    required DateTime paidDate,
    String? paymentMethod,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'payment_received',
      variables: {
        'invoiceNumber': invoiceNumber,
        'customerName': customerName,
        'amount': _formatCurrency(amount, currency!),
        'paymentMethod': paymentMethod ?? 'Unknown',
        'receivedDate': _formatDate(paidDate),
      },
      additionalPayload: {
        'invoiceId': invoiceId,
        'actionType': 'view_payment',
      },
    );
  }

  /// Schedule invoice reminder series
  Future<void> scheduleInvoiceReminderSeries({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    required DateTime dueDate,
    required double amount,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    // Reminder 3 days before due date
    final reminder3Days = dueDate.subtract(const Duration(days: 3));
    if (reminder3Days.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        title: 'Invoice Due Soon - $invoiceNumber',
        body: 'Invoice $invoiceNumber for $customerName is due in 3 days',
        scheduledFor: reminder3Days,
        type: BusinessNotificationType.invoiceReminder,
        category: NotificationCategory.invoice,
        priority: NotificationPriority.medium,
        payload: {
          'invoiceId': invoiceId,
          'reminderType': '3_days',
        },
      );
    }

    // Reminder 1 day before due date
    final reminder1Day = dueDate.subtract(const Duration(days: 1));
    if (reminder1Day.isAfter(DateTime.now())) {
      await _notificationService.scheduleNotification(
        title: 'Invoice Due Tomorrow - $invoiceNumber',
        body: 'Invoice $invoiceNumber for $customerName is due tomorrow',
        scheduledFor: reminder1Day,
        type: BusinessNotificationType.invoiceReminder,
        category: NotificationCategory.invoice,
        priority: NotificationPriority.high,
        payload: {
          'invoiceId': invoiceId,
          'reminderType': '1_day',
        },
      );
    }

    // Overdue reminder 1 day after due date
    final overdueReminder = dueDate.add(const Duration(days: 1));
    await _notificationService.scheduleNotification(
      title: 'Invoice Overdue - $invoiceNumber',
      body: 'Invoice $invoiceNumber is now overdue',
      scheduledFor: overdueReminder,
      type: BusinessNotificationType.invoiceOverdue,
      category: NotificationCategory.invoice,
      priority: NotificationPriority.critical,
      payload: {
        'invoiceId': invoiceId,
        'reminderType': 'overdue',
      },
    );
  }

  /// Check for invoice reminders (called by monitoring timer)
  Future<void> _checkInvoiceReminders() async {
    try {
      // This would integrate with your invoice repository
      // For now, we'll simulate checking
      
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString('last_invoice_check');
      final now = DateTime.now();
      
      // Skip if checked recently (within last hour)
      if (lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        if (now.difference(lastCheckTime).inHours < 1) return;
      }

      // Here you would query your invoice database for:
      // 1. Invoices due within the next 3 days
      // 2. Overdue invoices
      // 3. Recently paid invoices

      await prefs.setString('last_invoice_check', now.toIso8601String());
    } catch (e) {
      print('Error checking invoice reminders: $e');
    }
  }

  // ======================== PAYMENT NOTIFICATIONS ========================

  /// Send payment received notification
  Future<void> sendPaymentReceivedNotification({
    required String paymentId,
    required String invoiceNumber,
    required String customerName,
    required double amount,
    required String paymentMethod,
    required DateTime receivedDate,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'payment_received',
      variables: {
        'amount': _formatCurrency(amount, currency!),
        'customerName': customerName,
        'invoiceNumber': invoiceNumber,
        'paymentMethod': paymentMethod,
        'receivedDate': _formatDate(receivedDate),
      },
      additionalPayload: {
        'paymentId': paymentId,
        'actionType': 'view_payment',
      },
    );
  }

  /// Send payment failed notification
  Future<void> sendPaymentFailedNotification({
    required String paymentId,
    required String invoiceNumber,
    required String customerName,
    required double amount,
    required String failureReason,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotification(
      title: 'Payment Failed',
      body: 'Payment of ${_formatCurrency(amount, currency!)} from $customerName failed: $failureReason',
      type: BusinessNotificationType.paymentFailed,
      category: NotificationCategory.payment,
      priority: NotificationPriority.critical,
      payload: {
        'paymentId': paymentId,
        'invoiceNumber': invoiceNumber,
        'actionType': 'retry_payment',
      },
      actions: [
        const NotificationAction(
          id: 'retry_payment',
          title: 'Retry Payment',
          type: NotificationActionType.custom,
        ),
        const NotificationAction(
          id: 'contact_customer',
          title: 'Contact Customer',
          type: NotificationActionType.custom,
        ),
      ],
    );
  }

  /// Check for payment alerts
  Future<void> _checkPaymentAlerts() async {
    try {
      // This would integrate with your payment service
      // Check for failed payments, pending payments, etc.
      
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString('last_payment_check');
      final now = DateTime.now();
      
      if (lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        if (now.difference(lastCheckTime).inHours < 1) return;
      }

      // Query payment database for alerts
      
      await prefs.setString('last_payment_check', now.toIso8601String());
    } catch (e) {
      print('Error checking payment alerts: $e');
    }
  }

  // ======================== TAX NOTIFICATIONS ========================

  /// Send tax deadline reminder
  Future<void> sendTaxDeadlineReminder({
    required String taxType,
    required DateTime deadlineDate,
    double? estimatedAmount,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    final daysUntilDeadline = deadlineDate.difference(DateTime.now()).inDays;

    await _notificationService.showNotificationFromTemplate(
      templateId: 'tax_deadline_reminder',
      variables: {
        'taxType': taxType,
        'deadlineDate': _formatDate(deadlineDate),
        'daysUntilDeadline': daysUntilDeadline.toString(),
        'estimatedAmount': estimatedAmount != null 
            ? _formatCurrency(estimatedAmount, currency!)
            : 'TBD',
      },
      additionalPayload: {
        'taxType': taxType,
        'actionType': 'open_tax_calculator',
      },
    );
  }

  /// Schedule tax deadline reminders
  Future<void> scheduleTaxDeadlineReminders({
    required String taxType,
    required DateTime deadlineDate,
    double? estimatedAmount,
  }) async {
    if (!_initialized) await initialize();

    // Reminders at 30, 14, 7, and 1 day intervals
    final reminderIntervals = [30, 14, 7, 1];
    
    for (final days in reminderIntervals) {
      final reminderDate = deadlineDate.subtract(Duration(days: days));
      
      if (reminderDate.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotification(
          title: 'Tax Deadline Approaching',
          body: '$taxType filing deadline is in $days days',
          scheduledFor: reminderDate,
          type: BusinessNotificationType.taxDeadline,
          category: NotificationCategory.tax,
          priority: days <= 7 ? NotificationPriority.high : NotificationPriority.medium,
          payload: {
            'taxType': taxType,
            'daysUntilDeadline': days.toString(),
          },
        );
      }
    }
  }

  /// Check for tax deadlines
  Future<void> _checkTaxDeadlines() async {
    try {
      // This would integrate with your tax service
      final now = DateTime.now();
      
      // Define common tax deadlines (this would come from your tax service)
      final taxDeadlines = [
        {
          'type': 'GST Filing',
          'deadline': DateTime(now.year, now.month + 1, 28),
        },
        {
          'type': 'Income Tax',
          'deadline': DateTime(now.year + 1, 4, 15),
        },
        {
          'type': 'Quarterly Tax',
          'deadline': _getNextQuarterEnd(),
        },
      ];

      for (final deadline in taxDeadlines) {
        final deadlineDate = deadline['deadline'] as DateTime;
        final daysUntilDeadline = deadlineDate.difference(now).inDays;
        
        if ([30, 14, 7, 1].contains(daysUntilDeadline)) {
          await sendTaxDeadlineReminder(
            taxType: deadline['type'] as String,
            deadlineDate: deadlineDate,
          );
        }
      }
    } catch (e) {
      print('Error checking tax deadlines: $e');
    }
  }

  DateTime _getNextQuarterEnd() {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final nextQuarter = currentQuarter == 4 ? 1 : currentQuarter + 1;
    final year = nextQuarter == 1 ? now.year + 1 : now.year;
    
    switch (nextQuarter) {
      case 1: return DateTime(year, 3, 31);
      case 2: return DateTime(year, 6, 30);
      case 3: return DateTime(year, 9, 30);
      case 4: return DateTime(year, 12, 31);
      default: return DateTime(year, 12, 31);
    }
  }

  // ======================== BACKUP NOTIFICATIONS ========================

  /// Send backup complete notification
  Future<void> sendBackupCompleteNotification({
    required DateTime completedTime,
    required int itemCount,
    required String backupSize,
    required String backupLocation,
    DateTime? nextBackup,
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'backup_complete',
      variables: {
        'completedTime': _formatDateTime(completedTime),
        'itemCount': itemCount.toString(),
        'backupSize': backupSize,
        'backupLocation': backupLocation,
        'nextBackup': nextBackup != null ? _formatDate(nextBackup) : 'Not scheduled',
      },
      additionalPayload: {
        'actionType': 'view_backup_details',
      },
    );
  }

  /// Send backup failed notification
  Future<void> sendBackupFailedNotification({
    required DateTime failedTime,
    required String errorMessage,
    DateTime? lastSuccessfulBackup,
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'backup_failed',
      variables: {
        'failedTime': _formatDateTime(failedTime),
        'errorMessage': errorMessage,
        'lastSuccessfulBackup': lastSuccessfulBackup != null 
            ? _formatDateTime(lastSuccessfulBackup)
            : 'Never',
      },
      additionalPayload: {
        'actionType': 'retry_backup',
        'priority': 'urgent',
      },
    );
  }

  /// Check backup status
  Future<void> _checkBackupStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupString = prefs.getString('last_backup_date');
      final now = DateTime.now();
      
      if (lastBackupString != null) {
        final lastBackup = DateTime.parse(lastBackupString);
        final daysSinceBackup = now.difference(lastBackup).inDays;
        
        // Remind if backup is overdue (7+ days)
        if (daysSinceBackup >= 7) {
          await _notificationService.showNotification(
            title: 'Backup Overdue',
            body: 'Last backup was $daysSinceBackup days ago. Consider backing up your data.',
            type: BusinessNotificationType.backupReminder,
            category: NotificationCategory.backup,
            priority: NotificationPriority.medium,
            actions: [
              const NotificationAction(
                id: 'start_backup',
                title: 'Start Backup',
                type: NotificationActionType.startBackup,
              ),
            ],
          );
        }
      } else {
        // No backup found - urgent reminder
        await _notificationService.showNotification(
          title: 'No Backup Found',
          body: 'No backup history found. Secure your business data with a backup.',
          type: BusinessNotificationType.backupReminder,
          category: NotificationCategory.backup,
          priority: NotificationPriority.high,
          actions: [
            const NotificationAction(
              id: 'start_backup',
              title: 'Start Backup',
              type: NotificationActionType.startBackup,
            ),
          ],
        );
      }
    } catch (e) {
      print('Error checking backup status: $e');
    }
  }

  // ======================== BUSINESS INSIGHTS ========================

  /// Send sales milestone notification
  Future<void> sendSalesMilestoneNotification({
    required String milestoneType,
    required String milestoneValue,
    required String period,
    required double percentageIncrease,
    required String previousValue,
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotificationFromTemplate(
      templateId: 'sales_milestone',
      variables: {
        'milestoneType': milestoneType,
        'milestoneValue': milestoneValue,
        'period': period,
        'percentageIncrease': percentageIncrease.toStringAsFixed(1),
        'previousValue': previousValue,
      },
      additionalPayload: {
        'actionType': 'view_analytics',
      },
    );
  }

  /// Send cash flow alert
  Future<void> sendCashFlowAlert({
    required String alertType,
    required double currentBalance,
    required double projectedBalance,
    required int daysToZero,
    String? currency = 'USD',
  }) async {
    if (!_initialized) await initialize();

    await _notificationService.showNotification(
      title: 'Cash Flow Alert',
      body: 'Current balance: ${_formatCurrency(currentBalance, currency!)}. '
            'Projected to reach zero in $daysToZero days.',
      type: BusinessNotificationType.cashFlowAlert,
      category: NotificationCategory.insight,
      priority: NotificationPriority.critical,
      bigText: 'Cash Flow Analysis:\n'
               'Current Balance: ${_formatCurrency(currentBalance, currency)}\n'
               'Projected Balance: ${_formatCurrency(projectedBalance, currency)}\n'
               'Days to Zero: $daysToZero\n\n'
               'Consider reviewing your upcoming expenses and receivables.',
      style: NotificationStyle.bigText,
      actions: [
        const NotificationAction(
          id: 'view_cash_flow',
          title: 'View Cash Flow',
          type: NotificationActionType.viewReport,
        ),
      ],
    );
  }

  /// Generate business insights
  Future<void> _generateBusinessInsights() async {
    try {
      // This would integrate with your analytics service
      final now = DateTime.now();
      
      // Example: Daily sales summary
      final prefs = await SharedPreferences.getInstance();
      final lastSalesReport = prefs.getString('last_sales_report_date');
      final today = DateTime(now.year, now.month, now.day);
      
      if (lastSalesReport == null || 
          DateTime.parse(lastSalesReport).isBefore(today)) {
        
        // Generate daily sales insight
        await _notificationService.showNotification(
          title: 'Daily Sales Summary',
          body: 'Your daily sales summary is ready to view.',
          type: BusinessNotificationType.salesMilestone,
          category: NotificationCategory.insight,
          priority: NotificationPriority.low,
          actions: [
            const NotificationAction(
              id: 'view_sales_report',
              title: 'View Report',
              type: NotificationActionType.viewReport,
            ),
          ],
        );
        
        await prefs.setString('last_sales_report_date', today.toIso8601String());
      }
    } catch (e) {
      print('Error generating business insights: $e');
    }
  }

  // ======================== UTILITY METHODS ========================

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount, String currency) {
    switch (currency) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'GBP':
        return '£${amount.toStringAsFixed(2)}';
      case 'SGD':
        return 'S\$${amount.toStringAsFixed(2)}';
      default:
        return '$currency ${amount.toStringAsFixed(2)}';
    }
  }

  /// Stop business monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
  }
}