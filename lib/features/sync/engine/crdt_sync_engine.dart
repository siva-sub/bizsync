import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crdt/vector_clock.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../models/sync_models.dart';
import '../security/encryption_service.dart';

/// CRDT-based synchronization engine for conflict-free distributed data
class CRDTSyncEngine {
  final EncryptionService _encryptionService;
  final StreamController<SyncEvent> _syncEventController =
      StreamController<SyncEvent>.broadcast();
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  final Map<String, CRDTDocument> _documents = {};
  final Map<String, VectorClock> _vectorClocks = {};
  final Map<String, HybridLogicalClock> _hlcClocks = {};
  final Map<String, SyncSession> _activeSessions = {};

  String? _deviceId;
  HybridLogicalClock? _localClock;

  CRDTSyncEngine(this._encryptionService);

  /// Initialize the sync engine
  Future<void> initialize(String deviceId) async {
    _deviceId = deviceId;
    _localClock = HybridLogicalClock(deviceId);

    debugPrint('CRDT sync engine initialized for device: $deviceId');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _activeSessions.clear();
    _documents.clear();
    _vectorClocks.clear();
    _hlcClocks.clear();

    await _syncEventController.close();
    await _progressController.close();
  }

  /// Stream of sync events
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

  /// Stream of sync progress updates
  Stream<SyncProgress> get progressUpdates => _progressController.stream;

  /// Start a new sync session
  Future<SyncSession> startSyncSession(
    List<String> participantDeviceIds,
    SyncConfiguration configuration,
  ) async {
    final sessionId = const Uuid().v4();

    final session = SyncSession(
      sessionId: sessionId,
      participantDeviceIds: participantDeviceIds,
      state: SyncSessionState.initializing,
      startedAt: DateTime.now(),
      configuration: configuration,
      progress: SyncProgress.initial(),
    );

    _activeSessions[sessionId] = session;

    _syncEventController.add(SyncEvent(
      type: SyncEventType.sessionStarted,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {'participantCount': participantDeviceIds.length},
    ));

    // Initialize sync process
    await _initializeSyncSession(session);

    return session;
  }

  /// Process incoming sync data
  Future<void> processSyncData(
    String sessionId,
    String fromDeviceId,
    SyncDataChunk dataChunk,
  ) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Sync session not found: $sessionId');
    }

    try {
      // Decrypt data if encrypted
      final decryptedData = dataChunk.encrypted
          ? await _decryptSyncData(dataChunk, fromDeviceId)
          : dataChunk.data;

      // Parse CRDT operations
      final operations = _parseCRDTOperations(decryptedData);

      // Apply operations to local state
      final conflicts = await _applyCRDTOperations(operations, fromDeviceId);

      // Update progress
      await _updateSyncProgress(sessionId, operations.length, conflicts.length);

      // Emit sync event
      _syncEventController.add(SyncEvent(
        type: SyncEventType.dataReceived,
        sessionId: sessionId,
        fromDeviceId: fromDeviceId,
        timestamp: DateTime.now(),
        data: {
          'operationsCount': operations.length,
          'conflictsCount': conflicts.length,
        },
      ));
    } catch (e) {
      debugPrint('Error processing sync data: $e');

      _syncEventController.add(SyncEvent(
        type: SyncEventType.error,
        sessionId: sessionId,
        fromDeviceId: fromDeviceId,
        timestamp: DateTime.now(),
        error: e.toString(),
      ));
    }
  }

  /// Generate sync data for transmission
  Future<SyncDataChunk> generateSyncData(String sessionId, String toDeviceId,
      {DateTime? since}) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Sync session not found: $sessionId');
    }

    try {
      // Get local changes since the specified time
      final operations = await _getLocalOperationsSince(since);

      // Serialize operations
      final operationsData = _serializeCRDTOperations(operations);

      // Compress if configured
      final finalData = session.configuration.compressData
          ? await _compressData(operationsData)
          : operationsData;

      // Encrypt if configured
      final encryptedData = session.configuration.encryptData
          ? await _encryptSyncData(finalData, toDeviceId)
          : null;

      final dataChunk = SyncDataChunk(
        chunkId: const Uuid().v4(),
        sessionId: sessionId,
        fromDeviceId: _deviceId!,
        toDeviceId: toDeviceId,
        data: encryptedData?.data ?? finalData,
        compressed: session.configuration.compressData,
        encrypted: session.configuration.encryptData,
        encryptionMetadata: encryptedData?.metadata,
        timestamp: DateTime.now(),
        operationsCount: operations.length,
      );

      _syncEventController.add(SyncEvent(
        type: SyncEventType.dataSent,
        sessionId: sessionId,
        toDeviceId: toDeviceId,
        timestamp: DateTime.now(),
        data: {
          'operationsCount': operations.length,
          'dataSize': finalData.length,
        },
      ));

      return dataChunk;
    } catch (e) {
      debugPrint('Error generating sync data: $e');
      rethrow;
    }
  }

  /// Get local document state
  CRDTDocument? getDocument(String documentId) {
    return _documents[documentId];
  }

  /// Apply local operation to a document
  Future<void> applyLocalOperation(CRDTOperation operation) async {
    // Update local clock
    _localClock!.tick();
    operation.timestamp = _localClock!.current;
    operation.deviceId = _deviceId!;

    // Apply operation locally
    final document = _documents[operation.documentId];
    if (document != null) {
      _applyOperationToDocument(document, operation);
    } else {
      // Create new document
      final newDocument = CRDTDocument(
        documentId: operation.documentId,
        documentType: operation.documentType,
        operations: [operation],
        vectorClock: VectorClock.fromDeviceId(_deviceId!),
        lastModified: DateTime.now(),
      );
      _documents[operation.documentId] = newDocument;
    }

    // Update vector clock
    final vectorClock = _vectorClocks[operation.documentId];
    if (vectorClock != null) {
      _vectorClocks[operation.documentId] = vectorClock.tickNode(_deviceId!);
    } else {
      _vectorClocks[operation.documentId] =
          VectorClock.fromDeviceId(_deviceId!).tickNode(_deviceId!);
    }

    debugPrint(
        'Applied local operation: ${operation.operationType} on ${operation.documentId}');
  }

  /// Get sync statistics
  SyncStatistics getSyncStatistics() {
    final totalDocuments = _documents.length;
    final totalOperations = _documents.values
        .fold<int>(0, (sum, doc) => sum + doc.operations.length);

    final activeSessions = _activeSessions.values
        .where((s) => s.state == SyncSessionState.active)
        .length;

    return SyncStatistics(
      totalDocuments: totalDocuments,
      totalOperations: totalOperations,
      activeSessions: activeSessions,
      vectorClocks: _vectorClocks.length,
      lastSyncTimestamp: _getLastSyncTimestamp(),
    );
  }

  // Private methods

  /// Initialize sync session
  Future<void> _initializeSyncSession(SyncSession session) async {
    try {
      // Update session state
      final activeSession = SyncSession(
        sessionId: session.sessionId,
        participantDeviceIds: session.participantDeviceIds,
        state: SyncSessionState.active,
        startedAt: session.startedAt,
        configuration: session.configuration,
        progress: session.progress,
      );

      _activeSessions[session.sessionId] = activeSession;

      // Calculate initial progress
      final totalDocuments = _documents.length;
      final initialProgress = SyncProgress(
        totalItems: totalDocuments,
        processedItems: 0,
        successfulItems: 0,
        failedItems: 0,
        skippedItems: 0,
        progressPercentage: 0.0,
        bytesTransferred: 0,
        totalBytes: _estimateTotalSyncBytes(),
        currentOperation: 'Initializing sync...',
      );

      _progressController.add(initialProgress);
    } catch (e) {
      debugPrint('Error initializing sync session: $e');
      rethrow;
    }
  }

  /// Parse CRDT operations from sync data
  List<CRDTOperation> _parseCRDTOperations(Uint8List data) {
    try {
      final json = utf8.decode(data);
      final List<dynamic> operationsList = jsonDecode(json);

      return operationsList
          .map((opJson) => CRDTOperation.fromMap(opJson))
          .toList();
    } catch (e) {
      debugPrint('Error parsing CRDT operations: $e');
      return [];
    }
  }

  /// Serialize CRDT operations for transmission
  Uint8List _serializeCRDTOperations(List<CRDTOperation> operations) {
    final operationsJson = operations.map((op) => op.toMap()).toList();
    final json = jsonEncode(operationsJson);
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Apply CRDT operations to local state
  Future<List<SyncConflict>> _applyCRDTOperations(
    List<CRDTOperation> operations,
    String fromDeviceId,
  ) async {
    final conflicts = <SyncConflict>[];

    for (final operation in operations) {
      try {
        // Update hybrid logical clock
        _localClock!.update(operation.timestamp);

        // Get or create document
        var document = _documents[operation.documentId];
        if (document == null) {
          document = CRDTDocument(
            documentId: operation.documentId,
            documentType: operation.documentType,
            operations: [],
            vectorClock: VectorClock.empty(),
            lastModified: DateTime.now(),
          );
          _documents[operation.documentId] = document;
        }

        // Check for conflicts
        final conflict = _detectConflict(document, operation);
        if (conflict != null) {
          conflicts.add(conflict);

          // Apply conflict resolution strategy
          final resolvedOperation = await _resolveConflict(conflict, operation);
          if (resolvedOperation != null) {
            _applyOperationToDocument(document, resolvedOperation);
          }
        } else {
          // No conflict, apply operation directly
          _applyOperationToDocument(document, operation);
        }

        // Update vector clock
        final vectorClock =
            _vectorClocks[operation.documentId] ?? VectorClock.empty();
        _vectorClocks[operation.documentId] =
            vectorClock.updateNode(fromDeviceId, operation.timestamp.logical);
      } catch (e) {
        debugPrint('Error applying CRDT operation: $e');

        // Create conflict for failed operation
        conflicts.add(SyncConflict(
          conflictId: const Uuid().v4(),
          itemType: operation.documentType,
          itemId: operation.documentId,
          type: ConflictType.updateUpdate,
          localData: {},
          remoteData: operation.toMap(),
          localModified: DateTime.now(),
          remoteModified:
              DateTime.fromMillisecondsSinceEpoch(operation.timestamp.wallTime),
        ));
      }
    }

    return conflicts;
  }

  /// Apply a single operation to a document
  void _applyOperationToDocument(
      CRDTDocument document, CRDTOperation operation) {
    document.operations.add(operation);
    document.lastModified = DateTime.now();

    // Update document vector clock - replace with new updated clock
    document.vectorClock = document.vectorClock
        .updateNode(operation.deviceId, operation.timestamp.logical);

    // Sort operations by timestamp for consistency
    document.operations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Detect conflicts between operations
  SyncConflict? _detectConflict(
      CRDTDocument document, CRDTOperation newOperation) {
    // Check for concurrent operations on the same field
    final concurrentOps = document.operations
        .where((op) =>
            op.fieldPath == newOperation.fieldPath &&
            op.operationType == CRDTOperationType.set &&
            newOperation.operationType == CRDTOperationType.set &&
            _areConcurrent(op.timestamp, newOperation.timestamp))
        .toList();

    if (concurrentOps.isNotEmpty) {
      final conflictingOp = concurrentOps.first;

      return SyncConflict(
        conflictId: const Uuid().v4(),
        itemType: document.documentType,
        itemId: document.documentId,
        type: ConflictType.updateUpdate,
        localData: conflictingOp.toMap(),
        remoteData: newOperation.toMap(),
        localModified: DateTime.fromMillisecondsSinceEpoch(
            conflictingOp.timestamp.wallTime),
        remoteModified: DateTime.fromMillisecondsSinceEpoch(
            newOperation.timestamp.wallTime),
      );
    }

    return null;
  }

  /// Check if two timestamps are concurrent (neither happens-before the other)
  bool _areConcurrent(HybridLogicalTimestamp a, HybridLogicalTimestamp b) {
    return !(a.happensBefore(b) || b.happensBefore(a));
  }

  /// Resolve a conflict using the configured strategy
  Future<CRDTOperation?> _resolveConflict(
    SyncConflict conflict,
    CRDTOperation remoteOperation,
  ) async {
    // For now, use last-writer-wins based on device ID (deterministic)
    final localOp = CRDTOperation.fromMap(conflict.localData);

    // Compare device IDs for deterministic resolution
    final useRemote = remoteOperation.deviceId.compareTo(localOp.deviceId) > 0;

    if (useRemote) {
      debugPrint(
          'Conflict resolved: using remote operation from ${remoteOperation.deviceId}');
      return remoteOperation;
    } else {
      debugPrint(
          'Conflict resolved: keeping local operation from ${localOp.deviceId}');
      return null; // Keep local operation
    }
  }

  /// Get local operations since a specific timestamp
  Future<List<CRDTOperation>> _getLocalOperationsSince(DateTime? since) async {
    final operations = <CRDTOperation>[];

    for (final document in _documents.values) {
      final filteredOps = document.operations.where((op) {
        if (since == null) return true;
        final opTime =
            DateTime.fromMillisecondsSinceEpoch(op.timestamp.wallTime);
        return opTime.isAfter(since);
      }).toList();

      operations.addAll(filteredOps);
    }

    // Sort by timestamp
    operations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return operations;
  }

  /// Compress data for efficient transmission
  Future<Uint8List> _compressData(Uint8List data) async {
    // Simple compression using gzip would be implemented here
    // For now, return data as-is
    return data;
  }

  /// Encrypt sync data
  Future<EncryptedSyncData> _encryptSyncData(
      Uint8List data, String toDeviceId) async {
    // Generate session key
    final sessionKey = _encryptionService.generateKey();

    // Encrypt data
    final encryptionResult = _encryptionService.encrypt(data, sessionKey);

    return EncryptedSyncData(
      data: encryptionResult.toBytes(),
      metadata: {
        'sessionKey': base64.encode(sessionKey),
        'nonce': base64.encode(encryptionResult.nonce),
      },
    );
  }

  /// Decrypt sync data
  Future<Uint8List> _decryptSyncData(
      SyncDataChunk dataChunk, String fromDeviceId) async {
    if (dataChunk.encryptionMetadata == null) {
      throw Exception('Missing encryption metadata');
    }

    final sessionKey =
        base64.decode(dataChunk.encryptionMetadata!['sessionKey']!);
    final encryptionResult = EncryptionResult.fromBytes(dataChunk.data);

    return _encryptionService.decrypt(encryptionResult, sessionKey);
  }

  /// Update sync progress
  Future<void> _updateSyncProgress(
    String sessionId,
    int operationsProcessed,
    int conflictsFound,
  ) async {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    final currentProgress = session.progress;
    final newProcessedItems =
        currentProgress.processedItems + operationsProcessed;

    final updatedProgress = SyncProgress(
      totalItems: currentProgress.totalItems,
      processedItems: newProcessedItems,
      successfulItems: currentProgress.successfulItems +
          (operationsProcessed - conflictsFound),
      failedItems: currentProgress.failedItems + conflictsFound,
      skippedItems: currentProgress.skippedItems,
      progressPercentage: (newProcessedItems /
              currentProgress.totalItems.clamp(1, double.infinity)) *
          100,
      bytesTransferred: currentProgress.bytesTransferred,
      totalBytes: currentProgress.totalBytes,
      currentOperation: 'Processing operations...',
    );

    _progressController.add(updatedProgress);
  }

  /// Estimate total bytes for sync progress calculation
  int _estimateTotalSyncBytes() {
    return _documents.values.fold<int>(0, (sum, doc) {
      return sum + (doc.operations.length * 1024); // Rough estimate
    });
  }

  /// Get last sync timestamp
  DateTime? _getLastSyncTimestamp() {
    DateTime? latest;

    for (final document in _documents.values) {
      if (latest == null || document.lastModified.isAfter(latest)) {
        latest = document.lastModified;
      }
    }

    return latest;
  }
}

/// CRDT document representation
class CRDTDocument {
  final String documentId;
  final String documentType;
  final List<CRDTOperation> operations;
  VectorClock vectorClock;
  DateTime lastModified;

  CRDTDocument({
    required this.documentId,
    required this.documentType,
    required this.operations,
    required this.vectorClock,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'documentType': documentType,
      'operations': operations.map((op) => op.toMap()).toList(),
      'vectorClock': vectorClock.toMap(),
      'lastModified': lastModified.millisecondsSinceEpoch,
    };
  }

  factory CRDTDocument.fromMap(Map<String, dynamic> map) {
    return CRDTDocument(
      documentId: map['documentId'],
      documentType: map['documentType'],
      operations: (map['operations'] as List)
          .map((opMap) => CRDTOperation.fromMap(opMap))
          .toList(),
      vectorClock: VectorClock.fromMap(map['vectorClock']),
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['lastModified']),
    );
  }
}

/// CRDT operation types
enum CRDTOperationType {
  set,
  insert,
  delete,
  move,
  increment,
  decrement,
}

/// CRDT operation
class CRDTOperation {
  final String operationId;
  final String documentId;
  final String documentType;
  final CRDTOperationType operationType;
  final String fieldPath;
  final dynamic value;
  final dynamic previousValue;
  late String deviceId;
  late HybridLogicalTimestamp timestamp;
  final Map<String, dynamic> metadata;

  CRDTOperation({
    String? operationId,
    required this.documentId,
    required this.documentType,
    required this.operationType,
    required this.fieldPath,
    this.value,
    this.previousValue,
    String? deviceId,
    HybridLogicalTimestamp? timestamp,
    this.metadata = const {},
  }) : operationId = operationId ?? const Uuid().v4() {
    if (deviceId != null) this.deviceId = deviceId;
    if (timestamp != null) this.timestamp = timestamp;
  }

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'documentId': documentId,
      'documentType': documentType,
      'operationType': operationType.name,
      'fieldPath': fieldPath,
      'value': value,
      'previousValue': previousValue,
      'deviceId': deviceId,
      'timestamp': timestamp.toMap(),
      'metadata': metadata,
    };
  }

  factory CRDTOperation.fromMap(Map<String, dynamic> map) {
    return CRDTOperation(
      operationId: map['operationId'],
      documentId: map['documentId'],
      documentType: map['documentType'],
      operationType: CRDTOperationType.values
          .firstWhere((type) => type.name == map['operationType']),
      fieldPath: map['fieldPath'],
      value: map['value'],
      previousValue: map['previousValue'],
      deviceId: map['deviceId'],
      timestamp: HybridLogicalTimestamp.fromMap(map['timestamp']),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

/// Sync data chunk for transmission
class SyncDataChunk {
  final String chunkId;
  final String sessionId;
  final String fromDeviceId;
  final String toDeviceId;
  final Uint8List data;
  final bool compressed;
  final bool encrypted;
  final Map<String, String>? encryptionMetadata;
  final DateTime timestamp;
  final int operationsCount;

  const SyncDataChunk({
    required this.chunkId,
    required this.sessionId,
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.data,
    required this.compressed,
    required this.encrypted,
    this.encryptionMetadata,
    required this.timestamp,
    required this.operationsCount,
  });
}

/// Encrypted sync data
class EncryptedSyncData {
  final Uint8List data;
  final Map<String, String> metadata;

  const EncryptedSyncData({
    required this.data,
    required this.metadata,
  });
}

/// Sync event types
enum SyncEventType {
  sessionStarted,
  sessionCompleted,
  sessionFailed,
  dataSent,
  dataReceived,
  conflictDetected,
  conflictResolved,
  error,
}

/// Sync event
class SyncEvent {
  final SyncEventType type;
  final String sessionId;
  final String? fromDeviceId;
  final String? toDeviceId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final String? error;

  const SyncEvent({
    required this.type,
    required this.sessionId,
    this.fromDeviceId,
    this.toDeviceId,
    required this.timestamp,
    this.data,
    this.error,
  });
}

/// Sync statistics
class SyncStatistics {
  final int totalDocuments;
  final int totalOperations;
  final int activeSessions;
  final int vectorClocks;
  final DateTime? lastSyncTimestamp;

  const SyncStatistics({
    required this.totalDocuments,
    required this.totalOperations,
    required this.activeSessions,
    required this.vectorClocks,
    this.lastSyncTimestamp,
  });
}
