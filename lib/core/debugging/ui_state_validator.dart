import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/uuid_generator.dart';
import '../error/exceptions.dart';

/// UI state validation result
class UIStateResult {
  final String id;
  final String validationName;
  final UIStateIssueType issueType;
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic> stateSnapshot;
  final UIStateSeverity severity;
  final DateTime timestamp;
  final String? suggestedFix;
  final Duration? detectionTime;

  const UIStateResult({
    required this.id,
    required this.validationName,
    required this.issueType,
    required this.isValid,
    this.errorMessage,
    required this.stateSnapshot,
    required this.severity,
    required this.timestamp,
    this.suggestedFix,
    this.detectionTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'validation_name': validationName,
      'issue_type': issueType.name,
      'is_valid': isValid,
      'error_message': errorMessage,
      'state_snapshot': jsonEncode(stateSnapshot),
      'severity': severity.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'suggested_fix': suggestedFix,
      'detection_time_ms': detectionTime?.inMilliseconds,
    };
  }

  factory UIStateResult.fromJson(Map<String, dynamic> json) {
    return UIStateResult(
      id: json['id'] as String,
      validationName: json['validation_name'] as String,
      issueType: UIStateIssueType.values.firstWhere(
        (e) => e.name == json['issue_type'],
      ),
      isValid: json['is_valid'] as bool,
      errorMessage: json['error_message'] as String?,
      stateSnapshot: jsonDecode(json['state_snapshot'] as String) as Map<String, dynamic>,
      severity: UIStateSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      suggestedFix: json['suggested_fix'] as String?,
      detectionTime: json['detection_time_ms'] != null
          ? Duration(milliseconds: json['detection_time_ms'] as int)
          : null,
    );
  }
}

/// UI state issue severity levels
enum UIStateSeverity {
  info,
  warning,
  error,
  critical,
}

/// Types of UI state issues
enum UIStateIssueType {
  memoryLeak,
  undisposedResource,
  infiniteLoop,
  performanceBottleneck,
  stateInconsistency,
  orphanedWidget,
  buildOverflow,
  animationStall,
  navigationIssue,
  keyboardIssue,
  renderingIssue,
  gestureConflict,
}

/// UI performance metrics
class UIPerformanceMetrics {
  final double frameDropRate;
  final double averageFrameTime;
  final int totalFrames;
  final int droppedFrames;
  final double memoryUsage;
  final int widgetCount;
  final Map<String, double> customMetrics;
  final DateTime timestamp;

  const UIPerformanceMetrics({
    required this.frameDropRate,
    required this.averageFrameTime,
    required this.totalFrames,
    required this.droppedFrames,
    required this.memoryUsage,
    required this.widgetCount,
    required this.customMetrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'frame_drop_rate': frameDropRate,
      'average_frame_time': averageFrameTime,
      'total_frames': totalFrames,
      'dropped_frames': droppedFrames,
      'memory_usage': memoryUsage,
      'widget_count': widgetCount,
      'custom_metrics': customMetrics,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Widget lifecycle state
class WidgetLifecycleState {
  final String widgetId;
  final String widgetType;
  final bool isBuilt;
  final bool isDisposed;
  final bool hasListeners;
  final int listenerCount;
  final DateTime createdAt;
  final DateTime? disposedAt;
  final Map<String, dynamic> properties;

  const WidgetLifecycleState({
    required this.widgetId,
    required this.widgetType,
    required this.isBuilt,
    required this.isDisposed,
    required this.hasListeners,
    required this.listenerCount,
    required this.createdAt,
    this.disposedAt,
    required this.properties,
  });
}

/// Navigation state snapshot
class NavigationState {
  final List<String> routeStack;
  final String currentRoute;
  final Map<String, dynamic> routeArguments;
  final bool canGoBack;
  final int stackDepth;
  final DateTime lastNavigation;

  const NavigationState({
    required this.routeStack,
    required this.currentRoute,
    required this.routeArguments,
    required this.canGoBack,
    required this.stackDepth,
    required this.lastNavigation,
  });

  Map<String, dynamic> toJson() {
    return {
      'route_stack': routeStack,
      'current_route': currentRoute,
      'route_arguments': routeArguments,
      'can_go_back': canGoBack,
      'stack_depth': stackDepth,
      'last_navigation': lastNavigation.millisecondsSinceEpoch,
    };
  }
}

/// Comprehensive UI state validator
class UIStateValidator {
  final List<UIStateResult> _validationHistory = [];
  final Map<String, WidgetLifecycleState> _widgetStates = {};
  final List<UIPerformanceMetrics> _performanceHistory = [];
  final Map<String, Timer> _monitoringTimers = {};
  
  // Performance tracking
  int _totalFrames = 0;
  int _droppedFrames = 0;
  final List<double> _frameTimes = [];
  final List<double> _memoryUsage = [];
  
  // State tracking
  NavigationState? _currentNavigationState;
  final Map<String, dynamic> _globalUIState = {};
  
  // Configuration
  static const int maxValidationHistory = 1000;
  static const int maxPerformanceHistory = 100;
  static const double frameDropThreshold = 0.05; // 5%
  static const double memoryLeakThreshold = 100.0; // MB increase
  static const Duration monitoringInterval = Duration(seconds: 5);

  UIStateValidator();

  /// Initialize the UI state validator
  Future<void> initialize() async {
    await _startUIMonitoring();
    await _registerPerformanceCallbacks();
    
    if (kDebugMode) {
      print('UIStateValidator initialized');
      developer.log('UI State Validator started', name: 'UIStateValidator');
    }
  }

  /// Validate current UI state
  Future<List<UIStateResult>> validateUIState({
    UIStateIssueType? filterType,
    UIStateSeverity? minSeverity,
  }) async {
    final results = <UIStateResult>[];

    try {
      // Check for memory leaks
      results.add(await _checkMemoryLeaks());
      
      // Check for undisposed resources
      results.addAll(await _checkUndisposedResources());
      
      // Check performance issues
      results.add(await _checkPerformanceIssues());
      
      // Check state consistency
      results.add(await _checkStateConsistency());
      
      // Check navigation state
      results.add(await _checkNavigationState());
      
      // Check widget lifecycle issues
      results.addAll(await _checkWidgetLifecycleIssues());
      
      // Check for build overflow
      results.add(await _checkBuildOverflow());
      
      // Check animation issues
      results.addAll(await _checkAnimationIssues());

      // Filter results
      var filteredResults = results;
      
      if (filterType != null) {
        filteredResults = filteredResults
            .where((r) => r.issueType == filterType)
            .toList();
      }
      
      if (minSeverity != null) {
        final minIndex = UIStateSeverity.values.indexOf(minSeverity);
        filteredResults = filteredResults
            .where((r) => UIStateSeverity.values.indexOf(r.severity) >= minIndex)
            .toList();
      }

      // Store validation history
      _validationHistory.addAll(filteredResults);
      if (_validationHistory.length > maxValidationHistory) {
        _validationHistory.removeRange(0, _validationHistory.length - maxValidationHistory);
      }

    } catch (e) {
      results.add(UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'UI State Validation Error',
        issueType: UIStateIssueType.stateInconsistency,
        isValid: false,
        errorMessage: 'Failed to validate UI state: ${e.toString()}',
        stateSnapshot: {'error': e.toString()},
        severity: UIStateSeverity.error,
        timestamp: DateTime.now(),
        suggestedFix: 'Check validator implementation and UI state access',
      ));
    }

    return filteredResults;
  }

  /// Track widget lifecycle
  void trackWidget(
    String widgetId,
    String widgetType, {
    Map<String, dynamic>? properties,
  }) {
    _widgetStates[widgetId] = WidgetLifecycleState(
      widgetId: widgetId,
      widgetType: widgetType,
      isBuilt: true,
      isDisposed: false,
      hasListeners: false,
      listenerCount: 0,
      createdAt: DateTime.now(),
      properties: properties ?? {},
    );
  }

  /// Mark widget as disposed
  void markWidgetDisposed(String widgetId) {
    if (_widgetStates.containsKey(widgetId)) {
      final currentState = _widgetStates[widgetId]!;
      _widgetStates[widgetId] = WidgetLifecycleState(
        widgetId: currentState.widgetId,
        widgetType: currentState.widgetType,
        isBuilt: currentState.isBuilt,
        isDisposed: true,
        hasListeners: currentState.hasListeners,
        listenerCount: currentState.listenerCount,
        createdAt: currentState.createdAt,
        disposedAt: DateTime.now(),
        properties: currentState.properties,
      );
    }
  }

  /// Update navigation state
  void updateNavigationState(NavigationState state) {
    _currentNavigationState = state;
  }

  /// Record frame performance
  void recordFrameMetrics(double frameTime, bool wasDropped) {
    _totalFrames++;
    if (wasDropped) _droppedFrames++;
    
    _frameTimes.add(frameTime);
    if (_frameTimes.length > 100) {
      _frameTimes.removeAt(0);
    }
  }

  /// Record memory usage
  void recordMemoryUsage(double memoryMB) {
    _memoryUsage.add(memoryMB);
    if (_memoryUsage.length > 100) {
      _memoryUsage.removeAt(0);
    }
  }

  /// Get UI performance metrics
  UIPerformanceMetrics getCurrentPerformanceMetrics() {
    final frameDropRate = _totalFrames > 0 ? (_droppedFrames / _totalFrames) : 0.0;
    final avgFrameTime = _frameTimes.isNotEmpty 
        ? _frameTimes.reduce((a, b) => a + b) / _frameTimes.length 
        : 0.0;
    final currentMemory = _memoryUsage.isNotEmpty ? _memoryUsage.last : 0.0;

    return UIPerformanceMetrics(
      frameDropRate: frameDropRate,
      averageFrameTime: avgFrameTime,
      totalFrames: _totalFrames,
      droppedFrames: _droppedFrames,
      memoryUsage: currentMemory,
      widgetCount: _widgetStates.length,
      customMetrics: _calculateCustomMetrics(),
      timestamp: DateTime.now(),
    );
  }

  /// Get UI state statistics
  Map<String, dynamic> getUIStateStatistics() {
    final totalValidations = _validationHistory.length;
    final issuesFound = _validationHistory.where((r) => !r.isValid).length;
    final issueRate = totalValidations > 0 ? (issuesFound / totalValidations * 100) : 0.0;

    final issuesByType = <String, int>{};
    for (final result in _validationHistory.where((r) => !r.isValid)) {
      issuesByType[result.issueType.name] = (issuesByType[result.issueType.name] ?? 0) + 1;
    }

    final currentMetrics = getCurrentPerformanceMetrics();

    return {
      'total_validations': totalValidations,
      'issues_found': issuesFound,
      'issue_rate_percent': issueRate,
      'issues_by_type': issuesByType,
      'active_widgets': _widgetStates.values.where((w) => !w.isDisposed).length,
      'undisposed_widgets': _widgetStates.values.where((w) => w.isDisposed).length,
      'current_performance': currentMetrics.toJson(),
      'navigation_stack_depth': _currentNavigationState?.stackDepth ?? 0,
      'last_validation': _validationHistory.isNotEmpty 
          ? _validationHistory.last.timestamp.toIso8601String() 
          : null,
    };
  }

  /// Export UI state report
  Future<Map<String, dynamic>> exportUIStateReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fromDate ??= DateTime.now().subtract(const Duration(hours: 6));
    toDate ??= DateTime.now();

    final relevantResults = _validationHistory
        .where((r) => r.timestamp.isAfter(fromDate!) && r.timestamp.isBefore(toDate!))
        .toList();

    final relevantPerformance = _performanceHistory
        .where((p) => p.timestamp.isAfter(fromDate!) && p.timestamp.isBefore(toDate!))
        .toList();

    return {
      'period': {
        'from': fromDate.toIso8601String(),
        'to': toDate.toIso8601String(),
      },
      'summary': {
        'total_validations': relevantResults.length,
        'issues_found': relevantResults.where((r) => !r.isValid).length,
        'performance_samples': relevantPerformance.length,
      },
      'issues_by_type': _groupIssuesByType(relevantResults),
      'issues_by_severity': _groupIssuesBySeverity(relevantResults),
      'performance_trends': _analyzePerformanceTrends(relevantPerformance),
      'widget_lifecycle_analysis': _analyzeWidgetLifecycle(),
      'top_issues': relevantResults
          .where((r) => !r.isValid)
          .take(20)
          .map((r) => {
            'validation_name': r.validationName,
            'issue_type': r.issueType.name,
            'severity': r.severity.name,
            'error_message': r.errorMessage,
            'suggested_fix': r.suggestedFix,
            'timestamp': r.timestamp.toIso8601String(),
          })
          .toList(),
      'recommendations': _generateUIRecommendations(relevantResults),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // Private helper methods

  Future<void> _startUIMonitoring() async {
    // Start periodic UI state monitoring
    _monitoringTimers['ui_state'] = Timer.periodic(
      monitoringInterval,
      (_) => _performPeriodicValidation(),
    );

    // Start performance monitoring
    _monitoringTimers['performance'] = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _recordPerformanceMetrics(),
    );
  }

  Future<void> _registerPerformanceCallbacks() async {
    if (kDebugMode) {
      // Register frame callback for performance monitoring
      WidgetsBinding.instance.addPersistentFrameCallback(_onFrameCallback);
    }
  }

  void _onFrameCallback(Duration timestamp) {
    // Record frame timing
    final frameTime = timestamp.inMicroseconds / 1000.0; // Convert to milliseconds
    final wasDropped = frameTime > 16.67; // 60fps threshold
    
    recordFrameMetrics(frameTime, wasDropped);
  }

  Future<void> _performPeriodicValidation() async {
    try {
      final results = await validateUIState();
      
      // Log critical issues
      final criticalIssues = results.where((r) => 
          !r.isValid && r.severity == UIStateSeverity.critical).toList();
      
      if (criticalIssues.isNotEmpty && kDebugMode) {
        for (final issue in criticalIssues) {
          developer.log(
            'Critical UI issue: ${issue.validationName} - ${issue.errorMessage}',
            name: 'UIStateValidator',
            level: 1000, // Error level
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Periodic UI validation failed: $e', name: 'UIStateValidator');
      }
    }
  }

  Future<void> _recordPerformanceMetrics() async {
    final metrics = getCurrentPerformanceMetrics();
    _performanceHistory.add(metrics);
    
    if (_performanceHistory.length > maxPerformanceHistory) {
      _performanceHistory.removeAt(0);
    }
  }

  Future<UIStateResult> _checkMemoryLeaks() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check memory usage trend
      if (_memoryUsage.length >= 10) {
        final recent = _memoryUsage.sublist(_memoryUsage.length - 10);
        final older = _memoryUsage.sublist(0, 10);
        
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final olderAvg = older.reduce((a, b) => a + b) / older.length;
        final memoryIncrease = recentAvg - olderAvg;
        
        if (memoryIncrease > memoryLeakThreshold) {
          stopwatch.stop();
          return UIStateResult(
            id: UuidGenerator.generateId(),
            validationName: 'Memory Leak Detection',
            issueType: UIStateIssueType.memoryLeak,
            isValid: false,
            errorMessage: 'Potential memory leak detected: ${memoryIncrease.toStringAsFixed(2)}MB increase',
            stateSnapshot: {
              'memory_increase_mb': memoryIncrease,
              'current_memory_mb': recentAvg,
              'baseline_memory_mb': olderAvg,
              'sample_count': _memoryUsage.length,
            },
            severity: memoryIncrease > memoryLeakThreshold * 2 
                ? UIStateSeverity.critical 
                : UIStateSeverity.error,
            timestamp: DateTime.now(),
            suggestedFix: 'Review widget disposal and stream subscriptions',
            detectionTime: stopwatch.elapsed,
          );
        }
      }
      
      stopwatch.stop();
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Memory Leak Detection',
        issueType: UIStateIssueType.memoryLeak,
        isValid: true,
        stateSnapshot: {
          'current_memory_mb': _memoryUsage.isNotEmpty ? _memoryUsage.last : 0.0,
          'samples_analyzed': _memoryUsage.length,
        },
        severity: UIStateSeverity.info,
        timestamp: DateTime.now(),
        detectionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Memory Leak Detection',
        issueType: UIStateIssueType.memoryLeak,
        isValid: false,
        errorMessage: 'Memory leak check failed: ${e.toString()}',
        stateSnapshot: {'error': e.toString()},
        severity: UIStateSeverity.warning,
        timestamp: DateTime.now(),
        detectionTime: stopwatch.elapsed,
      );
    }
  }

  Future<List<UIStateResult>> _checkUndisposedResources() async {
    final results = <UIStateResult>[];
    final undisposedWidgets = _widgetStates.values
        .where((w) => !w.isDisposed && 
               DateTime.now().difference(w.createdAt) > const Duration(minutes: 30))
        .toList();

    if (undisposedWidgets.isNotEmpty) {
      for (final widget in undisposedWidgets.take(10)) { // Limit to top 10
        results.add(UIStateResult(
          id: UuidGenerator.generateId(),
          validationName: 'Undisposed Resource Detection',
          issueType: UIStateIssueType.undisposedResource,
          isValid: false,
          errorMessage: 'Widget ${widget.widgetType} (${widget.widgetId}) not disposed after 30 minutes',
          stateSnapshot: {
            'widget_id': widget.widgetId,
            'widget_type': widget.widgetType,
            'created_at': widget.createdAt.toIso8601String(),
            'age_minutes': DateTime.now().difference(widget.createdAt).inMinutes,
            'has_listeners': widget.hasListeners,
            'listener_count': widget.listenerCount,
          },
          severity: UIStateSeverity.warning,
          timestamp: DateTime.now(),
          suggestedFix: 'Ensure widget disposal in dispose() method',
        ));
      }
    } else {
      results.add(UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Undisposed Resource Detection',
        issueType: UIStateIssueType.undisposedResource,
        isValid: true,
        stateSnapshot: {
          'total_widgets': _widgetStates.length,
          'disposed_widgets': _widgetStates.values.where((w) => w.isDisposed).length,
        },
        severity: UIStateSeverity.info,
        timestamp: DateTime.now(),
      ));
    }

    return results;
  }

  Future<UIStateResult> _checkPerformanceIssues() async {
    final metrics = getCurrentPerformanceMetrics();
    
    if (metrics.frameDropRate > frameDropThreshold) {
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Performance Issue Detection',
        issueType: UIStateIssueType.performanceBottleneck,
        isValid: false,
        errorMessage: 'High frame drop rate: ${(metrics.frameDropRate * 100).toStringAsFixed(2)}%',
        stateSnapshot: metrics.toJson(),
        severity: metrics.frameDropRate > frameDropThreshold * 2 
            ? UIStateSeverity.critical 
            : UIStateSeverity.error,
        timestamp: DateTime.now(),
        suggestedFix: 'Optimize UI rendering and reduce expensive operations in build methods',
      );
    }

    return UIStateResult(
      id: UuidGenerator.generateId(),
      validationName: 'Performance Issue Detection',
      issueType: UIStateIssueType.performanceBottleneck,
      isValid: true,
      stateSnapshot: metrics.toJson(),
      severity: UIStateSeverity.info,
      timestamp: DateTime.now(),
    );
  }

  Future<UIStateResult> _checkStateConsistency() async {
    // Check for common state inconsistencies
    final inconsistencies = <String>[];
    
    // Check if navigation state is consistent
    if (_currentNavigationState != null) {
      if (_currentNavigationState!.stackDepth != _currentNavigationState!.routeStack.length) {
        inconsistencies.add('Navigation stack depth mismatch');
      }
      
      if (_currentNavigationState!.canGoBack && _currentNavigationState!.stackDepth <= 1) {
        inconsistencies.add('Navigation can go back but stack depth is <= 1');
      }
    }

    if (inconsistencies.isNotEmpty) {
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'State Consistency Check',
        issueType: UIStateIssueType.stateInconsistency,
        isValid: false,
        errorMessage: 'State inconsistencies found: ${inconsistencies.join(', ')}',
        stateSnapshot: {
          'inconsistencies': inconsistencies,
          'navigation_state': _currentNavigationState?.toJson(),
        },
        severity: UIStateSeverity.warning,
        timestamp: DateTime.now(),
        suggestedFix: 'Review state management and navigation logic',
      );
    }

    return UIStateResult(
      id: UuidGenerator.generateId(),
      validationName: 'State Consistency Check',
      issueType: UIStateIssueType.stateInconsistency,
      isValid: true,
      stateSnapshot: {
        'navigation_state': _currentNavigationState?.toJson(),
        'widget_states_count': _widgetStates.length,
      },
      severity: UIStateSeverity.info,
      timestamp: DateTime.now(),
    );
  }

  Future<UIStateResult> _checkNavigationState() async {
    if (_currentNavigationState == null) {
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Navigation State Check',
        issueType: UIStateIssueType.navigationIssue,
        isValid: false,
        errorMessage: 'Navigation state not being tracked',
        stateSnapshot: {'navigation_state': null},
        severity: UIStateSeverity.warning,
        timestamp: DateTime.now(),
        suggestedFix: 'Initialize navigation state tracking',
      );
    }

    // Check for potential navigation issues
    final issues = <String>[];
    
    if (_currentNavigationState!.stackDepth > 20) {
      issues.add('Deep navigation stack (${_currentNavigationState!.stackDepth} levels)');
    }
    
    final timeSinceLastNav = DateTime.now().difference(_currentNavigationState!.lastNavigation);
    if (timeSinceLastNav > const Duration(hours: 1)) {
      issues.add('No navigation activity for ${timeSinceLastNav.inHours} hours');
    }

    if (issues.isNotEmpty) {
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Navigation State Check',
        issueType: UIStateIssueType.navigationIssue,
        isValid: false,
        errorMessage: 'Navigation issues: ${issues.join(', ')}',
        stateSnapshot: _currentNavigationState!.toJson(),
        severity: UIStateSeverity.warning,
        timestamp: DateTime.now(),
        suggestedFix: 'Review navigation patterns and stack management',
      );
    }

    return UIStateResult(
      id: UuidGenerator.generateId(),
      validationName: 'Navigation State Check',
      issueType: UIStateIssueType.navigationIssue,
      isValid: true,
      stateSnapshot: _currentNavigationState!.toJson(),
      severity: UIStateSeverity.info,
      timestamp: DateTime.now(),
    );
  }

  Future<List<UIStateResult>> _checkWidgetLifecycleIssues() async {
    final results = <UIStateResult>[];
    
    // Check for widgets with listeners but no disposal
    final widgetsWithListeners = _widgetStates.values
        .where((w) => w.hasListeners && !w.isDisposed)
        .toList();

    if (widgetsWithListeners.isNotEmpty) {
      results.add(UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Widget Lifecycle Check',
        issueType: UIStateIssueType.undisposedResource,
        isValid: false,
        errorMessage: '${widgetsWithListeners.length} widgets have active listeners',
        stateSnapshot: {
          'widgets_with_listeners': widgetsWithListeners.length,
          'total_listeners': widgetsWithListeners.fold<int>(0, (sum, w) => sum + w.listenerCount),
        },
        severity: UIStateSeverity.warning,
        timestamp: DateTime.now(),
        suggestedFix: 'Ensure proper listener cleanup in dispose methods',
      ));
    }

    return results;
  }

  Future<UIStateResult> _checkBuildOverflow() async {
    // This would typically be detected through Flutter's debug information
    // For now, we'll simulate a check based on widget count
    
    final activeWidgets = _widgetStates.values.where((w) => !w.isDisposed).length;
    
    if (activeWidgets > 10000) { // Arbitrary threshold
      return UIStateResult(
        id: UuidGenerator.generateId(),
        validationName: 'Build Overflow Check',
        issueType: UIStateIssueType.buildOverflow,
        isValid: false,
        errorMessage: 'High widget count may cause build overflow ($activeWidgets widgets)',
        stateSnapshot: {
          'active_widgets': activeWidgets,
          'total_widgets': _widgetStates.length,
        },
        severity: UIStateSeverity.warning,
        timestamp: DateTime.now(),
        suggestedFix: 'Consider widget virtualization or lazy loading',
      );
    }

    return UIStateResult(
      id: UuidGenerator.generateId(),
      validationName: 'Build Overflow Check',
      issueType: UIStateIssueType.buildOverflow,
      isValid: true,
      stateSnapshot: {
        'active_widgets': activeWidgets,
        'total_widgets': _widgetStates.length,
      },
      severity: UIStateSeverity.info,
      timestamp: DateTime.now(),
    );
  }

  Future<List<UIStateResult>> _checkAnimationIssues() async {
    final results = <UIStateResult>[];
    
    // Check for potential animation stalls based on frame performance
    if (_frameTimes.isNotEmpty) {
      final recentFrameTimes = _frameTimes.length >= 30 
          ? _frameTimes.sublist(_frameTimes.length - 30)
          : _frameTimes;
      
      final avgFrameTime = recentFrameTimes.reduce((a, b) => a + b) / recentFrameTimes.length;
      final maxFrameTime = recentFrameTimes.reduce((a, b) => a > b ? a : b);
      
      if (maxFrameTime > 100) { // 100ms frame time indicates stall
        results.add(UIStateResult(
          id: UuidGenerator.generateId(),
          validationName: 'Animation Stall Check',
          issueType: UIStateIssueType.animationStall,
          isValid: false,
          errorMessage: 'Animation stall detected: ${maxFrameTime.toStringAsFixed(2)}ms frame time',
          stateSnapshot: {
            'max_frame_time_ms': maxFrameTime,
            'avg_frame_time_ms': avgFrameTime,
            'frame_samples': recentFrameTimes.length,
          },
          severity: maxFrameTime > 500 ? UIStateSeverity.critical : UIStateSeverity.error,
          timestamp: DateTime.now(),
          suggestedFix: 'Optimize animation performance or reduce concurrent animations',
        ));
      }
    }

    return results;
  }

  Map<String, double> _calculateCustomMetrics() {
    return {
      'disposal_rate': _widgetStates.isNotEmpty 
          ? (_widgetStates.values.where((w) => w.isDisposed).length / _widgetStates.length)
          : 0.0,
      'listener_density': _widgetStates.isNotEmpty
          ? (_widgetStates.values.fold<int>(0, (sum, w) => sum + w.listenerCount) / _widgetStates.length)
          : 0.0,
      'navigation_activity': _currentNavigationState != null
          ? (DateTime.now().difference(_currentNavigationState!.lastNavigation).inMinutes.toDouble())
          : -1.0,
    };
  }

  Map<String, int> _groupIssuesByType(List<UIStateResult> results) {
    final groups = <String, int>{};
    for (final result in results.where((r) => !r.isValid)) {
      groups[result.issueType.name] = (groups[result.issueType.name] ?? 0) + 1;
    }
    return groups;
  }

  Map<String, int> _groupIssuesBySeverity(List<UIStateResult> results) {
    final groups = <String, int>{};
    for (final result in results.where((r) => !r.isValid)) {
      groups[result.severity.name] = (groups[result.severity.name] ?? 0) + 1;
    }
    return groups;
  }

  Map<String, dynamic> _analyzePerformanceTrends(List<UIPerformanceMetrics> metrics) {
    if (metrics.isEmpty) return {};

    final frameDropRates = metrics.map((m) => m.frameDropRate).toList();
    final avgFrameTimes = metrics.map((m) => m.averageFrameTime).toList();
    final memoryUsages = metrics.map((m) => m.memoryUsage).toList();

    return {
      'frame_drop_rate_trend': _calculateTrend(frameDropRates),
      'avg_frame_time_trend': _calculateTrend(avgFrameTimes),
      'memory_usage_trend': _calculateTrend(memoryUsages),
      'performance_stability': _calculateStability(frameDropRates),
    };
  }

  Map<String, dynamic> _analyzeWidgetLifecycle() {
    final totalWidgets = _widgetStates.length;
    final disposedWidgets = _widgetStates.values.where((w) => w.isDisposed).length;
    final widgetsWithListeners = _widgetStates.values.where((w) => w.hasListeners).length;
    
    final widgetTypes = <String, int>{};
    for (final widget in _widgetStates.values) {
      widgetTypes[widget.widgetType] = (widgetTypes[widget.widgetType] ?? 0) + 1;
    }

    return {
      'total_widgets': totalWidgets,
      'disposed_widgets': disposedWidgets,
      'disposal_rate': totalWidgets > 0 ? (disposedWidgets / totalWidgets) : 0.0,
      'widgets_with_listeners': widgetsWithListeners,
      'widget_types': widgetTypes,
    };
  }

  double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final first = values.take(values.length ~/ 2).reduce((a, b) => a + b) / (values.length ~/ 2);
    final last = values.skip(values.length ~/ 2).reduce((a, b) => a + b) / (values.length - values.length ~/ 2);
    
    return last - first;
  }

  double _calculateStability(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    
    return variance;
  }

  List<Map<String, dynamic>> _generateUIRecommendations(List<UIStateResult> results) {
    final recommendations = <Map<String, dynamic>>[];
    final issueGroups = _groupIssuesByType(results);

    for (final group in issueGroups.entries) {
      if (group.value >= 3) { // Threshold for recommendation
        recommendations.add({
          'type': 'ui_optimization',
          'issue_type': group.key,
          'count': group.value,
          'suggestion': _getUIOptimizationSuggestion(group.key),
          'priority': group.value > 10 ? 'high' : 'medium',
        });
      }
    }

    return recommendations;
  }

  String _getUIOptimizationSuggestion(String issueType) {
    switch (issueType) {
      case 'memoryLeak':
        return 'Review widget disposal and stream subscriptions for memory leaks';
      case 'undisposedResource':
        return 'Implement proper resource cleanup in dispose() methods';
      case 'performanceBottleneck':
        return 'Optimize expensive operations and consider widget virtualization';
      case 'stateInconsistency':
        return 'Review state management patterns and data flow';
      case 'navigationIssue':
        return 'Optimize navigation stack management and routing logic';
      case 'animationStall':
        return 'Reduce animation complexity or implement frame throttling';
      default:
        return 'Review UI implementation for this issue type';
    }
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _monitoringTimers.values) {
      timer.cancel();
    }
    _monitoringTimers.clear();
    
    if (kDebugMode) {
      WidgetsBinding.instance.removeFrameCallback(_onFrameCallback);
    }
  }
}