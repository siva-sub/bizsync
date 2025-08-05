/// Comprehensive Test Runner for BizSync Test Suite
library run_all_tests;

import 'dart:io';
import 'dart:async';

void main() async {
  print('🚀 BizSync Comprehensive Test Suite Runner');
  print('============================================');
  
  final runner = TestSuiteRunner();
  await runner.runAllTests([]);
}

class TestSuiteRunner {
  final List<TestResult> _results = [];
  
  Future<void> runAllTests(List<String> args) async {
    final startTime = DateTime.now();
    
    try {
      print('\n📋 Starting comprehensive test execution...\n');
      
      // Parse command line arguments
      final config = _parseArguments(args);
      
      // Verify test environment
      await _verifyTestEnvironment();
      
      // Run test categories based on configuration
      if (config.runUnit) await _runUnitTests();
      if (config.runWidget) await _runWidgetTests();
      if (config.runIntegration) await _runIntegrationTests();
      if (config.runPerformance) await _runPerformanceTests();
      
      // Generate comprehensive report
      await _generateTestReport(startTime);
      
      // Exit with appropriate code
      final failed = _results.where((r) => !r.passed).length;
      exit(failed > 0 ? 1 : 0);
      
    } catch (e) {
      print('❌ Test runner failed: $e');
      exit(2);
    }
  }
  
  TestRunnerConfig _parseArguments(List<String> args) {
    final config = TestRunnerConfig();
    
    for (final arg in args) {
      switch (arg) {
        case '--unit-only':
          config.runUnit = true;
          config.runWidget = false;
          config.runIntegration = false;
          config.runPerformance = false;
          break;
        case '--widget-only':
          config.runUnit = false;
          config.runWidget = true;
          config.runIntegration = false;
          config.runPerformance = false;
          break;
        case '--integration-only':
          config.runUnit = false;
          config.runWidget = false;
          config.runIntegration = true;
          config.runPerformance = false;
          break;
        case '--performance-only':
          config.runUnit = false;
          config.runWidget = false;
          config.runIntegration = false;
          config.runPerformance = true;
          break;
        case '--fast':
          config.runIntegration = false;
          config.runPerformance = false;
          break;
        case '--with-coverage':
          config.generateCoverage = true;
          break;
        case '--verbose':
          config.verbose = true;
          break;
        case '--help':
          _printUsage();
          exit(0);
      }
    }
    
    return config;
  }
  
  void _printUsage() {
    print('''
BizSync Test Suite Runner

Usage: dart test/run_all_tests.dart [options]

Options:
  --unit-only         Run only unit tests
  --widget-only       Run only widget tests  
  --integration-only  Run only integration tests
  --performance-only  Run only performance tests
  --fast             Skip slow tests (integration and performance)
  --with-coverage    Generate coverage report
  --verbose          Enable verbose output
  --help             Show this help message

Examples:
  dart test/run_all_tests.dart                    # Run all tests
  dart test/run_all_tests.dart --fast             # Run fast tests only
  dart test/run_all_tests.dart --unit-only        # Run unit tests only
  dart test/run_all_tests.dart --with-coverage    # Run with coverage
''');
  }
  
  Future<void> _verifyTestEnvironment() async {
    print('🔍 Verifying test environment...');
    
    // Check Flutter installation
    final flutterResult = await Process.run('flutter', ['--version']);
    if (flutterResult.exitCode != 0) {
      throw Exception('Flutter not found or not properly installed');
    }
    
    // Check dependencies
    final pubGetResult = await Process.run('flutter', ['pub', 'get']);
    if (pubGetResult.exitCode != 0) {
      throw Exception('Failed to get dependencies: ${pubGetResult.stderr}');
    }
    
    // Verify test files exist
    final testDirs = [
      Directory('test/unit'),
      Directory('test/widget'),
      Directory('test/integration'),
      Directory('test/performance'),
    ];
    
    for (final dir in testDirs) {
      if (!dir.existsSync()) {
        throw Exception('Test directory not found: ${dir.path}');
      }
    }
    
    print('✅ Test environment verified');
  }
  
  Future<void> _runUnitTests() async {
    print('\n📝 Running Unit Tests...');
    print('========================');
    
    final unitTests = [
      'test/unit/database/database_schema_migration_test.dart',
      'test/unit/validation/null_safety_validation_test.dart',
      'test/unit/services/comprehensive_profile_picture_test.dart',
      'test/unit/notifications/notification_system_test.dart',
      'test/unit/crdt/crdt_synchronization_test.dart',
    ];
    
    for (final test in unitTests) {
      await _runSingleTest(test, 'Unit');
    }
  }
  
  Future<void> _runWidgetTests() async {
    print('\n🎨 Running Widget Tests...');
    print('===========================');
    
    final widgetTests = [
      'test/widget/ui_components_test.dart',
    ];
    
    for (final test in widgetTests) {
      await _runSingleTest(test, 'Widget');
    }
  }
  
  Future<void> _runIntegrationTests() async {
    print('\n🔗 Running Integration Tests...');
    print('================================');
    
    final integrationTests = [
      'test/integration/critical_workflows_test.dart',
      'test/integration/customer_management_test.dart',
      'test/integration/data_integrity_test.dart',
      'test/integration/inventory_management_test.dart',
      'test/integration/invoice_flow_test.dart',
      'test/integration/offline_functionality_test.dart',
      'test/integration/tax_calculations_test.dart',
    ];
    
    for (final test in integrationTests) {
      await _runSingleTest(test, 'Integration', timeout: '5m');
    }
  }
  
  Future<void> _runPerformanceTests() async {
    print('\n⚡ Running Performance Tests...');
    print('===============================');
    
    final performanceTests = [
      'test/performance/performance_benchmarks_test.dart',
    ];
    
    for (final test in performanceTests) {
      await _runSingleTest(test, 'Performance', timeout: '10m');
    }
  }
  
  Future<void> _runSingleTest(String testPath, String category, {String? timeout}) async {
    final testName = testPath.split('/').last.replaceAll('_test.dart', '');
    print('  Running $testName...');
    
    final args = ['test', testPath];
    if (timeout != null) {
      args.addAll(['--timeout', timeout]);
    }
    
    final startTime = DateTime.now();
    final result = await Process.run('flutter', args);
    final duration = DateTime.now().difference(startTime);
    
    final testResult = TestResult(
      name: testName,
      category: category,
      path: testPath,
      passed: result.exitCode == 0,
      duration: duration,
      output: result.stdout.toString(),
      error: result.stderr.toString(),
    );
    
    _results.add(testResult);
    
    if (testResult.passed) {
      print('    ✅ $testName passed (${duration.inMilliseconds}ms)');
    } else {
      print('    ❌ $testName failed (${duration.inMilliseconds}ms)');
      if (testResult.error.isNotEmpty) {
        print('    Error: ${testResult.error}');
      }
    }
  }
  
  Future<void> _generateTestReport(DateTime startTime) async {
    final totalDuration = DateTime.now().difference(startTime);
    
    print('\n📊 Test Execution Summary');
    print('==========================');
    
    final totalTests = _results.length;
    final passedTests = _results.where((r) => r.passed).length;
    final failedTests = totalTests - passedTests;
    
    print('Total Tests: $totalTests');
    print('Passed: $passedTests');
    print('Failed: $failedTests');
    print('Success Rate: ${(passedTests / totalTests * 100).toStringAsFixed(1)}%');
    print('Total Duration: ${totalDuration.inSeconds}s');
    
    // Category breakdown
    print('\n📈 Results by Category:');
    final categories = _results.map((r) => r.category).toSet();
    for (final category in categories) {
      final categoryResults = _results.where((r) => r.category == category);
      final categoryPassed = categoryResults.where((r) => r.passed).length;
      final categoryTotal = categoryResults.length;
      
      print('  $category: $categoryPassed/$categoryTotal (${(categoryPassed / categoryTotal * 100).toStringAsFixed(1)}%)');
    }
    
    // Performance metrics
    print('\n⏱️ Performance Metrics:');
    final avgDuration = _results.fold<int>(0, (sum, r) => sum + r.duration.inMilliseconds) / _results.length;
    final slowestTest = _results.reduce((a, b) => a.duration > b.duration ? a : b);
    final fastestTest = _results.reduce((a, b) => a.duration < b.duration ? a : b);
    
    print('  Average test duration: ${avgDuration.toStringAsFixed(1)}ms');
    print('  Slowest test: ${slowestTest.name} (${slowestTest.duration.inMilliseconds}ms)');
    print('  Fastest test: ${fastestTest.name} (${fastestTest.duration.inMilliseconds}ms)');
    
    // Failed tests details
    if (failedTests > 0) {
      print('\n❌ Failed Tests Details:');
      final failed = _results.where((r) => !r.passed);
      for (final test in failed) {
        print('  - ${test.name} (${test.category})');
        if (test.error.isNotEmpty) {
          final errorLines = test.error.split('\n').take(3);
          for (final line in errorLines) {
            if (line.trim().isNotEmpty) {
              print('    $line');
            }
          }
        }
      }
    }
    
    // Generate detailed report file
    await _generateDetailedReport();
    
    // Final status
    print('\n' + '=' * 50);
    if (failedTests == 0) {
      print('🎉 ALL TESTS PASSED! 🎉');
      print('The BizSync application is ready for production.');
    } else {
      print('⚠️  SOME TESTS FAILED');
      print('Please review the failed tests and fix issues before deployment.');
    }
    print('=' * 50);
  }
  
  Future<void> _generateDetailedReport() async {
    final reportFile = File('test_report_${DateTime.now().millisecondsSinceEpoch}.json');
    
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'summary': {
        'total_tests': _results.length,
        'passed_tests': _results.where((r) => r.passed).length,
        'failed_tests': _results.where((r) => !r.passed).length,
        'total_duration_ms': _results.fold<int>(0, (sum, r) => sum + r.duration.inMilliseconds),
      },
      'results': _results.map((r) => r.toJson()).toList(),
      'environment': {
        'platform': Platform.operatingSystem,
        'dart_version': Platform.version,
        'flutter_version': await _getFlutterVersion(),
      },
    };
    
    await reportFile.writeAsString(_formatJson(report));
    print('\n📄 Detailed report saved to: ${reportFile.path}');
  }
  
  Future<String> _getFlutterVersion() async {
    try {
      final result = await Process.run('flutter', ['--version']);
      return result.stdout.toString().split('\n').first;
    } catch (e) {
      return 'Unknown';
    }
  }
  
  String _formatJson(Map<String, dynamic> json) {
    // Simple JSON formatting for report
    return json.entries
        .map((e) => '"${e.key}": ${_jsonValue(e.value)}')
        .join(',\n');
  }
  
  String _jsonValue(dynamic value) {
    if (value is String) return '"$value"';
    if (value is Map) return '{${_formatJson(Map<String, dynamic>.from(value))}}';
    if (value is List) return '[${value.map(_jsonValue).join(',')}]';
    return value.toString();
  }
}

class TestRunnerConfig {
  bool runUnit = true;
  bool runWidget = true;
  bool runIntegration = true;
  bool runPerformance = true;
  bool generateCoverage = false;
  bool verbose = false;
}

class TestResult {
  final String name;
  final String category;
  final String path;
  final bool passed;
  final Duration duration;
  final String output;
  final String error;
  
  TestResult({
    required this.name,
    required this.category,
    required this.path,
    required this.passed,
    required this.duration,
    required this.output,
    required this.error,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'path': path,
      'passed': passed,
      'duration_ms': duration.inMilliseconds,
      'output': output,
      'error': error,
    };
  }
}