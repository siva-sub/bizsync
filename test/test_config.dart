/// Test configuration and setup for the BizSync test suite
library test_config;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Test configuration class for setting up common test environments
class TestConfig {
  static bool _initialized = false;
  
  /// Initialize the test environment with common mocks and configurations
  static Future<void> initialize() async {
    if (_initialized) return;
    
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize sqflite for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Setup SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    
    // Setup PathProvider mock
    PathProviderPlatform.instance = MockPathProviderPlatform();
    
    // Setup method channel mocks for platform-specific functionality
    _setupMethodChannelMocks();
    
    _initialized = true;
  }
  
  /// Reset test environment for clean state between tests
  static Future<void> reset() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(null, null);
  }
  
  /// Setup common method channel mocks
  static void _setupMethodChannelMocks() {
    // Mock device_info_plus
    const deviceInfoChannel = MethodChannel('dev.fluttercommunity.plus/device_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getDeviceInfo':
          return {
            'model': 'Test Device',
            'manufacturer': 'Test Manufacturer',
            'isPhysicalDevice': false,
          };
        default:
          return null;
      }
    });
    
    // Mock permission_handler
    const permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'checkPermissionStatus':
        case 'requestPermissions':
          return 1; // granted
        default:
          return null;
      }
    });
    
    // Mock flutter_local_notifications
    const notificationChannel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
        case 'show':
        case 'cancel':
        case 'cancelAll':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {
            'notificationLaunchedApp': false,
            'notificationResponse': null,
          };
        default:
          return null;
      }
    });
    
    // Mock image_picker
    const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imagePickerChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'pickImage':
          return '/tmp/test_image.jpg';
        default:
          return null;
      }
    });
    
    // Mock connectivity_plus
    const connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'check':
          return 'wifi';
        default:
          return null;
      }
    });
  }
}

/// Mock PathProvider for testing
class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/tmp/test_app_documents';
  }
  
  @override
  Future<String?> getApplicationSupportPath() async {
    return '/tmp/test_app_support';
  }
  
  @override
  Future<String?> getTemporaryPath() async {
    return '/tmp/test_temp';
  }
  
  @override
  Future<String?> getExternalStoragePath() async {
    return '/tmp/test_external';
  }
  
  @override
  Future<List<String>?> getExternalCachePaths() async {
    return ['/tmp/test_external_cache'];
  }
  
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return ['/tmp/test_external_storage'];
  }
  
  @override
  Future<String?> getLibraryPath() async {
    return '/tmp/test_library';
  }
  
  @override
  Future<String?> getApplicationCachePath() async {
    return '/tmp/test_app_cache';
  }
  
  @override
  Future<String?> getDownloadsPath() async {
    return '/tmp/test_downloads';
  }
}

/// Mock class base for creating test mocks
class Mock {
  // Base mock class for test mocks
}

/// Test database configuration
class TestDatabaseConfig {
  static const String testDatabaseName = 'test_bizsync.db';
  static const String testDatabasePath = '/tmp/test_bizsync.db';
  
  /// Get a fresh in-memory database for testing
  static Future<Database> getInMemoryDatabase() async {
    return await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // Create tables for testing
        await _createTestTables(db);
      },
    );
  }
  
  /// Create test database tables
  static Future<void> _createTestTables(Database db) async {
    // Create basic tables for testing
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        gst_registered INTEGER DEFAULT 0,
        gst_registration_number TEXT,
        country_code TEXT DEFAULT 'SG',
        billing_address TEXT,
        shipping_address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock_quantity INTEGER DEFAULT 0,
        min_stock_level INTEGER DEFAULT 0,
        category_id TEXT,
        category TEXT,
        barcode TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_email TEXT,
        customer_gst_registered INTEGER DEFAULT 0,
        customer_country_code TEXT DEFAULT 'SG',
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        payment_terms TEXT NOT NULL,
        status TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        currency TEXT DEFAULT 'SGD',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE invoice_line_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        description TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_rate REAL DEFAULT 0,
        line_total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE crdt_operations (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        operation_data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        node_id TEXT NOT NULL,
        vector_clock TEXT NOT NULL,
        applied INTEGER DEFAULT 0
      )
    ''');
  }
}

/// Test performance utilities
class TestPerformanceUtils {
  /// Measure execution time of a function
  static Future<Duration> measureExecutionTime(Future<void> Function() function) async {
    final stopwatch = Stopwatch()..start();
    await function();
    stopwatch.stop();
    return stopwatch.elapsed;
  }
  
  /// Check if execution time is within acceptable limits
  static bool isPerformanceAcceptable(Duration duration, Duration maxDuration) {
    return duration <= maxDuration;
  }
  
  /// Performance test wrapper
  static Future<TestResult> performanceTest(
    String testName,
    Future<void> Function() test,
    Duration maxDuration,
  ) async {
    try {
      final duration = await measureExecutionTime(test);
      final passed = isPerformanceAcceptable(duration, maxDuration);
      
      return TestResult(
        testName: testName,
        passed: passed,
        duration: duration,
        maxDuration: maxDuration,
        message: passed 
            ? 'Performance test passed: ${duration.inMilliseconds}ms (max: ${maxDuration.inMilliseconds}ms)'
            : 'Performance test failed: ${duration.inMilliseconds}ms exceeds max: ${maxDuration.inMilliseconds}ms',
      );
    } catch (e) {
      return TestResult(
        testName: testName,
        passed: false,
        duration: Duration.zero,
        maxDuration: maxDuration,
        message: 'Performance test error: $e',
      );
    }
  }
}

/// Test result model
class TestResult {
  final String testName;
  final bool passed;
  final Duration duration;
  final Duration maxDuration;
  final String message;
  
  TestResult({
    required this.testName,
    required this.passed,
    required this.duration,
    required this.maxDuration,
    required this.message,
  });
  
  @override
  String toString() => '$testName: $message';
}

/// Test constants
class TestConstants {
  // Performance limits
  static const Duration maxDatabaseQueryTime = Duration(milliseconds: 100);
  static const Duration maxUIRenderTime = Duration(milliseconds: 16); // 60fps
  static const Duration maxSyncOperationTime = Duration(seconds: 5);
  static const Duration maxNotificationTime = Duration(milliseconds: 500);
  
  // Test data sizes
  static const int smallDatasetSize = 10;
  static const int mediumDatasetSize = 100;
  static const int largeDatasetSize = 1000;
  
  // Test timeout durations
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration mediumTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(minutes: 2);
}