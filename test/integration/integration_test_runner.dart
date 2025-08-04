import 'package:flutter_test/flutter_test.dart';
import 'invoice_flow_test.dart' as invoice_tests;
import 'inventory_management_test.dart' as inventory_tests;
import 'customer_management_test.dart' as customer_tests;
import 'tax_calculations_test.dart' as tax_tests;
import 'offline_functionality_test.dart' as offline_tests;
import 'data_integrity_test.dart' as integrity_tests;

/// Comprehensive integration test runner for BizSync critical business paths
/// This serves as the main entry point for running all integration tests
void main() {
  group('BizSync Production Validation Suite', () {
    print('🚀 Starting BizSync Integration Test Suite...');
    print('📋 Testing critical business paths before production release');

    // Run all integration test suites
    invoice_tests.main();
    inventory_tests.main();
    customer_tests.main();
    tax_tests.main();
    offline_tests.main();
    integrity_tests.main();

    print('✅ BizSync Integration Test Suite Complete');
  });
}
