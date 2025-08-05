import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/uuid_generator.dart';
import '../constants/app_constants.dart';
import '../database/platform_database_factory.dart';

/// Types of evidence that can be collected
enum EvidenceType {
  systemInfo,
  databaseState,
  errorLogs,
  performanceMetrics,
  userActions,
  configurationSnapshot,
  networkStatus,
  fileSystemState,
  memoryUsage,
  stackTrace,
  environmentVariables,
  dependencyVersions,
}

/// Evidence collection methods
enum CollectionMethod {
  automatic,
  triggered,
  periodic,
  onDemand,
  onError,
}

/// Evidence priority levels
enum EvidencePriority {
  low,
  normal,
  high,
  critical,
  emergency,
}

/// Collected evidence item
class EvidenceItem {
  final String id;
  final EvidenceType type;
  final CollectionMethod method;
  final EvidencePriority priority;
  final DateTime collectedAt;
  final String platform;
  final String source;
  final Map<String, dynamic> data;
  final List<String> tags;
  final String? correlationId;
  final String? sessionId;
  final String? errorId;
  final Map<String, dynamic> metadata;

  const EvidenceItem({
    required this.id,
    required this.type,
    required this.method,
    required this.priority,
    required this.collectedAt,
    required this.platform,
    required this.source,
    required this.data,
    required this.tags,
    this.correlationId,
    this.sessionId,
    this.errorId,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'method': method.name,
      'priority': priority.name,
      'collected_at': collectedAt.toIso8601String(),
      'platform': platform,
      'source': source,
      'data': jsonEncode(data),
      'tags': tags,
      'correlation_id': correlationId,
      'session_id': sessionId,
      'error_id': errorId,
      'metadata': jsonEncode(metadata),
    };
  }

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      id: json['id'] as String,
      type: EvidenceType.values.firstWhere((e) => e.name == json['type']),
      method: CollectionMethod.values.firstWhere((e) => e.name == json['method']),
      priority: EvidencePriority.values.firstWhere((e) => e.name == json['priority']),
      collectedAt: DateTime.parse(json['collected_at'] as String),
      platform: json['platform'] as String,
      source: json['source'] as String,
      data: jsonDecode(json['data'] as String) as Map<String, dynamic>,
      tags: List<String>.from(json['tags'] as List),
      correlationId: json['correlation_id'] as String?,
      sessionId: json['session_id'] as String?,
      errorId: json['error_id'] as String?,
      metadata: jsonDecode(json['metadata'] as String) as Map<String, dynamic>,
    );
  }
}

/// Evidence collection rule
class CollectionRule {
  final String id;
  final String name;
  final EvidenceType evidenceType;
  final CollectionMethod method;
  final Duration? interval;
  final List<String> triggers;
  final bool enabled;
  final EvidencePriority priority;
  final int maxItems;
  final Duration retention;
  final Map<String, dynamic> conditions;

  const CollectionRule({
    required this.id,
    required this.name,
    required this.evidenceType,
    required this.method,
    this.interval,
    required this.triggers,
    required this.enabled,
    required this.priority,
    required this.maxItems,
    required this.retention,
    required this.conditions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'evidence_type': evidenceType.name,
      'method': method.name,
      'interval_seconds': interval?.inSeconds,
      'triggers': triggers,
      'enabled': enabled,
      'priority': priority.name,
      'max_items': maxItems,
      'retention_seconds': retention.inSeconds,
      'conditions': jsonEncode(conditions),
    };
  }
}

/// Evidence collection session
class EvidenceSession {
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String purpose;
  final List<String> evidenceIds;
  final Map<String, dynamic> context;
  final bool isActive;

  const EvidenceSession({
    required this.id,
    required this.name,
    required this.startedAt,
    this.endedAt,
    required this.purpose,
    required this.evidenceIds,
    required this.context,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'purpose': purpose,
      'evidence_ids': evidenceIds,
      'context': jsonEncode(context),
      'is_active': isActive,
    };
  }
}

/// Comprehensive evidence collection and tracking system
class EvidenceCollectionSystem {
  final Map<String, EvidenceItem> _evidence = {};
  final Map<String, CollectionRule> _rules = {};
  final Map<String, Timer> _timers = {};
  final Map<String, EvidenceSession> _sessions = {};
  final List<String> _activeCollectors = [];
  
  // Configuration
  final int _maxEvidenceItems;
  final Duration _defaultRetention;
  final bool _enableAutoCleanup;
  final String _storageDirectory;
  
  bool _isInitialized = false;
  String? _currentSessionId;

  EvidenceCollectionSystem({
    int maxEvidenceItems = 10000,
    Duration defaultRetention = const Duration(days: 30),
    bool enableAutoCleanup = true,
    String? storageDirectory,
  }) : _maxEvidenceItems = maxEvidenceItems,
       _defaultRetention = defaultRetention,
       _enableAutoCleanup = enableAutoCleanup,
       _storageDirectory = storageDirectory ?? 'evidence_collection';

  /// Initialize the evidence collection system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🔍 Initializing Evidence Collection System...');

    // Setup default collection rules
    await _setupDefaultRules();
    
    // Start automatic collectors
    await _startAutomaticCollectors();
    
    // Setup cleanup timer
    if (_enableAutoCleanup) {
      await _setupAutoCleanup();
    }
    
    // Load historical data
    await _loadHistoricalData();
    
    _isInitialized = true;
    debugPrint('✅ Evidence Collection System initialized');
  }

  /// Start a new evidence collection session
  Future<EvidenceSession> startSession(
    String name,
    String purpose, {
    Map<String, dynamic>? context,
  }) async {
    final session = EvidenceSession(
      id: UuidGenerator.generateId(),
      name: name,
      startedAt: DateTime.now(),
      purpose: purpose,
      evidenceIds: [],
      context: context ?? {},
      isActive: true,
    );

    _sessions[session.id] = session;
    _currentSessionId = session.id;

    debugPrint('📋 Started evidence session: $name');
    return session;
  }

  /// End an evidence collection session
  Future<void> endSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    final updatedSession = EvidenceSession(
      id: session.id,
      name: session.name,
      startedAt: session.startedAt,
      endedAt: DateTime.now(),
      purpose: session.purpose,
      evidenceIds: session.evidenceIds,
      context: session.context,
      isActive: false,
    );

    _sessions[sessionId] = updatedSession;
    
    if (_currentSessionId == sessionId) {
      _currentSessionId = null;
    }

    debugPrint('📋 Ended evidence session: ${session.name}');
  }

  /// Collect evidence immediately
  Future<EvidenceItem> collectEvidence(
    EvidenceType type,
    String source, {
    EvidencePriority priority = EvidencePriority.normal,
    List<String> tags = const [],
    String? correlationId,
    String? errorId,
    Map<String, dynamic>? metadata,
  }) async {
    final evidence = EvidenceItem(
      id: UuidGenerator.generateId(),
      type: type,
      method: CollectionMethod.onDemand,
      priority: priority,
      collectedAt: DateTime.now(),
      platform: Platform.operatingSystem,
      source: source,
      data: await _collectEvidenceData(type, source),
      tags: tags,
      correlationId: correlationId,
      sessionId: _currentSessionId,
      errorId: errorId,
      metadata: metadata ?? {},
    );

    await _storeEvidence(evidence);
    
    debugPrint('📊 Collected evidence: ${type.name} from $source');
    return evidence;
  }

  /// Collect evidence for a specific error
  Future<List<EvidenceItem>> collectErrorEvidence(
    String errorId,
    String errorMessage, {
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    debugPrint('🚨 Collecting error evidence for: $errorId');
    
    final evidenceItems = <EvidenceItem>[];
    final correlationId = UuidGenerator.generateId();

    // Collect system info
    evidenceItems.add(await collectEvidence(
      EvidenceType.systemInfo,
      'error_handler',
      priority: EvidencePriority.high,
      tags: ['error', 'system'],
      correlationId: correlationId,
      errorId: errorId,
      metadata: {
        'error_message': errorMessage,
        'has_stack_trace': stackTrace != null,
      },
    ));

    // Collect database state
    evidenceItems.add(await collectEvidence(
      EvidenceType.databaseState,
      'error_handler',
      priority: EvidencePriority.high,
      tags: ['error', 'database'],
      correlationId: correlationId,
      errorId: errorId,
    ));

    // Collect error logs
    final errorLogData = {
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'context': context,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final errorLogEvidence = EvidenceItem(
      id: UuidGenerator.generateId(),
      type: EvidenceType.errorLogs,
      method: CollectionMethod.onError,
      priority: EvidencePriority.critical,
      collectedAt: DateTime.now(),
      platform: Platform.operatingSystem,
      source: 'error_handler',
      data: errorLogData,
      tags: ['error', 'logs'],
      correlationId: correlationId,
      sessionId: _currentSessionId,
      errorId: errorId,
      metadata: {'error_severity': 'high'},
    );

    await _storeEvidence(errorLogEvidence);
    evidenceItems.add(errorLogEvidence);

    // Collect performance metrics
    evidenceItems.add(await collectEvidence(
      EvidenceType.performanceMetrics,
      'error_handler',
      priority: EvidencePriority.normal,
      tags: ['error', 'performance'],
      correlationId: correlationId,
      errorId: errorId,
    ));

    debugPrint('✅ Collected ${evidenceItems.length} error evidence items');
    return evidenceItems;
  }

  /// Add a new collection rule
  Future<void> addCollectionRule(CollectionRule rule) async {
    _rules[rule.id] = rule;
    
    if (rule.enabled) {
      await _activateRule(rule);
    }

    debugPrint('📏 Added collection rule: ${rule.name}');
  }

  /// Remove a collection rule
  Future<void> removeCollectionRule(String ruleId) async {
    final rule = _rules[ruleId];
    if (rule == null) return;

    await _deactivateRule(rule);
    _rules.remove(ruleId);

    debugPrint('📏 Removed collection rule: ${rule.name}');
  }

  /// Enable/disable a collection rule
  Future<void> toggleCollectionRule(String ruleId, bool enabled) async {
    final rule = _rules[ruleId];
    if (rule == null) return;

    final updatedRule = CollectionRule(
      id: rule.id,
      name: rule.name,
      evidenceType: rule.evidenceType,
      method: rule.method,
      interval: rule.interval,
      triggers: rule.triggers,
      enabled: enabled,
      priority: rule.priority,
      maxItems: rule.maxItems,
      retention: rule.retention,
      conditions: rule.conditions,
    );

    _rules[ruleId] = updatedRule;

    if (enabled) {
      await _activateRule(updatedRule);
    } else {
      await _deactivateRule(updatedRule);
    }

    debugPrint('📏 ${enabled ? 'Enabled' : 'Disabled'} collection rule: ${rule.name}');
  }

  /// Query evidence items
  List<EvidenceItem> queryEvidence({
    EvidenceType? type,
    EvidencePriority? priority,
    String? correlationId,
    String? sessionId,
    String? errorId,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? tags,
    int? limit,
  }) {
    var results = _evidence.values.toList();

    // Apply filters
    if (type != null) {
      results = results.where((e) => e.type == type).toList();
    }
    
    if (priority != null) {
      results = results.where((e) => e.priority == priority).toList();
    }
    
    if (correlationId != null) {
      results = results.where((e) => e.correlationId == correlationId).toList();
    }
    
    if (sessionId != null) {
      results = results.where((e) => e.sessionId == sessionId).toList();
    }
    
    if (errorId != null) {
      results = results.where((e) => e.errorId == errorId).toList();
    }
    
    if (fromDate != null) {
      results = results.where((e) => e.collectedAt.isAfter(fromDate)).toList();
    }
    
    if (toDate != null) {
      results = results.where((e) => e.collectedAt.isBefore(toDate)).toList();
    }
    
    if (tags != null && tags.isNotEmpty) {
      results = results.where((e) => 
        tags.any((tag) => e.tags.contains(tag))
      ).toList();
    }

    // Sort by collection time (newest first)
    results.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

    // Apply limit
    if (limit != null && limit > 0) {
      results = results.take(limit).toList();
    }

    return results;
  }

  /// Get evidence collection statistics
  Map<String, dynamic> getCollectionStatistics() {
    final stats = <String, dynamic>{
      'total_evidence_items': _evidence.length,
      'active_rules': _rules.values.where((r) => r.enabled).length,
      'total_rules': _rules.length,
      'active_sessions': _sessions.values.where((s) => s.isActive).length,
      'total_sessions': _sessions.length,
      'evidence_by_type': <String, int>{},
      'evidence_by_priority': <String, int>{},
      'evidence_by_method': <String, int>{},
      'recent_evidence_count': 0,
      'storage_usage_mb': 0.0,
    };

    // Analyze evidence distribution
    for (final evidence in _evidence.values) {
      final type = evidence.type.name;
      stats['evidence_by_type'][type] = (stats['evidence_by_type'][type] ?? 0) + 1;
      
      final priority = evidence.priority.name;
      stats['evidence_by_priority'][priority] = (stats['evidence_by_priority'][priority] ?? 0) + 1;
      
      final method = evidence.method.name;
      stats['evidence_by_method'][method] = (stats['evidence_by_method'][method] ?? 0) + 1;
      
      // Count recent evidence (last 24 hours)
      if (DateTime.now().difference(evidence.collectedAt).inHours < 24) {
        stats['recent_evidence_count']++;
      }
    }

    return stats;
  }

  /// Export evidence for analysis
  Future<Map<String, dynamic>> exportEvidence({
    String? sessionId,
    String? correlationId,
    DateTime? fromDate,
    DateTime? toDate,
    List<EvidenceType>? types,
  }) async {
    debugPrint('📤 Exporting evidence...');
    
    final evidenceItems = queryEvidence(
      sessionId: sessionId,
      correlationId: correlationId,
      fromDate: fromDate,
      toDate: toDate,
    );

    // Filter by types if specified
    final filteredItems = types != null
      ? evidenceItems.where((e) => types.contains(e.type)).toList()
      : evidenceItems;

    final export = <String, dynamic>{
      'export_id': UuidGenerator.generateId(),
      'generated_at': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'total_items': filteredItems.length,
      'date_range': {
        'from': fromDate?.toIso8601String(),
        'to': toDate?.toIso8601String(),
      },
      'evidence_items': filteredItems.map((e) => e.toJson()).toList(),
      'sessions': sessionId != null 
        ? [_sessions[sessionId]?.toJson()].where((s) => s != null).toList()
        : _sessions.values.map((s) => s.toJson()).toList(),
      'collection_rules': _rules.values.map((r) => r.toJson()).toList(),
      'statistics': getCollectionStatistics(),
    };

    debugPrint('✅ Exported ${filteredItems.length} evidence items');
    return export;
  }

  /// Clean up old evidence
  Future<void> cleanupOldEvidence() async {
    debugPrint('🧹 Cleaning up old evidence...');
    
    final cutoffDate = DateTime.now().subtract(_defaultRetention);
    final toRemove = <String>[];
    
    for (final entry in _evidence.entries) {
      if (entry.value.collectedAt.isBefore(cutoffDate)) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _evidence.remove(id);
    }

    debugPrint('🧹 Cleaned up ${toRemove.length} old evidence items');
  }

  // Private methods

  Future<void> _setupDefaultRules() async {
    // System info collection
    await addCollectionRule(CollectionRule(
      id: 'system_info_periodic',
      name: 'Periodic System Info',
      evidenceType: EvidenceType.systemInfo,
      method: CollectionMethod.periodic,
      interval: const Duration(hours: 1),
      triggers: [],
      enabled: true,
      priority: EvidencePriority.low,
      maxItems: 24,
      retention: const Duration(days: 7),
      conditions: {},
    ));

    // Database state monitoring
    await addCollectionRule(CollectionRule(
      id: 'database_state_triggered',
      name: 'Database State on Events',
      evidenceType: EvidenceType.databaseState,
      method: CollectionMethod.triggered,
      triggers: ['database_error', 'initialization_failure'],
      enabled: true,
      priority: EvidencePriority.high,
      maxItems: 100,
      retention: const Duration(days: 30),
      conditions: {},
    ));

    // Performance metrics
    await addCollectionRule(CollectionRule(
      id: 'performance_periodic',
      name: 'Performance Metrics',
      evidenceType: EvidenceType.performanceMetrics,
      method: CollectionMethod.periodic,
      interval: const Duration(minutes: 30),
      triggers: [],
      enabled: true,
      priority: EvidencePriority.normal,
      maxItems: 48,
      retention: const Duration(days: 14),
      conditions: {},
    ));

    // Error logs
    await addCollectionRule(CollectionRule(
      id: 'error_logs_triggered',
      name: 'Error Logs Collection',
      evidenceType: EvidenceType.errorLogs,
      method: CollectionMethod.onError,
      triggers: ['error', 'exception', 'crash'],
      enabled: true,
      priority: EvidencePriority.critical,
      maxItems: 1000,
      retention: const Duration(days: 90),
      conditions: {},
    ));
  }

  Future<void> _startAutomaticCollectors() async {
    debugPrint('🤖 Starting automatic evidence collectors...');
    
    for (final rule in _rules.values.where((r) => r.enabled)) {
      await _activateRule(rule);
    }
  }

  Future<void> _setupAutoCleanup() async {
    Timer.periodic(const Duration(hours: 6), (_) async {
      await cleanupOldEvidence();
    });
  }

  Future<void> _loadHistoricalData() async {
    // Load historical evidence from persistent storage
    // Implementation would load from database or file system
    debugPrint('📚 Loading historical evidence data...');
  }

  Future<void> _activateRule(CollectionRule rule) async {
    if (rule.method == CollectionMethod.periodic && rule.interval != null) {
      _timers[rule.id] = Timer.periodic(rule.interval!, (_) async {
        await _collectByRule(rule);
      });
    }
    
    if (!_activeCollectors.contains(rule.id)) {
      _activeCollectors.add(rule.id);
    }
  }

  Future<void> _deactivateRule(CollectionRule rule) async {
    _timers[rule.id]?.cancel();
    _timers.remove(rule.id);
    _activeCollectors.remove(rule.id);
  }

  Future<void> _collectByRule(CollectionRule rule) async {
    try {
      await collectEvidence(
        rule.evidenceType,
        'rule_${rule.id}',
        priority: rule.priority,
        tags: ['automatic', 'rule_based'],
      );
    } catch (e) {
      debugPrint('❌ Rule-based collection failed for ${rule.name}: $e');
    }
  }

  Future<Map<String, dynamic>> _collectEvidenceData(
    EvidenceType type,
    String source,
  ) async {
    switch (type) {
      case EvidenceType.systemInfo:
        return await _collectSystemInfo();
      case EvidenceType.databaseState:
        return await _collectDatabaseState();
      case EvidenceType.performanceMetrics:
        return await _collectPerformanceMetrics();
      case EvidenceType.configurationSnapshot:
        return await _collectConfigurationSnapshot();
      case EvidenceType.fileSystemState:
        return await _collectFileSystemState();
      case EvidenceType.memoryUsage:
        return await _collectMemoryUsage();
      case EvidenceType.networkStatus:
        return await _collectNetworkStatus();
      case EvidenceType.dependencyVersions:
        return await _collectDependencyVersions();
      case EvidenceType.environmentVariables:
        return await _collectEnvironmentVariables();
      default:
        return {
          'type': type.name,
          'collected_at': DateTime.now().toIso8601String(),
          'note': 'Collection not implemented for this evidence type',
        };
    }
  }

  Future<Map<String, dynamic>> _collectSystemInfo() async {
    return {
      'operating_system': Platform.operatingSystem,
      'operating_system_version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'number_of_processors': Platform.numberOfProcessors,
      'hostname': Platform.localHostname,
      'is_android': Platform.isAndroid,
      'is_ios': Platform.isIOS,
      'is_linux': Platform.isLinux,
      'is_windows': Platform.isWindows,
      'is_macos': Platform.isMacOS,
      'path_separator': Platform.pathSeparator,
      'collected_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _collectDatabaseState() async {
    final state = <String, dynamic>{
      'collected_at': DateTime.now().toIso8601String(),
    };

    try {
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      state.addAll(dbInfo);
      
      // Test connectivity
      final connectivity = await PlatformDatabaseFactory.testDatabaseConnectivity('test.db');
      state['connectivity_test'] = connectivity;
      
      state['app_database_name'] = AppConstants.databaseName;
      state['app_database_version'] = AppConstants.databaseVersion;
      
    } catch (e) {
      state['error'] = e.toString();
      state['error_occurred'] = true;
    }

    return state;
  }

  Future<Map<String, dynamic>> _collectPerformanceMetrics() async {
    final metrics = <String, dynamic>{
      'collected_at': DateTime.now().toIso8601String(),
    };

    try {
      // Database initialization timing
      final startTime = DateTime.now();
      await PlatformDatabaseFactory.testDatabaseConnectivity('perf_test.db');
      final endTime = DateTime.now();
      
      metrics['database_init_time_ms'] = endTime.difference(startTime).inMilliseconds;
      
      // Memory usage (if available)
      metrics['memory_usage_estimate'] = _getMemoryUsageEstimate();
      
    } catch (e) {
      metrics['error'] = e.toString();
    }

    return metrics;
  }

  Future<Map<String, dynamic>> _collectConfigurationSnapshot() async {
    return {
      'app_constants': {
        'app_name': AppConstants.appName,
        'app_version': AppConstants.appVersion,
        'database_name': AppConstants.databaseName,
        'database_version': AppConstants.databaseVersion,
        'encryption_enabled': AppConstants.encryptionKey.isNotEmpty,
      },
      'platform_config': Platform.operatingSystem,
      'debug_mode': kDebugMode,
      'collected_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _collectFileSystemState() async {
    final fsState = <String, dynamic>{
      'collected_at': DateTime.now().toIso8601String(),
    };

    try {
      // Get app documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      fsState['app_documents_directory'] = {
        'path': appDocsDir.path,
        'exists': await appDocsDir.exists(),
      };

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      fsState['temporary_directory'] = {
        'path': tempDir.path,
        'exists': await tempDir.exists(),
      };

      // Check database file
      final dbPath = '${appDocsDir.path}/${AppConstants.databaseName}';
      final dbFile = File(dbPath);
      fsState['database_file'] = {
        'path': dbPath,
        'exists': await dbFile.exists(),
        'size': await dbFile.exists() ? (await dbFile.stat()).size : 0,
      };

    } catch (e) {
      fsState['error'] = e.toString();
    }

    return fsState;
  }

  Future<Map<String, dynamic>> _collectMemoryUsage() async {
    return {
      'collected_at': DateTime.now().toIso8601String(),
      'estimated_usage_mb': _getMemoryUsageEstimate(),
      'note': 'Memory usage is estimated - exact measurement not available',
    };
  }

  Future<Map<String, dynamic>> _collectNetworkStatus() async {
    return {
      'collected_at': DateTime.now().toIso8601String(),
      'hostname': Platform.localHostname,
      'note': 'Network connectivity testing not implemented',
    };
  }

  Future<Map<String, dynamic>> _collectDependencyVersions() async {
    return {
      'dart_version': Platform.version,
      'platform_version': Platform.operatingSystemVersion,
      'collected_at': DateTime.now().toIso8601String(),
      'note': 'Dependency version collection needs implementation',
    };
  }

  Future<Map<String, dynamic>> _collectEnvironmentVariables() async {
    return {
      'platform_environment': Platform.environment.keys.take(10).toList(), // Only keys for privacy
      'collected_at': DateTime.now().toIso8601String(),
      'note': 'Environment variable values hidden for security',
    };
  }

  Future<void> _storeEvidence(EvidenceItem evidence) async {
    _evidence[evidence.id] = evidence;
    
    // Add to current session if active
    if (_currentSessionId != null) {
      final session = _sessions[_currentSessionId!];
      if (session != null && session.isActive) {
        final updatedSession = EvidenceSession(
          id: session.id,
          name: session.name,
          startedAt: session.startedAt,
          endedAt: session.endedAt,
          purpose: session.purpose,
          evidenceIds: [...session.evidenceIds, evidence.id],
          context: session.context,
          isActive: session.isActive,
        );
        _sessions[_currentSessionId!] = updatedSession;
      }
    }

    // Cleanup if too many items
    if (_evidence.length > _maxEvidenceItems) {
      await _cleanupExcessEvidence();
    }
  }

  Future<void> _cleanupExcessEvidence() async {
    // Remove oldest, lowest priority evidence
    final sortedEvidence = _evidence.values.toList()
      ..sort((a, b) {
        // Sort by priority first (lower priority removed first)
        final priorityCompare = a.priority.index.compareTo(b.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        
        // Then by age (older removed first)
        return a.collectedAt.compareTo(b.collectedAt);
      });

    final toRemove = sortedEvidence.take(_evidence.length - (_maxEvidenceItems ~/ 2)).toList();
    
    for (final evidence in toRemove) {
      _evidence.remove(evidence.id);
    }

    debugPrint('🧹 Cleaned up ${toRemove.length} excess evidence items');
  }

  double _getMemoryUsageEstimate() {
    // Estimate memory usage based on evidence collection
    return (_evidence.length * 2.0) + (_sessions.length * 0.5); // Rough estimate in MB
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _activeCollectors.clear();
    debugPrint('🛑 Evidence Collection System disposed');
  }
}