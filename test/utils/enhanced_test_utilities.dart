/// Enhanced Test Utilities and Mock Data Factories
library enhanced_test_utilities;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:clock/clock.dart';
import '../test_config.dart';
import '../test_factories.dart';

/// Enhanced test utilities for BizSync application testing
class EnhancedTestUtils {
  static final _random = math.Random();
  
  /// Generate realistic test data with various patterns
  static List<T> generateTestDataWithPattern<T>(
    int count,
    T Function(int index, String pattern) generator, {
    List<String> patterns = const ['normal', 'edge_case', 'stress'],
  }) {
    final data = <T>[];
    
    for (int i = 0; i < count; i++) {
      final pattern = patterns[i % patterns.length];
      data.add(generator(i, pattern));
    }
    
    return data;
  }
  
  /// Create test data with realistic business scenarios
  static Map<String, dynamic> createBusinessScenario(String scenarioType) {
    switch (scenarioType) {
      case 'startup_company':
        return {
          'company_type': 'startup',
          'customer_count': 5,
          'product_count': 10,
          'monthly_revenue': 5000.0,
          'gst_registered': false,
          'employee_count': 3,
        };
        
      case 'small_business':
        return {
          'company_type': 'small_business',
          'customer_count': 50,
          'product_count': 100,
          'monthly_revenue': 50000.0,
          'gst_registered': true,
          'employee_count': 15,
        };
        
      case 'medium_enterprise':
        return {
          'company_type': 'medium_enterprise',
          'customer_count': 500,
          'product_count': 1000,
          'monthly_revenue': 500000.0,
          'gst_registered': true,
          'employee_count': 100,
        };
        
      case 'export_business':
        return {
          'company_type': 'export_business',
          'customer_count': 25,
          'product_count': 50,
          'monthly_revenue': 100000.0,
          'gst_registered': true,
          'employee_count': 20,
          'export_percentage': 80,
        };
        
      default:
        return createBusinessScenario('small_business');
    }
  }
  
  /// Generate realistic Singapore business data
  static Map<String, dynamic> createSingaporeBusinessData() {
    final businessTypes = ['PTE LTD', 'LLP', 'SOLE PROPRIETORSHIP'];
    final sectors = ['TECHNOLOGY', 'RETAIL', 'MANUFACTURING', 'SERVICES'];
    final locations = ['CBD', 'JURONG', 'TAMPINES', 'WOODLANDS', 'ORCHARD'];
    
    return {
      'business_name': '${_generateCompanyName()} ${businessTypes[_random.nextInt(businessTypes.length)]}',
      'sector': sectors[_random.nextInt(sectors.length)],
      'location': locations[_random.nextInt(locations.length)],
      'uen': _generateUEN(),
      'gst_number': _generateGSTNumber(),
      'postal_code': _generateSingaporePostalCode(),
      'incorporation_date': _generatePastDate(maxYearsAgo: 10),
    };
  }
  
  /// Generate realistic financial test data
  static Map<String, dynamic> createFinancialTestData({
    String currency = 'SGD',
    bool includeHistoricalData = true,
  }) {
    final data = <String, dynamic>{
      'currency': currency,
      'current_month': {
        'revenue': _generateAmount(1000, 100000),
        'expenses': _generateAmount(500, 50000),
        'tax_liability': _generateAmount(100, 10000),
        'outstanding_receivables': _generateAmount(0, 50000),
        'outstanding_payables': _generateAmount(0, 30000),
      },
    };
    
    if (includeHistoricalData) {
      data['historical_data'] = _generateHistoricalFinancialData(12);
    }
    
    return data;
  }
  
  /// Create test data for tax scenarios
  static List<Map<String, dynamic>> createTaxTestScenarios() {
    return [
      // Standard scenarios
      {
        'scenario': 'Singapore B2B GST',
        'seller_country': 'SG',
        'buyer_country': 'SG',
        'seller_gst_registered': true,
        'buyer_gst_registered': true,
        'amount': 1000.0,
        'expected_gst_rate': 0.09,
        'expected_gst_amount': 90.0,
      },
      
      // Export scenarios
      {
        'scenario': 'Singapore Export to US',
        'seller_country': 'SG',
        'buyer_country': 'US',
        'seller_gst_registered': true,
        'buyer_gst_registered': false,
        'amount': 1000.0,
        'expected_gst_rate': 0.0,
        'expected_gst_amount': 0.0,
      },
      
      // Historical rate scenarios
      {
        'scenario': 'Historical 7% GST Rate',
        'seller_country': 'SG',
        'buyer_country': 'SG',
        'seller_gst_registered': true,
        'buyer_gst_registered': true,
        'amount': 1000.0,
        'calculation_date': DateTime(2020, 1, 1),
        'expected_gst_rate': 0.07,
        'expected_gst_amount': 70.0,
      },
      
      // Non-GST registered scenarios
      {
        'scenario': 'Non-GST Registered Seller',
        'seller_country': 'SG',
        'buyer_country': 'SG',
        'seller_gst_registered': false,
        'buyer_gst_registered': true,
        'amount': 1000.0,
        'expected_gst_rate': 0.0,
        'expected_gst_amount': 0.0,
      },
    ];
  }
  
  /// Generate test data for edge cases
  static Map<String, dynamic> createEdgeCaseTestData() {
    return {
      'zero_values': {
        'amount': 0.0,
        'quantity': 0,
        'discount': 0.0,
      },
      'negative_values': {
        'amount': -100.0,
        'quantity': -1,
        'discount': -50.0,
      },
      'very_large_values': {
        'amount': 999999999.99,
        'quantity': 9999999,
        'discount': 999999.99,
      },
      'precision_values': {
        'amount': 0.01,
        'tax_rate': 0.001,
        'discount_rate': 0.0001,
      },
      'unicode_strings': {
        'name': 'Café René & Søn 北京烤鸭 مطعم الشام',
        'description': '🎉 Special characters: àáâãäåæçèéêë ñ ü ß',
        'notes': 'Mixed script: Hello 世界 مرحبا 🌍',
      },
      'very_long_strings': {
        'description': 'A' * 10000,
        'notes': 'Lorem ipsum ' * 1000,
      },
      'null_and_empty': {
        'null_value': null,
        'empty_string': '',
        'empty_list': [],
        'empty_map': {},
      },
    };
  }
  
  /// Create performance test datasets of various sizes
  static Map<String, List<Map<String, dynamic>>> createPerformanceTestDatasets() {
    return {
      'small': List.generate(
        TestConstants.smallDatasetSize,
        (i) => TestFactories.createCustomer(name: 'Small Dataset Customer $i').toJson(),
      ),
      'medium': List.generate(
        TestConstants.mediumDatasetSize,
        (i) => TestFactories.createCustomer(name: 'Medium Dataset Customer $i').toJson(),
      ),
      'large': List.generate(
        TestConstants.largeDatasetSize,
        (i) => TestFactories.createCustomer(name: 'Large Dataset Customer $i').toJson(),
      ),
    };
  }
  
  /// Generate test data for concurrent operations
  static List<Map<String, dynamic>> createConcurrentTestOperations(int operationCount) {
    final operations = <Map<String, dynamic>>[];
    final operationTypes = ['create', 'update', 'delete'];
    final entityTypes = ['customer', 'product', 'invoice'];
    
    for (int i = 0; i < operationCount; i++) {
      operations.add({
        'id': 'concurrent-op-$i',
        'type': operationTypes[i % operationTypes.length],
        'entity_type': entityTypes[i % entityTypes.length],
        'entity_id': 'entity-$i',
        'timestamp': DateTime.now().add(Duration(milliseconds: i)),
        'thread_id': i % 10, // Simulate 10 concurrent threads
      });
    }
    
    return operations;
  }
  
  // Private helper methods
  static String _generateCompanyName() {
    final prefixes = ['Tech', 'Global', 'Smart', 'Digital', 'Creative', 'Premium'];
    final suffixes = ['Solutions', 'Systems', 'Trading', 'Services', 'Enterprises'];
    
    return '${prefixes[_random.nextInt(prefixes.length)]} ${suffixes[_random.nextInt(suffixes.length)]}';
  }
  
  static String _generateUEN() {
    // Singapore UEN format: 8 digits + 1 check character
    final digits = List.generate(8, (index) => _random.nextInt(10));
    final checkChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final checkChar = checkChars[_random.nextInt(checkChars.length)];
    
    return '${digits.join()}$checkChar';
  }
  
  static String _generateGSTNumber() {
    // Singapore GST format: UEN + 'G' + 3 digits
    return '${_generateUEN()}G${_random.nextInt(1000).toString().padLeft(3, '0')}';
  }
  
  static String _generateSingaporePostalCode() {
    // Singapore postal codes are 6 digits
    return _random.nextInt(1000000).toString().padLeft(6, '0');
  }
  
  static DateTime _generatePastDate({int maxYearsAgo = 5}) {
    final now = DateTime.now();
    final maxDaysAgo = maxYearsAgo * 365;
    final daysAgo = _random.nextInt(maxDaysAgo);
    
    return now.subtract(Duration(days: daysAgo));
  }
  
  static double _generateAmount(double min, double max) {
    return min + (_random.nextDouble() * (max - min));
  }
  
  static List<Map<String, dynamic>> _generateHistoricalFinancialData(int months) {
    final data = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    for (int i = 0; i < months; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      data.add({
        'month': month.toIso8601String(),
        'revenue': _generateAmount(5000, 150000),
        'expenses': _generateAmount(2000, 100000),
        'profit_margin': _generateAmount(0.05, 0.30),
      });
    }
    
    return data;
  }
}

/// Test assertion utilities for business logic validation
class BusinessTestAssertions {
  /// Assert invoice calculations are correct
  static void assertInvoiceCalculationsCorrect(Map<String, dynamic> invoice) {
    final lineItems = invoice['line_items'] as List<Map<String, dynamic>>;
    final subtotal = invoice['subtotal'] as double;
    final discount = invoice['discount_amount'] as double? ?? 0.0;
    final taxAmount = invoice['tax_amount'] as double;
    final totalAmount = invoice['total_amount'] as double;
    
    // Calculate expected values
    final expectedSubtotal = lineItems.fold<double>(
      0.0,
      (sum, item) => sum + (item['line_total'] as double),
    );
    
    final netAmount = expectedSubtotal - discount;
    final expectedTotal = netAmount + taxAmount;
    
    // Assert calculations with tolerance for floating point precision
    expect(subtotal, closeTo(expectedSubtotal, 0.01));
    expect(totalAmount, closeTo(expectedTotal, 0.01));
    expect(totalAmount, greaterThanOrEqualTo(netAmount));
  }
  
  /// Assert GST calculations are correct
  static void assertGSTCalculationCorrect({
    required double amount,
    required double gstRate,
    required double calculatedGstAmount,
    required double calculatedTotal,
  }) {
    final expectedGstAmount = amount * gstRate;
    final expectedTotal = amount + expectedGstAmount;
    
    expect(calculatedGstAmount, closeTo(expectedGstAmount, 0.01));
    expect(calculatedTotal, closeTo(expectedTotal, 0.01));
  }
  
  /// Assert customer data is complete and valid
  static void assertCustomerDataValid(Map<String, dynamic> customer) {
    expect(customer['id'], isNotNull);
    expect(customer['name'], isNotNull);
    expect(customer['name'], isNotEmpty);
    
    if (customer['email'] != null) {
      expect(customer['email'], contains('@'));
    }
    
    if (customer['gst_registered'] == true) {
      expect(customer['gst_registration_number'], isNotNull);
      expect(customer['gst_registration_number'], matches(r'^\d{8}[A-Z]G\d{3}$'));
    }
    
    expect(customer['created_at'], isNotNull);
    expect(customer['updated_at'], isNotNull);
  }
  
  /// Assert product data is complete and valid
  static void assertProductDataValid(Map<String, dynamic> product) {
    expect(product['id'], isNotNull);
    expect(product['name'], isNotNull);
    expect(product['name'], isNotEmpty);
    expect(product['price'], isA<double>());
    expect(product['price'], greaterThan(0));
    expect(product['stock_quantity'], isA<int>());
    expect(product['stock_quantity'], greaterThanOrEqualTo(0));
    expect(product['min_stock_level'], isA<int>());
    expect(product['min_stock_level'], greaterThanOrEqualTo(0));
  }
  
  /// Assert CRDT operation is valid
  static void assertCRDTOperationValid(Map<String, dynamic> operation) {
    expect(operation['id'], isNotNull);
    expect(operation['entity_type'], isNotNull);
    expect(operation['entity_id'], isNotNull);
    expect(operation['operation_type'], isIn(['create', 'update', 'delete']));
    expect(operation['timestamp'], isA<int>());
    expect(operation['node_id'], isNotNull);
    expect(operation['vector_clock'], isNotNull);
  }
}

/// Test data generators for specific business scenarios
class BusinessScenarioGenerators {
  /// Generate data for a complete invoice workflow test
  static Map<String, dynamic> generateInvoiceWorkflowData() {
    final customer = TestFactories.createSingaporeGstCustomer();
    final products = [
      TestFactories.createProduct(name: 'Premium Service', price: 500.0),
      TestFactories.createProduct(name: 'Consultation', price: 200.0),
      TestFactories.createProduct(name: 'Support Package', price: 150.0),
    ];
    
    final lineItems = products.map((product) => {
      'id': EnhancedTestUtils._random.nextInt(10000).toString(),
      'product_id': product.id,
      'product_name': product.name,
      'quantity': 1.0 + EnhancedTestUtils._random.nextDouble() * 3, // 1-4 quantity
      'unit_price': product.price,
      'discount_amount': 0.0,
      'tax_rate': 0.09,
    }).toList();
    
    // Calculate line totals
    for (final item in lineItems) {
      item['line_total'] = (item['quantity'] as num) * (item['unit_price'] as num);
    }
    
    return {
      'customer': customer.toJson(),
      'products': products.map((p) => p.toJson()).toList(),
      'line_items': lineItems,
      'payment_terms': 'NET_30',
      'currency': 'SGD',
      'notes': 'Generated test invoice for workflow testing',
    };
  }
  
  /// Generate data for P2P sync testing
  static Map<String, dynamic> generateP2PSyncTestData() {
    return {
      'local_node': {
        'node_id': 'test-node-1',
        'customers': List.generate(5, (i) => TestFactories.createCustomer().toJson()),
        'products': List.generate(10, (i) => TestFactories.createProduct().toJson()),
        'invoices': List.generate(8, (i) => TestFactories.createInvoiceData()),
      },
      'remote_nodes': [
        {
          'node_id': 'test-node-2',
          'customers': List.generate(3, (i) => TestFactories.createCustomer().toJson()),
          'products': List.generate(7, (i) => TestFactories.createProduct().toJson()),
          'invoices': List.generate(5, (i) => TestFactories.createInvoiceData()),
        },
        {
          'node_id': 'test-node-3',
          'customers': List.generate(4, (i) => TestFactories.createCustomer().toJson()),
          'products': List.generate(6, (i) => TestFactories.createProduct().toJson()),
          'invoices': List.generate(7, (i) => TestFactories.createInvoiceData()),
        },
      ],
      'sync_conflicts': [
        {
          'entity_type': 'customer',
          'entity_id': 'conflict-customer-1',
          'local_version': {'name': 'Local Customer Name'},
          'remote_version': {'name': 'Remote Customer Name'},
        },
      ],
    };
  }
  
  /// Generate stress test data
  static Map<String, List<Map<String, dynamic>>> generateStressTestData() {
    return {
      'customers': List.generate(
        1000,
        (i) => TestFactories.createCustomer(name: 'Stress Test Customer $i').toJson(),
      ),
      'products': List.generate(
        2000,
        (i) => TestFactories.createProduct(name: 'Stress Test Product $i').toJson(),
      ),
      'invoices': List.generate(
        500,
        (i) => TestFactories.createInvoiceData(),
      ),
      'crdt_operations': EnhancedTestUtils.createConcurrentTestOperations(5000),
    };
  }
}

/// Test execution utilities
class TestExecutionUtils {
  /// Run test with timeout and proper error handling
  static Future<T> runWithTimeout<T>(
    Future<T> Function() test,
    Duration timeout, {
    String? testName,
  }) async {
    try {
      return await test().timeout(timeout);
    } catch (e) {
      throw TestFailure(
        'Test${testName != null ? " '$testName'" : ""} failed: $e',
      );
    }
  }
  
  /// Run test with controlled time using fake_async
  static T runWithFakeTime<T>(
    T Function(FakeAsync) test, {
    DateTime? initialTime,
  }) {
    return fakeAsync((async) {
      if (initialTime != null) {
        async.elapse(initialTime.difference(DateTime.now()));
      }
      return test(async);
    });
  }
  
  /// Run test with fixed clock
  static Future<T> runWithFixedClock<T>(
    Future<T> Function() test,
    DateTime fixedTime,
  ) async {
    return await withClock(Clock.fixed(fixedTime), test);
  }
  
  /// Run performance test and collect metrics
  static Future<PerformanceTestResult> runPerformanceTest(
    String testName,
    Future<void> Function() test, {
    int iterations = 1,
    Duration? maxDuration,
  }) async {
    final durations = <Duration>[];
    final startTime = DateTime.now();
    var successful = 0;
    var failed = 0;
    Exception? lastException;
    
    for (int i = 0; i < iterations; i++) {
      try {
        final iterationStart = DateTime.now();
        await test();
        final iterationDuration = DateTime.now().difference(iterationStart);
        
        durations.add(iterationDuration);
        successful++;
        
        if (maxDuration != null && iterationDuration > maxDuration) {
          throw TestFailure('Test iteration exceeded maximum duration: ${iterationDuration.inMilliseconds}ms > ${maxDuration.inMilliseconds}ms');
        }
      } catch (e) {
        failed++;
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }
    
    final totalDuration = DateTime.now().difference(startTime);
    
    return PerformanceTestResult(
      testName: testName,
      iterations: iterations,
      successful: successful,
      failed: failed,
      durations: durations,
      totalDuration: totalDuration,
      lastException: lastException,
    );
  }
  
  /// Verify test environment is properly set up
  static Future<void> verifyTestEnvironment() async {
    // Check if required services are available
    // Note: TestConfig doesn't have _initialized field, skip this check
    
    // Verify database connection
    final db = await TestDatabaseConfig.getInMemoryDatabase();
    expect(db, isNotNull);
    
    // Test basic database operations
    await db.execute('CREATE TABLE IF NOT EXISTS test_table (id TEXT PRIMARY KEY)');
    await db.insert('test_table', {'id': 'test'});
    final result = await db.query('test_table');
    expect(result.length, equals(1));
    
    await db.close();
  }
}

/// Performance test result model
class PerformanceTestResult {
  final String testName;
  final int iterations;
  final int successful;
  final int failed;
  final List<Duration> durations;
  final Duration totalDuration;
  final Exception? lastException;
  
  PerformanceTestResult({
    required this.testName,
    required this.iterations,
    required this.successful,
    required this.failed,
    required this.durations,
    required this.totalDuration,
    this.lastException,
  });
  
  bool get allPassed => failed == 0;
  
  Duration get averageDuration {
    if (durations.isEmpty) return Duration.zero;
    final totalMicros = durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicros ~/ durations.length);
  }
  
  Duration get minDuration => durations.isEmpty ? Duration.zero : durations.reduce((a, b) => a < b ? a : b);
  
  Duration get maxDuration => durations.isEmpty ? Duration.zero : durations.reduce((a, b) => a > b ? a : b);
  
  Map<String, dynamic> toJson() {
    return {
      'test_name': testName,
      'iterations': iterations,
      'successful': successful,
      'failed': failed,
      'success_rate': successful / iterations,
      'total_duration_ms': totalDuration.inMilliseconds,
      'average_duration_ms': averageDuration.inMilliseconds,
      'min_duration_ms': minDuration.inMilliseconds,
      'max_duration_ms': maxDuration.inMilliseconds,
      'has_errors': lastException != null,
      'last_error': lastException?.toString(),
    };
  }
  
  @override
  String toString() {
    return 'PerformanceTestResult(testName: $testName, success: $successful/$iterations, avgDuration: ${averageDuration.inMilliseconds}ms)';
  }
}

/// Image test utilities
class ImageTestUtils {
  /// Create test image data
  static Uint8List createTestImageData({
    int width = 100,
    int height = 100,
    ImageFormat format = ImageFormat.png,
  }) {
    // Create simple test image data
    final data = Uint8List(width * height * 4); // RGBA
    
    for (int i = 0; i < data.length; i += 4) {
      data[i] = 255;     // R
      data[i + 1] = 128; // G
      data[i + 2] = 64;  // B
      data[i + 3] = 255; // A
    }
    
    return data;
  }
  
  /// Create corrupted image data for testing error handling
  static Uint8List createCorruptedImageData() {
    return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // Invalid JPEG header
  }
  
  /// Create large test image for performance testing
  static Uint8List createLargeTestImage({int sizeInMB = 5}) {
    final sizeInBytes = sizeInMB * 1024 * 1024;
    final data = Uint8List(sizeInBytes);
    
    // Fill with pattern to simulate real image data
    for (int i = 0; i < data.length; i++) {
      data[i] = i % 256;
    }
    
    return data;
  }
}

/// Network test utilities
class NetworkTestUtils {
  /// Simulate network delay
  static Future<void> simulateNetworkDelay({
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    await Future.delayed(delay);
  }
  
  /// Simulate network timeout
  static Future<T> simulateNetworkTimeout<T>(
    Future<T> operation,
    Duration timeout,
  ) async {
    return await operation.timeout(timeout);
  }
  
  /// Create mock HTTP response data
  static Map<String, dynamic> createMockHttpResponse({
    int statusCode = 200,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    return {
      'status_code': statusCode,
      'headers': headers ?? {'content-type': 'application/json'},
      'body': body ?? {'success': true, 'data': {}},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// File system test utilities
class FileSystemTestUtils {
  /// Create temporary test directory
  static Future<String> createTempDirectory() async {
    final tempDir = '/tmp/bizsync_test_${DateTime.now().millisecondsSinceEpoch}';
    // In real implementation, would create actual directory
    return tempDir;
  }
  
  /// Clean up test files and directories
  static Future<void> cleanupTestFiles(List<String> paths) async {
    // In real implementation, would delete actual files
    for (final path in paths) {
      // Delete file/directory at path
    }
  }
  
  /// Create test file with specific content
  static Future<String> createTestFile(String content, {String? extension}) async {
    final fileName = 'test_file_${DateTime.now().millisecondsSinceEpoch}${extension ?? '.txt'}';
    final filePath = '/tmp/$fileName';
    
    // In real implementation, would create actual file
    return filePath;
  }
}

/// Available image formats for testing
enum ImageFormat {
  png,
  jpg,
  jpeg,
  gif,
  webp,
}

/// Test failure exception
class TestFailure implements Exception {
  final String message;
  
  TestFailure(this.message);
  
  @override
  String toString() => 'TestFailure: $message';
}

/// Main function for testing
void main() {
  // This is a test utilities library, not meant to be run directly
  // Individual tests will import the required utilities
}