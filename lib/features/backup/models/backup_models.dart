import 'package:json_annotation/json_annotation.dart';

part 'backup_models.g.dart';

/// Represents the complete backup manifest for a .bdb file
@JsonSerializable()
class BackupManifest {
  final String version;
  final String appVersion;
  final DateTime createdAt;
  final String deviceId;
  final String deviceName;
  final BackupMetadata metadata;
  final List<BackupTable> tables;
  final List<BackupFile> attachments;
  final BackupIntegrity integrity;
  final BackupEncryption? encryption;

  const BackupManifest({
    required this.version,
    required this.appVersion,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.metadata,
    required this.tables,
    required this.attachments,
    required this.integrity,
    this.encryption,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) =>
      _$BackupManifestFromJson(json);
  Map<String, dynamic> toJson() => _$BackupManifestToJson(this);
}

/// Metadata about the backup
@JsonSerializable()
class BackupMetadata {
  final BackupType type;
  final BackupScope scope;
  final int totalRecords;
  final int totalSize;
  final int compressedSize;
  final String compressionAlgorithm;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Map<String, dynamic> customData;

  const BackupMetadata({
    required this.type,
    required this.scope,
    required this.totalRecords,
    required this.totalSize,
    required this.compressedSize,
    required this.compressionAlgorithm,
    this.fromDate,
    this.toDate,
    this.customData = const {},
  });

  factory BackupMetadata.fromJson(Map<String, dynamic> json) =>
      _$BackupMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$BackupMetadataToJson(this);
}

/// Information about each table in the backup
@JsonSerializable()
class BackupTable {
  final String name;
  final String schema;
  final int recordCount;
  final int size;
  final String checksum;
  final DateTime lastModified;
  final List<String> dependencies;

  const BackupTable({
    required this.name,
    required this.schema,
    required this.recordCount,
    required this.size,
    required this.checksum,
    required this.lastModified,
    this.dependencies = const [],
  });

  factory BackupTable.fromJson(Map<String, dynamic> json) =>
      _$BackupTableFromJson(json);
  Map<String, dynamic> toJson() => _$BackupTableToJson(this);
}

/// Information about file attachments in the backup
@JsonSerializable()
class BackupFile {
  final String path;
  final String name;
  final int size;
  final String checksum;
  final String mimeType;
  final DateTime lastModified;
  final bool isCompressed;

  const BackupFile({
    required this.path,
    required this.name,
    required this.size,
    required this.checksum,
    required this.mimeType,
    required this.lastModified,
    this.isCompressed = false,
  });

  factory BackupFile.fromJson(Map<String, dynamic> json) =>
      _$BackupFileFromJson(json);
  Map<String, dynamic> toJson() => _$BackupFileToJson(this);
}

/// Integrity verification information
@JsonSerializable()
class BackupIntegrity {
  final String manifestChecksum;
  final String dataChecksum;
  final String algorithm;
  final Map<String, String> tableChecksums;
  final Map<String, String> fileChecksums;

  const BackupIntegrity({
    required this.manifestChecksum,
    required this.dataChecksum,
    required this.algorithm,
    required this.tableChecksums,
    required this.fileChecksums,
  });

  factory BackupIntegrity.fromJson(Map<String, dynamic> json) =>
      _$BackupIntegrityFromJson(json);
  Map<String, dynamic> toJson() => _$BackupIntegrityToJson(this);
}

/// Encryption information
@JsonSerializable()
class BackupEncryption {
  final String algorithm;
  final String keyDerivation;
  final String salt;
  final int iterations;
  final String iv;
  final bool isEncrypted;

  const BackupEncryption({
    required this.algorithm,
    required this.keyDerivation,
    required this.salt,
    required this.iterations,
    required this.iv,
    this.isEncrypted = true,
  });

  factory BackupEncryption.fromJson(Map<String, dynamic> json) =>
      _$BackupEncryptionFromJson(json);
  Map<String, dynamic> toJson() => _$BackupEncryptionToJson(this);
}

/// Restore progress information
@JsonSerializable()
class RestoreProgress {
  final String backupId;
  final RestoreStatus status;
  final int totalSteps;
  final int completedSteps;
  final String currentOperation;
  final double progressPercentage;
  final List<String> errors;
  final List<String> warnings;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;

  const RestoreProgress({
    required this.backupId,
    required this.status,
    required this.totalSteps,
    required this.completedSteps,
    required this.currentOperation,
    required this.progressPercentage,
    this.errors = const [],
    this.warnings = const [],
    required this.startedAt,
    this.completedAt,
    this.metadata = const {},
  });

  factory RestoreProgress.fromJson(Map<String, dynamic> json) =>
      _$RestoreProgressFromJson(json);
  Map<String, dynamic> toJson() => _$RestoreProgressToJson(this);
}

/// Backup configuration settings
@JsonSerializable()
class BackupConfig {
  final bool autoBackupEnabled;
  final Duration autoBackupInterval;
  final BackupType defaultBackupType;
  final BackupScope defaultScope;
  final bool encryptionEnabled;
  final String compressionAlgorithm;
  final int compressionLevel;
  final bool includeAttachments;
  final int maxBackupHistory;
  final String defaultExportPath;
  final List<String> excludedTables;

  const BackupConfig({
    this.autoBackupEnabled = false,
    this.autoBackupInterval = const Duration(days: 1),
    this.defaultBackupType = BackupType.full,
    this.defaultScope = BackupScope.all,
    this.encryptionEnabled = true,
    this.compressionAlgorithm = 'zstd',
    this.compressionLevel = 3,
    this.includeAttachments = true,
    this.maxBackupHistory = 10,
    this.defaultExportPath = '',
    this.excludedTables = const [],
  });

  factory BackupConfig.fromJson(Map<String, dynamic> json) =>
      _$BackupConfigFromJson(json);
  Map<String, dynamic> toJson() => _$BackupConfigToJson(this);
}

/// Backup history entry
@JsonSerializable()
class BackupHistoryEntry {
  final String id;
  final String fileName;
  final String filePath;
  final BackupMetadata metadata;
  final int fileSize;
  final DateTime createdAt;
  final BackupStatus status;
  final String? errorMessage;
  final bool isEncrypted;

  const BackupHistoryEntry({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.metadata,
    required this.fileSize,
    required this.createdAt,
    required this.status,
    this.errorMessage,
    this.isEncrypted = false,
  });

  factory BackupHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$BackupHistoryEntryFromJson(json);
  Map<String, dynamic> toJson() => _$BackupHistoryEntryToJson(this);
}

/// Enums
enum BackupType {
  @JsonValue('full')
  full,
  @JsonValue('incremental')
  incremental,
  @JsonValue('differential')
  differential,
}

enum BackupScope {
  @JsonValue('all')
  all,
  @JsonValue('business_data')
  businessData,
  @JsonValue('user_settings')
  userSettings,
  @JsonValue('sync_data')
  syncData,
  @JsonValue('custom')
  custom,
}

enum BackupStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
}

enum RestoreStatus {
  @JsonValue('preparing')
  preparing,
  @JsonValue('validating')
  validating,
  @JsonValue('extracting')
  extracting,
  @JsonValue('restoring_database')
  restoringDatabase,
  @JsonValue('restoring_files')
  restoringFiles,
  @JsonValue('finalizing')
  finalizing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
}

enum ConflictResolutionStrategy {
  @JsonValue('skip')
  skip,
  @JsonValue('overwrite')
  overwrite,
  @JsonValue('merge')
  merge,
  @JsonValue('prompt')
  prompt,
}

/// Conflict resolution data
@JsonSerializable()
class ConflictData {
  final String tableName;
  final String recordId;
  final Map<String, dynamic> existingData;
  final Map<String, dynamic> incomingData;
  final ConflictResolutionStrategy strategy;
  final Map<String, dynamic>? resolvedData;

  const ConflictData({
    required this.tableName,
    required this.recordId,
    required this.existingData,
    required this.incomingData,
    required this.strategy,
    this.resolvedData,
  });

  factory ConflictData.fromJson(Map<String, dynamic> json) =>
      _$ConflictDataFromJson(json);
  Map<String, dynamic> toJson() => _$ConflictDataToJson(this);
}