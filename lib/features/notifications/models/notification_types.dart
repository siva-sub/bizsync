import 'package:json_annotation/json_annotation.dart';

part 'notification_types.g.dart';

/// Notification categories for better organization
enum NotificationCategory {
  invoice,
  payment,
  tax,
  backup,
  insight,
  reminder,
  system,
  custom
}

/// Business-specific notification types
enum BusinessNotificationType {
  // Invoice related
  invoiceDue,
  invoiceOverdue,
  invoiceReminder,
  invoicePaid,
  invoiceCancelled,
  
  // Payment related
  paymentReceived,
  paymentFailed,
  paymentDue,
  paymentReminder,
  
  // Tax related
  taxDeadline,
  taxCalculationComplete,
  taxFilingReminder,
  gstDue,
  
  // Backup related
  backupComplete,
  backupFailed,
  backupScheduled,
  backupReminder,
  
  // Business insights
  salesMilestone,
  revenueAlert,
  lowInventory,
  customerInsight,
  cashFlowAlert,
  
  // Reminders
  taskReminder,
  meetingReminder,
  followUpReminder,
  documentExpiry,
  
  // System
  syncComplete,
  syncFailed,
  updateAvailable,
  maintenanceMode,
  
  // Custom
  custom
}

/// Priority levels for notifications
enum NotificationPriority {
  critical,
  high,
  medium,
  low,
  info
}

/// Notification display styles
enum NotificationStyle {
  basic,
  expanded,
  inbox,
  bigText,
  bigPicture,
  messaging
}

/// Notification action types
enum NotificationActionType {
  view,
  dismiss,
  snooze,
  markAsPaid,
  createInvoice,
  viewReport,
  openCalculator,
  startBackup,
  custom
}

/// Notification delivery channels
enum NotificationChannel {
  urgent,
  business,
  reminders,
  insights,
  system,
  marketing
}

/// Frequency for recurring notifications
enum NotificationFrequency {
  once,
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
  custom
}

/// Time-based notification triggers
enum NotificationTrigger {
  immediate,
  delayed,
  scheduled,
  recurring,
  conditional,
  locationBased,
  eventBased
}

/// Notification delivery status
enum NotificationStatus {
  pending,
  scheduled,
  delivered,
  opened,
  dismissed,
  expired,
  cancelled,
  failed
}

@JsonSerializable()
class NotificationAction {
  final String id;
  final String title;
  final String? icon;
  final NotificationActionType type;
  final Map<String, dynamic>? payload;
  final bool requiresAuth;
  final bool destructive;

  const NotificationAction({
    required this.id,
    required this.title,
    this.icon,
    required this.type,
    this.payload,
    this.requiresAuth = false,
    this.destructive = false,
  });

  factory NotificationAction.fromJson(Map<String, dynamic> json) =>
      _$NotificationActionFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationActionToJson(this);
}

@JsonSerializable()
class NotificationChannelConfig {
  final NotificationChannel channel;
  final String name;
  final String description;
  final NotificationPriority defaultPriority;
  final bool enableVibration;
  final bool enableSound;
  final bool enableLights;
  final String? soundUri;
  final int? lightColor;
  final List<int>? vibrationPattern;
  final bool bypassDnd;
  final bool showBadge;

  const NotificationChannelConfig({
    required this.channel,
    required this.name,
    required this.description,
    this.defaultPriority = NotificationPriority.medium,
    this.enableVibration = true,
    this.enableSound = true,
    this.enableLights = true,
    this.soundUri,
    this.lightColor,
    this.vibrationPattern,
    this.bypassDnd = false,
    this.showBadge = true,
  });

  factory NotificationChannelConfig.fromJson(Map<String, dynamic> json) =>
      _$NotificationChannelConfigFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationChannelConfigToJson(this);
}

/// Extension methods for enum utilities
extension NotificationCategoryExtension on NotificationCategory {
  String get displayName {
    switch (this) {
      case NotificationCategory.invoice:
        return 'Invoices';
      case NotificationCategory.payment:
        return 'Payments';
      case NotificationCategory.tax:
        return 'Tax & Compliance';
      case NotificationCategory.backup:
        return 'Backup & Sync';
      case NotificationCategory.insight:
        return 'Business Insights';
      case NotificationCategory.reminder:
        return 'Reminders';
      case NotificationCategory.system:
        return 'System';
      case NotificationCategory.custom:
        return 'Custom';
    }
  }

  String get icon {
    switch (this) {
      case NotificationCategory.invoice:
        return 'receipt';
      case NotificationCategory.payment:
        return 'payment';
      case NotificationCategory.tax:
        return 'account_balance';
      case NotificationCategory.backup:
        return 'backup';
      case NotificationCategory.insight:
        return 'analytics';
      case NotificationCategory.reminder:
        return 'schedule';
      case NotificationCategory.system:
        return 'settings';
      case NotificationCategory.custom:
        return 'notifications';
    }
  }

  NotificationChannel get defaultChannel {
    switch (this) {
      case NotificationCategory.invoice:
      case NotificationCategory.payment:
      case NotificationCategory.tax:
        return NotificationChannel.business;
      case NotificationCategory.backup:
      case NotificationCategory.system:
        return NotificationChannel.system;
      case NotificationCategory.insight:
        return NotificationChannel.insights;
      case NotificationCategory.reminder:
        return NotificationChannel.reminders;
      case NotificationCategory.custom:
        return NotificationChannel.business;
    }
  }
}

extension BusinessNotificationTypeExtension on BusinessNotificationType {
  NotificationCategory get category {
    switch (this) {
      case BusinessNotificationType.invoiceDue:
      case BusinessNotificationType.invoiceOverdue:
      case BusinessNotificationType.invoiceReminder:
      case BusinessNotificationType.invoicePaid:
      case BusinessNotificationType.invoiceCancelled:
        return NotificationCategory.invoice;
      
      case BusinessNotificationType.paymentReceived:
      case BusinessNotificationType.paymentFailed:
      case BusinessNotificationType.paymentDue:
      case BusinessNotificationType.paymentReminder:
        return NotificationCategory.payment;
      
      case BusinessNotificationType.taxDeadline:
      case BusinessNotificationType.taxCalculationComplete:
      case BusinessNotificationType.taxFilingReminder:
      case BusinessNotificationType.gstDue:
        return NotificationCategory.tax;
      
      case BusinessNotificationType.backupComplete:
      case BusinessNotificationType.backupFailed:
      case BusinessNotificationType.backupScheduled:
      case BusinessNotificationType.backupReminder:
        return NotificationCategory.backup;
      
      case BusinessNotificationType.salesMilestone:
      case BusinessNotificationType.revenueAlert:
      case BusinessNotificationType.lowInventory:
      case BusinessNotificationType.customerInsight:
      case BusinessNotificationType.cashFlowAlert:
        return NotificationCategory.insight;
      
      case BusinessNotificationType.taskReminder:
      case BusinessNotificationType.meetingReminder:
      case BusinessNotificationType.followUpReminder:
      case BusinessNotificationType.documentExpiry:
        return NotificationCategory.reminder;
      
      case BusinessNotificationType.syncComplete:
      case BusinessNotificationType.syncFailed:
      case BusinessNotificationType.updateAvailable:
      case BusinessNotificationType.maintenanceMode:
        return NotificationCategory.system;
      
      case BusinessNotificationType.custom:
        return NotificationCategory.custom;
    }
  }

  NotificationPriority get defaultPriority {
    switch (this) {
      case BusinessNotificationType.invoiceOverdue:
      case BusinessNotificationType.paymentFailed:
      case BusinessNotificationType.taxDeadline:
      case BusinessNotificationType.backupFailed:
      case BusinessNotificationType.cashFlowAlert:
      case BusinessNotificationType.syncFailed:
        return NotificationPriority.critical;
      
      case BusinessNotificationType.invoiceDue:
      case BusinessNotificationType.paymentDue:
      case BusinessNotificationType.gstDue:
      case BusinessNotificationType.documentExpiry:
        return NotificationPriority.high;
      
      case BusinessNotificationType.invoiceReminder:
      case BusinessNotificationType.paymentReminder:
      case BusinessNotificationType.taxFilingReminder:
      case BusinessNotificationType.backupReminder:
      case BusinessNotificationType.taskReminder:
      case BusinessNotificationType.meetingReminder:
      case BusinessNotificationType.followUpReminder:
        return NotificationPriority.medium;
      
      case BusinessNotificationType.invoicePaid:
      case BusinessNotificationType.paymentReceived:
      case BusinessNotificationType.backupComplete:
      case BusinessNotificationType.syncComplete:
      case BusinessNotificationType.salesMilestone:
        return NotificationPriority.low;
      
      default:
        return NotificationPriority.info;
    }
  }

  String get displayTitle {
    switch (this) {
      case BusinessNotificationType.invoiceDue:
        return 'Invoice Due';
      case BusinessNotificationType.invoiceOverdue:
        return 'Invoice Overdue';
      case BusinessNotificationType.invoiceReminder:
        return 'Invoice Reminder';
      case BusinessNotificationType.invoicePaid:
        return 'Invoice Paid';
      case BusinessNotificationType.invoiceCancelled:
        return 'Invoice Cancelled';
      case BusinessNotificationType.paymentReceived:
        return 'Payment Received';
      case BusinessNotificationType.paymentFailed:
        return 'Payment Failed';
      case BusinessNotificationType.paymentDue:
        return 'Payment Due';
      case BusinessNotificationType.paymentReminder:
        return 'Payment Reminder';
      case BusinessNotificationType.taxDeadline:
        return 'Tax Deadline';
      case BusinessNotificationType.taxCalculationComplete:
        return 'Tax Calculation Complete';
      case BusinessNotificationType.taxFilingReminder:
        return 'Tax Filing Reminder';
      case BusinessNotificationType.gstDue:
        return 'GST Due';
      case BusinessNotificationType.backupComplete:
        return 'Backup Complete';
      case BusinessNotificationType.backupFailed:
        return 'Backup Failed';
      case BusinessNotificationType.backupScheduled:
        return 'Backup Scheduled';
      case BusinessNotificationType.backupReminder:
        return 'Backup Reminder';
      case BusinessNotificationType.salesMilestone:
        return 'Sales Milestone';
      case BusinessNotificationType.revenueAlert:
        return 'Revenue Alert';
      case BusinessNotificationType.lowInventory:
        return 'Low Inventory';
      case BusinessNotificationType.customerInsight:
        return 'Customer Insight';
      case BusinessNotificationType.cashFlowAlert:
        return 'Cash Flow Alert';
      case BusinessNotificationType.taskReminder:
        return 'Task Reminder';
      case BusinessNotificationType.meetingReminder:
        return 'Meeting Reminder';
      case BusinessNotificationType.followUpReminder:
        return 'Follow-up Reminder';
      case BusinessNotificationType.documentExpiry:
        return 'Document Expiry';
      case BusinessNotificationType.syncComplete:
        return 'Sync Complete';
      case BusinessNotificationType.syncFailed:
        return 'Sync Failed';
      case BusinessNotificationType.updateAvailable:
        return 'Update Available';
      case BusinessNotificationType.maintenanceMode:
        return 'Maintenance Mode';
      case BusinessNotificationType.custom:
        return 'Custom Notification';
    }
  }
}