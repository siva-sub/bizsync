/// Integration Tests for Critical Business Workflows
library critical_workflows_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../test_config.dart';
import '../test_factories.dart';
import '../mocks/mock_services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Critical Business Workflows Integration Tests', () {
    late MockDatabaseService databaseService;
    late MockNotificationService notificationService;
    late MockCRDTDatabaseService crdtService;
    
    setUpAll(() async {
      await TestConfig.initialize();
    });
    
    setUp(() async {
      await TestConfig.reset();
      databaseService = MockDatabaseService();
      notificationService = MockNotificationService();
      crdtService = MockCRDTDatabaseService();
    });
    
    group('End-to-End Customer Management Workflow', () {
      testWidgets('should create, view, edit, and delete customer', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to customers
        await tester.tap(find.text('Customers'));
        await tester.pumpAndSettle();
        
        // Create new customer
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        
        // Fill customer form
        await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name'), 'Test Customer Ltd');
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@testcustomer.com');
        await tester.enterText(find.widgetWithText(TextFormField, 'Phone'), '+65 91234567');
        await tester.enterText(find.widgetWithText(TextFormField, 'Address'), '123 Test Street, Singapore 123456');
        
        // Mark as GST registered
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'GST Registration Number'), '201234567M');
        
        // Save customer
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        
        // Verify customer appears in list
        expect(find.text('Test Customer Ltd'), findsOneWidget);
        
        // View customer details
        await tester.tap(find.text('Test Customer Ltd'));
        await tester.pumpAndSettle();
        
        expect(find.text('test@testcustomer.com'), findsOneWidget);
        expect(find.text('+65 91234567'), findsOneWidget);
        expect(find.text('GST Registered: Yes'), findsOneWidget);
        
        // Edit customer
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name'), 'Updated Test Customer Ltd');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        
        // Verify update
        expect(find.text('Updated Test Customer Ltd'), findsOneWidget);
        
        // Delete customer
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        
        // Confirm deletion
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        
        // Verify customer is removed
        expect(find.text('Updated Test Customer Ltd'), findsNothing);
      }, timeout: Timeout(Duration(minutes: 2)));
      
      testWidgets('should handle customer creation with validation errors', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to create customer
        await tester.tap(find.text('Customers'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        
        // Try to save without required fields
        await tester.tap(find.text('Save'));
        await tester.pump();
        
        // Should show validation errors
        expect(find.text('Customer name is required'), findsOneWidget);
        
        // Enter invalid email
        await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name'), 'Test Customer');
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
        await tester.tap(find.text('Save'));
        await tester.pump();
        
        expect(find.text('Please enter a valid email'), findsOneWidget);
        
        // Fix email and save
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'valid@email.com');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        
        // Should succeed
        expect(find.text('Test Customer'), findsOneWidget);
      });
    });
    
    group('End-to-End Invoice Creation Workflow', () {
      testWidgets('should create complete invoice with line items and calculations', (WidgetTester tester) async {
        // Setup test data
        final customer = TestFactories.createSingaporeGstCustomer();
        final products = [
          TestFactories.createProduct(name: 'Product A', price: 100.0),
          TestFactories.createProduct(name: 'Product B', price: 200.0),
        ];
        
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to invoices
        await tester.tap(find.text('Invoices'));
        await tester.pumpAndSettle();
        
        // Create new invoice
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        
        // Select customer
        await tester.tap(find.text('Select Customer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(customer.name));
        await tester.pumpAndSettle();
        
        // Verify customer details are populated
        expect(find.text(customer.name), findsOneWidget);
        expect(find.text('GST: Yes'), findsOneWidget);
        
        // Add first line item
        await tester.tap(find.text('Add Product'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Product A'));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '2');
        await tester.pump();
        
        // Verify line total calculation
        expect(find.text('200.00'), findsOneWidget); // 2 * 100
        
        // Add second line item
        await tester.tap(find.text('Add Product'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Product B'));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '1');
        await tester.pump();
        
        // Verify invoice totals
        expect(find.textContaining('Subtotal: 400.00'), findsOneWidget); // 200 + 200
        expect(find.textContaining('GST (9%): 36.00'), findsOneWidget); // 400 * 0.09
        expect(find.textContaining('Total: 436.00'), findsOneWidget); // 400 + 36
        
        // Add discount
        await tester.enterText(find.widgetWithText(TextFormField, 'Discount'), '50.00');
        await tester.pump();
        
        // Verify recalculated totals
        expect(find.textContaining('Net Amount: 350.00'), findsOneWidget); // 400 - 50
        expect(find.textContaining('GST (9%): 31.50'), findsOneWidget); // 350 * 0.09
        expect(find.textContaining('Total: 381.50'), findsOneWidget); // 350 + 31.50
        
        // Set payment terms
        await tester.tap(find.text('Payment Terms'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Net 30'));
        await tester.pumpAndSettle();
        
        // Save invoice
        await tester.tap(find.text('Save Invoice'));
        await tester.pumpAndSettle();
        
        // Verify invoice is created and appears in list
        expect(find.textContaining('INV-'), findsOneWidget);
        expect(find.text('381.50'), findsOneWidget);
        expect(find.text('Draft'), findsOneWidget);
        
        // Send invoice
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();
        
        // Confirm send
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        
        // Verify status changed
        expect(find.text('Sent'), findsOneWidget);
      }, timeout: Timeout(Duration(minutes: 3)));
      
      testWidgets('should handle export invoice with zero GST', (WidgetTester tester) async {
        final exportCustomer = TestFactories.createExportCustomer();
        
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Create invoice for export customer
        await tester.tap(find.text('Invoices'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        
        // Select export customer
        await tester.tap(find.text('Select Customer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(exportCustomer.name));
        await tester.pumpAndSettle();
        
        // Add product
        await tester.tap(find.text('Add Product'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Product A'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '1');
        await tester.pump();
        
        // Verify zero-rated GST for export
        expect(find.textContaining('Subtotal: 100.00'), findsOneWidget);
        expect(find.textContaining('GST (0%): 0.00'), findsOneWidget);
        expect(find.textContaining('Total: 100.00'), findsOneWidget);
        expect(find.text('Export - Zero Rated'), findsOneWidget);
        
        await tester.tap(find.text('Save Invoice'));
        await tester.pumpAndSettle();
        
        expect(find.text('100.00'), findsOneWidget);
      });
    });
    
    group('End-to-End Payment Processing Workflow', () {
      testWidgets('should process payment and update invoice status', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to sent invoice
        await tester.tap(find.text('Invoices'));
        await tester.pumpAndSettle();
        
        // Assume we have a sent invoice
        await tester.tap(find.text('INV-001'));
        await tester.pumpAndSettle();
        
        // Record payment
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();
        
        // Enter payment details
        await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '381.50');
        
        await tester.tap(find.text('Payment Method'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PayNow'));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Reference'), 'PAYNOW123456');
        
        // Process payment
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();
        
        // Verify invoice status updated
        expect(find.text('Paid'), findsOneWidget);
        expect(find.text('Payment Received: 381.50'), findsOneWidget);
        
        // Verify payment notification
        final notifications = notificationService.getSentNotifications();
        expect(notifications.any((n) => n['title'].contains('Payment Received')), isTrue);
      });
      
      testWidgets('should handle partial payments', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        await tester.tap(find.text('Invoices'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('INV-002'));
        await tester.pumpAndSettle();
        
        // Record partial payment
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '200.00');
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();
        
        // Verify partial payment status
        expect(find.text('Partially Paid'), findsOneWidget);
        expect(find.text('Outstanding: 181.50'), findsOneWidget);
        
        // Record remaining payment
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '181.50');
        await tester.tap(find.text('Record Payment'));
        await tester.pumpAndSettle();
        
        // Verify fully paid
        expect(find.text('Paid'), findsOneWidget);
        expect(find.text('Outstanding: 0.00'), findsOneWidget);
      });
    });
    
    group('End-to-End Inventory Management Workflow', () {
      testWidgets('should manage product stock levels and trigger notifications', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to products
        await tester.tap(find.text('Products'));
        await tester.pumpAndSettle();
        
        // Create product with low stock level
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Product Name'), 'Low Stock Product');
        await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '50.00');
        await tester.enterText(find.widgetWithText(TextFormField, 'Stock Quantity'), '15');
        await tester.enterText(find.widgetWithText(TextFormField, 'Min Stock Level'), '10');
        
        await tester.tap(find.text('Save Product'));
        await tester.pumpAndSettle();
        
        // Stock is above minimum, no alert
        expect(find.byIcon(Icons.warning), findsNothing);
        
        // Simulate stock reduction through sales
        await tester.tap(find.text('Low Stock Product'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Stock Quantity'), '8');
        await tester.tap(find.text('Save Product'));
        await tester.pumpAndSettle();
        
        // Should show low stock warning
        expect(find.byIcon(Icons.warning), findsOneWidget);
        expect(find.text('Low Stock'), findsOneWidget);
        
        // Should trigger low stock notification
        final notifications = notificationService.getSentNotifications();
        expect(notifications.any((n) => n['title'].contains('Low Stock Alert')), isTrue);
        
        // Restock product
        await tester.tap(find.text('Restock'));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.widgetWithText(TextFormField, 'Quantity to Add'), '20');
        await tester.tap(find.text('Add Stock'));
        await tester.pumpAndSettle();
        
        // Verify stock updated
        expect(find.text('Stock: 28'), findsOneWidget);
        expect(find.byIcon(Icons.warning), findsNothing);
      });
      
      testWidgets('should handle out of stock scenario', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Try to sell out of stock product
        await tester.tap(find.text('Invoices'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        
        // Select customer and add out of stock product
        await tester.tap(find.text('Select Customer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Customer'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Add Product'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Out of Stock Product'));
        await tester.pumpAndSettle();
        
        // Should show out of stock warning
        expect(find.text('Out of Stock'), findsOneWidget);
        expect(find.byIcon(Icons.error), findsOneWidget);
        
        // Try to add quantity
        await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '1');
        await tester.pump();
        
        // Should show error
        expect(find.text('Insufficient stock available'), findsOneWidget);
      });
    });
    
    group('End-to-End Backup and Sync Workflow', () {
      testWidgets('should create backup and restore data', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        
        // Access backup settings
        await tester.tap(find.text('Backup & Sync'));
        await tester.pumpAndSettle();
        
        // Create backup
        await tester.tap(find.text('Create Backup'));
        await tester.pumpAndSettle();
        
        // Select backup options
        await tester.tap(find.text('Include Customers'));
        await tester.tap(find.text('Include Products'));
        await tester.tap(find.text('Include Invoices'));
        
        await tester.tap(find.text('Start Backup'));
        await tester.pumpAndSettle(Duration(seconds: 2));
        
        // Verify backup completion
        expect(find.text('Backup completed successfully'), findsOneWidget);
        
        // Should receive backup notification
        final notifications = notificationService.getSentNotifications();
        expect(notifications.any((n) => n['title'].contains('Backup Completed')), isTrue);
        
        // Test restore functionality
        await tester.tap(find.text('Restore from Backup'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Select Backup File'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('backup_20240101.biz'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Start Restore'));
        await tester.pumpAndSettle();
        
        // Confirm restore
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle(Duration(seconds: 2));
        
        expect(find.text('Data restored successfully'), findsOneWidget);
      });
      
      testWidgets('should sync data between devices', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Backup & Sync'));
        await tester.pumpAndSettle();
        
        // Enable P2P sync
        await tester.tap(find.text('P2P Sync'));
        await tester.pumpAndSettle();
        
        // Discover devices
        await tester.tap(find.text('Discover Devices'));
        await tester.pumpAndSettle(Duration(seconds: 1));
        
        // Should show discovered devices
        expect(find.text('Device-A'), findsOneWidget);
        expect(find.text('Device-B'), findsOneWidget);
        
        // Connect to device
        await tester.tap(find.text('Device-A'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        
        // Start sync
        await tester.tap(find.text('Start Sync'));
        await tester.pumpAndSettle(Duration(seconds: 2));
        
        // Verify sync completion
        expect(find.text('Sync completed'), findsOneWidget);
        expect(find.textContaining('records synced'), findsOneWidget);
      });
    });
    
    group('End-to-End Tax Calculation Workflow', () {
      testWidgets('should calculate GST correctly for different scenarios', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Navigate to tax calculator
        await tester.tap(find.text('Reports'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tax Calculator'));
        await tester.pumpAndSettle();
        
        // Test standard GST calculation
        await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '1000.00');
        
        await tester.tap(find.text('Customer Type'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Singapore Business (GST Registered)'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Calculate'));
        await tester.pumpAndSettle();
        
        // Verify GST calculation
        expect(find.text('GST Rate: 9%'), findsOneWidget);
        expect(find.text('GST Amount: 90.00'), findsOneWidget);
        expect(find.text('Total Amount: 1090.00'), findsOneWidget);
        
        // Test export calculation
        await tester.tap(find.text('Customer Type'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export Customer'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Calculate'));
        await tester.pumpAndSettle();
        
        // Verify zero-rated calculation
        expect(find.text('GST Rate: 0% (Export)'), findsOneWidget);
        expect(find.text('GST Amount: 0.00'), findsOneWidget);
        expect(find.text('Total Amount: 1000.00'), findsOneWidget);
        
        // Test historical rate calculation
        await tester.tap(find.text('Calculation Date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2022-01-01')); // 8% GST rate period
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Customer Type'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Singapore Business (GST Registered)'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Calculate'));
        await tester.pumpAndSettle();
        
        // Verify historical rate
        expect(find.text('GST Rate: 8% (Historical)'), findsOneWidget);
        expect(find.text('GST Amount: 80.00'), findsOneWidget);
        expect(find.text('Total Amount: 1080.00'), findsOneWidget);
      });
    });
    
    group('End-to-End Error Recovery Workflow', () {
      testWidgets('should handle and recover from database errors', (WidgetTester tester) async {
        // Simulate database error
        databaseService.setShouldThrowError(true);
        
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Try to load customers
        await tester.tap(find.text('Customers'));
        await tester.pumpAndSettle();
        
        // Should show error message
        expect(find.text('Failed to load customers'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        
        // Fix database and retry
        databaseService.setShouldThrowError(false);
        
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        
        // Should load successfully
        expect(find.text('Customers'), findsOneWidget);
        expect(find.text('Failed to load customers'), findsNothing);
      });
      
      testWidgets('should handle network connectivity issues', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BizSyncApp(),
            ),
          ),
        );
        
        // Simulate network disconnection
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Backup & Sync'));
        await tester.pumpAndSettle();
        
        // Try to sync when offline
        await tester.tap(find.text('Sync Now'));
        await tester.pumpAndSettle();
        
        // Should show offline message
        expect(find.text('No internet connection'), findsOneWidget);
        expect(find.text('Data will sync when connection is restored'), findsOneWidget);
        
        // Show offline indicator
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });
    });
  });
}

// Mock BizSync App for integration testing
class BizSyncApp extends StatefulWidget {
  @override
  _BizSyncAppState createState() => _BizSyncAppState();
}

class _BizSyncAppState extends State<BizSyncApp> {
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getBodyWidget(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Invoices'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
  
  Widget _getBodyWidget() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen();
      case 1:
        return InvoicesScreen();
      case 2:
        return CustomersScreen();
      case 3:
        return ProductsScreen();
      case 4:
        return ReportsScreen();
      case 5:
        return SettingsScreen();
      default:
        return DashboardScreen();
    }
  }
}

// Mock screens for integration testing
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Dashboard'));
  }
}

class InvoicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Invoices')),
      body: Column(
        children: [
          ListTile(title: Text('INV-001'), subtitle: Text('381.50')),
          ListTile(title: Text('INV-002'), subtitle: Text('200.00')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}

class CustomersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customers')),
      body: Column(
        children: [
          Text('No customers found'),
          ElevatedButton(
            onPressed: () {},
            child: Text('Add Customer'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}

class ProductsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Products')),
      body: Column(
        children: [
          ListTile(
            title: Text('Low Stock Product'),
            subtitle: Text('Stock: 8'),
            trailing: Icon(Icons.warning),
          ),
          ListTile(
            title: Text('Out of Stock Product'),
            subtitle: Text('Stock: 0'),
            trailing: Icon(Icons.error),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reports')),
      body: Column(
        children: [
          ListTile(
            title: Text('Tax Calculator'),
            onTap: () {},
          ),
          ListTile(
            title: Text('Sales Report'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Column(
        children: [
          ListTile(
            title: Text('Backup & Sync'),
            onTap: () {},
          ),
          ListTile(
            title: Text('Tax Settings'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}