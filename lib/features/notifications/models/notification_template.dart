import 'package:json_annotation/json_annotation.dart';
import 'notification_types.dart';

part 'notification_template.g.dart';

/// Template for generating notifications with dynamic content
@JsonSerializable()
class NotificationTemplate {
  final String id;
  final String name;
  final String description;
  final BusinessNotificationType type;
  final NotificationCategory category;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final String titleTemplate;
  final String bodyTemplate;
  final String? bigTextTemplate;
  final NotificationStyle style;
  final List<NotificationAction>? actions;
  final Map<String, dynamic>? defaultPayload;
  final List<String> requiredVariables;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;
  final String? largeIcon;
  final bool persistent;
  final bool autoCancel;
  final int? timeoutMs;
  final Map<String, dynamic>? metadata;

  const NotificationTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    this.priority = NotificationPriority.medium,
    required this.channel,
    required this.titleTemplate,
    required this.bodyTemplate,
    this.bigTextTemplate,
    this.style = NotificationStyle.basic,
    this.actions,
    this.defaultPayload,
    this.requiredVariables = const [],
    this.enabled = true,
    required this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.largeIcon,
    this.persistent = false,
    this.autoCancel = true,
    this.timeoutMs,
    this.metadata,
  });

  factory NotificationTemplate.fromJson(Map<String, dynamic> json) =>
      _$NotificationTemplateFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationTemplateToJson(this);

  /// Generate notification from template with provided variables
  String generateTitle(Map<String, dynamic> variables) {
    return _substituteVariables(titleTemplate, variables);
  }

  String generateBody(Map<String, dynamic> variables) {
    return _substituteVariables(bodyTemplate, variables);
  }

  String? generateBigText(Map<String, dynamic> variables) {
    if (bigTextTemplate == null) return null;
    return _substituteVariables(bigTextTemplate!, variables);
  }

  String _substituteVariables(String template, Map<String, dynamic> variables) {
    String result = template;
    for (final entry in variables.entries) {
      final placeholder = '{{${entry.key}}}';
      result = result.replaceAll(placeholder, entry.value.toString());
    }
    return result;
  }

  bool validateVariables(Map<String, dynamic> variables) {
    for (final required in requiredVariables) {
      if (!variables.containsKey(required) || variables[required] == null) {
        return false;
      }
    }
    return true;
  }

  List<String> getMissingVariables(Map<String, dynamic> variables) {
    return requiredVariables
        .where((required) => !variables.containsKey(required) || variables[required] == null)
        .toList();
  }
}

/// Pre-defined notification templates for common business scenarios
class NotificationTemplates {
  static final List<NotificationTemplate> defaultTemplates = [
    // Invoice Templates
    NotificationTemplate(
      id: 'invoice_due_reminder',
      name: 'Invoice Due Reminder',
      description: 'Reminds about upcoming invoice due date',
      type: BusinessNotificationType.invoiceDue,
      category: NotificationCategory.invoice,
      priority: NotificationPriority.high,
      channel: NotificationChannel.business,
      titleTemplate: 'Invoice {{invoiceNumber}} Due Soon',
      bodyTemplate: 'Invoice {{invoiceNumber}} for {{customerName}} is due on {{dueDate}}. Amount: {{amount}}',
      bigTextTemplate: 'Invoice Details:\nNumber: {{invoiceNumber}}\nCustomer: {{customerName}}\nAmount: {{amount}}\nDue Date: {{dueDate}}\n\nTap to view details or send reminder.',
      style: NotificationStyle.bigText,
      requiredVariables: ['invoiceNumber', 'customerName', 'dueDate', 'amount'],
      actions: [
        NotificationAction(
          id: 'view_invoice',
          title: 'View Invoice',
          type: NotificationActionType.view,
        ),
        NotificationAction(
          id: 'send_reminder',
          title: 'Send Reminder',
          type: NotificationActionType.custom,
        ),
      ],
      createdAt: DateTime.now() // Default creation time
    ),

    NotificationTemplate(
      id: 'invoice_overdue',
      name: 'Invoice Overdue Alert',
      description: 'Alert for overdue invoices',
      type: BusinessNotificationType.invoiceOverdue,
      category: NotificationCategory.invoice,
      priority: NotificationPriority.critical,
      channel: NotificationChannel.urgent,
      titleTemplate: 'OVERDUE: Invoice {{invoiceNumber}}',
      bodyTemplate: 'Invoice {{invoiceNumber}} is {{daysPastDue}} days overdue. Amount: {{amount}}',
      bigTextTemplate: 'Overdue Invoice Alert:\nNumber: {{invoiceNumber}}\nCustomer: {{customerName}}\nAmount: {{amount}}\nDays Overdue: {{daysPastDue}}\nOriginal Due Date: {{originalDueDate}}\n\nImmediate action required!',
      style: NotificationStyle.bigText,
      persistent: true,
      requiredVariables: ['invoiceNumber', 'customerName', 'amount', 'daysPastDue', 'originalDueDate'],
      actions: [
        NotificationAction(
          id: 'view_invoice',
          title: 'View Invoice',
          type: NotificationActionType.view,
        ),
        NotificationAction(
          id: 'contact_customer',
          title: 'Contact Customer',
          type: NotificationActionType.custom,
        ),
      ],
      createdAt: DateTime.now(),
    ),

    // Payment Templates
    NotificationTemplate(
      id: 'payment_received',
      name: 'Payment Received',
      description: 'Notification when payment is received',
      type: BusinessNotificationType.paymentReceived,
      category: NotificationCategory.payment,
      priority: NotificationPriority.low,
      channel: NotificationChannel.business,
      titleTemplate: 'Payment Received - {{amount}}',
      bodyTemplate: 'Received {{amount}} from {{customerName}} for invoice {{invoiceNumber}}',
      bigTextTemplate: 'Payment Details:\nAmount: {{amount}}\nFrom: {{customerName}}\nInvoice: {{invoiceNumber}}\nPayment Method: {{paymentMethod}}\nReceived: {{receivedDate}}',
      style: NotificationStyle.bigText,
      requiredVariables: ['amount', 'customerName', 'invoiceNumber', 'paymentMethod', 'receivedDate'],
      actions: [
        NotificationAction(
          id: 'view_payment',
          title: 'View Payment',
          type: NotificationActionType.view,
        ),
      ],
      createdAt: DateTime.now(),
    ),

    // Tax Templates
    NotificationTemplate(
      id: 'tax_deadline_reminder',
      name: 'Tax Deadline Reminder',
      description: 'Reminder for upcoming tax deadlines',
      type: BusinessNotificationType.taxDeadline,
      category: NotificationCategory.tax,
      priority: NotificationPriority.high,
      channel: NotificationChannel.business,
      titleTemplate: 'Tax Deadline: {{taxType}}',
      bodyTemplate: '{{taxType}} filing deadline is {{daysUntilDeadline}} days away ({{deadlineDate}})',
      bigTextTemplate: 'Tax Filing Reminder:\nType: {{taxType}}\nDeadline: {{deadlineDate}}\nDays Remaining: {{daysUntilDeadline}}\nEstimated Amount: {{estimatedAmount}}\n\nPrepare your documents now!',
      style: NotificationStyle.bigText,
      requiredVariables: ['taxType', 'deadlineDate', 'daysUntilDeadline'],
      actions: [
        NotificationAction(
          id: 'open_tax_calculator',
          title: 'Open Calculator',
          type: NotificationActionType.openCalculator,
        ),
        NotificationAction(
          id: 'view_requirements',
          title: 'View Requirements',
          type: NotificationActionType.view,
        ),
      ],
      createdAt: DateTime.now(),
    ),

    // Backup Templates
    NotificationTemplate(
      id: 'backup_complete',
      name: 'Backup Complete',
      description: 'Notification when backup is completed',
      type: BusinessNotificationType.backupComplete,
      category: NotificationCategory.backup,
      priority: NotificationPriority.low,
      channel: NotificationChannel.system,
      titleTemplate: 'Backup Completed Successfully',
      bodyTemplate: 'Your data backup finished at {{completedTime}}. {{itemCount}} items backed up.',
      bigTextTemplate: 'Backup Summary:\nCompleted: {{completedTime}}\nItems Backed Up: {{itemCount}}\nBackup Size: {{backupSize}}\nLocation: {{backupLocation}}\nNext Scheduled: {{nextBackup}}',
      style: NotificationStyle.bigText,
      requiredVariables: ['completedTime', 'itemCount'],
      actions: [
        NotificationAction(
          id: 'view_backup_details',
          title: 'View Details',
          type: NotificationActionType.view,
        ),
      ],
      createdAt: DateTime.now(),
    ),

    NotificationTemplate(
      id: 'backup_failed',
      name: 'Backup Failed',
      description: 'Alert when backup fails',
      type: BusinessNotificationType.backupFailed,
      category: NotificationCategory.backup,
      priority: NotificationPriority.critical,
      channel: NotificationChannel.urgent,
      titleTemplate: 'Backup Failed',
      bodyTemplate: 'Data backup failed at {{failedTime}}. Error: {{errorMessage}}',
      bigTextTemplate: 'Backup Failure Details:\nFailed At: {{failedTime}}\nError: {{errorMessage}}\nLast Successful Backup: {{lastSuccessfulBackup}}\n\nImmediate attention required!',
      style: NotificationStyle.bigText,
      persistent: true,
      requiredVariables: ['failedTime', 'errorMessage'],
      actions: [
        NotificationAction(
          id: 'retry_backup',
          title: 'Retry Backup',
          type: NotificationActionType.startBackup,
        ),
        NotificationAction(
          id: 'view_error_details',
          title: 'View Details',
          type: NotificationActionType.view,
        ),
      ],
      createdAt: DateTime.now(),
    ),

    // Business Insights Templates
    NotificationTemplate(
      id: 'sales_milestone',
      name: 'Sales Milestone Achieved',
      description: 'Celebration notification for sales milestones',
      type: BusinessNotificationType.salesMilestone,
      category: NotificationCategory.insight,
      priority: NotificationPriority.low,
      channel: NotificationChannel.insights,
      titleTemplate: 'Congratulations! {{milestoneType}} Achieved',
      bodyTemplate: 'You\'ve reached {{milestoneValue}} in {{period}}. {{percentageIncrease}}% increase!',
      bigTextTemplate: 'Sales Milestone Celebration:\n{{milestoneType}}: {{milestoneValue}}\nPeriod: {{period}}\nIncrease: {{percentageIncrease}}%\nPrevious: {{previousValue}}\n\nKeep up the great work!',
      style: NotificationStyle.bigText,
      requiredVariables: ['milestoneType', 'milestoneValue', 'period', 'percentageIncrease'],
      actions: [
        NotificationAction(
          id: 'view_analytics',
          title: 'View Analytics',
          type: NotificationActionType.viewReport,
        ),
      ],
      createdAt: DateTime.now(),
    ),

    // Reminder Templates
    NotificationTemplate(
      id: 'task_reminder',
      name: 'Task Reminder',
      description: 'General task reminder notification',
      type: BusinessNotificationType.taskReminder,
      category: NotificationCategory.reminder,
      priority: NotificationPriority.medium,
      channel: NotificationChannel.reminders,
      titleTemplate: 'Task Reminder: {{taskTitle}}',
      bodyTemplate: '{{taskTitle}} is due {{dueTime}}. Priority: {{priority}}',
      bigTextTemplate: 'Task Details:\nTitle: {{taskTitle}}\nDue: {{dueTime}}\nPriority: {{priority}}\nDescription: {{taskDescription}}\n\nTap to mark as complete or snooze.',
      style: NotificationStyle.bigText,
      requiredVariables: ['taskTitle', 'dueTime', 'priority'],
      actions: [
        NotificationAction(
          id: 'mark_complete',
          title: 'Mark Complete',
          type: NotificationActionType.custom,
        ),
        NotificationAction(
          id: 'snooze',
          title: 'Snooze',
          type: NotificationActionType.snooze,
        ),
      ],
      createdAt: DateTime.now(),
    ),
  ];

  static NotificationTemplate? findTemplate(String id) {
    try {
      return defaultTemplates.firstWhere((template) => template.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<NotificationTemplate> getTemplatesByCategory(NotificationCategory category) {
    return defaultTemplates.where((template) => template.category == category).toList();
  }

  static List<NotificationTemplate> getTemplatesByType(BusinessNotificationType type) {
    return defaultTemplates.where((template) => template.type == type).toList();
  }
}