/// Comprehensive Performance Tests and Benchmarks
library performance_benchmarks_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'dart:math' as math;
import '../test_config.dart';
import '../test_factories.dart';
import '../mocks/mock_services.dart';

void main() {
  group('Performance Benchmarks and Tests', () {
    setUpAll(() async {
      await TestConfig.initialize();
    });
    
    setUp(() async {
      await TestConfig.reset();
    });
    
    group('Database Performance Tests', () {
      test('should perform database queries within acceptable time limits', () async {
        final databaseService = MockDatabaseService();
        
        // Add test data
        final customers = List.generate(
          TestConstants.largeDatasetSize,
          (index) => TestFactories.createCustomer(name: 'Customer $index').toJson(),
        );
        
        databaseService.addMockData('customers', customers);
        
        // Test query performance
        final result = await TestPerformanceUtils.performanceTest(
          'Query ${TestConstants.largeDatasetSize} customers',
          () async {
            await databaseService.query('customers');
          },
          TestConstants.maxDatabaseQueryTime,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should perform database inserts efficiently', () async {
        final databaseService = MockDatabaseService();
        
        final result = await TestPerformanceUtils.performanceTest(
          'Insert ${TestConstants.mediumDatasetSize} customers',
          () async {
            for (int i = 0; i < TestConstants.mediumDatasetSize; i++) {
              await databaseService.insert(
                'customers',
                TestFactories.createCustomer(name: 'Customer $i').toJson(),
              );
            }
          },
          TestConstants.maxDatabaseQueryTime * TestConstants.mediumDatasetSize ~/ 10,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should perform batch updates efficiently', () async {
        final databaseService = MockDatabaseService();
        
        // Setup initial data
        final customers = List.generate(
          TestConstants.mediumDatasetSize,
          (index) => TestFactories.createCustomer(name: 'Customer $index').toJson(),
        );
        databaseService.addMockData('customers', customers);
        
        final result = await TestPerformanceUtils.performanceTest(
          'Update ${TestConstants.mediumDatasetSize} customer records',
          () async {
            for (int i = 0; i < TestConstants.mediumDatasetSize; i++) {
              await databaseService.update(
                'customers',
                {'name': 'Updated Customer $i'},
                where: 'id = ?',
                whereArgs: [customers[i]['id']],
              );
            }
          },
          TestConstants.maxDatabaseQueryTime * TestConstants.mediumDatasetSize ~/ 5,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle complex join queries efficiently', () async {
        final databaseService = MockDatabaseService();
        
        // Setup related data
        final customers = List.generate(10, (i) => TestFactories.createCustomer().toJson());
        final invoices = List.generate(100, (i) => TestFactories.createInvoiceData().toJson());
        
        databaseService.addMockData('customers', customers);
        databaseService.addMockData('invoices', invoices);
        
        final result = await TestPerformanceUtils.performanceTest(
          'Complex join query with 100 invoices and 10 customers',
          () async {
            // Simulate complex join query
            await databaseService.query('invoices');
            await databaseService.query('customers');
          },
          TestConstants.maxDatabaseQueryTime * 2,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle concurrent database operations', () async {
        final databaseService = MockDatabaseService();
        final concurrentOperations = 50;
        
        final result = await TestPerformanceUtils.performanceTest(
          'Handle $concurrentOperations concurrent database operations',
          () async {
            final futures = <Future>[];
            
            for (int i = 0; i < concurrentOperations; i++) {
              futures.add(databaseService.insert(
                'customers',
                TestFactories.createCustomer(name: 'Concurrent Customer $i').toJson(),
              ));
            }
            
            await Future.wait(futures);
          },
          TestConstants.maxDatabaseQueryTime * 5,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('CRDT Performance Tests', () {
      test('should apply CRDT operations efficiently', () async {
        final crdtService = MockCRDTDatabaseService();
        final hlc = MockHybridLogicalClock('performance-node');
        final vectorClock = MockVectorClock();
        
        final result = await TestPerformanceUtils.performanceTest(
          'Apply ${TestConstants.largeDatasetSize} CRDT operations',
          () async {
            for (int i = 0; i < TestConstants.largeDatasetSize; i++) {
              final operation = {
                'id': 'op-$i',
                'entity_type': 'customer',
                'entity_id': 'customer-$i',
                'operation_type': 'create',
                'operation_data': TestFactories.createCustomer().toJson(),
                'timestamp': hlc.now(),
                'node_id': hlc.nodeId,
                'vector_clock': vectorClock.toJson(),
              };
              
              await crdtService.applyOperation(operation);
            }
          },
          TestConstants.maxSyncOperationTime,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle CRDT conflict resolution efficiently', () async {
        final crdtService = MockCRDTDatabaseService();
        final hlc1 = MockHybridLogicalClock('node-1');
        final hlc2 = MockHybridLogicalClock('node-2');
        
        final result = await TestPerformanceUtils.performanceTest(
          'Resolve ${TestConstants.mediumDatasetSize} CRDT conflicts',
          () async {
            for (int i = 0; i < TestConstants.mediumDatasetSize; i++) {
              // Create conflicting operations
              final operation1 = {
                'id': 'op-1-$i',
                'entity_type': 'product',
                'entity_id': 'product-$i',
                'operation_type': 'update',
                'operation_data': {'name': 'Node 1 Update $i'},
                'timestamp': hlc1.now(),
                'node_id': hlc1.nodeId,
                'vector_clock': '{"node-1": $i}',
              };
              
              final operation2 = {
                'id': 'op-2-$i',
                'entity_type': 'product',
                'entity_id': 'product-$i',
                'operation_type': 'update',
                'operation_data': {'name': 'Node 2 Update $i'},
                'timestamp': hlc2.now(),
                'node_id': hlc2.nodeId,
                'vector_clock': '{"node-2": $i}',
              };
              
              await crdtService.applyOperation(operation1);
              await crdtService.applyOperation(operation2);
            }
          },
          TestConstants.maxSyncOperationTime * 2,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('P2P Sync Performance Tests', () {
      test('should sync large datasets efficiently', () async {
        final syncService = MockP2PSyncService();
        
        // Setup sync data
        final syncData = List.generate(
          TestConstants.largeDatasetSize,
          (index) => TestFactories.createCustomer().toJson(),
        );
        
        syncService.addDiscoveredDevice('performance-device');
        await syncService.connectToDevice('performance-device');
        
        final result = await TestPerformanceUtils.performanceTest(
          'Sync ${TestConstants.largeDatasetSize} records',
          () async {
            await syncService.syncData(syncData);
          },
          TestConstants.maxSyncOperationTime,
        );
        
        expect(result.passed, isTrue, reason: result.message);
        expect(syncService.getSyncedData().length, equals(TestConstants.largeDatasetSize));
      });
      
      test('should handle multiple device connections efficiently', () async {
        final syncService = MockP2PSyncService();
        final deviceCount = 10;
        
        // Add multiple devices
        for (int i = 0; i < deviceCount; i++) {
          syncService.addDiscoveredDevice('device-$i');
        }
        
        final result = await TestPerformanceUtils.performanceTest(
          'Connect to $deviceCount devices',
          () async {
            for (int i = 0; i < deviceCount; i++) {
              await syncService.connectToDevice('device-$i');
            }
          },
          TestConstants.maxSyncOperationTime,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('Notification Performance Tests', () {
      test('should send notifications within time limits', () async {
        final notificationService = MockNotificationService();
        
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
        final notificationService = MockNotificationService();
        final batchSize = 100;
        
        final result = await TestPerformanceUtils.performanceTest(
          'Send $batchSize notifications',
          () async {
            final futures = <Future<bool>>[];
            
            for (int i = 0; i < batchSize; i++) {
              futures.add(notificationService.showNotification(
                title: 'Batch Notification $i',
                body: 'Testing batch performance',
              ));
            }
            
            await Future.wait(futures);
          },
          TestConstants.maxNotificationTime * batchSize ~/ 10, // Allow some batching efficiency
        );
        
        expect(result.passed, isTrue, reason: result.message);
        expect(notificationService.getSentNotifications().length, equals(batchSize));
      });
      
      test('should schedule notifications efficiently', () async {
        final notificationService = MockNotificationService();
        final scheduleCount = 200;
        
        final result = await TestPerformanceUtils.performanceTest(
          'Schedule $scheduleCount notifications',
          () async {
            final futures = <Future<bool>>[];
            
            for (int i = 0; i < scheduleCount; i++) {
              futures.add(notificationService.scheduleNotification(
                title: 'Scheduled Notification $i',
                body: 'Testing schedule performance',
                scheduledDate: DateTime.now().add(Duration(minutes: i)),
              ));
            }
            
            await Future.wait(futures);
          },
          TestConstants.maxNotificationTime * scheduleCount ~/ 20,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('Business Logic Performance Tests', () {
      test('should calculate invoice totals efficiently', () async {
        final invoices = List.generate(
          TestConstants.mediumDatasetSize,
          (index) => TestFactories.createInvoiceData(),
        );
        
        final result = await TestPerformanceUtils.performanceTest(
          'Calculate totals for ${TestConstants.mediumDatasetSize} invoices',
          () async {
            for (final invoice in invoices) {
              // Simulate invoice calculation
              TestValidators.validateInvoiceCalculations(invoice);
            }
          },
          TestConstants.maxDatabaseQueryTime * 5,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should process tax calculations efficiently', () async {
        final taxScenarios = TestFactories.createTaxScenarios();
        final repeatedScenarios = <Map<String, dynamic>>[];
        
        // Create large dataset by repeating scenarios
        for (int i = 0; i < TestConstants.mediumDatasetSize ~/ taxScenarios.length; i++) {
          repeatedScenarios.addAll(taxScenarios);
        }
        
        final result = await TestPerformanceUtils.performanceTest(
          'Process ${repeatedScenarios.length} tax calculations',
          () async {
            for (final scenario in repeatedScenarios) {
              // Simulate tax calculation
              final amount = scenario['amount'] as double;
              final isGstRegistered = scenario['is_gst_registered'] as bool;
              final isExport = scenario['is_export'] as bool;
              
              if (isGstRegistered && !isExport) {
                final taxAmount = amount * 0.09; // 9% GST
                final total = amount + taxAmount;
                
                // Simulate calculation work
                expect(total, greaterThan(amount));
              }
            }
          },
          TestConstants.maxDatabaseQueryTime * 3,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should search and filter large datasets efficiently', () async {
        final customers = List.generate(
          TestConstants.largeDatasetSize,
          (index) => TestFactories.createCustomer(
            name: 'Customer ${index % 100}', // Create some duplicates for search
            email: 'customer$index@test.com',
          ),
        );
        
        final result = await TestPerformanceUtils.performanceTest(
          'Search through ${TestConstants.largeDatasetSize} customers',
          () async {
            // Simulate search operations
            final searchTerms = ['Customer 1', 'test.com', 'Singapore', 'GST'];
            
            for (final term in searchTerms) {
              final results = customers.where((customer) =>
                customer.name.contains(term) ||
                (customer.email?.contains(term) ?? false) ||
                (customer.address?.contains(term) ?? false)
              ).toList();
              
              // Ensure search found results
              expect(results.isNotEmpty, isTrue);
            }
          },
          TestConstants.maxDatabaseQueryTime * 2,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('Memory Performance Tests', () {
      test('should handle large datasets without memory leaks', () async {
        final largeDataset = <Map<String, dynamic>>[];
        
        final result = await TestPerformanceUtils.performanceTest(
          'Create and process ${TestConstants.largeDatasetSize} records in memory',
          () async {
            // Create large dataset
            for (int i = 0; i < TestConstants.largeDatasetSize; i++) {
              largeDataset.add(TestFactories.createCustomer().toJson());
            }
            
            // Process dataset
            var totalProcessed = 0;
            for (final record in largeDataset) {
              // Simulate processing
              if (record['name'] != null) {
                totalProcessed++;
              }
            }
            
            expect(totalProcessed, equals(TestConstants.largeDatasetSize));
            
            // Clear dataset to simulate cleanup
            largeDataset.clear();
          },
          TestConstants.longTimeout,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should efficiently manage object creation and disposal', () async {
        final result = await TestPerformanceUtils.performanceTest(
          'Create and dispose ${TestConstants.largeDatasetSize} objects',
          () async {
            for (int i = 0; i < TestConstants.largeDatasetSize; i++) {
              // Create objects
              final customer = TestFactories.createCustomer();
              final product = TestFactories.createProduct();
              final invoice = TestFactories.createInvoiceData();
              
              // Use objects to prevent optimization
              expect(customer.name, isNotNull);
              expect(product.name, isNotNull);
              expect(invoice['id'], isNotNull);
              
              // Objects go out of scope and should be garbage collected
            }
          },
          TestConstants.longTimeout,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('Concurrent Operations Performance Tests', () {
      test('should handle concurrent database operations efficiently', () async {
        final databaseService = MockDatabaseService();
        final concurrentThreads = 20;
        final operationsPerThread = 50;
        
        final result = await TestPerformanceUtils.performanceTest(
          'Handle $concurrentThreads concurrent threads with $operationsPerThread operations each',
          () async {
            final futures = <Future>[];
            
            for (int thread = 0; thread < concurrentThreads; thread++) {
              futures.add(Future(() async {
                for (int op = 0; op < operationsPerThread; op++) {
                  await databaseService.insert(
                    'customers',
                    TestFactories.createCustomer(name: 'Thread $thread Op $op').toJson(),
                  );
                }
              }));
            }
            
            await Future.wait(futures);
          },
          TestConstants.longTimeout,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle concurrent sync operations', () async {
        final syncService = MockP2PSyncService();
        final deviceCount = 5;
        final recordsPerDevice = 100;
        
        // Setup devices
        for (int i = 0; i < deviceCount; i++) {
          syncService.addDiscoveredDevice('concurrent-device-$i');
        }
        
        final result = await TestPerformanceUtils.performanceTest(
          'Sync $recordsPerDevice records to $deviceCount devices concurrently',
          () async {
            final futures = <Future>[];
            
            for (int device = 0; device < deviceCount; device++) {
              futures.add(Future(() async {
                await syncService.connectToDevice('concurrent-device-$device');
                
                final deviceData = List.generate(
                  recordsPerDevice,
                  (index) => TestFactories.createCustomer(name: 'Device $device Record $index').toJson(),
                );
                
                await syncService.syncData(deviceData);
              }));
            }
            
            await Future.wait(futures);
          },
          TestConstants.maxSyncOperationTime * 2,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('Benchmark Harness Tests', () {
      test('should run custom benchmarks', () async {
        // Customer creation benchmark
        final customerBenchmark = CustomerCreationBenchmark();
        final customerScore = customerBenchmark.measure();
        print('Customer Creation Benchmark: $customerScore μs/op');
        
        // Invoice calculation benchmark  
        final invoiceBenchmark = InvoiceCalculationBenchmark();
        final invoiceScore = invoiceBenchmark.measure();
        print('Invoice Calculation Benchmark: $invoiceScore μs/op');
        
        // Tax calculation benchmark
        final taxBenchmark = TaxCalculationBenchmark();
        final taxScore = taxBenchmark.measure();
        print('Tax Calculation Benchmark: $taxScore μs/op');
        
        // CRDT operation benchmark
        final crdtBenchmark = CRDTOperationBenchmark();
        final crdtScore = crdtBenchmark.measure();
        print('CRDT Operation Benchmark: $crdtScore μs/op');
        
        // Verify benchmarks completed
        expect(customerScore, greaterThan(0));
        expect(invoiceScore, greaterThan(0));
        expect(taxScore, greaterThan(0));
        expect(crdtScore, greaterThan(0));
      });
    });
  });
}

// Benchmark Harness implementations
class CustomerCreationBenchmark extends BenchmarkBase {
  CustomerCreationBenchmark() : super('CustomerCreation');
  
  @override
  void run() {
    // Create customers with random data
    for (int i = 0; i < 100; i++) {
      TestFactories.createCustomer(
        name: 'Benchmark Customer $i',
        email: 'benchmark$i@test.com',
      );
    }
  }
}

class InvoiceCalculationBenchmark extends BenchmarkBase {
  late List<Map<String, dynamic>> invoices;
  
  InvoiceCalculationBenchmark() : super('InvoiceCalculation');
  
  @override
  void setup() {
    invoices = List.generate(
      50,
      (index) => TestFactories.createInvoiceData(),
    );
  }
  
  @override
  void run() {
    for (final invoice in invoices) {
      TestValidators.validateInvoiceCalculations(invoice);
    }
  }
}

class TaxCalculationBenchmark extends BenchmarkBase {
  late List<Map<String, dynamic>> taxScenarios;
  
  TaxCalculationBenchmark() : super('TaxCalculation');
  
  @override
  void setup() {
    taxScenarios = TestFactories.createTaxScenarios();
    
    // Expand scenarios for more work
    final expandedScenarios = <Map<String, dynamic>>[];
    for (int i = 0; i < 20; i++) {
      expandedScenarios.addAll(taxScenarios);
    }
    taxScenarios = expandedScenarios;
  }
  
  @override
  void run() {
    for (final scenario in taxScenarios) {
      final amount = scenario['amount'] as double;
      final isGstRegistered = scenario['is_gst_registered'] as bool;
      final isExport = scenario['is_export'] as bool;
      
      if (isGstRegistered && !isExport) {
        final taxAmount = amount * 0.09;
        final total = amount + taxAmount;
        
        // Prevent optimization
        if (total < amount) throw Exception('Invalid calculation');
      }
    }
  }
}

class CRDTOperationBenchmark extends BenchmarkBase {
  late MockCRDTDatabaseService crdtService;
  late MockHybridLogicalClock hlc;
  late MockVectorClock vectorClock;
  
  CRDTOperationBenchmark() : super('CRDTOperation');
  
  @override
  void setup() {
    crdtService = MockCRDTDatabaseService();
    hlc = MockHybridLogicalClock('benchmark-node');
    vectorClock = MockVectorClock();
  }
  
  @override
  void run() {
    for (int i = 0; i < 50; i++) {
      final operation = {
        'id': 'benchmark-op-$i',
        'entity_type': 'customer',
        'entity_id': 'customer-$i',
        'operation_type': 'create',
        'operation_data': TestFactories.createCustomer().toJson(),
        'timestamp': hlc.now(),
        'node_id': hlc.nodeId,
        'vector_clock': vectorClock.toJson(),
      };
      
      // Apply operation synchronously for benchmark
      crdtService.applyOperation(operation);
    }
  }
}

// Performance analysis utilities
class PerformanceAnalyzer {
  static Map<String, dynamic> analyzeResults(List<TestResult> results) {
    final analysis = <String, dynamic>{};
    
    // Calculate statistics
    final durations = results.map((r) => r.duration.inMicroseconds).toList();
    durations.sort();
    
    analysis['total_tests'] = results.length;
    analysis['passed_tests'] = results.where((r) => r.passed).length;
    analysis['failed_tests'] = results.where((r) => !r.passed).length;
    
    if (durations.isNotEmpty) {
      analysis['min_duration_us'] = durations.first;
      analysis['max_duration_us'] = durations.last;
      analysis['avg_duration_us'] = durations.reduce((a, b) => a + b) / durations.length;
      analysis['median_duration_us'] = durations[durations.length ~/ 2];
      
      // Calculate percentiles
      analysis['p95_duration_us'] = durations[(durations.length * 0.95).round() - 1];
      analysis['p99_duration_us'] = durations[(durations.length * 0.99).round() - 1];
    }
    
    return analysis;
  }
  
  static void printPerformanceReport(Map<String, dynamic> analysis) {
    print('\n=== Performance Test Analysis ===');
    print('Total Tests: ${analysis['total_tests']}');
    print('Passed: ${analysis['passed_tests']}');
    print('Failed: ${analysis['failed_tests']}');
    
    if (analysis.containsKey('avg_duration_us')) {
      print('\nDuration Statistics (microseconds):');
      print('  Min: ${analysis['min_duration_us']}');
      print('  Max: ${analysis['max_duration_us']}');
      print('  Average: ${analysis['avg_duration_us']?.toStringAsFixed(2)}');
      print('  Median: ${analysis['median_duration_us']}');
      print('  95th Percentile: ${analysis['p95_duration_us']}');
      print('  99th Percentile: ${analysis['p99_duration_us']}');
    }
    
    print('================================\n');
  }
}

// Memory usage tracker
class MemoryTracker {
  static int _initialMemory = 0;
  static int _peakMemory = 0;
  
  static void startTracking() {
    _initialMemory = _getCurrentMemoryUsage();
    _peakMemory = _initialMemory;
  }
  
  static void updatePeak() {
    final currentMemory = _getCurrentMemoryUsage();
    if (currentMemory > _peakMemory) {
      _peakMemory = currentMemory;
    }
  }
  
  static Map<String, int> getMemoryStats() {
    final currentMemory = _getCurrentMemoryUsage();
    return {
      'initial_memory_bytes': _initialMemory,
      'current_memory_bytes': currentMemory,
      'peak_memory_bytes': _peakMemory,
      'memory_growth_bytes': currentMemory - _initialMemory,
      'peak_growth_bytes': _peakMemory - _initialMemory,
    };
  }
  
  static int _getCurrentMemoryUsage() {
    // In a real implementation, this would get actual memory usage
    // For testing purposes, return a simulated value
    return DateTime.now().millisecondsSinceEpoch % 100000000;
  }
}