import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';
import '../database/crdt_database_service.dart';

/// Error report structure
class ErrorReport {
  final String id;
  final String errorType;
  final String errorMessage;
  final String? stackTrace;
  final Map<String, dynamic> context;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final String deviceInfo;
  final String appVersion;
  final Map<String, dynamic> systemState;
  final List<String> breadcrumbs;
  final bool isFatal;
  final String? userId;
  final String? sessionId;

  const ErrorReport({
    required this.id,
    required this.errorType,
    required this.errorMessage,
    this.stackTrace,
    required this.context,
    required this.severity,
    required this.timestamp,
    required this.deviceInfo,
    required this.appVersion,
    required this.systemState,
    required this.breadcrumbs,
    this.isFatal = false,
    this.userId,
    this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'error_type': errorType,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'context': jsonEncode(context),
      'severity': severity.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'device_info': deviceInfo,
      'app_version': appVersion,
      'system_state': jsonEncode(systemState),
      'breadcrumbs': jsonEncode(breadcrumbs),
      'is_fatal': isFatal,
      'user_id': userId,
      'session_id': sessionId,
    };
  }

  factory ErrorReport.fromJson(Map<String, dynamic> json) {
    return ErrorReport(
      id: json['id'] as String,
      errorType: json['error_type'] as String,
      errorMessage: json['error_message'] as String,
      stackTrace: json['stack_trace'] as String?,
      context: jsonDecode(json['context'] as String) as Map<String, dynamic>,
      severity: ErrorSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      deviceInfo: json['device_info'] as String,
      appVersion: json['app_version'] as String,
      systemState: jsonDecode(json['system_state'] as String) as Map<String, dynamic>,
      breadcrumbs: List<String>.from(
        jsonDecode(json['breadcrumbs'] as String) as List,
      ),
      isFatal: json['is_fatal'] as bool? ?? false,
      userId: json['user_id'] as String?,
      sessionId: json['session_id'] as String?,
    );
  }
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
  fatal,
}

/// Error categories for better organization
enum ErrorCategory {
  ui,
  database,
  network,
  business_logic,
  crdt_sync,
  performance,
  security,
  system,
  user_action,
  unknown,
}

/// Breadcrumb for tracking user actions
class Breadcrumb {
  final String action;
  final String category;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const Breadcrumb({
    required this.action,
    required this.category,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'category': category,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return '${timestamp.toIso8601String()}: [$category] $action';
  }
}

/// Error pattern for detecting recurring issues
class ErrorPattern {
  final String id;
  final String patternName;
  final String errorSignature;
  final int occurrenceCount;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final List<String> affectedVersions;
  final Map<String, dynamic> patternData;

  const ErrorPattern({
    required this.id,
    required this.patternName,
    required this.errorSignature,
    required this.occurrenceCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.affectedVersions,
    required this.patternData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pattern_name': patternName,
      'error_signature': errorSignature,
      'occurrence_count': occurrenceCount,
      'first_seen': firstSeen.millisecondsSinceEpoch,
      'last_seen': lastSeen.millisecondsSinceEpoch,
      'affected_versions': jsonEncode(affectedVersions),
      'pattern_data': jsonEncode(patternData),
    };
  }
}

/// Comprehensive automated error reporting system
class ErrorReportingSystem {
  final CRDTDatabaseService _databaseService;
  final List<ErrorReport> _pendingReports = [];
  final List<Breadcrumb> _breadcrumbs = [];
  final Map<String, ErrorPattern> _errorPatterns = {};
  
  // Session tracking
  String? _currentSessionId;
  String? _currentUserId;
  DateTime? _sessionStartTime;
  
  // System information
  Map<String, dynamic> _deviceInfo = {};
  String _appVersion = 'unknown';
  
  // Configuration
  static const int maxBreadcrumbs = 100;
  static const int maxPendingReports = 1000;
  static const Duration reportingInterval = Duration(minutes: 5);
  static const int patternThreshold = 3; // Min occurrences to create pattern
  
  // Statistics
  int _totalErrorsReported = 0;
  int _totalPatterns = 0;
  final Map<String, int> _errorsByCategory = {};
  final Map<String, int> _errorsBySeverity = {};

  ErrorReportingSystem(this._databaseService);

  /// Initialize the error reporting system
  Future<void> initialize({
    String? userId,
    Map<String, dynamic>? deviceInfo,
    String? appVersion,
  }) async {
    _currentUserId = userId;
    _deviceInfo = deviceInfo ?? await _collectDeviceInfo();
    _appVersion = appVersion ?? await _getAppVersion();
    _currentSessionId = UuidGenerator.generateId();
    _sessionStartTime = DateTime.now();

    await _createErrorTables();
    await _loadErrorPatterns();
    await _setupErrorHandlers();
    await _startPeriodicReporting();

    // Add session start breadcrumb
    addBreadcrumb(
      action: 'session_started',
      category: 'system',
      data: {
        'session_id': _currentSessionId,
        'user_id': _currentUserId,
        'app_version': _appVersion,
      },
    );

    if (kDebugMode) {
      print('ErrorReportingSystem initialized for session: $_currentSessionId');
    }
  }

  /// Report an error manually
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, dynamic>? context,
    ErrorCategory category = ErrorCategory.unknown,
    bool isFatal = false,
  }) async {
    final errorReport = await _createErrorReport(
      error: error,
      stackTrace: stackTrace,
      severity: severity,
      context: context ?? {},
      category: category,
      isFatal: isFatal,
    );

    await _processErrorReport(errorReport);
  }

  /// Add a breadcrumb to track user actions
  void addBreadcrumb({
    required String action,
    required String category,
    Map<String, dynamic>? data,
  }) {
    final breadcrumb = Breadcrumb(
      action: action,
      category: category,
      data: data ?? {},
      timestamp: DateTime.now(),
    );

    _breadcrumbs.add(breadcrumb);

    // Keep only recent breadcrumbs
    if (_breadcrumbs.length > maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Update user context
  void setUser(String? userId) {
    _currentUserId = userId;
    addBreadcrumb(
      action: 'user_changed',
      category: 'auth',
      data: {'new_user_id': userId},
    );
  }

  /// Set custom context for error reporting
  void setContext(String key, dynamic value) {
    _deviceInfo[key] = value;
  }

  /// Get error reporting statistics
  Map<String, dynamic> getStatistics() {
    final sessionDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inMinutes
        : 0;

    return {
      'session_id': _currentSessionId,
      'session_duration_minutes': sessionDuration,
      'total_errors_reported': _totalErrorsReported,
      'pending_reports': _pendingReports.length,
      'error_patterns': _totalPatterns,
      'errors_by_category': Map.from(_errorsByCategory),
      'errors_by_severity': Map.from(_errorsBySeverity),
      'breadcrumbs_count': _breadcrumbs.length,
      'user_id': _currentUserId,
      'app_version': _appVersion,
    };
  }

  /// Get error patterns analysis
  Future<Map<String, dynamic>> getErrorPatternsAnalysis() async {
    final patterns = _errorPatterns.values.toList();
    patterns.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));

    final topPatterns = patterns.take(10).map((p) => {
      'pattern_name': p.patternName,
      'error_signature': p.errorSignature,
      'occurrence_count': p.occurrenceCount,
      'first_seen': p.firstSeen.toIso8601String(),
      'last_seen': p.lastSeen.toIso8601String(),
      'affected_versions': p.affectedVersions,
    }).toList();

    return {
      'total_patterns': patterns.length,
      'active_patterns': patterns.where((p) => 
          p.lastSeen.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length,
      'top_patterns': topPatterns,
      'pattern_statistics': {
        'avg_occurrences': patterns.isNotEmpty 
            ? patterns.map((p) => p.occurrenceCount).reduce((a, b) => a + b) / patterns.length
            : 0.0,
        'most_frequent': patterns.isNotEmpty ? patterns.first.occurrenceCount : 0,
        'least_frequent': patterns.isNotEmpty ? patterns.last.occurrenceCount : 0,
      },
    };
  }

  /// Export error report
  Future<Map<String, dynamic>> exportErrorReport({
    DateTime? fromDate,
    DateTime? toDate,
    ErrorSeverity? minSeverity,
  }) async {
    fromDate ??= DateTime.now().subtract(const Duration(days: 7));
    toDate ??= DateTime.now();

    final db = await _databaseService.database;

    // Build query conditions
    var whereClause = 'timestamp >= ? AND timestamp <= ?';
    final whereArgs = <dynamic>[
      fromDate.millisecondsSinceEpoch,
      toDate.millisecondsSinceEpoch,
    ];

    if (minSeverity != null) {
      final minIndex = ErrorSeverity.values.indexOf(minSeverity);
      final severityNames = ErrorSeverity.values
          .skip(minIndex)
          .map((s) => "'${s.name}'")
          .join(',');
      whereClause += ' AND severity IN ($severityNames)';
    }

    // Get error reports
    final errorResults = await db.query(
      'error_reports',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    final errors = errorResults.map((r) => ErrorReport.fromJson(r)).toList();

    // Analyze errors
    final errorsByType = <String, int>{};
    final errorsBySeverity = <String, int>{};
    final errorsByVersion = <String, int>{};

    for (final error in errors) {
      errorsByType[error.errorType] = (errorsByType[error.errorType] ?? 0) + 1;
      errorsBySeverity[error.severity.name] = (errorsBySeverity[error.severity.name] ?? 0) + 1;
      errorsByVersion[error.appVersion] = (errorsByVersion[error.appVersion] ?? 0) + 1;
    }

    return {
      'period': {
        'from': fromDate.toIso8601String(),
        'to': toDate.toIso8601String(),
      },
      'summary': {
        'total_errors': errors.length,
        'fatal_errors': errors.where((e) => e.isFatal).length,
        'unique_error_types': errorsByType.length,
        'affected_sessions': errors.map((e) => e.sessionId).toSet().length,
      },
      'breakdown': {
        'by_type': errorsByType,
        'by_severity': errorsBySeverity,
        'by_version': errorsByVersion,
      },
      'top_errors': errors
          .take(20)
          .map((e) => {
            'error_type': e.errorType,
            'error_message': e.errorMessage,
            'severity': e.severity.name,
            'timestamp': e.timestamp.toIso8601String(),
            'is_fatal': e.isFatal,
            'app_version': e.appVersion,
          })
          .toList(),
      'patterns': await getErrorPatternsAnalysis(),
      'statistics': getStatistics(),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Force send pending reports
  Future<Map<String, dynamic>> sendPendingReports() async {
    if (_pendingReports.isEmpty) {
      return {
        'success': true,
        'reports_sent': 0,
        'message': 'No pending reports to send',
      };
    }

    try {
      final reportsSent = await _sendReportsToStorage();
      
      return {
        'success': true,
        'reports_sent': reportsSent,
        'remaining_pending': _pendingReports.length,
        'message': 'Reports sent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'reports_sent': 0,
        'remaining_pending': _pendingReports.length,
        'error': e.toString(),
      };
    }
  }

  // Private helper methods

  Future<void> _createErrorTables() async {
    final db = await _databaseService.database;

    // Error reports table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS error_reports (
        id TEXT PRIMARY KEY,
        error_type TEXT NOT NULL,
        error_message TEXT NOT NULL,
        stack_trace TEXT,
        context TEXT NOT NULL,
        severity TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        device_info TEXT NOT NULL,
        app_version TEXT NOT NULL,
        system_state TEXT NOT NULL,
        breadcrumbs TEXT NOT NULL,
        is_fatal INTEGER DEFAULT 0,
        user_id TEXT,
        session_id TEXT
      )
    ''');

    // Error patterns table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS error_patterns (
        id TEXT PRIMARY KEY,
        pattern_name TEXT NOT NULL,
        error_signature TEXT NOT NULL,
        occurrence_count INTEGER NOT NULL,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        affected_versions TEXT NOT NULL,
        pattern_data TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_error_reports_timestamp ON error_reports(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_error_reports_severity ON error_reports(severity)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_error_reports_type ON error_reports(error_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_error_patterns_signature ON error_patterns(error_signature)');
  }

  Future<void> _loadErrorPatterns() async {
    final db = await _databaseService.database;
    
    final results = await db.query('error_patterns');
    
    for (final result in results) {
      final pattern = ErrorPattern(
        id: result['id'] as String,
        patternName: result['pattern_name'] as String,
        errorSignature: result['error_signature'] as String,
        occurrenceCount: result['occurrence_count'] as int,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(result['first_seen'] as int),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(result['last_seen'] as int),
        affectedVersions: List<String>.from(
          jsonDecode(result['affected_versions'] as String) as List,
        ),
        patternData: jsonDecode(result['pattern_data'] as String) as Map<String, dynamic>,
      );
      
      _errorPatterns[pattern.errorSignature] = pattern;
    }
    
    _totalPatterns = _errorPatterns.length;
  }

  Future<void> _setupErrorHandlers() async {
    // Set up Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Set up Dart error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleDartError(error, stack);
      return true;
    };

    // Set up isolate error handler
    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final List<dynamic> errorAndStackTrace = pair;
      await reportError(
        errorAndStackTrace.first,
        StackTrace.fromString(errorAndStackTrace.last.toString()),
        severity: ErrorSeverity.fatal,
        category: ErrorCategory.system,
        isFatal: true,
      );
    }).sendPort);
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // Report Flutter framework errors
    reportError(
      details.exception,
      details.stack,
      severity: details.silent ? ErrorSeverity.warning : ErrorSeverity.error,
      context: {
        'library': details.library,
        'context': details.context?.toString(),
        'silent': details.silent,
      },
      category: ErrorCategory.ui,
    );
  }

  void _handleDartError(Object error, StackTrace stackTrace) {
    // Report uncaught Dart errors
    reportError(
      error,
      stackTrace,
      severity: ErrorSeverity.fatal,
      category: ErrorCategory.system,
      isFatal: true,
    );
  }

  Future<void> _startPeriodicReporting() async {
    Timer.periodic(reportingInterval, (_) => _sendPendingReports());
  }

  Future<ErrorReport> _createErrorReport({
    required dynamic error,
    StackTrace? stackTrace,
    required ErrorSeverity severity,
    required Map<String, dynamic> context,
    required ErrorCategory category,
    required bool isFatal,
  }) async {
    final systemState = await _collectSystemState();
    final breadcrumbStrings = _breadcrumbs.map((b) => b.toString()).toList();

    return ErrorReport(
      id: UuidGenerator.generateId(),
      errorType: error.runtimeType.toString(),
      errorMessage: error.toString(),
      stackTrace: stackTrace?.toString(),
      context: {
        ...context,
        'category': category.name,
      },
      severity: severity,
      timestamp: DateTime.now(),
      deviceInfo: jsonEncode(_deviceInfo),
      appVersion: _appVersion,
      systemState: systemState,
      breadcrumbs: breadcrumbStrings,
      isFatal: isFatal,
      userId: _currentUserId,
      sessionId: _currentSessionId,
    );
  }

  Future<void> _processErrorReport(ErrorReport report) async {
    // Update statistics
    _totalErrorsReported++;
    _errorsByCategory[report.context['category']?.toString() ?? 'unknown'] = 
        (_errorsByCategory[report.context['category']?.toString() ?? 'unknown'] ?? 0) + 1;
    _errorsBySeverity[report.severity.name] = 
        (_errorsBySeverity[report.severity.name] ?? 0) + 1;

    // Add to pending reports
    _pendingReports.add(report);
    
    // Keep pending reports under limit
    if (_pendingReports.length > maxPendingReports) {
      _pendingReports.removeAt(0);
    }

    // Update error patterns
    await _updateErrorPatterns(report);

    // Log critical errors immediately
    if (report.severity == ErrorSeverity.critical || report.severity == ErrorSeverity.fatal) {
      if (kDebugMode) {
        print('CRITICAL ERROR: ${report.errorType} - ${report.errorMessage}');
        if (report.stackTrace != null) {
          print('Stack trace: ${report.stackTrace}');
        }
      }
      
      // Send critical errors immediately
      await _sendReportsToStorage([report]);
    }
  }

  Future<void> _updateErrorPatterns(ErrorReport report) async {
    final signature = _generateErrorSignature(report);
    
    if (_errorPatterns.containsKey(signature)) {
      // Update existing pattern
      final existingPattern = _errorPatterns[signature]!;
      final updatedVersions = existingPattern.affectedVersions.toSet();
      updatedVersions.add(report.appVersion);
      
      _errorPatterns[signature] = ErrorPattern(
        id: existingPattern.id,
        patternName: existingPattern.patternName,
        errorSignature: signature,
        occurrenceCount: existingPattern.occurrenceCount + 1,
        firstSeen: existingPattern.firstSeen,
        lastSeen: DateTime.now(),
        affectedVersions: updatedVersions.toList(),
        patternData: {
          ...existingPattern.patternData,
          'latest_occurrence': report.timestamp.toIso8601String(),
          'latest_context': report.context,
        },
      );
    } else {
      // Create new pattern if we've seen this error enough times
      final similarReports = _pendingReports
          .where((r) => _generateErrorSignature(r) == signature)
          .length;
      
      if (similarReports >= patternThreshold) {
        _errorPatterns[signature] = ErrorPattern(
          id: UuidGenerator.generateId(),
          patternName: _generatePatternName(report),
          errorSignature: signature,
          occurrenceCount: similarReports + 1,
          firstSeen: DateTime.now().subtract(const Duration(minutes: 30)), // Estimate
          lastSeen: DateTime.now(),
          affectedVersions: [report.appVersion],
          patternData: {
            'error_type': report.errorType,
            'category': report.context['category'],
            'first_context': report.context,
          },
        );
        
        _totalPatterns++;
      }
    }

    // Store pattern in database
    if (_errorPatterns.containsKey(signature)) {
      await _storeErrorPattern(_errorPatterns[signature]!);
    }
  }

  String _generateErrorSignature(ErrorReport report) {
    // Create a unique signature for the error based on type and key parts of message
    final typeHash = report.errorType.hashCode;
    final messageWords = report.errorMessage.split(' ').take(5).join(' ');
    final messageHash = messageWords.hashCode;
    
    return '${typeHash}_${messageHash}';
  }

  String _generatePatternName(ErrorReport report) {
    final category = report.context['category']?.toString() ?? 'Unknown';
    final type = report.errorType;
    return '$category - $type Pattern';
  }

  Future<void> _storeErrorPattern(ErrorPattern pattern) async {
    final db = await _databaseService.database;
    await db.insert(
      'error_patterns',
      pattern.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _sendReportsToStorage([List<ErrorReport>? specificReports]) async {
    final reportsToSend = specificReports ?? List.from(_pendingReports);
    final db = await _databaseService.database;
    
    int reportsSent = 0;
    
    for (final report in reportsToSend) {
      try {
        await db.insert('error_reports', report.toJson());
        reportsSent++;
        
        // Remove from pending if it was in the main list
        if (specificReports == null) {
          _pendingReports.remove(report);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to store error report: $e');
        }
      }
    }
    
    return reportsSent;
  }

  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final info = <String, dynamic>{};
    
    try {
      if (Platform.isAndroid) {
        info['platform'] = 'android';
        info['os_version'] = Platform.operatingSystemVersion;
      } else if (Platform.isIOS) {
        info['platform'] = 'ios';
        info['os_version'] = Platform.operatingSystemVersion;
      } else if (Platform.isWindows) {
        info['platform'] = 'windows';
      } else if (Platform.isLinux) {
        info['platform'] = 'linux';
      } else if (Platform.isMacOS) {
        info['platform'] = 'macos';
      }
      
      info['dart_version'] = Platform.version;
      info['locale'] = Platform.localeName;
      info['number_of_processors'] = Platform.numberOfProcessors;
    } catch (e) {
      info['collection_error'] = e.toString();
    }
    
    return info;
  }

  Future<String> _getAppVersion() async {
    try {
      // This would typically come from package_info_plus or similar
      return '1.0.0'; // Placeholder
    } catch (e) {
      return 'unknown';
    }
  }

  Future<Map<String, dynamic>> _collectSystemState() async {
    final state = <String, dynamic>{};
    
    try {
      state['timestamp'] = DateTime.now().toIso8601String();
      state['memory_usage'] = await _getMemoryUsage();
      state['available_memory'] = await _getAvailableMemory();
      state['battery_level'] = await _getBatteryLevel();
      state['network_status'] = await _getNetworkStatus();
      state['storage_space'] = await _getStorageSpace();
    } catch (e) {
      state['collection_error'] = e.toString();
    }
    
    return state;
  }

  Future<double> _getMemoryUsage() async {
    // Placeholder - would use platform-specific APIs
    return 0.0;
  }

  Future<double> _getAvailableMemory() async {
    // Placeholder - would use platform-specific APIs
    return 0.0;
  }

  Future<double> _getBatteryLevel() async {
    // Placeholder - would use battery_plus or similar
    return 0.0;
  }

  Future<String> _getNetworkStatus() async {
    // Placeholder - would use connectivity_plus or similar
    return 'unknown';
  }

  Future<Map<String, double>> _getStorageSpace() async {
    // Placeholder - would use path_provider and directory size calculation
    return {'available_gb': 0.0, 'total_gb': 0.0};
  }

  /// Dispose resources
  void dispose() {
    // Send any remaining reports before disposing
    if (_pendingReports.isNotEmpty) {
      _sendReportsToStorage();
    }

    // Add session end breadcrumb
    addBreadcrumb(
      action: 'session_ended',
      category: 'system',
      data: {
        'session_duration_minutes': _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!).inMinutes
            : 0,
        'total_errors': _totalErrorsReported,
      },
    );
  }
}