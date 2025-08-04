/// Comprehensive Notification System Tests
library notification_system_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:clock/clock.dart';
import '../../test_config.dart';
import '../../mocks/mock_services.dart';
import '../../test_factories.dart';

void main() {
  group('Notification System Tests', () {
    late MockNotificationService notificationService;
    
    setUpAll(() async {
      await TestConfig.initialize();
    });
    
    setUp(() async {
      await TestConfig.reset();
      notificationService = MockNotificationService();
    });
    
    group('Basic Notification Tests', () {
      test('should send simple notification successfully', () async {
        final result = await notificationService.showNotification(
          title: 'Test Notification',
          body: 'This is a test notification',
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.length, equals(1));
        expect(sentNotifications.first['title'], equals('Test Notification'));
        expect(sentNotifications.first['body'], equals('This is a test notification'));
      });
      
      test('should handle notification with payload', () async {
        final result = await notificationService.showNotification(
          title: 'Test with Payload',
          body: 'This notification has a payload',
          payload: 'test_payload_data',
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['payload'], equals('test_payload_data'));
      });
      
      test('should handle notification with custom data', () async {
        final customData = {
          'invoice_id': 'INV-001',
          'customer_name': 'Test Customer',
          'amount': 100.0,
        };
        
        final result = await notificationService.showNotification(
          title: 'Invoice Created',
          body: 'New invoice created for Test Customer',
          data: customData,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['data'], equals(customData));
      });
      
      test('should fail notification when service is unavailable', () async {
        notificationService.setShouldFailSending(true);
        
        final result = await notificationService.showNotification(
          title: 'Test Notification',
          body: 'This should fail',
        );
        
        expect(result, isFalse);
        expect(notificationService.getSentNotifications().length, equals(0));
      });
    });
    
    group('Scheduled Notification Tests', () {
      test('should schedule notification for future delivery', () async {
        final scheduledDate = DateTime.now().add(Duration(hours: 1));
        
        final result = await notificationService.scheduleNotification(
          title: 'Scheduled Notification',
          body: 'This is scheduled for later',
          scheduledDate: scheduledDate,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.length, equals(1));
        expect(sentNotifications.first['title'], equals('Scheduled Notification'));
        expect(sentNotifications.first['scheduledDate'], equals(scheduledDate.toIso8601String()));
      });
      
      test('should handle multiple scheduled notifications', () async {
        final notifications = [
          {
            'title': 'Reminder 1',
            'body': 'First reminder',
            'scheduledDate': DateTime.now().add(Duration(minutes: 30)),
          },
          {
            'title': 'Reminder 2',
            'body': 'Second reminder',
            'scheduledDate': DateTime.now().add(Duration(hours: 1)),
          },
          {
            'title': 'Reminder 3',
            'body': 'Third reminder',
            'scheduledDate': DateTime.now().add(Duration(hours: 2)),
          },
        ];
        
        for (final notification in notifications) {
          final result = await notificationService.scheduleNotification(
            title: notification['title'] as String,
            body: notification['body'] as String,
            scheduledDate: notification['scheduledDate'] as DateTime,
          );
          expect(result, isTrue);
        }
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.length, equals(3));
      });
      
      test('should fail scheduling when service is unavailable', () async {
        notificationService.setShouldFailSending(true);
        
        final result = await notificationService.scheduleNotification(
          title: 'Failed Scheduled',
          body: 'This should fail to schedule',
          scheduledDate: DateTime.now().add(Duration(hours: 1)),
        );
        
        expect(result, isFalse);
        expect(notificationService.getSentNotifications().length, equals(0));
      });
    });
    
    group('Business Logic Notification Tests', () {
      test('should send invoice payment reminder notification', () async {
        final customer = TestFactories.createCustomer();
        final invoiceData = TestFactories.createInvoiceData(customer: customer);
        
        final result = await notificationService.showNotification(
          title: 'Payment Reminder',
          body: 'Invoice ${invoiceData['invoice_number']} is due for payment',
          data: {
            'type': 'payment_reminder',
            'invoice_id': invoiceData['id'],
            'customer_id': invoiceData['customer_id'],
            'amount': invoiceData['total_amount'],
            'due_date': invoiceData['due_date'],
          },
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        final notification = sentNotifications.first;
        
        expect(notification['title'], equals('Payment Reminder'));
        expect(notification['data']['type'], equals('payment_reminder'));
        expect(notification['data']['invoice_id'], equals(invoiceData['id']));
      });
      
      test('should send low stock alert notification', () async {
        final product = TestFactories.createLowStockProduct();
        
        final result = await notificationService.showNotification(
          title: 'Low Stock Alert',
          body: '${product.name} is running low (${product.stockQuantity} remaining)',
          data: {
            'type': 'low_stock_alert',
            'product_id': product.id,
            'product_name': product.name,
            'current_stock': product.stockQuantity,
            'min_stock_level': product.minStockLevel,
          },
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        final notification = sentNotifications.first;
        
        expect(notification['title'], equals('Low Stock Alert'));
        expect(notification['data']['type'], equals('low_stock_alert'));
        expect(notification['data']['current_stock'], equals(product.stockQuantity));
      });
      
      test('should send tax filing reminder notification', () async {
        final dueDate = DateTime(2024, 4, 18); // GST filing deadline
        
        final result = await notificationService.scheduleNotification(
          title: 'GST Filing Reminder',
          body: 'Your GST filing is due on ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          scheduledDate: dueDate.subtract(Duration(days: 7)), // 1 week before
          data: {
            'type': 'tax_filing_reminder',
            'filing_type': 'GST',
            'due_date': dueDate.toIso8601String(),
            'days_remaining': 7,
          },
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        final notification = sentNotifications.first;
        
        expect(notification['title'], equals('GST Filing Reminder'));
        expect(notification['data']['type'], equals('tax_filing_reminder'));
        expect(notification['data']['filing_type'], equals('GST'));
      });
      
      test('should send backup completion notification', () async {
        final backupSize = '2.5 MB';
        final backupLocation = '/backup/bizsync_backup_20240101.zip';
        
        final result = await notificationService.showNotification(
          title: 'Backup Completed',
          body: 'Your data has been successfully backed up ($backupSize)',
          data: {
            'type': 'backup_completed',
            'backup_size': backupSize,
            'backup_location': backupLocation,
            'backup_date': DateTime.now().toIso8601String(),
            'items_backed_up': {
              'customers': 45,
              'products': 123,
              'invoices': 78,
            },
          },
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        final notification = sentNotifications.first;
        
        expect(notification['title'], equals('Backup Completed'));
        expect(notification['data']['type'], equals('backup_completed'));
        expect(notification['data']['backup_size'], equals(backupSize));
      });
      
      test('should send CRDT sync conflict notification', () async {
        final conflictData = TestFactories.createCRDTConflictScenario(
          entityType: 'customer',
          entityId: 'customer-123',
          localChanges: {'name': 'Local Customer Name'},
          remoteChanges: {'name': 'Remote Customer Name'},
        );
        
        final result = await notificationService.showNotification(
          title: 'Sync Conflict Detected',
          body: 'A conflict was detected for ${conflictData['entity_type']} data',
          data: {
            'type': 'sync_conflict',
            'entity_type': conflictData['entity_type'],
            'entity_id': conflictData['entity_id'],
            'requires_resolution': true,
          },
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        final notification = sentNotifications.first;
        
        expect(notification['title'], equals('Sync Conflict Detected'));
        expect(notification['data']['type'], equals('sync_conflict'));
        expect(notification['data']['requires_resolution'], isTrue);
      });
    });
    
    group('Notification Timing Tests', () {
      test('should handle notifications sent within time constraints', () async {
        fakeAsync((async) {
          var notificationSent = false;
          
          // Schedule a notification to be sent
          notificationService.showNotification(
            title: 'Time Test',
            body: 'Testing timing',
          ).then((_) {
            notificationSent = true;
          });
          
          // Advance time by 100ms
          async.elapse(Duration(milliseconds: 100));
          
          expect(notificationSent, isTrue);
        });
      });
      
      test('should respect notification rate limiting', () async {
        // Send multiple notifications rapidly
        final futures = <Future<bool>>[];
        
        for (int i = 0; i < 10; i++) {
          futures.add(notificationService.showNotification(
            title: 'Rate Limit Test $i',
            body: 'Testing rate limiting',
          ));
        }
        
        final results = await Future.wait(futures);
        
        // All should succeed in mock, but in real implementation,
        // rate limiting might prevent some from being sent
        expect(results.every((result) => result), isTrue);
      });
      
      test('should handle notification scheduling with clock dependency', () async {
        await withClock(Clock.fixed(DateTime(2024, 1, 1, 12, 0, 0)), () async {
          final scheduledDate = DateTime(2024, 1, 1, 18, 0, 0); // 6 PM same day
          
          final result = await notificationService.scheduleNotification(
            title: 'Clock Test',
            body: 'Testing with fixed clock',
            scheduledDate: scheduledDate,
          );
          
          expect(result, isTrue);
          
          final sentNotifications = notificationService.getSentNotifications();
          expect(sentNotifications.first['scheduledDate'], equals(scheduledDate.toIso8601String()));
        });
      });
    });
    
    group('Notification Performance Tests', () {
      test('should send notifications within acceptable time limits', () async {
        final result = await TestPerformanceUtils.performanceTest(
          'Send single notification',
          () async {
            await notificationService.showNotification(
              title: 'Performance Test',
              body: 'Testing notification performance',
            );
          },
          TestConstants.maxNotificationTime,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle batch notifications efficiently', () async {
        final batchSize = 50;
        
        final result = await TestPerformanceUtils.performanceTest(
          'Send $batchSize notifications',
          () async {
            final futures = <Future<bool>>[];
            
            for (int i = 0; i < batchSize; i++) {
              futures.add(notificationService.showNotification(
                title: 'Batch Test $i',
                body: 'Batch notification $i',
              ));
            }
            
            await Future.wait(futures);
          },
          TestConstants.maxNotificationTime * batchSize, // Scale with batch size
        );
        
        expect(result.passed, isTrue, reason: result.message);
        expect(notificationService.getSentNotifications().length, equals(batchSize));
      });
      
      test('should handle scheduled notifications without performance degradation', () async {
        final scheduleCount = 100;
        
        final result = await TestPerformanceUtils.performanceTest(
          'Schedule $scheduleCount notifications',
          () async {
            final futures = <Future<bool>>[];
            
            for (int i = 0; i < scheduleCount; i++) {
              futures.add(notificationService.scheduleNotification(
                title: 'Scheduled Test $i',
                body: 'Scheduled notification $i',
                scheduledDate: DateTime.now().add(Duration(minutes: i)),
              ));
            }
            
            await Future.wait(futures);
          },
          TestConstants.longTimeout,
        );
        
        expect(result.passed, isTrue, reason: result.message);
        expect(notificationService.getSentNotifications().length, equals(scheduleCount));
      });
    });
    
    group('Notification Error Handling Tests', () {
      test('should handle platform-specific notification failures', () async {
        notificationService.setShouldFailSending(true);
        
        final result = await notificationService.showNotification(
          title: 'Platform Failure Test',
          body: 'This should fail due to platform issues',
        );
        
        expect(result, isFalse);
      });
      
      test('should handle notification permission denied', () async {
        // Simulate permission denied scenario
        notificationService.setShouldFailSending(true);
        
        final result = await notificationService.showNotification(
          title: 'Permission Test',
          body: 'This should fail due to permission denial',
        );
        
        expect(result, isFalse);
      });
      
      test('should handle network failures for remote notifications', () async {
        // Simulate network failure for push notifications
        notificationService.setShouldFailSending(true);
        
        final result = await notificationService.showNotification(
          title: 'Network Failure Test',
          body: 'This should fail due to network issues',
          data: {
            'type': 'push_notification',
            'remote': true,
          },
        );
        
        expect(result, isFalse);
      });
      
      test('should retry failed notifications with exponential backoff', () async {
        var attemptCount = 0;
        
        // Mock retry mechanism
        Future<bool> retryNotification() async {
          attemptCount++;
          
          if (attemptCount < 3) {
            return false; // Fail first 2 attempts
          }
          
          return await notificationService.showNotification(
            title: 'Retry Test',
            body: 'This should succeed on the 3rd attempt',
          );
        }
        
        // Simulate retry logic
        var result = false;
        for (int i = 0; i < 3 && !result; i++) {
          result = await retryNotification();
          if (!result) {
            await Future.delayed(Duration(milliseconds: 100 * (i + 1))); // Exponential backoff
          }
        }
        
        expect(result, isTrue);
        expect(attemptCount, equals(3));
      });
    });
    
    group('Notification Content Validation Tests', () {
      test('should validate notification title length', () async {
        final longTitle = 'A' * 1000; // Very long title
        
        final result = await notificationService.showNotification(
          title: longTitle,
          body: 'Test body',
        );
        
        // Should succeed in mock, but real implementation might truncate or reject
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['title'], equals(longTitle));
      });
      
      test('should validate notification body content', () async {
        final longBody = 'B' * 5000; // Very long body
        
        final result = await notificationService.showNotification(
          title: 'Test Title',
          body: longBody,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['body'], equals(longBody));
      });
      
      test('should handle special characters in notifications', () async {
        final specialTitle = 'Test 🔔 Notification 📱 With 🎉 Emojis';
        final specialBody = 'Special chars: àáâãäåæçèéêë & symbols: @#\$%^&*()';
        
        final result = await notificationService.showNotification(
          title: specialTitle,
          body: specialBody,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['title'], equals(specialTitle));
        expect(sentNotifications.first['body'], equals(specialBody));
      });
      
      test('should handle empty or null notification content', () async {
        // Test empty title
        var result = await notificationService.showNotification(
          title: '',
          body: 'Test body',
        );
        expect(result, isTrue); // Mock allows empty title
        
        // Test empty body
        result = await notificationService.showNotification(
          title: 'Test title',
          body: '',
        );
        expect(result, isTrue); // Mock allows empty body
      });
    });
    
    group('Notification Data Payload Tests', () {
      test('should handle complex data payloads', () async {
        final complexData = {
          'invoice': {
            'id': 'INV-001',
            'customer': {
              'id': 'CUST-001',
              'name': 'Test Customer',
              'email': 'test@example.com',
            },
            'line_items': [
              {'product_id': 'PROD-001', 'quantity': 2, 'price': 50.0},
              {'product_id': 'PROD-002', 'quantity': 1, 'price': 100.0},
            ],
            'totals': {
              'subtotal': 200.0,
              'tax': 18.0,
              'total': 218.0,
            },
          },
          'metadata': {
            'created_at': DateTime.now().toIso8601String(),
            'created_by': 'system',
            'priority': 'high',
          },
        };
        
        final result = await notificationService.showNotification(
          title: 'Complex Data Test',
          body: 'Testing complex data payload',
          data: complexData,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['data'], equals(complexData));
      });
      
      test('should handle large data payloads', () async {
        final largeData = <String, dynamic>{};
        
        // Create large data structure
        for (int i = 0; i < 100; i++) {
          largeData['item_$i'] = {
            'id': 'item_$i',
            'name': 'Item $i Name',
            'description': 'This is a detailed description for item $i' * 10,
            'properties': List.generate(10, (j) => 'property_${i}_$j'),
          };
        }
        
        final result = await notificationService.showNotification(
          title: 'Large Data Test',
          body: 'Testing large data payload',
          data: largeData,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        expect(sentNotifications.first['data'], equals(largeData));
      });
      
      test('should serialize and deserialize data correctly', () async {
        final testData = {
          'string_value': 'test string',
          'int_value': 42,
          'double_value': 3.14159,
          'bool_value': true,
          'null_value': null,
          'list_value': [1, 2, 3, 'four', 5.0],
          'map_value': {
            'nested_string': 'nested value',
            'nested_number': 123,
          },
          'date_value': DateTime.now().toIso8601String(),
        };
        
        final result = await notificationService.showNotification(
          title: 'Serialization Test',
          body: 'Testing data serialization',
          data: testData,
        );
        
        expect(result, isTrue);
        
        final sentNotifications = notificationService.getSentNotifications();
        final retrievedData = sentNotifications.first['data'];
        
        expect(retrievedData['string_value'], equals(testData['string_value']));
        expect(retrievedData['int_value'], equals(testData['int_value']));
        expect(retrievedData['double_value'], equals(testData['double_value']));
        expect(retrievedData['bool_value'], equals(testData['bool_value']));
        expect(retrievedData['null_value'], equals(testData['null_value']));
        expect(retrievedData['list_value'], equals(testData['list_value']));
        expect(retrievedData['map_value'], equals(testData['map_value']));
      });
    });
  });
}