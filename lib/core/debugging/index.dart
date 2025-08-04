/// BizSync Hypothesis-Driven Debugging Framework
/// 
/// A comprehensive, production-ready debugging system designed to predict,
/// detect, prevent, and resolve errors before they impact users.
/// 
/// This framework implements advanced debugging methodologies including:
/// - Hypothesis-driven debugging with error prediction
/// - Runtime validation of critical operations
/// - Schema consistency monitoring
/// - Null safety validation with auto-fixing
/// - CRDT operation monitoring and conflict resolution
/// - UI state validation and performance monitoring
/// - Automated error reporting and pattern analysis
/// - Performance monitoring with bottleneck detection
/// 
/// ## Quick Start
/// 
/// ```dart
/// import 'package:bizsync/core/debugging/index.dart';
/// 
/// void main() async {
///   final databaseService = CRDTDatabaseService();
///   await databaseService.initialize();
///   
///   final debugFramework = DebugFrameworkService(databaseService);
///   await debugFramework.initialize(
///     userId: 'user123',
///     config: {'enable_auto_fix': true}
///   );
///   
///   // Run diagnostics
///   final diagnostics = await debugFramework.runComprehensiveDiagnostics();
///   print('System Health: ${diagnostics['overall_health']}');
/// }
/// ```
/// 
/// ## Components
/// 
/// - [DebugFrameworkService]: Main orchestration service
/// - [HypothesisDrivenDebugger]: Error prediction and hypothesis validation
/// - [RuntimeValidator]: Real-time operation validation
/// - [SchemaValidator]: Database schema consistency validation
/// - [NullSafetyValidator]: Null safety validation with auto-fixing
/// - [CRDTMonitor]: CRDT operation monitoring and conflict resolution
/// - [UIStateValidator]: UI state and performance monitoring
/// - [ErrorReportingSystem]: Comprehensive error reporting and analysis
/// - [PerformanceMonitor]: Performance monitoring and bottleneck detection

library bizsync_debugging_framework;

// Core debugging service
export 'debug_framework_service.dart';

// Hypothesis-driven debugging
export 'hypothesis_driven_debugger.dart';

// Validation components
export 'runtime_validator.dart';
export 'schema_validator.dart';
export 'null_safety_validator.dart';

// Monitoring components
export 'crdt_monitor.dart';
export 'ui_state_validator.dart';
export 'performance_monitor.dart';

// Error reporting
export 'error_reporting_system.dart';

// Re-export commonly used types and enums

/// Hypothesis-driven debugging types
export 'hypothesis_driven_debugger.dart' show
    HypothesisType,
    ConfidenceLevel,
    DebugSeverity,
    ErrorHypothesis,
    DebugSession;

/// Runtime validation types
export 'runtime_validator.dart' show
    ValidationResult,
    ValidationSeverity,
    ValidationType,
    ValidationRule;

/// Schema validation types
export 'schema_validator.dart' show
    SchemaValidationResult,
    SchemaSeverity,
    SchemaInconsistencyType,
    ExpectedSchema,
    TableSchema,
    ColumnSchema,
    SchemaDefinitionFactory;

/// Null safety validation types
export 'null_safety_validator.dart' show
    NullSafetyResult,
    NullSafetySeverity,
    NullViolationType,
    NullSafetyRule,
    DataIntegrityPattern;

/// CRDT monitoring types
export 'crdt_monitor.dart' show
    CRDTMonitorResult,
    CRDTSeverity,
    CRDTIssueType,
    CRDTOperation,
    ConflictResolutionStrategy,
    SyncState;

/// UI state validation types
export 'ui_state_validator.dart' show
    UIStateResult,
    UIStateSeverity,
    UIStateIssueType,
    UIPerformanceMetrics,
    WidgetLifecycleState,
    NavigationState;

/// Error reporting types
export 'error_reporting_system.dart' show
    ErrorReport,
    ErrorSeverity,
    ErrorCategory,
    Breadcrumb,
    ErrorPattern;

/// Performance monitoring types
export 'performance_monitor.dart' show
    PerformanceMetric,
    BottleneckResult,
    BottleneckSeverity,
    PerformanceCategory,
    PerformanceBenchmark,
    OperationTimer;

/// Debugging framework configuration and utilities
class DebugFrameworkConfig {
  /// Default configuration for the debugging framework
  static const Map<String, dynamic> defaultConfig = {
    // General settings
    'enable_auto_fix': false,
    'monitoring_interval': 300000, // 5 minutes
    'max_history_size': 1000,
    'debug_mode': false,
    
    // Hypothesis debugger settings
    'hypothesis_confidence_threshold': 0.7,
    'max_hypotheses_per_run': 50,
    'enable_pattern_learning': true,
    
    // Validation settings
    'validation_timeout': 30000, // 30 seconds
    'critical_validation_only': false,
    'enable_scheduled_validation': true,
    
    // Performance monitoring
    'frame_drop_threshold': 0.05, // 5%
    'memory_leak_threshold': 100.0, // 100MB
    'performance_sampling_rate': 1.0, // 100%
    
    // Error reporting
    'max_breadcrumbs': 100,
    'error_rate_limit': 10, // per minute
    'enable_crash_reporting': true,
    
    // UI monitoring
    'ui_monitoring_enabled': true,
    'widget_lifecycle_tracking': true,
    'animation_performance_monitoring': true,
  };

  /// Production-optimized configuration
  static const Map<String, dynamic> productionConfig = {
    // General settings
    'enable_auto_fix': true,
    'monitoring_interval': 600000, // 10 minutes
    'max_history_size': 500,
    'debug_mode': false,
    
    // Hypothesis debugger settings
    'hypothesis_confidence_threshold': 0.8,
    'max_hypotheses_per_run': 25,
    'enable_pattern_learning': true,
    
    // Validation settings
    'validation_timeout': 15000, // 15 seconds
    'critical_validation_only': true,
    'enable_scheduled_validation': true,
    
    // Performance monitoring
    'frame_drop_threshold': 0.1, // 10%
    'memory_leak_threshold': 200.0, // 200MB
    'performance_sampling_rate': 0.1, // 10%
    
    // Error reporting
    'max_breadcrumbs': 50,
    'error_rate_limit': 5, // per minute
    'enable_crash_reporting': true,
    
    // UI monitoring
    'ui_monitoring_enabled': false,
    'widget_lifecycle_tracking': false,
    'animation_performance_monitoring': false,
  };

  /// Development configuration with verbose logging
  static const Map<String, dynamic> developmentConfig = {
    // General settings
    'enable_auto_fix': false,
    'monitoring_interval': 60000, // 1 minute
    'max_history_size': 2000,
    'debug_mode': true,
    
    // Hypothesis debugger settings
    'hypothesis_confidence_threshold': 0.5,
    'max_hypotheses_per_run': 100,
    'enable_pattern_learning': true,
    
    // Validation settings
    'validation_timeout': 60000, // 60 seconds
    'critical_validation_only': false,
    'enable_scheduled_validation': true,
    
    // Performance monitoring
    'frame_drop_threshold': 0.01, // 1%
    'memory_leak_threshold': 50.0, // 50MB
    'performance_sampling_rate': 1.0, // 100%
    
    // Error reporting
    'max_breadcrumbs': 200,
    'error_rate_limit': 50, // per minute
    'enable_crash_reporting': true,
    
    // UI monitoring
    'ui_monitoring_enabled': true,
    'widget_lifecycle_tracking': true,
    'animation_performance_monitoring': true,
  };

  /// Get configuration for specific environment
  static Map<String, dynamic> getConfig(String environment) {
    switch (environment.toLowerCase()) {
      case 'production':
      case 'prod':
        return Map.from(productionConfig);
      case 'development':
      case 'dev':
        return Map.from(developmentConfig);
      case 'default':
      default:
        return Map.from(defaultConfig);
    }
  }

  /// Merge custom configuration with defaults
  static Map<String, dynamic> mergeConfig(
    Map<String, dynamic> base,
    Map<String, dynamic> custom,
  ) {
    final merged = Map<String, dynamic>.from(base);
    merged.addAll(custom);
    return merged;
  }
}

/// Debugging framework utilities
class DebugFrameworkUtils {
  /// Check if running in debug mode
  static bool get isDebugMode {
    bool debugMode = false;
    assert(debugMode = true);
    return debugMode;
  }

  /// Generate unique session ID
  static String generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get framework version
  static String get frameworkVersion => '1.0.0';

  /// Get recommended configuration based on environment
  static Map<String, dynamic> getRecommendedConfig() {
    if (isDebugMode) {
      return DebugFrameworkConfig.developmentConfig;
    } else {
      return DebugFrameworkConfig.productionConfig;
    }
  }

  /// Validate configuration
  static bool validateConfig(Map<String, dynamic> config) {
    final requiredKeys = [
      'monitoring_interval',
      'max_history_size',
      'hypothesis_confidence_threshold',
      'validation_timeout',
    ];

    for (final key in requiredKeys) {
      if (!config.containsKey(key)) {
        return false;
      }
    }

    return true;
  }

  /// Get framework statistics
  static Map<String, dynamic> getFrameworkInfo() {
    return {
      'version': frameworkVersion,
      'debug_mode': isDebugMode,
      'components': [
        'HypothesisDrivenDebugger',
        'RuntimeValidator',
        'SchemaValidator',
        'NullSafetyValidator',
        'CRDTMonitor',
        'UIStateValidator',
        'ErrorReportingSystem',
        'PerformanceMonitor',
      ],
      'features': [
        'Error Prediction',
        'Runtime Validation',
        'Schema Consistency',
        'Null Safety Validation',
        'CRDT Monitoring',
        'UI State Monitoring',
        'Performance Analysis',
        'Automated Error Reporting',
      ],
    };
  }
}

/// Framework exceptions
class DebugFrameworkException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const DebugFrameworkException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'DebugFrameworkException: $message'
      '${code != null ? ' (Code: $code)' : ''}';
}

/// Framework initialization helper
class DebugFrameworkInitializer {
  /// Initialize framework with recommended settings
  static Future<DebugFrameworkService> initializeRecommended(
    dynamic databaseService, {
    String? userId,
    String? sessionId,
    Map<String, dynamic>? customConfig,
  }) async {
    final config = DebugFrameworkUtils.getRecommendedConfig();
    
    if (customConfig != null) {
      config.addAll(customConfig);
    }

    final framework = DebugFrameworkService(databaseService);
    await framework.initialize(
      config: config,
      userId: userId,
      sessionId: sessionId ?? DebugFrameworkUtils.generateSessionId(),
    );

    return framework;
  }

  /// Initialize framework for testing
  static Future<DebugFrameworkService> initializeForTesting(
    dynamic databaseService, {
    Map<String, dynamic>? testConfig,
  }) async {
    final config = {
      ...DebugFrameworkConfig.developmentConfig,
      'enable_auto_fix': false,
      'monitoring_interval': 10000, // 10 seconds for testing
      'max_history_size': 100,
      ...?testConfig,
    };

    final framework = DebugFrameworkService(databaseService);
    await framework.initialize(
      config: config,
      sessionId: 'test_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'test_user',
    );

    return framework;
  }
}