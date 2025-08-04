import 'dart:typed_data';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'sync_models.g.dart';

/// Converter for Uint8List to/from base64 string
class Uint8ListConverter implements JsonConverter<Uint8List?, String?> {
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null) return null;
    return base64Decode(json);
  }

  @override
  String? toJson(Uint8List? object) {
    if (object == null) return null;
    return base64Encode(object);
  }
}

/// Device information for P2P discovery and identification
@JsonSerializable()
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String deviceType; // mobile, desktop, tablet
  final String platform; // android, linux, ios, etc.
  final String appVersion;
  final DateTime lastSeen;
  final bool isOnline;
  final List<String> supportedTransports; // bluetooth, wifi, usb, etc.
  final Map<String, dynamic> metadata;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.appVersion,
    required this.lastSeen,
    required this.isOnline,
    required this.supportedTransports,
    this.metadata = const {},
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);
}

/// Transport types for P2P communication
enum TransportType {
  bluetooth,
  wifiDirect,
  nearbyConnections,
  mdns,
  usb,
  tcp,
}

/// Connection states for P2P sessions
enum ConnectionState {
  disconnected,
  discovering,
  connecting,
  authenticating,
  connected,
  syncing,
  error,
}

/// P2P Connection information
@JsonSerializable()
class P2PConnection {
  final String connectionId;
  final DeviceInfo remoteDevice;
  final TransportType transport;
  final ConnectionState state;
  final DateTime connectedAt;
  final String? errorMessage;
  final Map<String, dynamic> connectionMetadata;

  const P2PConnection({
    required this.connectionId,
    required this.remoteDevice,
    required this.transport,
    required this.state,
    required this.connectedAt,
    this.errorMessage,
    this.connectionMetadata = const {},
  });

  factory P2PConnection.fromJson(Map<String, dynamic> json) =>
      _$P2PConnectionFromJson(json);
  Map<String, dynamic> toJson() => _$P2PConnectionToJson(this);

  P2PConnection copyWith({
    String? connectionId,
    DeviceInfo? remoteDevice,
    TransportType? transport,
    ConnectionState? state,
    DateTime? connectedAt,
    String? errorMessage,
    Map<String, dynamic>? connectionMetadata,
  }) {
    return P2PConnection(
      connectionId: connectionId ?? this.connectionId,
      remoteDevice: remoteDevice ?? this.remoteDevice,
      transport: transport ?? this.transport,
      state: state ?? this.state,
      connectedAt: connectedAt ?? this.connectedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      connectionMetadata: connectionMetadata ?? this.connectionMetadata,
    );
  }
}

/// Sync session information
@JsonSerializable()
class SyncSession {
  final String sessionId;
  final List<String> participantDeviceIds;
  final SyncSessionState state;
  final DateTime startedAt;
  final DateTime? completedAt;
  final SyncConfiguration configuration;
  final SyncProgress progress;
  final List<SyncConflict> conflicts;
  final String? errorMessage;

  const SyncSession({
    required this.sessionId,
    required this.participantDeviceIds,
    required this.state,
    required this.startedAt,
    this.completedAt,
    required this.configuration,
    required this.progress,
    this.conflicts = const [],
    this.errorMessage,
  });

  factory SyncSession.fromJson(Map<String, dynamic> json) =>
      _$SyncSessionFromJson(json);
  Map<String, dynamic> toJson() => _$SyncSessionToJson(this);
}

/// Sync session states
enum SyncSessionState {
  initializing,
  active,
  paused,
  completed,
  failed,
  cancelled,
}

/// Sync configuration for controlling what gets synced
@JsonSerializable()
class SyncConfiguration {
  final bool syncInvoices;
  final bool syncCustomers;
  final bool syncProducts;
  final bool syncPayments;
  final bool syncReports;
  final bool syncSettings;
  final DateTime? syncFromDate;
  final DateTime? syncToDate;
  final int maxBandwidthKbps;
  final bool compressData;
  final bool encryptData;
  final List<String> excludedTables;
  final Map<String, dynamic> customFilters;

  const SyncConfiguration({
    this.syncInvoices = true,
    this.syncCustomers = true,
    this.syncProducts = true,
    this.syncPayments = true,
    this.syncReports = false,
    this.syncSettings = true,
    this.syncFromDate,
    this.syncToDate,
    this.maxBandwidthKbps = 1024,
    this.compressData = true,
    this.encryptData = true,
    this.excludedTables = const [],
    this.customFilters = const {},
  });

  factory SyncConfiguration.fromJson(Map<String, dynamic> json) =>
      _$SyncConfigurationFromJson(json);
  Map<String, dynamic> toJson() => _$SyncConfigurationToJson(this);
}

/// Sync progress tracking
@JsonSerializable()
class SyncProgress {
  final int totalItems;
  final int processedItems;
  final int successfulItems;
  final int failedItems;
  final int skippedItems;
  final double progressPercentage;
  final int bytesTransferred;
  final int totalBytes;
  final DateTime? estimatedCompletion;
  final String currentOperation;
  final Map<String, int> itemsByType;

  const SyncProgress({
    required this.totalItems,
    required this.processedItems,
    required this.successfulItems,
    required this.failedItems,
    required this.skippedItems,
    required this.progressPercentage,
    required this.bytesTransferred,
    required this.totalBytes,
    this.estimatedCompletion,
    required this.currentOperation,
    this.itemsByType = const {},
  });

  factory SyncProgress.fromJson(Map<String, dynamic> json) =>
      _$SyncProgressFromJson(json);
  Map<String, dynamic> toJson() => _$SyncProgressToJson(this);

  factory SyncProgress.initial() {
    return const SyncProgress(
      totalItems: 0,
      processedItems: 0,
      successfulItems: 0,
      failedItems: 0,
      skippedItems: 0,
      progressPercentage: 0.0,
      bytesTransferred: 0,
      totalBytes: 0,
      currentOperation: 'Initializing...',
    );
  }
}

/// Sync conflict representation
@JsonSerializable()
class SyncConflict {
  final String conflictId;
  final String itemType;
  final String itemId;
  final ConflictType type;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localModified;
  final DateTime remoteModified;
  final ConflictResolution? resolution;
  final String? resolutionNote;

  const SyncConflict({
    required this.conflictId,
    required this.itemType,
    required this.itemId,
    required this.type,
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
    this.resolution,
    this.resolutionNote,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) =>
      _$SyncConflictFromJson(json);
  Map<String, dynamic> toJson() => _$SyncConflictToJson(this);
}

/// Types of sync conflicts
enum ConflictType {
  updateUpdate, // Both sides modified
  updateDelete, // One side modified, other deleted
  deleteUpdate, // One side deleted, other modified
  duplicate, // Same item exists with different IDs
}

/// Conflict resolution strategies
enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  createBoth,
  skip,
  manual,
}

/// Sync message for P2P communication
@JsonSerializable()
class SyncMessage {
  final String messageId;
  final SyncMessageType type;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final String? signature;

  const SyncMessage({
    required this.messageId,
    required this.type,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.payload,
    this.signature,
  });

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
  Map<String, dynamic> toJson() => _$SyncMessageToJson(this);
}

/// Types of sync messages
enum SyncMessageType {
  handshake,
  authenticationRequest,
  authenticationResponse,
  syncRequest,
  syncResponse,
  dataChunk,
  acknowledgment,
  conflictNotification,
  progressUpdate,
  error,
  heartbeat,
}

/// Pairing information for device authentication
@JsonSerializable()
class DevicePairing {
  final String pairingId;
  final String localDeviceId;
  final String remoteDeviceId;
  final PairingMethod method;
  final PairingState state;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? pairingCode;
  final String? qrCode;
  @Uint8ListConverter()
  final Uint8List? sharedSecret;
  final Map<String, dynamic> metadata;

  const DevicePairing({
    required this.pairingId,
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.method,
    required this.state,
    required this.createdAt,
    this.completedAt,
    this.pairingCode,
    this.qrCode,
    this.sharedSecret,
    this.metadata = const {},
  });

  factory DevicePairing.fromJson(Map<String, dynamic> json) =>
      _$DevicePairingFromJson(json);
  Map<String, dynamic> toJson() => _$DevicePairingToJson(this);
}

/// Pairing methods
enum PairingMethod {
  qrCode,
  pinCode,
  nfc,
  automatic,
}

/// Pairing states
enum PairingState {
  initiated,
  codeGenerated,
  codeScanned,
  authenticating,
  completed,
  failed,
  expired,
}

/// Sync statistics and history
@JsonSerializable()
class SyncStats {
  final String deviceId;
  final DateTime lastSyncAt;
  final int totalSyncSessions;
  final int successfulSyncs;
  final int failedSyncs;
  final int totalItemsSynced;
  final int totalBytesTransferred;
  final Duration averageSyncDuration;
  final Map<String, int> syncsByTransport;
  final Map<String, int> syncsByType;
  final List<String> recentErrors;

  const SyncStats({
    required this.deviceId,
    required this.lastSyncAt,
    required this.totalSyncSessions,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.totalItemsSynced,
    required this.totalBytesTransferred,
    required this.averageSyncDuration,
    this.syncsByTransport = const {},
    this.syncsByType = const {},
    this.recentErrors = const [],
  });

  factory SyncStats.fromJson(Map<String, dynamic> json) =>
      _$SyncStatsFromJson(json);
  Map<String, dynamic> toJson() => _$SyncStatsToJson(this);
}
