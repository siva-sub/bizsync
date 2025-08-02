# BizSync Notification System Integration Guide

## Overview

The BizSync notification system is a comprehensive, offline-first notification solution designed specifically for business applications. It provides intelligent scheduling, advanced templating, business-specific features, and detailed analytics.

## Architecture

### Core Components

1. **Enhanced Notification Service** (`enhanced_notification_service.dart`)
   - Main service handling notification display and management
   - Channel management with priority-based routing
   - Intelligent batching and scheduling
   - Real-time notification streams

2. **Business Notification Service** (`business_notification_service.dart`)
   - Business-specific notification logic
   - Invoice, payment, tax, and backup notifications
   - Automated monitoring and alerting
   - Integration with existing business services

3. **Background Task Service** (`background_task_service.dart`)
   - Offline notification processing
   - Scheduled task execution
   - Background monitoring of business metrics
   - Work manager integration

4. **Notification Scheduler** (`notification_scheduler.dart`)
   - Advanced scheduling with recurrence rules
   - Conditional notifications
   - Context-aware delivery
   - Maintenance and cleanup

5. **Template Service** (`notification_template_service.dart`)
   - Dynamic notification templates
   - Template management and analytics
   - Import/export functionality
   - Usage tracking

## Key Features

### 1. Business-Specific Notifications

- **Invoice Notifications**: Due, overdue, paid, cancelled
- **Payment Notifications**: Received, failed, reminders
- **Tax Notifications**: Deadline reminders, filing alerts
- **Backup Notifications**: Complete, failed, scheduled
- **Business Insights**: Sales milestones, cash flow alerts
- **Custom Notifications**: Flexible business rules

### 2. Intelligent Scheduling

- **Smart Timing**: Based on user activity patterns
- **Business Hours**: Respect working hours
- **Do Not Disturb**: Quiet hours configuration
- **Batching**: Group related notifications
- **Context Awareness**: App usage and screen time

### 3. Advanced Features

- **Rich Notifications**: Actions, progress bars, big text
- **Notification Channels**: Priority-based organization
- **Templates**: Reusable notification patterns
- **Analytics**: Engagement tracking and insights
- **Offline Support**: Works completely offline

### 4. UI Components

- **Notification Center**: Comprehensive notification management
- **Settings Screen**: Granular configuration options
- **History Screen**: Analytics and insights
- **Widgets**: Reusable notification components

## Integration Steps

### 1. Add to App Providers

```dart
// In your app_providers.dart
final notificationServiceProvider = Provider<EnhancedNotificationService>((ref) {
  return EnhancedNotificationService();
});

final businessNotificationServiceProvider = Provider<BusinessNotificationService>((ref) {
  return BusinessNotificationService();
});
```

### 2. Initialize in Main App

```dart
// In your main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification system
  final notificationService = EnhancedNotificationService();
  await notificationService.initialize();
  
  final businessService = BusinessNotificationService();
  await businessService.initialize();
  
  runApp(ProviderScope(child: MyApp()));
}
```

### 3. Add to Navigation

```dart
// Add notification routes
routes: {
  '/notifications': (context) => const NotificationCenterScreen(),
  '/notifications/settings': (context) => const NotificationSettingsScreen(),
  '/notifications/history': (context) => const NotificationHistoryScreen(),
  '/notifications/detail': (context) => NotificationDetailScreen(
    notificationId: ModalRoute.of(context)!.settings.arguments as String,
  ),
}
```

### 4. Integration with Business Logic

#### Invoice Service Integration

```dart
// In your invoice service
class InvoiceService {
  final BusinessNotificationService _notificationService;
  
  Future<void> createInvoice(Invoice invoice) async {
    // Create invoice logic...
    
    // Schedule reminders
    await _notificationService.scheduleInvoiceReminderSeries(
      invoiceId: invoice.id,
      invoiceNumber: invoice.number,
      customerName: invoice.customer.name,
      dueDate: invoice.dueDate,
      amount: invoice.total,
    );
  }
  
  Future<void> markInvoiceAsPaid(String invoiceId, Payment payment) async {
    // Payment logic...
    
    // Send notification
    await _notificationService.sendInvoicePaidNotification(
      invoiceId: invoiceId,
      invoiceNumber: invoice.number,
      customerName: invoice.customer.name,
      amount: payment.amount,
      paidDate: payment.date,
      paymentMethod: payment.method,
    );
  }
}
```

#### Tax Service Integration

```dart
// In your tax service
class TaxService {
  final BusinessNotificationService _notificationService;
  
  Future<void> scheduleDeadlineReminders() async {
    final deadlines = await getTaxDeadlines();
    
    for (final deadline in deadlines) {
      await _notificationService.scheduleTaxDeadlineReminders(
        taxType: deadline.type,
        deadlineDate: deadline.date,
        estimatedAmount: deadline.estimatedAmount,
      );
    }
  }
}
```

#### Backup Service Integration

```dart
// In your backup service
class BackupService {
  final BusinessNotificationService _notificationService;
  
  Future<void> performBackup() async {
    try {
      // Backup logic...
      final result = await createBackup();
      
      await _notificationService.sendBackupCompleteNotification(
        completedTime: DateTime.now(),
        itemCount: result.itemCount,
        backupSize: result.size,
        backupLocation: result.location,
        nextBackup: result.nextScheduled,
      );
    } catch (e) {
      await _notificationService.sendBackupFailedNotification(
        failedTime: DateTime.now(),
        errorMessage: e.toString(),
        lastSuccessfulBackup: await getLastSuccessfulBackup(),
      );
    }
  }
}
```

### 5. Custom Notification Templates

```dart
// Create custom template
final templateService = NotificationTemplateService();

final customTemplate = await templateService.createCustomTemplate(
  name: 'Low Stock Alert',
  description: 'Alert when product stock is low',
  type: BusinessNotificationType.lowInventory,
  category: NotificationCategory.insight,
  titleTemplate: 'Low Stock: {{productName}}',
  bodyTemplate: 'Only {{stockLevel}} units left of {{productName}}',
  requiredVariables: ['productName', 'stockLevel'],
  actions: [
    NotificationAction(
      id: 'reorder',
      title: 'Reorder',
      type: NotificationActionType.custom,
    ),
  ],
);

// Use template
await notificationService.showNotificationFromTemplate(
  templateId: customTemplate.id,
  variables: {
    'productName': 'Widget Pro',
    'stockLevel': '3',
  },
);
```

## Configuration

### Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<receiver android:name="io.flutter.plugins.androidalarmmanager.AlarmService" />
<service android:name="io.flutter.plugins.androidalarmmanager.AlarmBroadcastReceiver" />
```

### Background Tasks Setup

The system uses `workmanager` for background processing. Tasks are automatically registered during initialization:

- **Notification Scheduler**: Runs every 15 minutes
- **Cleanup Task**: Runs daily
- **Business Metrics Check**: Runs every 4 hours
- **Invoice Reminders**: Runs hourly during business hours
- **Backup Reminders**: Runs daily
- **Tax Deadline Checks**: Runs daily at 9 AM

## Usage Examples

### Basic Notification

```dart
await notificationService.showNotification(
  title: 'Payment Received',
  body: 'Received \$500.00 from John Doe',
  type: BusinessNotificationType.paymentReceived,
  category: NotificationCategory.payment,
  priority: NotificationPriority.medium,
);
```

### Scheduled Notification

```dart
await notificationService.scheduleNotification(
  title: 'Monthly Report Due',
  body: 'Your monthly financial report is due tomorrow',
  scheduledFor: DateTime.now().add(Duration(days: 1)),
  type: BusinessNotificationType.taskReminder,
  category: NotificationCategory.reminder,
);
```

### Recurring Notification

```dart
final recurrenceRule = NotificationRecurrenceRule(
  id: 'monthly-backup',
  frequency: NotificationFrequency.monthly,
  daysOfMonth: [1], // First day of each month
);

await scheduler.scheduleRecurringNotification(
  templateId: 'backup_reminder',
  variables: {'backupType': 'Monthly'},
  firstOccurrence: DateTime.now().add(Duration(days: 30)),
  recurrenceRule: recurrenceRule,
);
```

### Conditional Notification

```dart
await scheduler.scheduleConditionalNotification(
  templateId: 'cash_flow_alert',
  variables: {'threshold': '1000'},
  conditions: {
    'cashBalance': {'lessThan': 1000},
    'businessHours': true,
  },
);
```

## Testing

### Unit Tests

```dart
void main() {
  group('Notification Service Tests', () {
    late EnhancedNotificationService service;
    
    setUp(() async {
      service = EnhancedNotificationService();
      await service.initialize();
    });
    
    test('should show notification', () async {
      await service.showNotification(
        title: 'Test',
        body: 'Test body',
      );
      
      final notifications = service.getActiveNotifications();
      expect(notifications.length, 1);
      expect(notifications.first.title, 'Test');
    });
  });
}
```

### Integration Tests

```dart
void main() {
  group('Business Notification Integration', () {
    testWidgets('should show invoice reminder', (tester) async {
      await tester.pumpWidget(MyApp());
      
      final businessService = BusinessNotificationService();
      await businessService.initialize();
      
      await businessService.sendInvoiceDueReminder(
        invoiceId: 'test-invoice',
        invoiceNumber: 'INV-001',
        customerName: 'Test Customer',
        dueDate: DateTime.now().add(Duration(days: 3)),
        amount: 500.0,
      );
      
      await tester.pump();
      
      // Verify notification appears
      expect(find.text('Invoice Due Soon'), findsOneWidget);
    });
  });
}
```

## Performance Considerations

1. **Memory Management**
   - Notifications are automatically cleaned up after 30 days
   - Metrics are pruned regularly
   - Use pagination for large notification lists

2. **Battery Optimization**
   - Background tasks are optimized for minimal battery usage
   - Intelligent scheduling reduces unnecessary wake-ups
   - Batching reduces notification frequency

3. **Storage Efficiency**
   - Notifications are stored efficiently using SharedPreferences
   - Large payloads are compressed
   - Old data is automatically purged

## Monitoring and Analytics

The system provides comprehensive analytics:

- **Engagement Metrics**: Open rates, action rates, dismissal rates
- **Performance Insights**: Category distribution, peak hours
- **Usage Patterns**: Daily averages, common priorities
- **Recommendations**: AI-generated optimization suggestions

Access analytics through:

```dart
final metrics = ref.watch(notificationMetricsProvider);
final summary = NotificationUtils.generateAnalyticsSummary(metrics);

print('Open rate: ${(summary.openRate * 100).toStringAsFixed(1)}%');
print('Average engagement: ${(summary.averageEngagement * 100).toStringAsFixed(1)}%');
```

## Troubleshooting

### Common Issues

1. **Notifications not appearing**
   - Check permissions in device settings
   - Verify notification channels are created
   - Ensure service is initialized

2. **Background tasks not running**
   - Check battery optimization settings
   - Verify WorkManager is properly initialized
   - Review device-specific restrictions

3. **Poor engagement rates**
   - Review notification timing
   - Improve notification content
   - Enable intelligent scheduling

### Debug Mode

Enable debug logging:

```dart
await Workmanager().initialize(
  callbackDispatcher,
  isInDebugMode: true, // Enable for debugging
);
```

## Security Considerations

1. **Data Protection**
   - Notification data is stored securely
   - Sensitive information is not logged
   - Background tasks follow security best practices

2. **Permission Handling**
   - Graceful degradation when permissions are denied
   - User-friendly permission request flows
   - Respect user privacy preferences

## Future Enhancements

1. **Machine Learning**
   - Predictive notification timing
   - Content optimization based on engagement
   - Anomaly detection for business metrics

2. **Cross-Platform Sync**
   - Notification sync across devices
   - Cloud-based notification history
   - Multi-user support

3. **Advanced Integrations**
   - Calendar integration
   - Email/SMS fallback
   - Third-party service webhooks

## Support

For technical support or questions:

1. Check the inline documentation in the code
2. Review test files for usage examples
3. Refer to Flutter's notification documentation
4. Check device-specific notification settings

The notification system is designed to be robust, scalable, and maintainable while providing excellent user experience and business value.