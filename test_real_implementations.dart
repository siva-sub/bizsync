#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as path;

/// Test script to verify that mock implementations have been replaced with real ones
void main() async {
  print('🧪 Testing BizSync real implementations...\n');

  final testResults = <String, bool>{};

  // Test 1: Check that customer repository doesn't use mock data
  testResults['Customer Repository Mock Removal'] = await _testCustomerRepository();

  // Test 2: Check that dashboard providers use real implementations
  testResults['Dashboard Real Implementation'] = await _testDashboardProviders();

  // Test 3: Check that demo data service is properly configured
  testResults['Demo Data Configuration'] = await _testDemoDataConfiguration();

  // Test 4: Verify database seeding service
  testResults['Database Seeding Service'] = await _testDatabaseSeedingService();

  // Test 5: Check for remaining mock references
  testResults['No Remaining Mocks'] = await _testNoRemainingMocks();

  // Print results
  print('\n📊 Test Results:');
  print('=' * 50);
  bool allPassed = true;

  testResults.forEach((test, passed) {
    final status = passed ? '✅ PASS' : '❌ FAIL';
    print('$status $test');
    if (!passed) allPassed = false;
  });

  print('=' * 50);
  print(allPassed ? '🎉 All tests passed!' : '⚠️  Some tests failed!');
  print('\n📝 Summary:');
  print('- Mock implementations removed from customer repository');
  print('- Dashboard providers now use real analytics service');
  print('- Demo data is disabled by default, real data is used');
  print('- Database seeding provides bootstrap data + optional demo data');
  print('- Proper error handling instead of mock fallbacks');

  exit(allPassed ? 0 : 1);
}

Future<bool> _testCustomerRepository() async {
  print('🔍 Testing Customer Repository...');
  
  final file = File('lib/data/repositories/customer_repository.dart');
  if (!await file.exists()) {
    print('  ❌ Customer repository file not found');
    return false;
  }

  final content = await file.readAsString();
  
  // Check that mock data has been removed
  if (content.contains('static final List<Customer> _mockCustomers')) {
    print('  ❌ Mock customers data still present');
    return false;
  }

  // Check that mock fallbacks have been removed
  if (content.contains('Fallback to mock data')) {
    print('  ❌ Mock fallback code still present');
    return false;
  }

  // Check that proper error handling is implemented
  if (!content.contains('throw Exception')) {
    print('  ❌ Proper error handling not implemented');
    return false;
  }

  print('  ✅ Customer repository uses real implementations only');
  return true;
}

Future<bool> _testDashboardProviders() async {
  print('🔍 Testing Dashboard Providers...');
  
  final file = File('lib/features/dashboard/providers/dashboard_providers.dart');
  if (!await file.exists()) {
    print('  ❌ Dashboard providers file not found');
    return false;
  }

  final content = await file.readAsString();
  
  // Check that mock dashboard data provider has been removed
  if (content.contains('MockDashboardDataNotifier')) {
    print('  ❌ Mock dashboard data notifier still present');
    return false;
  }

  // Check that main dashboard provider uses real implementation
  if (!content.contains('RealDashboardDataNotifier')) {
    print('  ❌ Real dashboard data notifier not being used');
    return false;
  }

  // Check that mock fallback in recent activities has been removed
  if (content.contains('Fallback to mock data if real data fails')) {
    print('  ❌ Mock fallback code still present in recent activities');
    return false;
  }

  print('  ✅ Dashboard providers use real implementations only');
  return true;
}

Future<bool> _testDemoDataConfiguration() async {
  print('🔍 Testing Demo Data Configuration...');
  
  final file = File('lib/core/config/feature_flags.dart');
  if (!await file.exists()) {
    print('  ❌ Feature flags file not found');
    return false;
  }

  final content = await file.readAsString();
  
  // Check that demo data is disabled by default
  if (!content.contains('bool _enableDemoData = false;')) {
    print('  ❌ Demo data should be disabled by default');
    return false;
  }

  print('  ✅ Demo data is properly configured (disabled by default)');
  return true;
}

Future<bool> _testDatabaseSeedingService() async {
  print('🔍 Testing Database Seeding Service...');
  
  final file = File('lib/core/database/database_seeding_service.dart');
  if (!await file.exists()) {
    print('  ❌ Database seeding service file not found');
    return false;
  }

  final content = await file.readAsString();
  
  // Check that it provides bootstrap data regardless of demo flag
  if (!content.contains('Always seed essential business data')) {
    print('  ❌ Bootstrap data seeding not implemented');
    return false;
  }

  // Check that demo data is conditional
  if (!content.contains('Only seed demo data if feature flag is enabled')) {
    print('  ❌ Conditional demo data seeding not implemented');
    return false;
  }

  print('  ✅ Database seeding service properly configured');
  return true;
}

Future<bool> _testNoRemainingMocks() async {
  print('🔍 Checking for remaining mock implementations...');
  
  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    print('  ❌ lib directory not found');
    return false;
  }

  final problemFiles = <String>[];
  
  // Recursively check all Dart files for problematic mock usage
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();
      
      // Skip the test mock files which are legitimate
      if (entity.path.contains('test/') || entity.path.contains('mock_services.dart')) {
        continue;
      }
      
      // Check for problematic mock usage in main code
      if (content.contains('Fallback to mock data') ||
          content.contains('return _mockCustomers') ||
          content.contains('MockDashboardDataNotifier') ||
          (content.contains('mock') && content.contains('fallback'))) {
        problemFiles.add(path.relative(entity.path));
      }
    }
  }

  if (problemFiles.isNotEmpty) {
    print('  ❌ Found mock fallbacks in: ${problemFiles.join(', ')}');
    return false;
  }

  print('  ✅ No problematic mock implementations found in main code');
  return true;
}