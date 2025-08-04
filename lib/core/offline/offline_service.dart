import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Connection status
enum ConnectionStatus {
  online,
  offline,
  limited, // Connected but with limited access
}

// Sync operation types
enum SyncOperationType {
  create,
  update,
  delete,
}

// Data entity types that can be synced
enum EntityType {
  customer,
  invoice,
  product,
  payment,
  report,
}

// Pending sync operation
class PendingSyncOperation {
  final String id;
  final EntityType entityType;
  final SyncOperationType operationType;
  final String entityId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  const PendingSyncOperation({
    required this.id,
    required this.entityType,
    required this.operationType,
    required this.entityId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingSyncOperation copyWith({
    String? id,
    EntityType? entityType,
    SyncOperationType? operationType,
    String? entityId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return PendingSyncOperation(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      operationType: operationType ?? this.operationType,
      entityId: entityId ?? this.entityId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType.index,
      'operationType': operationType.index,
      'entityId': entityId,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'retryCount': retryCount,
    };
  }

  static PendingSyncOperation fromJson(Map<String, dynamic> json) {
    return PendingSyncOperation(
      id: json['id'],
      entityType: EntityType.values[json['entityType']],
      operationType: SyncOperationType.values[json['operationType']],
      entityId: json['entityId'],
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

// Sync conflict resolution
class SyncConflict {
  final String entityId;
  final EntityType entityType;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localModified;
  final DateTime remoteModified;

  const SyncConflict({
    required this.entityId,
    required this.entityType,
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
  });
}

// Offline sync statistics
class SyncStats {
  final int pendingOperations;
  final int completedOperations;
  final int failedOperations;
  final int conflictedOperations;
  final DateTime? lastSyncTime;

  const SyncStats({
    required this.pendingOperations,
    required this.completedOperations,
    required this.failedOperations,
    required this.conflictedOperations,
    this.lastSyncTime,
  });
}

// Offline service for managing connectivity and sync operations
class OfflineService extends ChangeNotifier {
  static const String _pendingOpsKey = 'pending_sync_operations';
  static const String _lastSyncKey = 'last_sync_time';
  static const String _syncStatsKey = 'sync_statistics';
  static const int _maxRetryCount = 3;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  final Queue<PendingSyncOperation> _pendingOperations =
      Queue<PendingSyncOperation>();
  final List<SyncConflict> _conflicts = [];
  SharedPreferences? _prefs;
  Timer? _syncTimer;

  // Sync statistics
  int _completedOperations = 0;
  int _failedOperations = 0;
  DateTime? _lastSyncTime;

  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;
  List<PendingSyncOperation> get pendingOperations =>
      _pendingOperations.toList();
  List<SyncConflict> get conflicts => List.unmodifiable(_conflicts);
  bool get isOnline => _connectionStatus == ConnectionStatus.online;
  bool get isOffline => _connectionStatus == ConnectionStatus.offline;
  bool get hasPendingOperations => _pendingOperations.isNotEmpty;
  bool get hasConflicts => _conflicts.isNotEmpty;

  SyncStats get syncStats => SyncStats(
        pendingOperations: _pendingOperations.length,
        completedOperations: _completedOperations,
        failedOperations: _failedOperations,
        conflictedOperations: _conflicts.length,
        lastSyncTime: _lastSyncTime,
      );

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPendingOperations();
    await _loadSyncStats();
    await _checkInitialConnectivity();
    _startConnectivityMonitoring();
    _startPeriodicSync();
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        debugPrint('Connectivity monitoring error: $error');
      },
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection =
        results.any((result) => result != ConnectivityResult.none);

    final newStatus =
        hasConnection ? ConnectionStatus.online : ConnectionStatus.offline;

    if (_connectionStatus != newStatus) {
      final wasOffline = _connectionStatus == ConnectionStatus.offline;
      _connectionStatus = newStatus;

      debugPrint('Connection status changed to: ${_connectionStatus.name}');

      // Trigger sync when coming back online
      if (wasOffline && newStatus == ConnectionStatus.online) {
        _triggerSync();
      }

      notifyListeners();
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isOnline && hasPendingOperations) {
        _triggerSync();
      }
    });
  }

  Future<void> _loadPendingOperations() async {
    if (_prefs == null) return;

    final pendingOpsJson = _prefs!.getStringList(_pendingOpsKey) ?? [];

    for (final opJson in pendingOpsJson) {
      try {
        final data = _parseJson(opJson);
        final operation = PendingSyncOperation.fromJson(data);
        _pendingOperations.add(operation);
      } catch (e) {
        debugPrint('Error loading pending operation: $e');
      }
    }

    debugPrint('Loaded ${_pendingOperations.length} pending sync operations');
  }

  Future<void> _savePendingOperations() async {
    if (_prefs == null) return;

    final pendingOpsJson =
        _pendingOperations.map((op) => _stringifyJson(op.toJson())).toList();

    await _prefs!.setStringList(_pendingOpsKey, pendingOpsJson);
  }

  Future<void> _loadSyncStats() async {
    if (_prefs == null) return;

    _completedOperations = _prefs!.getInt('${_syncStatsKey}_completed') ?? 0;
    _failedOperations = _prefs!.getInt('${_syncStatsKey}_failed') ?? 0;

    final lastSyncTimestamp = _prefs!.getInt(_lastSyncKey);
    if (lastSyncTimestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
    }
  }

  Future<void> _saveSyncStats() async {
    if (_prefs == null) return;

    await _prefs!.setInt('${_syncStatsKey}_completed', _completedOperations);
    await _prefs!.setInt('${_syncStatsKey}_failed', _failedOperations);

    if (_lastSyncTime != null) {
      await _prefs!.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    }
  }

  // Queue an operation for sync when online
  Future<void> queueOperation({
    required EntityType entityType,
    required SyncOperationType operationType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final operation = PendingSyncOperation(
      id: _generateOperationId(),
      entityType: entityType,
      operationType: operationType,
      entityId: entityId,
      data: data,
      createdAt: DateTime.now(),
    );

    _pendingOperations.add(operation);
    await _savePendingOperations();

    debugPrint(
        'Queued ${operationType.name} operation for ${entityType.name}: $entityId');

    // Try to sync immediately if online
    if (isOnline) {
      _triggerSync();
    }

    notifyListeners();
  }

  // Trigger sync process
  Future<void> _triggerSync() async {
    if (isOffline || !hasPendingOperations) return;

    debugPrint(
        'Starting sync process with ${_pendingOperations.length} pending operations');

    final operationsToProcess =
        List<PendingSyncOperation>.from(_pendingOperations);
    final processedOperations = <PendingSyncOperation>[];

    for (final operation in operationsToProcess) {
      try {
        final success = await _processSyncOperation(operation);

        if (success) {
          _pendingOperations.remove(operation);
          processedOperations.add(operation);
          _completedOperations++;
          debugPrint(
              'Successfully synced ${operation.operationType.name} for ${operation.entityType.name}: ${operation.entityId}');
        } else {
          // Increment retry count
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );

          if (updatedOperation.retryCount >= _maxRetryCount) {
            // Remove operation after max retries
            _pendingOperations.remove(operation);
            _failedOperations++;
            debugPrint('Max retries reached for operation: ${operation.id}');
          } else {
            // Update operation with retry count
            _pendingOperations.remove(operation);
            _pendingOperations.add(updatedOperation);
          }
        }
      } catch (e) {
        debugPrint('Error processing sync operation ${operation.id}: $e');
        _failedOperations++;
      }
    }

    if (processedOperations.isNotEmpty) {
      _lastSyncTime = DateTime.now();
      await _savePendingOperations();
      await _saveSyncStats();

      debugPrint(
          'Sync completed. Processed: ${processedOperations.length}, Remaining: ${_pendingOperations.length}');
      notifyListeners();
    }
  }

  // Process individual sync operation
  Future<bool> _processSyncOperation(PendingSyncOperation operation) async {
    // This is where you would implement the actual sync logic
    // For now, we'll simulate the sync process

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate success/failure (90% success rate)
    final success = DateTime.now().millisecond % 10 != 0;

    if (success) {
      // Here you would make the actual API call to sync the data
      switch (operation.operationType) {
        case SyncOperationType.create:
          // await apiService.create(operation.entityType, operation.data);
          break;
        case SyncOperationType.update:
          // await apiService.update(operation.entityType, operation.entityId, operation.data);
          break;
        case SyncOperationType.delete:
          // await apiService.delete(operation.entityType, operation.entityId);
          break;
      }
    }

    return success;
  }

  // Manual sync trigger
  Future<void> forcSync() async {
    if (isOffline) {
      debugPrint('Cannot sync while offline');
      return;
    }

    await _triggerSync();
  }

  // Clear all pending operations
  Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    await _savePendingOperations();
    notifyListeners();
  }

  // Resolve sync conflict
  Future<void> resolveConflict(
      SyncConflict conflict, Map<String, dynamic> resolvedData) async {
    _conflicts.remove(conflict);

    // Queue the resolved data for sync
    await queueOperation(
      entityType: conflict.entityType,
      operationType: SyncOperationType.update,
      entityId: conflict.entityId,
      data: resolvedData,
    );

    notifyListeners();
  }

  String _generateOperationId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_pendingOperations.length}';
  }

  // Simple JSON parsing methods
  Map<String, dynamic> _parseJson(String jsonString) {
    final Map<String, dynamic> result = {};

    final content = jsonString.replaceAll(RegExp(r'[{}"]'), '');
    final pairs = content.split(',');

    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();

        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value == 'null') {
          result[key] = null;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }

  String _stringifyJson(Map<String, dynamic> data) {
    final List<String> pairs = [];

    data.forEach((key, value) {
      String valueStr;
      if (value == null) {
        valueStr = 'null';
      } else if (value is bool) {
        valueStr = value.toString();
      } else if (value is int) {
        valueStr = value.toString();
      } else if (value is Map) {
        valueStr = _stringifyJson(Map<String, dynamic>.from(value));
      } else {
        valueStr = '"$value"';
      }
      pairs.add('"$key":$valueStr');
    });

    return '{${pairs.join(',')}}';
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}

// Riverpod providers for offline service
final offlineServiceProvider = Provider<OfflineService>((ref) {
  final service = OfflineService();
  service.initialize();
  return service;
});

final connectionStatusProvider = StateProvider<ConnectionStatus>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return service.connectionStatus;
});

final syncStatsProvider = StateProvider<SyncStats>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return service.syncStats;
});

final pendingOperationsProvider =
    StateProvider<List<PendingSyncOperation>>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return service.pendingOperations;
});

final syncConflictsProvider = StateProvider<List<SyncConflict>>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return service.conflicts;
});

// Offline service notifier
final offlineServiceNotifierProvider =
    StateNotifierProvider<OfflineServiceNotifier, OfflineService>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return OfflineServiceNotifier(service);
});

class OfflineServiceNotifier extends StateNotifier<OfflineService> {
  OfflineServiceNotifier(OfflineService service) : super(service) {
    service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    // Force rebuild by creating new state
    state = state;
  }

  Future<void> queueOperation({
    required EntityType entityType,
    required SyncOperationType operationType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    await state.queueOperation(
      entityType: entityType,
      operationType: operationType,
      entityId: entityId,
      data: data,
    );
  }

  Future<void> forceSync() async {
    await state.forcSync();
  }

  Future<void> clearPendingOperations() async {
    await state.clearPendingOperations();
  }

  Future<void> resolveConflict(
      SyncConflict conflict, Map<String, dynamic> resolvedData) async {
    await state.resolveConflict(conflict, resolvedData);
  }

  @override
  void dispose() {
    state.removeListener(_onServiceUpdate);
    super.dispose();
  }
}
